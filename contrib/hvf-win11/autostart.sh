#!/bin/bash
# Started by ~/Library/LaunchAgents/com.nightness.win11-vm.plist at login: run the
# Windows 11 VM full screen unless it is already running.
cd "$(dirname "$0")"
if pgrep -f 'qemu-system-x86_64-tpmfix.*Windows 11 x64' >/dev/null; then
  echo "$(date) VM already running"; exit 0
fi
echo "$(date) starting VM"
FULLSCREEN=1 exec ./start.sh
