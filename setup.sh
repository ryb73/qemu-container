#!/bin/bash
set -euo pipefail

DEBIAN_IMAGE="debian-12-genericcloud-arm64.qcow2"
DEBIAN_URL="https://cloud.debian.org/images/cloud/bookworm/latest/${DEBIAN_IMAGE}"

QEMU_PREFIX="$(dirname "$(dirname "$(realpath "$(which qemu-system-aarch64)")")")/share/qemu"
FIRMWARE="${QEMU_PREFIX}/edk2-aarch64-code.fd"

if [ ! -f "$FIRMWARE" ]; then
  echo "Error: UEFI firmware not found at ${FIRMWARE}"
  exit 1
fi

echo "==> Setting up UEFI variable store"
VARS_SRC="${QEMU_PREFIX}/edk2-aarch64-vars.fd"
if [ ! -f efivars.fd ]; then
  if [ -f "$VARS_SRC" ]; then
    cp "$VARS_SRC" efivars.fd
  else
    # EDK2 will initialize an empty store on first boot
    dd if=/dev/zero of=efivars.fd bs=1m count=64 2>/dev/null
  fi
fi

echo "==> Downloading Debian 12 ARM64 cloud image"
if [ ! -f "$DEBIAN_IMAGE" ]; then
  curl -L --progress-bar -o "$DEBIAN_IMAGE" "$DEBIAN_URL"
else
  echo "    Already exists, skipping download"
fi

echo "==> Resizing disk to 20GB"
qemu-img resize "$DEBIAN_IMAGE" 20G

echo "==> Creating cloud-init ISO"
CIDATA_TMP=$(mktemp -d)
cp cloud-init/meta-data cloud-init/user-data "$CIDATA_TMP/"
hdiutil makehybrid -o cloud-init.iso -hfs -joliet -iso \
  -default-volume-name cidata "$CIDATA_TMP"
rm -rf "$CIDATA_TMP"

echo ""
echo "Done. Boot with: ./start.sh"
echo "SSH with:        ssh -p 2222 -o StrictHostKeyChecking=no debian@localhost"
echo ""
echo "First boot takes ~2-3 min while cloud-init installs packages."
