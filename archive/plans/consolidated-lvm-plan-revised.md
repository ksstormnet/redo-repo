# Kubuntu System Rebuild with LVM

## Storage Strategy Overview

This plan utilizes Logical Volume Management (LVM) to create a flexible storage architecture that provides both redundancy for critical data and performance optimization for specific workloads.

## Physical Drive Architecture

- **System Drive**: SSD for operating system (/) and boot partition
- **Data Storage**: 7 NVMe drives combined into a single volume group for logical volume allocation

## Logical Volume Design

### Volume Allocation

| Logical Volume | Size | Type | Mount Point | Purpose |
|----------------|------|------|-------------|---------|
| lv_home | 200GB | Mirrored (RAID1) | /home | User profile and configuration files |
| lv_docker | 500GB | Striped (RAID0) | /var/lib/docker | Docker containers, images, volumes |
| lv_virtualbox | 150GB | Striped (RAID0) | /VirtualBox | Virtual machine storage |
| lv_models | 800GB | Striped (RAID0) | /opt/models | AI model storage for LLM inference |
| lv_data | 2.3TB | Mirrored (RAID1) | /data | User documents, media, project files |
| lv_var | 50GB | Standard | /var | System logs and temporary files |

### Storage Strategy Benefits

1. **Data Security**: Mirrored volumes (RAID1) for critical user data in `/home` and `/data` ensures redundancy
2. **Performance Optimization**: Striped volumes (RAID0) for I/O-intensive applications like Docker, VirtualBox, and AI models
3. **Flexibility**: Easy to resize volumes as needs change without physical drive reorganization
4. **Future Growth**: Simple to add physical drives to expand the volume group later

## Pre-Installation Preparation

### Backup Critical Data

1. Create a comprehensive backup of all data
2. Back up all important data to external storage
3. Verify backups are complete and readable

### Create Installation Media

1. Download Kubuntu 24.04 ISO
2. Create bootable USB with a tool like Balena Etcher or using `dd`

## Installation Process Using Scripts

The LVM installation process has been broken down into sequential scripts for easier management and error recovery. Each script handles a specific phase of the process:

### Phase 1: Initial Setup from Ubuntu Server Live Environment

1. Boot from the Ubuntu Server USB
2. Access the shell environment (Ctrl+Alt+F2, login as "ubuntu")
3. Mount your scripts USB drive and navigate to the scripts directory
4. Run `00-lvm-prepare.sh` to prepare the NVMe drives for LVM
   - Installs necessary tools
   - Stops any existing RAID arrays
   - Clears drive signatures
   
5. Run `01-lvm-setup.sh` to create the physical volumes and volume group
   - Creates physical volumes on all NVMe drives
   - Creates the volume group 'vg_data'
   - Verifies the volume group creation
   
6. Run `02-lvm-logical-volumes.sh` to create and format the logical volumes
   - Creates all logical volumes with the appropriate RAID levels
   - Formats volumes with ext4 filesystem
   - Adds labels to the volumes

### Phase 2: Base System Installation

1. Return to the Ubuntu Server installer (Ctrl+Alt+F1)
2. Proceed with installation and select "Manual" partitioning when prompted
3. Create an EFI partition (if needed) and a root partition on the SSD
4. Complete the installation up to the point before rebooting
5. When prompted to restart, select "Cancel" and return to the shell (Ctrl+Alt+F2)

### Phase 3: Configure Mount Points

1. Mount the installed system and set up for chroot:
   ```bash
   sudo mount /dev/sda2 /mnt  # Assuming sda2 is your root partition
   sudo mount /dev/sda1 /mnt/boot/efi  # Assuming sda1 is your EFI partition
   for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done
   sudo chroot /mnt
   ```

2. Run `03-lvm-mount-config.sh` from within the chroot environment
   - Creates necessary mount points
   - Updates fstab configuration
   - Updates initramfs to include LVM modules

3. Exit chroot and reboot:
   ```bash
   exit
   for i in /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys /mnt/run; do sudo umount $i; done
   sudo umount /mnt/boot/efi
   sudo umount /mnt
   sudo reboot
   ```

### Phase 4: Post-Installation Configuration

1. Boot into your new system
2. Run `04-lvm-post-install.sh` to set up the directory structure
   - Creates data directory structure in /data
   - Sets up XDG user directories
   - Configures proper permissions

## LVM Management Reference

### Monitoring LVM

Check on your LVM setup with these commands:

```bash
# Display volume group information
vgs

# Display logical volume information
lvs

# Display detailed information about volume group
sudo vgdisplay vg_data

# Display detailed information about logical volume
sudo lvdisplay /dev/vg_data/lv_home
```

### Resizing Logical Volumes

Adjust volume sizes as your needs change:

```bash
# Extend a logical volume (add 100GB)
sudo lvextend -L +100G /dev/vg_data/lv_data
sudo resize2fs /dev/vg_data/lv_data

# Reduce a logical volume (remove 50GB) - requires unmounting first
sudo umount /data
sudo fsck -f /dev/vg_data/lv_data
sudo resize2fs /dev/vg_data/lv_data 2250G  # New size in GB
sudo lvreduce -L -50G /dev/vg_data/lv_data
sudo mount /data
```

### Creating and Using Snapshots

Create point-in-time snapshots for backups or before making changes:

```bash
# Create a snapshot of lv_home (10GB for changes)
sudo lvcreate -s -L 10G -n lv_home_snapshot /dev/vg_data/lv_home

# Restore from a snapshot
sudo umount /home
sudo lvconvert --merge /dev/vg_data/lv_home_snapshot
sudo mount /home
```

## Troubleshooting

### Boot Problems

If your system fails to boot:

1. Boot from live USB
2. Install LVM tools: `sudo apt install lvm2`
3. Scan for volume groups: `sudo vgscan`
4. Activate volume groups: `sudo vgchange -ay vg_data`
5. Check logical volumes: `sudo lvs`
6. Mount volumes for data recovery: `sudo mount /dev/vg_data/lv_data /mnt/data`

### LVM Issues

- **Missing Volumes after Boot**: Ensure `lvm2` package is installed and LVM modules are in initramfs
- **Cannot Access LVM**: Check if LVM service is running with `systemctl status lvm2-lvmetad.service`
- **Disk Space Discrepancy**: Use `sudo lvdisplay -m` to check for any inactive extents
