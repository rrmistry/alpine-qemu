# Windows 7 QEMU VM Setup

This directory contains scripts to run Windows 7 in QEMU on ARM64 macOS (Apple Silicon).

## ⚠️ Important Notices

- **Windows 7 End of Life**: Windows 7 reached end of support on January 14, 2020. Use at your own risk.
- **Licensing**: You need a valid Windows 7 license to use Windows 7.
- **Performance**: Running x86_64 Windows on ARM64 requires full CPU emulation (no hardware virtualization), resulting in slower performance.
- **Security**: Running unsupported operating systems poses security risks.

## Prerequisites

Install QEMU via Homebrew:
```bash
brew install qemu
```

## Quick Start

### Option 1: Using a Pre-built QCOW2 Image

If you have a pre-built Windows 7 QCOW2 image:

1. Download a Windows 7 QCOW2 image (e.g., [Windows 7 SuperNano Lite](https://archive.org/details/windows-7-supernano-lite))
2. Place it in this directory as `win7-vm.qcow2`
3. Run the setup script:
   ```bash
   chmod +x win7-qemu-setup.sh
   ./win7-qemu-setup.sh
   ```

### Option 2: Install from ISO

If you have a Windows 7 installation ISO:

1. Download Windows 7 ISO (requires valid license)
2. Place the ISO in this directory (e.g., `win7.iso`)
3. Run the setup script with ISO parameter:
   ```bash
   chmod +x win7-qemu-setup.sh
   ISO=win7.iso ./win7-qemu-setup.sh
   ```
4. Connect via VNC to complete the installation:
   ```bash
   open vnc://localhost:5900
   ```

## Accessing the VM

### VNC Access (Graphical Interface)

Connect to the VM's display:
```bash
open vnc://localhost:5900
```

Or use any VNC client connecting to `localhost:5900`

### RDP Access (After Windows Setup)

Once Windows is installed and configured with RDP enabled:
```bash
open rdp://localhost:3389
```

Or use Microsoft Remote Desktop app connecting to `localhost:3389`

## Running the VM

After initial setup, use the generated runtime script:

```bash
./win7-vm.sh
```

### Customization

Environment variables can customize the VM configuration:

```bash
# Adjust memory (in MB)
MEMORY=8192 ./win7-vm.sh

# Adjust CPU cores
CPUS=8 ./win7-vm.sh

# Change VNC port
VNC_PORT=5901 ./win7-vm.sh

# Change RDP port
RDP_PORT=3390 ./win7-vm.sh

# Combine multiple options
MEMORY=8192 CPUS=8 ./win7-vm.sh
```

## VM Configuration

Default settings:
- **Memory**: 4096 MB (4 GB)
- **CPUs**: 4 cores
- **Disk**: 40 GB (QCOW2 format, dynamically allocated)
- **Network**: User-mode networking with RDP port forwarding
- **Graphics**: VNC server on port 5900
- **Machine Type**: Q35 (modern Intel chipset)
- **Network Card**: Intel E1000
- **Sound**: AC97 audio device

## Installing Windows Drivers

For better performance, install VirtIO drivers in Windows:

1. Download VirtIO drivers ISO from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/
2. Attach the ISO during installation or after boot
3. Install drivers for storage, network, and other devices

## Troubleshooting

### VM won't start
- Ensure QEMU is installed: `qemu-system-x86_64 --version`
- Check that `win7-vm.qcow2` exists
- Verify VNC port 5900 is not in use: `lsof -i :5900`

### Slow performance
- This is expected on ARM64 Mac due to x86_64 emulation
- Increase memory: `MEMORY=8192 ./win7-vm.sh`
- Reduce CPU cores: `CPUS=2 ./win7-vm.sh`
- Consider using Windows 11 ARM64 instead for better performance

### Cannot connect via VNC
- Check if QEMU is running: `ps aux | grep qemu`
- Try different VNC client
- Check firewall settings

### No network connectivity in Windows
- Wait for Windows to detect network adapter
- Install E1000 network drivers
- Check Windows network settings

## Advanced Usage

### Snapshot Management

Create a snapshot before making changes:
```bash
qemu-img snapshot -c snapshot_name win7-vm.qcow2
```

List snapshots:
```bash
qemu-img snapshot -l win7-vm.qcow2
```

Restore from snapshot:
```bash
qemu-img snapshot -a snapshot_name win7-vm.qcow2
```

### Resize Disk

```bash
qemu-img resize win7-vm.qcow2 +20G
```

Note: You'll need to extend the partition inside Windows.

### Convert Image Format

Convert to raw format (for compatibility):
```bash
qemu-img convert -f qcow2 -O raw win7-vm.qcow2 win7-vm.img
```

## Stopping the VM

### Graceful Shutdown
1. Shut down Windows normally from the Start menu
2. Or press Ctrl+C in the terminal

### Force Stop
If the VM is unresponsive:
```bash
pkill -9 qemu-system-x86_64
```

## File Structure

After setup, you'll have:
- `win7-qemu-setup.sh` - Initial setup script
- `win7-vm.qcow2` - VM disk image
- `win7-vm.sh` - Runtime script for subsequent boots
- `ReadMe.md` - This file

## Performance Tips

1. **Allocate sufficient memory**: Windows 7 needs at least 2 GB, 4 GB recommended
2. **Don't over-allocate CPUs**: More cores don't always help with emulation
3. **Use snapshots**: Take snapshots before major changes for quick rollback
4. **Consider alternatives**: For better performance on Apple Silicon, consider:
   - UTM (native macOS virtualization app)
   - Windows 11 ARM64 (better ARM support)
   - CrossOver/Wine for running Windows applications

## References

- [QEMU Windows 7 Documentation](https://wiki.qemu.org/Documentation/GuestOperatingSystems/Windows7)
- [QEMU Official Website](https://www.qemu.org/)
- [VirtIO Windows Drivers](https://github.com/virtio-win/virtio-win-pkg-scripts)

## License

These scripts are provided as-is. You are responsible for obtaining proper Windows 7 licensing.