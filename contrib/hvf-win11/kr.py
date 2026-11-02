# Reads the HAL timer list from a running guest over QMP. /tmp/addrs.txt holds
# "symbol rva" lines from the public PDB of that exact ntoskrnl build.
import sys,re
sys.path.insert(0,'.')
import vmctl
s,f=vmctl.connect()
def hmp(c): return vmctl.cmd(f,"human-monitor-command",**{"command-line":c})
A=dict(l.split() for l in open('/tmp/addrs.txt')); A={k:int(v,16) for k,v in A.items()}
def rdq(va,n=1):
    o=hmp(f"x /{n}gx {va:#x}"); r=[]
    for l in o.splitlines():
        p=l.split(':')
        if len(p)>1: r+=[int(x,16) for x in p[1].split()]
    return r
reg=hmp("info registers")
idt=int(re.search(r'IDT=\s*([0-9a-f]+)',reg).group(1),16)
a,b=rdq(idt,2)
h=(a&0xffff)|((a>>48)<<16)|((b&0xffffffff)<<32)
print('idt',hex(idt),'handler0',hex(h))
for nm in ['KiDivideErrorFault','KiDivideErrorFaultShadow']:
    if nm in A:
        base=h-A[nm]
        if base&0xfff==0:
            m=rdq(base)[0]&0xffff
            print(nm,'base',hex(base),'MZ' if m==0x5a4d else hex(m))
            if m==0x5a4d: break
print('count',rdq(base+A['HalpRegisteredTimerCount'])[0]&0xffffffff,'lastProblem',rdq(base+A['HalpTimerLastProblem'])[0]&0xffffffff)
print('HvPresent',rdq(base+A['HalpHvPresent'])[0]&0xff,'forced',rdq(base+A['HalpTimerPlatformClockSourceForced'])[0]&0xff)
clk=rdq(base+A['HalpClockTimer'])[0]; print('clock timer',hex(clk))
head=base+A['HalpRegisteredTimers']; p=rdq(head)[0]; n=0
while p!=head and n<20:
    d=rdq(p,40)
    flags=rdq(p+0xb8)[0]&0xffffffff; freq=rdq(p+0xc0)[0]; caps=rdq(p+0xe0)[0]; typ=caps>>32; caps&=0xffffffff
    print(f"timer {p:#x} {'<-CLOCK ' if p==clk else ''}type={typ} caps={caps:#x} state={flags:#x} freq={freq}")
    p=d[0]; n+=1

for n in ["HalpApicX2Mode","HalpInterruptX2ApicPolicy","HalpIommuX2ApicSupport"]:
    print(n, hex(rdq(base+A[n])[0]&0xffffffff))
