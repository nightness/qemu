# Windows 11 x64 with a vTPM on an Intel Mac (QEMU + HVF)

Target machine: 2017 MacBook Pro 15" (i7-7700HQ, 16 GB), macOS 15 via OpenCore
Legacy Patcher, QEMU 11.1.3, swtpm 0.10.2, OVMF edk2-stable202608.

## Status

Tested on one existing install: boots to SSH in 30-40 s, with Secure Boot on
and a working TPM. A full unattended install from a blank disk, with none of
the earlier workarounds, is still being validated.

## Causes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| OVMF freezes at `[TPM2PP] mPpi=FED45000` | The 0x400-byte PPI region is not page-sized, so HVF leaves it unmapped and accesses reach its instruction emulator | `hw/tpm/tpm_ppi.c`: map a whole page |
| TPM Event 15 (`0xC0000034`), `Get-Tpm` fails `0x80284001` | Observed without PPI; both cleared when PPI was restored | The PPI fix above |
| Not ready for attestation | TPM state has no EK certificate | `swtpm_setup --create-ek-cert --create-platform-cert --lock-nvram` (done by `start.sh`) |
| Very slow; HAL Event 17 | Windows only considers the APIC timer as its clock when CPUID leaf 0xA reports a PMU, so it used an HPET-backed virtual timer | `pmu=on` with `target/i386/hvf`: host leaf 0xA, PMU MSRs as non-counting registers |
| Slow clock reads | Windows reads the HPET through VM exits when the hypervisor is visible | `+invtsc,-hypervisor` |
| BSOD 0xA | `-cpu host` under HVF (UTM issue #2368) | `kabylake.env` CPU profile |
| Black screen | `-vga std` shows nothing under HVF on Intel | `-vga none -device ramfb` |
| "Why did my PC restart?" | OOBE monitor restarts setup 180 s after monitor event 103 while the UI is still working | See below |
| Secure Boot unavailable | QEMU's secure firmware requires SMM, which HVF lacks | `build-ovmf-secboot.sh`: `SECURE_BOOT_ENABLE=TRUE SMM_REQUIRE=FALSE` |
| OpenSSH capability install hangs | Not determined; stalled twice at the same point | Install the signed Win32-OpenSSH MSI instead |

Measured on the same disk, before and after the PMU change:

| Measure | Before | After |
|---|---|---|
| Boot to lock screen | about 8 min | about 90 s |
| `Sleep(1)` under load | 188 ms | 18 ms |
| 1M PowerShell loop | 2.7 s | 0.2 s |

## How the clock cause was found

`HalpTimerFindIdealClockSource` in `ntoskrnl.exe` only searches for a timer with
the APIC's capabilities when `HalpProfileInterface` is not the default.
`HalpInitializeProfiling` sets it only for GenuineIntel with CPUID leaf 0xA
version >= 1, a non-zero event vector length and core cycles available. `kr.py`
reads the registered timers and current clock from a running guest.

## OOBE watchdog

`UserOOBE.dll` logged `timer expired for event: 103` and ordered a restart
180-181 s after event 103 on every failing run examined. See
`C:\Windows\Panther\UnattendGC\setupact.log`. To re-run OOBE on a test install,
set `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\RecoveryOOBEEnabled`
to 0 and reboot.

## Limitations

- Guest profilers that use hardware counters get no samples.
- Without SMM, a compromised guest kernel can write the UEFI variable flash, so
  Secure Boot variables are not protected against it.
- `build-ovmf-secboot.sh` enrolls keys with `virt-fw-vars --enroll-redhat`: Red
  Hat's Platform Key, with Microsoft's keys for Windows.
- x2APIC stays off: Windows requires an x2APIC-capable IOMMU or Hyper-V host, and
  adding `intel-iommu,intremap=on` did not enable it in testing.
- Windows does not use the TSC-deadline timer here. It is implemented because the
  real CPU has it.

## Usage

Build `qemu-system-x86_64` and copy it next to `start.sh` as
`qemu-system-x86_64-tpmfix`. Run `build-ovmf-secboot.sh` in an arm64 Ubuntu 24.04
container with `/out` mounted, and copy `OVMF_CODE.fd` and
`OVMF_VARS.secboot.fd` to `fw/`. Then run `./start.sh`.

Replace the binary with `rm` then `cp`. Copying over it in place makes macOS kill
it silently. `start.sh` attaches `autounattend.iso` when present; an answer file
that wipes disk 0 destroys the disk if booted from CD.
