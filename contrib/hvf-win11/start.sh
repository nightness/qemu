#!/bin/bash
# Windows 11 x64 VM on the MacBook (Intel i7, Apple Hypervisor): 6 threads, 8 GB RAM, 140 GB disk, virtual TPM 2.0.
# From the Mac mini: ssh -J macbook -p 2222 nightness@localhost   |  RDP: localhost:3389 on the MacBook
set -euo pipefail
# swtpm_setup runs swtpm from PATH, which lacks Homebrew's prefix under launchd.
export PATH=/usr/local/bin:$PATH
cd "$(dirname "$0")"
. ./kabylake.env
# ACCEL=tcg selects pure emulation; the default is hvf.
if [ "${ACCEL:-hvf}" = tcg ]; then
  ACC=(-accel tcg,thread=multi,tb-size=1024 -cpu Broadwell-v4,-pcid,-tsc-deadline,-invpcid,-spec-ctrl -smp 8)
else
  ACC=(-accel hvf -cpu "$CPU" -smp "${SMP:-6}")
fi
# First run: manufacture the vTPM with EK and platform certificates in an empty
# directory (swtpm_setup can fail in one holding other files), and copy secure vars.
if [ ! -f tpm/tpm2-00.permall ]; then
  t=$(mktemp -d)
  /usr/local/bin/swtpm_setup --tpm2 --tpmstate "$t" --create-ek-cert --create-platform-cert --lock-nvram --overwrite
  mkdir -p tpm; cp "$t/tpm2-00.permall" tpm/; rm -rf "$t"
fi
[ -f vars.fd ] || cp fw/OVMF_VARS.secboot.fd vars.fd
/usr/local/bin/swtpm socket --tpm2 --tpmstate dir=tpm --ctrl type=unixio,path=tpm/swtpm.sock --daemon --terminate
cd=()
[ -f windows.iso ] && cd+=(-drive file=windows.iso,media=cdrom,if=none,id=cd0,readonly=on -device ide-cd,drive=cd0,bus=ide.0,bootindex=1)
[ -f autounattend.iso ] && cd+=(-drive file=autounattend.iso,media=cdrom,if=none,id=cd1,readonly=on -device ide-cd,drive=cd1,bus=ide.1)
rm -f qmp.sock
exec ./qemu-system-x86_64-tpmfix -L /usr/local/share/qemu \
  -name "Windows 11 x64 (MacBook)" \
  -M "q35${MOPT:-}" "${ACC[@]}" -m 8G -overcommit mem-lock=on \
  -drive if=pflash,format=raw,readonly=on,file=${CODEFD:-fw/OVMF_CODE.fd} \
  -drive if=pflash,format=raw,file=${VARSFD:-vars.fd} \
  ${EXTRA:-} -vga none -device virtio-vga,xres=${XRES:-1440},yres=${YRES:-900} -device qemu-xhci -device usb-kbd -device usb-tablet \
  -drive file=disk.qcow2,if=none,id=hd0,format=qcow2,discard=unmap \
  -device nvme,drive=hd0,serial=winmbp,bootindex=${DISKBOOT:-0} \
  ${cd[@]+"${cd[@]}"} \
  -nic user,model=e1000e,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:3389-:3389 \
  -chardev socket,id=chrtpm,path=tpm/swtpm.sock \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -rtc base=localtime \
  -qmp unix:qmp.sock,server=on,wait=off \
  -display cocoa,zoom-to-fit=on ${FULLSCREEN:+-full-screen}
