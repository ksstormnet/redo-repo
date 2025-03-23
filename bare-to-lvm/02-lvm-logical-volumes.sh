#!/bin/bash

# 02-lvm-logical-volumes.sh
# This script creates and formats logical volumes for the LVM setup
# Run this after 01-lvm-setup.sh

# Exit on any error
set -e

# Function to display section headers
section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "LVM Logical Volumes Setup"
echo "This script will create and format logical volumes."
echo "Make sure you've already run 01-lvm-setup.sh before continuing."
echo
read -p "Have you run 01-lvm-setup.sh? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run 01-lvm-setup.sh first."
    exit 1
fi

# Check if volume group exists
if ! vgdisplay vg_data &> /dev/null; then
    echo "Volume group 'vg_data' not found. Please run 01-lvm-setup.sh first."
    exit 1
fi

# Display volume group information
section "Volume Group Information"
vgdisplay vg_data

# Confirm volume sizes
section "Logical Volume Configuration"
echo "The following logical volumes will be created:"
echo
echo "Mirror volumes for critical data:"
echo "  - lv_home (50GB, RAID1): User profile and config files"
echo "  - lv_data (2TB, RAID1): User documents, media, and project files"
echo
echo "Striped volumes for performance:"
echo "  - lv_docker (250GB, RAID0): Docker containers and images"
echo "  - lv_virtualbox (150GB, RAID0): Virtual machine storage"
echo "  - lv_models (600GB, RAID0): AI model storage for LLM inference"
echo
echo "Standard volume:"
echo "  - lv_var (50GB): System logs and temporary files"
echo

# Check if volume group has enough space
VG_SIZE_KB=$(vgdisplay vg_data | grep "VG Size" | awk '{print $3}' | sed 's/\..*//')
TOTAL_LV_SIZE_KB=$((200 * 1024 * 1024 + 2000 * 1024 * 1024 + 250 * 1024 * 1024 + 150 * 1024 * 1024 + 600 * 1024 * 1024 + 50 * 1024 * 1024))

if [ "$VG_SIZE_KB" -lt "$TOTAL_LV_SIZE_KB" ]; then
    echo "WARNING: The total size of logical volumes may exceed the available space."
    echo "Volume group size: ${VG_SIZE_KB}KB"
    echo "Required size: ${TOTAL_LV_SIZE_KB}KB"
    echo
    read -p "Do you want to adjust the logical volume sizes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Please edit this script and adjust the volume sizes before running it again."
        exit 1
    fi
fi

read -p "Do you want to proceed with creating these logical volumes? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# Create logical volumes
section "Creating Logical Volumes"

# Create mirrored volumes for critical data
echo "Creating mirrored volumes for critical data..."
echo "Creating lv_home (50GB, RAID1)..."
lvcreate --type raid1 -m1 -L 50G -n lv_home vg_data
echo "Creating lv_data (2TB, RAID1)..."
lvcreate --type raid1 -m1 -L 2T -n lv_data vg_data
echo "✓ Mirrored volumes created"

# Create striped volumes for performance
echo "Creating striped volumes for performance..."
echo "Creating lv_docker (250GB, RAID0)..."
lvcreate --type raid0 -i 3 -L 250G -n lv_docker vg_data
echo "Creating lv_virtualbox (150GB, RAID0)..."
lvcreate --type raid0 -i 3 -L 150G -n lv_virtualbox vg_data
echo "Creating lv_models (600GB, RAID0)..."
lvcreate --type raid0 -i 3 -L 600G -n lv_models vg_data
echo "✓ Striped volumes created"

# Create standard volume
echo "Creating standard volume..."
echo "Creating lv_var (50GB)..."
lvcreate -L 50G -n lv_var vg_data
echo "✓ Standard volume created"

# Display logical volume information
section "Logical Volume Information"
lvs
echo "✓ All logical volumes created"

# Format logical volumes
section "Formatting Logical Volumes"
echo "Formatting logical volumes with ext4 filesystem..."

echo "Formatting lv_home..."
mkfs.ext4 -L home /dev/vg_data/lv_home

echo "Formatting lv_docker..."
mkfs.ext4 -L docker /dev/vg_data/lv_docker

echo "Formatting lv_virtualbox..."
mkfs.ext4 -L virtualbox /dev/vg_data/lv_virtualbox

echo "Formatting lv_models..."
mkfs.ext4 -L models /dev/vg_data/lv_models

echo "Formatting lv_data..."
mkfs.ext4 -L data /dev/vg_data/lv_data

echo "Formatting lv_var..."
mkfs.ext4 -L var /dev/vg_data/lv_var


echo "Setting up /var structure..."
mkdir -p /mnt/var_temp
mount /dev/vg_data/lv_var /mnt/var_temp

# Create the essential directory structure
mkdir -p /mnt/var_temp/log/apt
mkdir -p /mnt/var_temp/log/kde-installer
mkdir -p /mnt/var_temp/cache/apt/archives
mkdir -p /mnt/var_temp/lib/python3
mkdir -p /mnt/var_temp/lib/apt
mkdir -p /mnt/var_temp/crash
mkdir -p /mnt/var_temp/spool
mkdir -p /mnt/var_temp/tmp
chmod 1777 /mnt/var_temp/tmp

# Set proper permissions
chmod 755 /mnt/var_temp/log/kde-installer

# Unmount the temporary location
umount /mnt/var_temp
echo "✓ All logical volumes formatted"

section "Logical Volumes Setup Complete"
echo "Your logical volumes have been created and formatted."
echo "You can now proceed to the next script: 03-lvm-mount-config.sh"
