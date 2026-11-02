#!/bin/bash
# Builds autounattend.iso from unattend/, filling __PASSWORD__ from credentials.txt
# ("password: ..." line), to $1 or ./autounattend.iso. Refuses to write an ISO with the placeholder left in.
set -euo pipefail
out=$(cd "$(dirname "${1:-.}")" && pwd)/$(basename "${1:-autounattend.iso}")
cd "$(dirname "$0")"
pw=$(sed -n 's/^password: *//p' credentials.txt)
[ -n "$pw" ] || { echo "no password line in credentials.txt" >&2; exit 1; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
cp unattend/autounattend.xml unattend/first.ps1 unattend/setup.ps1 "$t/"
PW="$pw" python3 -c 'import os,sys;p=sys.argv[1];s=open(p).read();open(p,"w").write(s.replace("__PASSWORD__",os.environ["PW"]))' "$t/autounattend.xml"
if grep -q __PASSWORD__ "$t/autounattend.xml"; then echo "placeholder left in answer file" >&2; exit 1; fi
rm -f "$out"
hdiutil makehybrid -quiet -iso -joliet -default-volume-name UNATTEND -o "$out" "$t"
echo "built $out"
