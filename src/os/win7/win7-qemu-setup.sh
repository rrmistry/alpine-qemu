#!/bin/bash

# Stop script on any error
set -e

# Variables
VM_NAME="${VM_NAME:-win7-vm}"
DISK_SIZE="${DISK_SIZE:-40G}"
MEMORY="${MEMORY:-4096}"
CPUS="${CPUS:-4}"
VNC_PORT="${VNC_PORT:-5900}"
RDP_PORT="${RDP_PORT:-3389}"
SYSTEM_ARCH=$(uname -m)

# Windows 7 requires x86_64 emulation on ARM64
ARCH="x86_64"
QEMU_BIN="qemu-system-x86_64"

echo "🪟 Windows 7 QEMU VM Setup"
echo "=========================="
echo ""
echo "⚠️  Important Notes:"
echo "   - Windows 7 reached end of support on January 14, 2020"
echo "   - Running x86_64 on ARM64 requires full emulation (slower performance)"
echo "   - You need a valid Windows 7 license"
echo ""

# Check if QEMU is installed
if ! command -v $QEMU_BIN >/dev/null 2>&1; then
  echo "❌ Error: $QEMU_BIN not found"
  echo "   Install QEMU via: brew install qemu"
  exit 1
fi

# Handle existing VM image
if [ -f "${VM_NAME}.qcow2" ]; then
  echo "Existing VM image ${VM_NAME}.qcow2 found."
  read -p "Do you want to remove it for a clean setup? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Removing existing VM image..."
    rm -f "${VM_NAME}.qcow2"
  else
    echo "Skipping removal of existing VM image."
    echo "Will use existing disk image for VM boot."
    USE_EXISTING_DISK=true
  fi
fi

# Create new disk image if needed
if [ ! -f "${VM_NAME}.qcow2" ]; then
  echo ""
  echo "📥 Choose Windows 7 image source:"
  echo ""
  echo "Option 1: Download pre-built Windows 7 SuperNano Lite (263MB, auto-download)"
  echo "Option 2: Use custom ISO installation"
  echo "Option 3: Use existing QCOW2 image"
  echo ""

  # Check if ISO is provided via environment variable
  if [ -n "$ISO" ] && [ -f "$ISO" ]; then
    INSTALL_MODE=true
    echo "✅ Found installation ISO: $ISO"
    echo "Creating new QCOW2 disk image (${DISK_SIZE})..."
    qemu-img create -f qcow2 "${VM_NAME}.qcow2" ${DISK_SIZE}
  else
    # Ask user for their choice
    read -p "Enter choice (1=Download, 2=ISO, 3=Skip): " choice

    case "$choice" in
      1)
        echo ""
        echo "📥 Downloading Windows 7 SuperNano Lite from Internet Archive..."
        echo "   Source: https://archive.org/details/windows-7-supernano-lite"
        echo "   Size: ~263 MB (compressed)"
        echo ""

        DOWNLOAD_URL="https://archive.org/download/windows-7-supernano-lite/Windows%207%20Supernano%20Lite.zip"
        ZIP_FILE="Windows_7_Supernano_Lite.zip"

        # Download the ZIP file
        if command -v curl >/dev/null 2>&1; then
          curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
        elif command -v wget >/dev/null 2>&1; then
          wget -O "$ZIP_FILE" "$DOWNLOAD_URL"
        else
          echo "❌ Error: Neither curl nor wget found. Please install one of them."
          exit 1
        fi

        echo "✅ Download complete"
        echo ""
        echo "📦 Extracting Windows 7 image..."

        # Check for unzip
        if ! command -v unzip >/dev/null 2>&1; then
          echo "❌ Error: unzip not found. Please install it: brew install unzip"
          rm -f "$ZIP_FILE"
          exit 1
        fi

        # Extract the ZIP file
        unzip -o "$ZIP_FILE"

        # Find the QCOW2 or IMG file in the extracted contents
        EXTRACTED_IMAGE=$(find . -maxdepth 2 -type f \( -name "*.qcow2" -o -name "*.img" -o -name "*.qcow" \) | head -1)

        if [ -z "$EXTRACTED_IMAGE" ]; then
          echo "❌ Error: No QCOW2/IMG file found in the archive"
          echo "   Contents extracted. Please manually locate the image file."
          ls -lah
          exit 1
        fi

        # Move/rename the image to our VM name
        echo "✅ Found image: $EXTRACTED_IMAGE"

        # If it's not a qcow2, convert it
        if [[ "$EXTRACTED_IMAGE" == *.img ]]; then
          echo "🔄 Converting IMG to QCOW2 format..."
          qemu-img convert -f raw -O qcow2 "$EXTRACTED_IMAGE" "${VM_NAME}.qcow2"
          rm -f "$EXTRACTED_IMAGE"
        else
          mv "$EXTRACTED_IMAGE" "${VM_NAME}.qcow2"
        fi

        # Resize the disk to desired size
        echo "📏 Resizing disk to ${DISK_SIZE}..."
        qemu-img resize "${VM_NAME}.qcow2" ${DISK_SIZE}

        # Clean up
        rm -f "$ZIP_FILE"
        # Remove any extracted directories
        find . -maxdepth 1 -type d -name "Windows*" -exec rm -rf {} + 2>/dev/null || true

        echo "✅ Windows 7 SuperNano Lite ready: ${VM_NAME}.qcow2"
        USE_PREBUILT=true
        ;;

      2)
        echo ""
        read -p "Enter path to Windows 7 ISO file: " ISO_PATH
        if [ -f "$ISO_PATH" ]; then
          ISO="$ISO_PATH"
          INSTALL_MODE=true
          echo "Creating new QCOW2 disk image (${DISK_SIZE})..."
          qemu-img create -f qcow2 "${VM_NAME}.qcow2" ${DISK_SIZE}
          echo "✅ Disk image created: ${VM_NAME}.qcow2"
        else
          echo "❌ Error: ISO file not found: $ISO_PATH"
          exit 1
        fi
        ;;

      3)
        echo ""
        read -p "Enter path to existing QCOW2 image: " QCOW2_PATH
        if [ -f "$QCOW2_PATH" ]; then
          cp "$QCOW2_PATH" "${VM_NAME}.qcow2"
          echo "✅ Using existing image: ${VM_NAME}.qcow2"
          USE_PREBUILT=true
        else
          echo "❌ Error: QCOW2 file not found: $QCOW2_PATH"
          exit 1
        fi
        ;;

      *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
    esac
  fi
fi

echo ""
echo "🔧 VM Configuration:"
echo "   - Architecture: ${ARCH} (emulated on ${SYSTEM_ARCH})"
echo "   - Memory: ${MEMORY}MB"
echo "   - CPUs: ${CPUS}"
echo "   - Disk: ${DISK_SIZE}"
echo "   - VNC: localhost:${VNC_PORT}"
echo "   - RDP: localhost:${RDP_PORT} (after Windows setup)"
echo ""

# Build QEMU command
QEMU_CMD="${QEMU_BIN}"
QEMU_CMD="${QEMU_CMD} -machine q35"
QEMU_CMD="${QEMU_CMD} -cpu qemu64"
QEMU_CMD="${QEMU_CMD} -m ${MEMORY}"
QEMU_CMD="${QEMU_CMD} -smp ${CPUS}"
QEMU_CMD="${QEMU_CMD} -drive file=${VM_NAME}.qcow2,if=ide,format=qcow2"

# Add network with port forwarding
QEMU_CMD="${QEMU_CMD} -netdev user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389"
QEMU_CMD="${QEMU_CMD} -device e1000,netdev=net0"

# Add display - use default windowed display (works on macOS, Linux, etc.)
# This will open a QEMU window directly
# To use VNC instead, set environment variable: DISPLAY_MODE=vnc

# Enable KVM acceleration if available (won't work on ARM64 for x86_64)
# This is kept for potential x86_64 host compatibility
if [ "${SYSTEM_ARCH}" = "x86_64" ]; then
  if [ -w /dev/kvm ]; then
    QEMU_CMD="${QEMU_CMD} -enable-kvm"
    echo "✅ KVM acceleration enabled"
  fi
fi

# Add USB support
QEMU_CMD="${QEMU_CMD} -usb -device usb-tablet"

# Add sound (optional, can be disabled)
QEMU_CMD="${QEMU_CMD} -device AC97"

# If installation mode, add ISO as CD-ROM and set boot order
if [ "$INSTALL_MODE" = true ]; then
  QEMU_CMD="${QEMU_CMD} -drive file=${ISO},media=cdrom,index=1"
  QEMU_CMD="${QEMU_CMD} -boot order=dc"
  echo "🚀 Starting Windows 7 installation..."
  echo "   QEMU window will open with the VM display"
else
  QEMU_CMD="${QEMU_CMD} -boot order=c"
  echo "🚀 Starting Windows 7 VM..."
  echo "   QEMU window will open with the VM display"
fi

echo ""
echo "💡 Controls:"
echo "   - Display: QEMU window"
echo "   - Stop VM: Close QEMU window or Ctrl+C in terminal"
echo "   - RDP (after setup): rdp://localhost:${RDP_PORT}"
echo ""
echo "Running QEMU command:"
echo "${QEMU_CMD}"
echo ""

# Create runtime script for subsequent runs
WIN7_QEMU_RUNTIME_SCRIPT="${VM_NAME}.sh"
cat > ${WIN7_QEMU_RUNTIME_SCRIPT} << 'EOF'
#!/bin/sh
set -e

# Environment variables
VM_NAME="${VM_NAME:-win7-vm}"
CPUS=${CPUS:-4}
MEMORY=${MEMORY:-4096}
VNC_PORT=${VNC_PORT:-5900}
RDP_PORT=${RDP_PORT:-3389}

# Check if VM disk exists
if [ ! -f "${VM_NAME}.qcow2" ]; then
  echo "❌ Error: VM disk ${VM_NAME}.qcow2 not found"
  echo "   Run win7-qemu-setup.sh first to create the VM"
  exit 1
fi

echo "🚀 Starting Windows 7 VM..."
echo "   VNC: vnc://localhost:${VNC_PORT}"
echo "   RDP: rdp://localhost:${RDP_PORT}"
echo ""

# Run QEMU
qemu-system-x86_64 \
  -machine q35 \
  -cpu qemu64 \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -drive file=${VM_NAME}.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389 \
  -device e1000,netdev=net0 \
  -usb -device usb-tablet \
  -device AC97 \
  -boot order=c \
  "$@"
EOF

chmod +x ${WIN7_QEMU_RUNTIME_SCRIPT}

echo "✅ Runtime script created: ${WIN7_QEMU_RUNTIME_SCRIPT}"
echo ""

# Execute QEMU
eval $QEMU_CMD
