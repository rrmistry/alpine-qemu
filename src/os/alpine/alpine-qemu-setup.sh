#!/bin/bash

# Stop script on any error
set -e

# Variables
ALPINE_VERSION="${ALPINE_VERSION:-3.21}"
ALPINE_VERSION_LONG="${ALPINE_VERSION_LONG:-${ALPINE_VERSION}.4}"
RELEASE="${RELEASE:-r0}"
SEED_FILE_NAME="${SEED_FILE_NAME:-alpine-seed.img}"
QEMU_EFI_FILE_NAME="${QEMU_EFI_FILE_NAME:-QEMU_EFI.fd}"
VM_NAME="${VM_NAME:-alpine-vm}"
DISK_SIZE="${DISK_SIZE:-20G}"
MEMORY="${MEMORY:-2048}"
CPUS="${CPUS:-2}"
SSH_PORT="${SSH_PORT:-8022}"
SYSTEM_ARCH=$(uname -m)
ARCH="${ARCH:-$SYSTEM_ARCH}"

# Always recreate VM image for clean state
if [ -f "${VM_NAME}.qcow2" ]; then

  # Confirm with the user before removing existing VM image
  echo "Existing VM image ${VM_NAME}.qcow2 found."
  read -p "Do you want to remove it for a clean setup? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Removing existing VM image..."
    rm -f "${VM_NAME}.qcow2"
  else
    echo "Skipping removal of existing VM image."
    echo "Exiting setup to avoid conflicts."
    exit 0
  fi
fi

# Download Alpine cloud image
case "${ARCH}" in
  x86_64)
    # Use BIOS image for x86_64 (simpler, works with the command)
    ALPINE_IMAGE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/generic_alpine-${ALPINE_VERSION_LONG}-${ARCH}-bios-cloudinit-${RELEASE}.qcow2"
    ;;
  aarch64)
    # Use UEFI image for aarch64 (required for ARM64)
    ALPINE_IMAGE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/cloud/generic_alpine-${ALPINE_VERSION_LONG}-${ARCH}-uefi-cloudinit-${RELEASE}.qcow2"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

echo ""
echo "Downloading Alpine cloud image..."
wget "${ALPINE_IMAGE_URL}" -v -O "${VM_NAME}.qcow2"

# Resize the disk image
if command -v qemu-img >/dev/null 2>&1; then
  qemu-img resize "${VM_NAME}.qcow2" ${DISK_SIZE}
  echo "VM disk resized to ${DISK_SIZE}"
else
  echo "Warning: qemu-img not found. Disk not resized."
fi

# Download pre-built seed image from GitHub releases
if [ ! -f "$SEED_FILE_NAME" ]; then
  echo ""
  echo "Downloading pre-built seed image from GitHub releases..."
  SEED_IMAGE_URL="https://github.com/rrmistry/alpine-qemu/releases/latest/download/${SEED_FILE_NAME}"
  wget "${SEED_IMAGE_URL}" -v -O "${SEED_FILE_NAME}"
else
  echo "${SEED_FILE_NAME} already exists. Skipping download."
fi

# Download UEFI firmware only for aarch64
if [ "${ARCH}" = "aarch64" ]; then
  if [ ! -f "$QEMU_EFI_FILE_NAME" ]; then
    echo ""
    echo "Downloading UEFI firmware for ${ARCH}..."
    UEFI_URL="https://releases.linaro.org/components/kernel/uefi-linaro/latest/release/qemu64/QEMU_EFI.fd"
    wget "$UEFI_URL" -v -O "$QEMU_EFI_FILE_NAME"
  else
    echo "${QEMU_EFI_FILE_NAME} already exists. Skipping download."
  fi
fi

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

# Run the VM with cloud-init configuration for first time setup
echo ""
echo "🎉 Alpine Linux VM setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. First boot with cloud-init will start now"
echo "   2. VM will auto-shutdown after cloud-init completes"
echo "   3. Runtime script will be created for subsequent runs"
echo ""
echo "🔧 Configuration:"
echo "   - Architecture: ${ARCH}"
case "${ARCH}" in
  x86_64)
    echo "   - Firmware: BIOS"
    ;;
  aarch64)
    echo "   - Firmware: UEFI"
    ;;
esac
echo "   - Memory: ${MEMORY}MB"
echo "   - CPUs: ${CPUS}"
echo "   - Disk: ${DISK_SIZE}"
echo ""
echo "📁 Files created:"
echo "   - ${VM_NAME}.qcow2 (VM disk image)"
echo "   - ${SEED_FILE_NAME} (cloud-init seed)"
if [ "${ARCH}" = "aarch64" ] && [ -f "${QEMU_EFI_FILE_NAME}" ]; then
echo "   - ${QEMU_EFI_FILE_NAME} (UEFI firmware)"
fi
echo ""
echo "💡 Starting first boot with cloud-init..."

# Build and execute QEMU command for initial setup
QEMU_CMD="${QEMU_BIN}"

# Add the main OS disk image
QEMU_CMD="${QEMU_CMD} -drive file=${VM_NAME}.qcow2,index=0,format=qcow2,media=disk"
QEMU_CMD="${QEMU_CMD} -net nic -net user"

case "${ARCH}" in
  x86_64)
    ;;
  aarch64)
    # Keep existing aarch64 configuration unchanged
    QEMU_CMD="${QEMU_CMD} -machine virt"
    QEMU_CMD="${QEMU_CMD} -cpu cortex-a57"
    if [ -f "${QEMU_EFI_FILE_NAME}" ]; then
      QEMU_CMD="${QEMU_CMD} -bios ${QEMU_EFI_FILE_NAME}"
    fi
    QEMU_CMD="${QEMU_CMD} -serial mon:stdio"
    QEMU_CMD="${QEMU_CMD} -display none"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Disable graphical output for all architectures
QEMU_CMD="${QEMU_CMD} -nographic"

# Add any additional arguments
QEMU_SETUP_CMD="${QEMU_CMD} -m ${MEMORY} -smp ${CPUS} -drive file=${SEED_FILE_NAME},index=1,media=cdrom $@"

echo "🚀 Starting VM with cloud-init for initial setup..."

# Execute cloud-init setup (with cloud-init drive)
# Use eval to ensure proper command execution with full TTY/signal handling
echo "Running QEMU command: ${QEMU_SETUP_CMD}"
eval $QEMU_SETUP_CMD

# Check if cloud-init completed successfully (VM should have shut down)
if [ $? -eq 0 ]; then
  echo ""
  echo "✅ QEMU first boot completed successfully!"
  echo ""
  echo "Creating runtime script for subsequent runs..."
  
  # Create runtime script for subsequent runs (without cloud-init)
  ALPINE_QEMU_RUNTIME_SCRIPT="${VM_NAME}.sh"
  echo "Creating runtime script ${ALPINE_QEMU_RUNTIME_SCRIPT}"
  
  cat > ${ALPINE_QEMU_RUNTIME_SCRIPT} << EOF
#!/bin/sh
set -e

# Environment variables
CPUS=\${CPUS:-${CPUS}}
MEMORY=\${MEMORY:-${MEMORY}}
SSH_PORT=\${SSH_PORT:-${SSH_PORT}}

# Run QEMU
${QEMU_CMD} -m \${MEMORY} -smp \${CPUS} -net user,hostfwd=tcp::\${SSH_PORT}-:22 \$@
EOF

  chmod +x ${ALPINE_QEMU_RUNTIME_SCRIPT}
  
  echo ""
  echo "🎉 Runtime script created: ${ALPINE_QEMU_RUNTIME_SCRIPT}"
  echo ""
  echo "📋 Next steps:"
  echo "   1. Start VM: ./${ALPINE_QEMU_RUNTIME_SCRIPT}"
  echo "   2. SSH access: ssh -p ${SSH_PORT} alpine@localhost (password: alpine)"
  echo "   3. Stop VM: Ctrl+A, X or 'sudo poweroff' inside VM"
  echo ""
  echo "✅ Setup complete! VM is ready for use."
else
  echo ""
  echo "❌ Cloud-init setup failed or was interrupted"
  echo "   You may need to run the setup script again"
fi
