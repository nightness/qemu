set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends gcc-x86-64-linux-gnu g++-x86-64-linux-gnu gcc g++ make nasm acpica-tools uuid-dev python3 python3-venv git ca-certificates >/dev/null
git clone -q --depth 1 --branch edk2-stable202608 --recurse-submodules --shallow-submodules https://github.com/tianocore/edk2.git /e
cd /e
export GCC5_X64_PREFIX=x86_64-linux-gnu- GCC_X64_PREFIX=x86_64-linux-gnu-
make -C BaseTools -j6 >/dev/null
. ./edksetup.sh >/dev/null
mkdir -p /xb; for t in gcc g++ cpp ld ar nm objcopy objdump strip ranlib gcc-ar gcc-nm gcc-ranlib; do [ -x /usr/bin/x86_64-linux-gnu-$t ] && ln -sf /usr/bin/x86_64-linux-gnu-$t /xb/$t; done; export PATH=/xb:$PATH; gcc -dumpmachine
build -a X64 -t GCC -b RELEASE -n 6 -p OvmfPkg/OvmfPkgX64.dsc \
  -D SECURE_BOOT_ENABLE=TRUE -D SMM_REQUIRE=FALSE -D TPM2_ENABLE=TRUE -D TPM1_ENABLE=FALSE -D FD_SIZE_IN_KB=4096 \
  -D NETWORK_HTTP_BOOT_ENABLE=FALSE -D NETWORK_TLS_ENABLE=FALSE >/out/build.log 2>&1 || { tail -30 /out/build.log; exit 1; }
cp Build/OvmfX64/RELEASE_GCC/FV/OVMF_CODE.fd Build/OvmfX64/RELEASE_GCC/FV/OVMF_VARS.fd /out/
python3 -m venv /v && /v/bin/pip -q install virt-firmware
cd /out && /v/bin/virt-fw-vars --input OVMF_VARS.fd --output OVMF_VARS.secboot.fd --enroll-redhat --secure-boot
/v/bin/virt-fw-vars --input OVMF_VARS.secboot.fd --print 2>/dev/null | grep -iE 'SecureBoot|^name|PK|KEK|db |subject|CN=' | head -30 > /out/vars.txt
echo edk2-stable202608 > /out/tag.txt; ls -l /out
