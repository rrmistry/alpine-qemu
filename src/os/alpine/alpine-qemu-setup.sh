#!/bin/bash
set -e

# Variables
ALPINE_VERSION="${ALPINE_VERSION:-3.21}"
ALPINE_VERSION_LONG="${ALPINE_VERSION_LONG:-${ALPINE_VERSION}.2}"
RELEASE="${RELEASE:-r0}"
SEED_FILE_NAME="${SEED_FILE_NAME:-alpine-seed.img}"
QEMU_EFI_FILE_NAME="${QEMU_EFI_FILE_NAME:-QEMU_EFI.fd}"
VM_NAME="${VM_NAME:-alpine-vm}"
DISK_SIZE="${DISK_SIZE:-20G}"
MEMORY="${MEMORY:-2048}"
CPUS="${CPUS:-2}"
SYSTEM_ARCH=$(uname -m)
ARCH="${ARCH:-$SYSTEM_ARCH}"

if [ ! -f "${VM_NAME}.qcow2" ]; then
  # Download Alpine cloud image (BIOS variant)
  ALPINE_IMAGE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/generic_alpine-${ALPINE_VERSION_LONG}-${ARCH}-bios-cloudinit-${RELEASE}.qcow2"
  echo "Downloading Alpine cloud image ${ALPINE_IMAGE_URL}..."
  if command -v curl >/dev/null 2>&1; then
    curl -L "${ALPINE_IMAGE_URL}" --output "${VM_NAME}.qcow2"
  elif command -v wget >/dev/null 2>&1; then
    wget "${ALPINE_IMAGE_URL}" -O "${VM_NAME}.qcow2"
  else
    echo "Error: curl or wget is required but not installed."
    exit 1
  fi
  # Example:
  # https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2

  qemu-img resize "${VM_NAME}.qcow2" ${DISK_SIZE}
else
  echo "VM image '${VM_NAME}.qcow2' already exists. Skipping download."
fi

# Download pre-built seed image from GitHub releases
if [ ! -f "$SEED_FILE_NAME" ]; then
  echo "Downloading pre-built seed image from GitHub releases..."
  if command -v curl >/dev/null 2>&1; then
    curl -L "https://github.com/rrmistry/alpine-qemu/releases/latest/download/${SEED_FILE_NAME}" --output ${SEED_FILE_NAME}
  elif command -v wget >/dev/null 2>&1; then
    wget "https://github.com/rrmistry/alpine-qemu/releases/latest/download/${SEED_FILE_NAME}" -O ${SEED_FILE_NAME}
  else
    echo "Error: curl or wget is required but not installed."
    exit 1
  fi
else
  echo "${SEED_FILE_NAME} already exists. Skipping download."
fi

# BIOS version doesn't need UEFI firmware
# if [ ! -f "$QEMU_EFI_FILE_NAME" ]; then
#   echo "File not found. Downloading '${QEMU_EFI_FILE_NAME}' ..."
#   curl -L "https://releases.linaro.org/components/kernel/uefi-linaro/latest/release/qemu64/QEMU_EFI.fd" --output ${QEMU_EFI_FILE_NAME}
# else
#   echo "${QEMU_EFI_FILE_NAME} already exists. Skipping download."
# fi

# Determine the host CPU architecture and select the appropriate QEMU binary.
case "$ARCH" in
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
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Create runtime script for subsequent runs (without cloud-init)
ALPINE_QEMU_RUNTIME_SCRIPT="${VM_NAME}.sh"
echo "Creating runtime script ${ALPINE_QEMU_RUNTIME_SCRIPT}"
echo "echo 'Starting Alpine VM...'" > ${ALPINE_QEMU_RUNTIME_SCRIPT}
echo "CPUS=\${CPUS:-${CPUS}}" >> ${ALPINE_QEMU_RUNTIME_SCRIPT}
echo "MEMORY=\${MEMORY:-${MEMORY}}" >> ${ALPINE_QEMU_RUNTIME_SCRIPT}
echo "${QEMU_BIN} -m \${MEMORY} -smp \${CPUS} -drive file=${VM_NAME}.qcow2,format=qcow2 -nic user,hostfwd=tcp::8022-:22 -nographic \$@" >> ${ALPINE_QEMU_RUNTIME_SCRIPT}
chmod u+x ${ALPINE_QEMU_RUNTIME_SCRIPT}

# Run the VM with cloud-init configuration for first time setup
echo "Starting VM Setup with cloud-init..."
echo "NOTE: 'sudo' is not installed by default, please use 'doas' instead. (e.g. \"doas -u root apk add podman\")"
echo "To check cloud-init status: cat /var/lib/cloud/instance/boot-finished"
echo "To connect via SSH: ssh -p 8022 alpine@localhost (password: alpine)"
echo "VM will remain running after cloud-init completes for interactive use."
echo "Use Ctrl+C to stop or 'shutdown -h now' inside VM to shutdown gracefully."

exec "${QEMU_BIN}" \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -drive file=${VM_NAME}.qcow2,format=qcow2 \
  -drive file=${SEED_FILE_NAME},format=raw \
  -nic user,hostfwd=tcp::8022-:22 \
  -nographic \
  $@
