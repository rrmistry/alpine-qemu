# linux-qemu
Create a Linux QEMU VM anywhere with a single command!

This repo provides a clean, production-ready script that lets you set up a persistent Alpine Linux QEMU VM with minimal effort:

## Quick Start

```bash
# One-command setup from anywhere:
curl -fsSL https://github.com/rrmistry/alpine-qemu/raw/main/src/os/alpine/alpine-qemu-setup.sh | bash
```

```bash
# Or download and run locally:
wget https://github.com/rrmistry/alpine-qemu/raw/main/src/os/alpine/alpine-qemu-setup.sh
chmod +x alpine-qemu-setup.sh
./alpine-qemu-setup.sh
```

## What it does

1. **First run**: Downloads Alpine cloud image, sets up cloud-init, creates persistent VM
2. **Subsequent runs**: Boots existing VM quickly without cloud-init
3. **Creates runtime script**: `alpine-vm.sh` for future local runs

## VM Features

- **Persistent storage**: VM state survives reboots
- **SSH access**: Available on port 8022 (password: alpine)
- **Minimal packages**: bash, curl, openssh, podman pre-installed
- **Cross-architecture**: Supports x86_64, aarch64, i686, armv7l

## Environment Variables

Customize your VM before running:

```bash
VM_NAME=my-vm DISK_SIZE=40G MEMORY=4096 CPUS=4 ./alpine-qemu-setup.sh
```

- `VM_NAME` - VM instance name (default: alpine-vm)
- `DISK_SIZE` - Virtual disk size (default: 20G)  
- `MEMORY` - RAM in MB (default: 2048)
- `CPUS` - CPU cores (default: 2)
- `ARCH` - Target architecture (default: host architecture)

## Dependencies

The script checks for and requires:
- `qemu-system-*` (for your architecture)
- `mkisofs` or `genisoimage` (for cloud-init)
- `curl` or `wget` (for downloads)

This [ReadMe.md](src/os/alpine/ReadMe.md) provides additional details about the Alpine Linux setup.

