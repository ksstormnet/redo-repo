#!/bin/bash

# 00-lvm-prepare.sh
# This script prepares drives for LVM setup during Kubuntu installation
# It installs necessary tools and clears existing RAID configurations

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

# Function to check if running in live environment
check_live_environment() {
    if [ ! -d /cdrom ]; then
        echo "WARNING: This script is designed to run from a live environment."
        echo "It doesn't appear you're running from a live USB/DVD."
        echo
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting. Please boot from the installation media."
            exit 1
        fi
    fi
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "LVM Preparation Script"
echo "This script will prepare your drives for LVM setup."
echo "WARNING: This will erase all data on the NVMe drives."
echo
read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# Check if running in live environment
check_live_environment

# Install necessary tools
section "Installing Required Tools"
apt update
apt install -y lvm2 mdadm
echo "✓ Required tools installed"

# Stop any existing RAID arrays
section "Stopping Existing RAID Arrays"
echo "Stopping any existing RAID arrays..."
mdadm --stop /dev/md0 2>/dev/null || true
mdadm --stop /dev/md1 2>/dev/null || true
mdadm --stop /dev/md2 2>/dev/null || true
mdadm --stop /dev/md3 2>/dev/null || true
mdadm --stop /dev/md127 2>/dev/null || true
echo "✓ RAID arrays stopped (if any)"

# Scan for NVMe drives
section "Scanning for NVMe Drives"
NVME_DRIVES=$(ls /dev/nvme*n1 2>/dev/null || echo "")
if [ -z "$NVME_DRIVES" ]; then
    echo "No NVMe drives found. Please check your hardware."
    exit 1
fi

echo "Found the following NVMe drives:"
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

# Clear superblocks and any RAID signatures
section "Clearing Drive Signatures"
echo "Clearing superblocks and RAID signatures on NVMe drives..."
for drive in $NVME_DRIVES; do
    echo "Processing $drive..."
    
    # Clear RAID superblocks
    mdadm --zero-superblock "$drive" 2>/dev/null || true
    
    # Clear filesystem and other signatures
    wipefs -a "$drive"
    
    echo "✓ $drive cleared"
done

section "Verification"
echo "Verifying drives are clear of signatures..."
for drive in $NVME_DRIVES; do
    SIGNATURES=$(wipefs -n "$drive" | grep -cv "offset")
    if [ "$SIGNATURES" -gt 0 ]; then
        echo "WARNING: $drive still has some signatures. You may need to clear them manually."
        wipefs -n "$drive"
    else
        echo "✓ $drive is clear of signatures"
    fi
done

section "LVM Preparation Complete"
echo "Your drives are now prepared for LVM setup."
echo "You can proceed to the next script: 01-lvm-setup.sh"
