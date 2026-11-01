import sys,vmctl
s,f=vmctl.connect()
for c in sys.argv[1:]:
    r=vmctl.cmd(f,"human-monitor-command",**{"command-line":c}); print(c,"->",r[:1500])
