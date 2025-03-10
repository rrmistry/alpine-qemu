#!/bin/bash
set -e

# Variables
ALPINE_VERSION="3.21"
ALPINE_VERSION_LONG="${ALPINE_VERSION}.2"
RELEASE="r0"
VM_NAME="alpine-vm"
DISK_SIZE="20G"
MEMORY="4096"
CPUS="4"

if [ ! -f "${VM_NAME}.qcow2" ]; then
  # Download Alpine cloud image (BIOS variant)
  echo "Downloading Alpine cloud image..."
  curl "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/generic_alpine-${ALPINE_VERSION_LONG}-x86_64-bios-cloudinit-${RELEASE}.qcow2" --output "${VM_NAME}.qcow2"
  # Example:
  # https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2

  qemu-img resize "${VM_NAME}.qcow2" ${DISK_SIZE}
else
  echo "VM image '${VM_NAME}.qcow2' already exists. Skipping download."
fi

SEED_FILE_NAME="cloud-init-seed.img"
if [ ! -f "$SEED_FILE_NAME" ]; then
  echo "File not found. Downloading $SEED_FILE_NAME..."
  curl -L "https://github.com/rrmistry/alpine-qemu/releases/latest/download/cloud-init-seed.img" --output ${SEED_FILE_NAME}
else
  echo "$SEED_FILE_NAME already exists. Skipping download."
fi

# Determine the host CPU architecture and select the appropriate QEMU binary.
arch=$(uname -m)
case "$arch" in
  x86_64)
    QEMU_BIN="qemu-system-x86_64"
    ;;
  i686)
    QEMU_BIN="qemu-system-i386"
    ;;
  aarch64)
    QEMU_BIN="qemu-system-aarch64"
    ;;
  armv7l)
    QEMU_BIN="qemu-system-arm"
    ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

# Run the VM with cloud-init configuration
echo "Starting VM..."
exec "${QEMU_BIN}" \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -drive file=${VM_NAME}.qcow2,format=qcow2 \
  -drive file=${SEED_FILE_NAME},format=raw \
  -nic user,hostfwd=tcp::8022-:22 \
  -nographic
# NOTE: 'sudo' is not installed by default, please use 'doas' instead. (e.g. "doas -u root apk add podman")
# To disable cloud-init everytime run this command
# Log into the VM and run:
#   touch /etc/cloud/cloud-init.disabled
# Confirm that cloud-init finished successfully by checking the file
#   cat /var/lib/cloud/instance/boot-finished

# For subsequent runs (without cloud-init):
# qemu-system-x86_64 -m ${MEMORY} -smp ${CPUS} -drive file=${VM_NAME}.qcow2,format=qcow2 -nic user,hostfwd=tcp::8022-:22 -nographic

ALPINE_QEMU_RUNTIME_SCRIPT="alpine-qemu.sh"
echo "${QEMU_BIN} -m ${MEMORY} -smp ${CPUS} -drive file=${VM_NAME}.qcow2,format=qcow2 -nic user,hostfwd=tcp::8022-:22 -nographic" > ${ALPINE_QEMU_RUNTIME_SCRIPT}
chmod u+x ${ALPINE_QEMU_RUNTIME_SCRIPT}
