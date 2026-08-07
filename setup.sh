#!/bin/bash
set -euo pipefail

DEBIAN_IMAGE="debian-12-genericcloud-arm64.qcow2"
DEBIAN_URL="https://cloud.debian.org/images/cloud/bookworm/latest/${DEBIAN_IMAGE}"

QEMU_PATH=$(which qemu-system-aarch64)
QEMU_REALPATH=$(realpath "${QEMU_PATH}")
QEMU_PREFIX="$(dirname "$(dirname "${QEMU_REALPATH}")")/share/qemu"
FIRMWARE="${QEMU_PREFIX}/edk2-aarch64-code.fd"

if [[ ! -f "${FIRMWARE}" ]]; then
  echo "Error: UEFI firmware not found at ${FIRMWARE}"
  exit 1
fi

echo "==> Setting up UEFI variable store"
VARS_SRC="${QEMU_PREFIX}/edk2-aarch64-vars.fd"
if [[ ! -f efivars.fd ]]; then
  if [[ -f "${VARS_SRC}" ]]; then
    cp "${VARS_SRC}" efivars.fd
  else
    # EDK2 will initialize an empty store on first boot
    dd if=/dev/zero of=efivars.fd bs=1m count=64 2>/dev/null
  fi
fi

echo "==> Downloading Debian 12 ARM64 cloud image"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/qemu-vm-images"
CACHED_IMAGE="${CACHE_DIR}/${DEBIAN_IMAGE}"
NEEDS_PROVISIONING_BOOT=false
if [[ ! -f "${DEBIAN_IMAGE}" ]]; then
  if [[ ! -f "${CACHED_IMAGE}" ]]; then
    mkdir -p "${CACHE_DIR}"
    curl -L --progress-bar -o "${CACHED_IMAGE}.tmp" "${DEBIAN_URL}"
    mv "${CACHED_IMAGE}.tmp" "${CACHED_IMAGE}"
  else
    echo "    Using cached image at ${CACHED_IMAGE}"
  fi
  cp "${CACHED_IMAGE}" "${DEBIAN_IMAGE}"
  NEEDS_PROVISIONING_BOOT=true
else
  echo "    Already exists, skipping download"
fi

echo "==> Resizing disk to 20GB"
qemu-img resize "${DEBIAN_IMAGE}" 20G

echo "==> Creating cloud-init ISO"
CIDATA_TMP=$(mktemp -d)
cp cloud-init/meta-data cloud-init/user-data "${CIDATA_TMP}/"
hdiutil makehybrid -o cloud-init.iso -hfs -joliet -iso \
  -default-volume-name cidata "${CIDATA_TMP}"
rm -rf "${CIDATA_TMP}"

if [[ "${NEEDS_PROVISIONING_BOOT}" == "true" ]]; then
  # rootless podman defaults to the systemd cgroup manager, which asks the
  # user's systemd instance (over D-Bus) to create a transient scope for
  # each container; that instance only starts on login, or when lingering
  # is enabled for the user (cloud-init/user-data does this via
  # `loginctl enable-linger`). Lingering activates immediately for logind
  # itself, but the D-Bus session that podman needs isn't reliably up in
  # time for commands run later in this same boot. Booting once here and
  # shutting down means the VM is already past a clean boot with lingering
  # in effect by the time start.sh is used for real, so podman sees a
  # proper active session instead of hitting Polkit's "Interactive
  # authentication required" on an SSH session it won't auto-approve.
  echo "==> Booting once to run cloud-init provisioning"
  ./start.sh
  echo "==> Shutting down after provisioning boot"
  ./stop.sh
fi
