#!/bin/bash
# Windows 11 x64 VM on the MacBook (Intel i7, Apple Hypervisor): 6 threads, 8 GB RAM, 140 GB disk, virtual TPM 2.0.
# From the Mac mini: ssh -J macbook -p 2222 nightness@localhost   |  RDP: localhost:3389 on the MacBook
set -euo pipefail
# ACCEL=tcg for the one-time install phase (Intel + HVF + TPM freezes until Windows has booted once),
# default hvf (hardware acceleration) for normal use.
if [ "${ACCEL:-hvf}" = tcg ]; then
  ACC=(-accel tcg,thread=multi,tb-size=1024 -cpu Broadwell-v4,-pcid,-tsc-deadline,-invpcid,-spec-ctrl -smp 8)
else
  ACC=(-accel hvf -cpu "${CPU:-Broadwell-v4,-pcid,-tsc-deadline,-invpcid,-spec-ctrl}" -smp "${SMP:-6}")
fi
cd "$(dirname "$0")"
Q=/usr/local/share/qemu
mkdir -p tpm
/usr/local/bin/swtpm socket --tpm2 --tpmstate dir=tpm --ctrl type=unixio,path=tpm/swtpm.sock --daemon --terminate
cd=()
[ -f windows.iso ] && cd+=(-drive file=windows.iso,media=cdrom,if=none,id=cd0,readonly=on -device ide-cd,drive=cd0,bus=ide.0,bootindex=1)
[ -f autounattend.iso ] && cd+=(-drive file=autounattend.iso,media=cdrom,if=none,id=cd1,readonly=on -device ide-cd,drive=cd1,bus=ide.1)
rm -f qmp.sock
exec ./qemu-system-x86_64-tpmfix -L /usr/local/share/qemu \
  -name "Windows 11 x64 (MacBook)" \
  -M "q35${MOPT:-}" "${ACC[@]}" -m 8G \
  -drive if=pflash,format=raw,readonly=on,file=$Q/edk2-x86_64-code.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -vga none -device ramfb -device qemu-xhci -device usb-kbd -device usb-tablet \
  -drive file=disk.qcow2,if=none,id=hd0,format=qcow2,discard=unmap \
  -device nvme,drive=hd0,serial=winmbp,bootindex=${DISKBOOT:-0} \
  "${cd[@]}" \
  -nic user,model=e1000e,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:3389-:3389 \
  -chardev socket,id=chrtpm,path=tpm/swtpm.sock \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -rtc base=localtime \
  -qmp unix:qmp.sock,server=on,wait=off \
  -display cocoa,zoom-to-fit=on
