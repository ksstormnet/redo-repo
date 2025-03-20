# LVM Installation Scripts

This directory contains sequential scripts for setting up an LVM storage architecture during an Ubuntu Server installation. Each script handles a specific phase of the process, allowing you to review and execute them individually.

## Overview

These scripts implement a storage strategy that uses Logical Volume Management (LVM) to create a flexible storage architecture with:
- Mirrored volumes (RAID1) for critical data
- Striped volumes (RAID0) for performance-sensitive applications
- Standard volumes for system use

## Prerequisites

- Ubuntu Server bootable USB drive
- Secondary USB drive containing these scripts
- Basic understanding of disk partitioning and LVM concepts
- 7 NVMe drives for data storage
- 1 SSD for system installation

## Accessing the Shell from Ubuntu Server ISO

1. **Boot from the Ubuntu Server ISO**
   - Insert the USB drive and boot from it
   - Wait for the Ubuntu Server installer to load

2. **Access the Shell Environment**
   - Press **Ctrl+Alt+F2** to switch to a terminal console (TTY2)
   - Log in with username **ubuntu** (no password required)
   - You now have access to a full shell environment

3. **Verify Network Connectivity**
   - Run `ip addr show` to check if you have an IP address
   - If networking isn't configured, set it up manually:
     ```
     sudo ip link set dev eth0 up  # Replace eth0 with your interface name
     sudo dhclient eth0
     ```

4. **Mount Your Scripts USB Drive**
   - Identify the USB drive with `lsblk` or `sudo fdisk -l`
   - Create a mount point: `sudo mkdir -p /mnt/usb`
   - Mount the drive: `sudo mount /dev/sdX1 /mnt/usb`  # Replace sdX1 with your USB device
   - Navigate to the scripts: `cd /mnt/usb/lvm-scripts`
   - Make scripts executable: `chmod +x *.sh`

5. **Return to Installer When Needed**
   - Press **Ctrl+Alt+F1** to return to the installer interface
   - You can toggle between the installer and shell as needed

## Script Sequence

Execute these scripts in order from the Ubuntu live environment:

### 1. 00-lvm-prepare.sh
- Installs LVM tools
- Stops any existing RAID arrays
- Clears superblocks and RAID signatures
- Prepares drives for LVM

### 2. 01-lvm-setup.sh
- Creates physical volumes on all NVMe drives
- Creates a volume group combining all drives
- Verifies volume group creation

### 3. 02-lvm-logical-volumes.sh
- Creates all logical volumes with appropriate RAID levels
- Formats volumes with ext4 filesystem
- Adds labels to volumes

### 4. 03-lvm-mount-config.sh
- Sets up mount points
- Updates fstab configuration
- Updates initramfs to include LVM modules

### 5. 04-lvm-post-install.sh
- Creates data directory structure
- Sets up XDG user directories
- Configures permissions

## Usage Instructions

After accessing the shell environment and mounting your scripts USB drive:

1. Run each script in sequence, reviewing output carefully
2. Return to the installer when indicated to proceed with system installation
3. Switch back to the shell when needed for additional configuration

Example:
```
# Run the first script
sudo ./00-lvm-prepare.sh

# Review the output before proceeding to the next script
sudo ./01-lvm-setup.sh

# And so on...
```

## Important Notes

- **BACKUP ALL DATA** before running these scripts. They will erase existing data on the drives.
- Review each script before execution to ensure it matches your system configuration.
- These scripts assume a specific drive configuration; adjust paths as needed for your system.
- Between running scripts 03 and 04, you will need to complete the Ubuntu installation and boot into your new system.

## Logical Volume Layout

| Logical Volume | Size | Type | Mount Point | Purpose |
|----------------|------|------|-------------|---------|
| lv_home | 200GB | Mirrored (RAID1) | /home | User profile and configuration files |
| lv_docker | 500GB | Striped (RAID0) | /var/lib/docker | Docker containers, images, volumes |
| lv_virtualbox | 150GB | Striped (RAID0) | /VirtualBox | Virtual machine storage |
| lv_models | 800GB | Striped (RAID0) | /opt/models | AI model storage for LLM inference |
| lv_data | 2.3TB | Mirrored (RAID1) | /data | User documents, media, project files |
| lv_var | 50GB | Standard | /var | System logs and temporary files |

## Recovery Information

If something goes wrong during the installation process:

1. Boot back into the live environment
2. Install LVM tools: `sudo apt install lvm2`
3. Scan for LVM volume groups: `sudo vgscan`
4. Activate volume groups: `sudo vgchange -ay`
5. Mount volumes to access data: `sudo mount /dev/vg_data/lv_home /mnt/home`

## Manual Installation Alternative

If you prefer to run commands manually rather than using these scripts, refer to the consolidated LVM installation plan document for step-by-step instructions.
