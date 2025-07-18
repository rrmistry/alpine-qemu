# Alpine Linux QEMU VM Setup

This directory contains the clean, production-ready Alpine Linux QEMU VM setup.

## Files

- **`alpine-qemu-setup.sh`**: Main script - single source of truth for VM setup
- **`meta-data`**: Cloud-init metadata (instance ID, hostname) 
- **`user-data`**: Cloud-init configuration (packages, SSH, services)

## Usage

### Local Setup
```bash
cd src/os/alpine
./alpine-qemu-setup.sh
```

### Remote Setup (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/rrmistry/alpine-qemu/main/src/os/alpine/alpine-qemu-setup.sh | bash
```

## What It Does

1. **Downloads Alpine BIOS cloud image** (180MB) with full console output
2. **Downloads pre-built cloud-init seed image** from GitHub releases
3. **Boots VM with cloud-init** for initial setup
4. **Generates runtime script** (`alpine-vm.sh`) for subsequent boots
5. **Disables cloud-init** after first run for faster boot

## VM Features

- **Full console output**: See complete boot process and kernel messages
- **SSH access**: Port 8022 (password: alpine)
- **Pre-installed packages**: bash, curl, openssh, podman
- **Persistent storage**: VM state survives reboots
- **Cross-architecture**: Supports x86_64, aarch64, i686, armv7l

## Environment Variables

```bash
VM_NAME=my-vm DISK_SIZE=40G MEMORY=4096 CPUS=4 ./alpine-qemu-setup.sh
```

- `VM_NAME`: Instance name (default: alpine-vm)
- `DISK_SIZE`: Virtual disk size (default: 20G)
- `MEMORY`: RAM in MB (default: 2048)
- `CPUS`: CPU cores (default: 2)
- `ARCH`: Target architecture (default: host)

## Files Created

After first run:
- `alpine-vm.qcow2`: VM disk image
- `alpine-seed.img`: Cloud-init seed image (downloaded from GitHub releases)
- `alpine-vm.sh`: Runtime script for subsequent boots