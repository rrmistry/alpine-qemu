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

# Run QEMU - based on UTM Windows 7 recommendations
qemu-system-x86_64 \
  -machine pc \
  -cpu qemu64 \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -drive file=${VM_NAME}.qcow2,if=ide,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::${RDP_PORT}-:3389 \
  -device rtl8139,netdev=net0 \
  -vga std \
  -usb -device usb-tablet \
  -rtc base=localtime \
  -boot c \
  "$@"
