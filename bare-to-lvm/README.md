# LVM Installation Scripts

This directory contains sequential scripts for setting up a Logical Volume Management (LVM) storage architecture during the Ubuntu Server installation process. Each script handles a specific phase to ensure proper organization and recovery in case of errors.

## Scripts Overview

### [00-lvm-prepare.sh](00-lvm-prepare.sh)

- **Purpose**: Prepares drives for LVM setup during installation
- **Functions**:
  - Installs necessary tools (lvm2, mdadm)
  - Stops any existing RAID arrays
  - Clears drive signatures and superblocks
  - Performs verification to ensure drives are ready
- **Usage**: Run first from Ubuntu Server live environment

### [01-lvm-setup.sh](01-lvm-setup.sh)

- **Purpose**: Creates physical volumes and a volume group from prepared drives
- **Functions**:
  - Creates physical volumes on all NVMe drives
  - Creates a combined volume group named 'vg_data'
  - Verifies volume group creation and size
- **Usage**: Run after `00-lvm-prepare.sh`

### [02-lvm-logical-volumes.sh](02-lvm-logical-volumes.sh)

- **Purpose**: Creates and formats logical volumes with appropriate RAID levels
- **Functions**:
  - Creates mirrored volumes (RAID1) for critical data
  - Creates striped volumes (RAID0) for performance-sensitive workloads
  - Creates standard volumes for system use
  - Formats all volumes with ext4 filesystem
- **Usage**: Run after `01-lvm-setup.sh`

### [03-lvm-mount-config.sh](03-lvm-mount-config.sh)

- **Purpose**: Configures mount points and fstab for the LVM setup
- **Functions**:
  - Creates mount points for logical volumes
  - Updates fstab configuration with proper mount entries
  - Updates initramfs to include LVM modules
- **Usage**: Run from chroot environment after base system installation

### [04-lvm-post-install.sh](04-lvm-post-install.sh)

- **Purpose**: Performs post-installation configuration for data directories
- **Functions**:
  - Verifies LVM volumes are properly mounted
  - Creates data directory structure in /data
  - Sets up XDG user directories
  - Configures proper permissions
- **Usage**: Run after first boot into new system

## Logical Volume Layout

The scripts configure the following volume layout:

| Logical Volume | Size | Type | Mount Point | Purpose |
|----------------|------|------|-------------|---------|
| lv_home | 200GB | Mirrored (RAID1) | /home | User profile and configuration files |
| lv_docker | 500GB | Striped (RAID0) | /var/lib/docker | Docker containers, images, volumes |
| lv_virtualbox | 150GB | Striped (RAID0) | /VirtualBox | Virtual machine storage |
| lv_models | 800GB | Striped (RAID0) | /opt/models | AI model storage for LLM inference |
| lv_data | 2.3TB | Mirrored (RAID1) | /data | User documents, media, project files |
| lv_var | 50GB | Standard | /var | System logs and temporary files |

## Usage Instructions

These scripts are designed to be run during the Ubuntu Server installation process:

1. Boot from Ubuntu Server installation media
2. Begin the installation process
3. When you reach the storage configuration step, press Ctrl+Alt+F2 to access a terminal
4. Log in with username "ubuntu" (no password required)
5. Mount your scripts USB drive and navigate to this directory
6. Run each script in sequence, verifying successful completion before proceeding
7. Return to the installer with Ctrl+Alt+F1 and continue the installation
8. After installation but before rebooting, run the mount configuration script in a chroot environment
9. Complete the installation and run the post-install script after first boot

For detailed, step-by-step instructions, refer to the [Installation Checklist](../CHECKLIST.md).

## Recovery Information

If issues occur during the installation process:

1. Boot back into the live environment
2. Install LVM tools: `sudo apt install lvm2`
3. Scan for volume groups: `sudo vgscan`
4. Activate volume groups: `sudo vgchange -ay vg_data`
5. Mount volumes for data recovery: `sudo mount /dev/vg_data/lv_data /mnt/data`

---

*Back to [Main README](../README.md) | Next: [Scripts](../scripts/README.md)*
