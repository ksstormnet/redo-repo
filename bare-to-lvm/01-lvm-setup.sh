#!/bin/bash

# 01-lvm-setup.sh
# This script creates physical volumes and a volume group for LVM setup
# Run this after 00-lvm-prepare.sh

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
section "LVM Volume Group Setup"
echo "This script will create physical volumes and set up the volume group."
echo "Make sure you've already run 00-lvm-prepare.sh before continuing."
echo
read -p "Have you run 00-lvm-prepare.sh? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run 00-lvm-prepare.sh first."
    exit 1
fi

# Check if LVM tools are installed
if ! command -v pvs &> /dev/null || ! command -v vgs &> /dev/null; then
    section "Installing LVM Tools"
    apt update
    apt install -y lvm2
    echo "✓ LVM tools installed"
fi

# Scan for NVMe drives
section "Scanning for NVMe Drives"
NVME_DRIVES=$(ls /dev/nvme*n1 2>/dev/null || echo "")
if [ -z "$NVME_DRIVES" ]; then
    echo "No NVMe drives found. Please check your hardware."
    exit 1
fi

echo "Found the following NVMe drives for LVM setup:"
for drive in $NVME_DRIVES; do
    echo "  - $drive"
done

echo
read -p "Are these the correct drives for your LVM setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation canceled. Please adjust the script to match your drive configuration."
    exit 1
fi

# Create physical volumes
section "Creating Physical Volumes"
echo "Creating physical volumes on NVMe drives..."
for drive in $NVME_DRIVES; do
    echo "Creating physical volume on $drive..."
    pvcreate "$drive"
    echo "✓ Physical volume created on $drive"
done

# Display physical volumes
pvs
echo "✓ All physical volumes created"

# Create volume group
section "Creating Volume Group"
echo "Creating volume group 'vg_data' combining all NVMe drives..."

# Get drive list for vgcreate command
DRIVE_LIST=""
for drive in $NVME_DRIVES; do
    DRIVE_LIST="$DRIVE_LIST $drive"
done

vgcreate -ff vg_data "$DRIVE_LIST"
echo "✓ Volume group 'vg_data' created"

# Display volume group information
section "Volume Group Information"
vgdisplay vg_data
echo "✓ Volume group creation verified"

# Check total size
VG_SIZE=$(vgdisplay vg_data | grep "VG Size" | awk '{print $3 $4}')
echo "Total volume group size: $VG_SIZE"

section "LVM Volume Group Setup Complete"
echo "The volume group 'vg_data' has been successfully created."
echo "You can now proceed to the next script: 02-lvm-logical-volumes.sh"
