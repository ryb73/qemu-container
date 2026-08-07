#!/bin/bash
set -euo pipefail

QEMU_PATH=$(which qemu-system-aarch64)
QEMU_REALPATH=$(realpath "${QEMU_PATH}")
QEMU_PREFIX="$(dirname "$(dirname "${QEMU_REALPATH}")")/share/qemu"
FIRMWARE="${QEMU_PREFIX}/edk2-aarch64-code.fd"

for f in "${FIRMWARE}" efivars.fd debian-12-genericcloud-arm64.qcow2 cloud-init.iso; do
  if [[ ! -f "${f}" ]]; then
    echo "Error: missing file: ${f}"
    echo "Run ./setup.sh first."
    exit 1
  fi
done

qemu-system-aarch64 \
  -M virt,accel=hvf \
  -cpu host \
  -smp 2 \
  -m 2048 \
  -drive if=pflash,format=raw,file="${FIRMWARE}",readonly=on \
  -drive if=pflash,format=raw,file=efivars.fd \
  -drive file=debian-12-genericcloud-arm64.qcow2,if=virtio,format=qcow2 \
  -drive file=cloud-init.iso,if=virtio,media=cdrom \
  -display none \
  -serial file:vm.log \
  -daemonize \
  -pidfile qemu.pid \
  -monitor unix:monitor.sock,server,nowait \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0

SSH_TARGET="debian@localhost"
SSH_PORT=2222
SSH_OPTS=(-p "${SSH_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

# -daemonize blocks until QEMU is fully initialized, so the PID file is ready
# immediately after the command returns. set -euo pipefail handles startup failures.
PID=$(cat qemu.pid)
echo "VM started (PID ${PID})"

SSH_WAIT_TIMEOUT=60

echo "==> Waiting for SSH"
SECONDS=0
until ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o ConnectTimeout=1 "${SSH_TARGET}" true 2>/dev/null; do
  if (( SECONDS >= SSH_WAIT_TIMEOUT )); then
    echo "Error: timed out after ${SSH_WAIT_TIMEOUT}s waiting for SSH. Check vm.log." >&2
    exit 1
  fi
  sleep 0.25
done

echo "==> Waiting for cloud-init to finish"
ssh "${SSH_OPTS[@]}" -o ConnectTimeout=5 "${SSH_TARGET}" 'cloud-init status --wait'

echo "VM ready. SSH with: ssh -p ${SSH_PORT} ${SSH_TARGET}"
