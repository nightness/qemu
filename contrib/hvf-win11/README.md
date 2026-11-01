# Windows 11 x64 with a vTPM on an Intel Mac (QEMU + HVF)

Work in progress. Target machine: 2017 MacBook Pro 15" (i7-7700HQ, 16 GB),
macOS 15 via OpenCore Legacy Patcher, QEMU 11.1.3, swtpm 0.10.2.

## Status

Not finished. Windows reached the sign-in screen and accepted its password
on an existing test install, but only with the workarounds below, and a
clean install has not yet been done this way. The TPM is not fully working.

## Changes in this branch

- `hw/tpm/tpm_tis_isa.c`: removes PPI. Without this, OVMF freezes at
  `[TPM2PP] mPpi=FED45000` under HVF. A workaround, not an upstreamable fix.
- `target/i386/hvf/hvf.c`: debug VM exit counters. Remove for real use.
- `contrib/hvf-win11/`: VM launch script, CPU profile and QMP helpers.

## Findings

| Symptom | Cause | Action |
|---|---|---|
| Black screen | `-vga std` shows nothing under HVF on Intel | `-vga none -device ramfb` |
| BSOD 0xA | `-cpu host` under HVF (UTM issue #2368) | `kabylake.env` CPU profile |
| Slow clock reads, high idle CPU | Windows reads the HPET through VM exits when the hypervisor is visible | `+invtsc,-hypervisor` |
| "Why did my PC restart?" | OOBE watchdog restarts setup 180 s after monitor event 103 while the UI is still working | See below |

`-hypervisor` measurements on the stuck OOBE screen, compared with the same
profile with the hypervisor bit visible:

| Measure | Visible | Hidden |
|---|---|---|
| QueryPerformanceCounter read | 133 us | about 1 us |
| `Sleep(1)` | 135 ms | 31 ms |
| Idle host CPU | about 80% | about 50% |

## OOBE watchdog

`UserOOBE.dll` (OOBE Monitor, in `taskhostw`) logged
`timer expired for event: 103` and ordered a restart 180-181 s after event
103 on every run examined. See `C:\Windows\Panther\UnattendGC\setupact.log`.

One run passed with a Defender exclusion for `C:\` and the virtual network
link down. Both were changed at once, so which one mattered is unknown.

To re-run OOBE without reinstalling, set
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\RecoveryOOBEEnabled` to
0 and reboot. Do this on test installs only.

## Known problems

- TPM: Event 15 (status `0xC0000034`), `Get-Tpm` fails with `0x80284001`,
  not ready for attestation. May relate to the PPI change; unproven.
- HAL Event 17: the clock interrupt uses a platform timer instead of a
  per-processor source.
- HVF hides `tsc-deadline`, `invpcid`, `spec-ctrl` and `xsavec`, and caps
  CPUID at leaf 0xD.
- Secure Boot is off.

## Usage

Build `qemu-system-x86_64`, copy it next to `start.sh` as
`qemu-system-x86_64-tpmfix`, then:

    . ./kabylake.env && ./start.sh

Replace the binary with `rm` then `cp`. Copying over it in place makes macOS
kill it silently. `start.sh` attaches `autounattend.iso` when present; an
answer file that wipes disk 0 will destroy the disk if booted from CD.
