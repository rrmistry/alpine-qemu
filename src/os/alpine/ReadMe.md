# Alpine Linux OS files for QEMU setup

This directory contains the necessary files and scripts to set up an Alpine Linux virtual machine using QEMU.

## Files

- `alpine-qemu-setup.sh`: Script to download and set up the Alpine Linux VM with QEMU.
- `meta-data`: Cloud-init metadata file for the VM.
- `user-data`: Cloud-init user data file for the VM configuration.

## Usage

1. Run the setup script to download and configure the Alpine Linux VM:
    ```sh
    ./alpine-qemu-setup.sh
    ```

2. The script will download the necessary Alpine Linux image and create a QEMU virtual machine.

3. The VM will be configured using the cloud-init files (`meta-data` and `user-data`).

## Cloud-init Configuration

- `meta-data`: Contains instance metadata such as instance ID and hostname.
- `user-data`: Contains user data for cloud-init to configure the VM, including setting the hostname, password, SSH access, and installing packages.

## Notes

- The VM image and seed image will be downloaded if they do not already exist.
- The script determines the host CPU architecture and selects the appropriate QEMU binary.
- The VM will be started with the specified memory, CPU, and disk size configurations.

## Example Commands

To create and run the VM:
```sh

```