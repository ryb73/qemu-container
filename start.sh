#!/bin/bash
set -euo pipefail

QEMU_PREFIX="$(dirname "$(dirname "$(realpath "$(which qemu-system-aarch64)")")")/share/qemu"
FIRMWARE="${QEMU_PREFIX}/edk2-aarch64-code.fd"

for f in "$FIRMWARE" efivars.fd debian-12-genericcloud-arm64.qcow2 cloud-init.iso; do
  if [ ! -f "$f" ]; then
    echo "Error: missing file: $f"
    echo "Run ./setup.sh first."
    exit 1
  fi
done

exec qemu-system-aarch64 \
  -M virt,accel=hvf \
  -cpu host \
  -smp 2 \
  -m 2048 \
  -drive if=pflash,format=raw,file="${FIRMWARE}",readonly=on \
  -drive if=pflash,format=raw,file=efivars.fd \
  -drive file=debian-12-genericcloud-arm64.qcow2,if=virtio,format=qcow2 \
  -drive file=cloud-init.iso,if=virtio,media=cdrom \
  -nographic \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
