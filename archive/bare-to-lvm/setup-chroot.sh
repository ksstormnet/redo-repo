#!/bin/bash

# setup-chroot.sh
# This script automates the chroot setup process for the LVM installation
# It mounts the necessary filesystems and prepares the chroot environment

# Exit on any error
set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display section headers
section() {
    echo
    echo -e "${BOLD}========================================================${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}========================================================${NC}"
    echo
}

# Function to display success messages
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to display error messages and exit
error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root (use sudo)."
fi

# Display welcome message
section "Chroot Setup for LVM Installation"
echo "This script will set up a chroot environment for the LVM installation."
echo "It will mount the necessary filesystems and prepare the chroot environment."
echo

# Ask for the root partition device
read -r -p "Enter the root partition device (e.g., /dev/sda2 or /dev/vg_data/lv_root): " ROOT_DEVICE
if [ -z "$ROOT_DEVICE" ]; then
    error "Root partition device cannot be empty."
fi

# Ask for the EFI partition device
read -r -p "Enter the EFI partition device (e.g., /dev/sda1): " EFI_DEVICE
if [ -z "$EFI_DEVICE" ]; then
    error "EFI partition device cannot be empty."
fi

# Mount the root partition
section "Mounting Root Partition"
echo "Mounting $ROOT_DEVICE to /mnt..."
if ! mount "$ROOT_DEVICE" /mnt; then
    error "Failed to mount $ROOT_DEVICE to /mnt."
fi
success "Root partition mounted"

# Create and mount the EFI partition
section "Mounting EFI Partition"
echo "Creating EFI mount point if it doesn't exist..."
mkdir -p /mnt/boot/efi

echo "Mounting $EFI_DEVICE to /mnt/boot/efi..."
if ! mount "$EFI_DEVICE" /mnt/boot/efi; then
    error "Failed to mount $EFI_DEVICE to /mnt/boot/efi."
fi
success "EFI partition mounted"

# Bind mount the necessary filesystems
section "Binding Necessary Filesystems"
echo "Binding /dev, /dev/pts, /proc, /sys, and /run..."
for i in /dev /dev/pts /proc /sys /run; do
    echo "Binding $i to /mnt$i..."
    mkdir -p "/mnt$i"
    if ! mount -B "$i" "/mnt$i"; then
        error "Failed to bind mount $i to /mnt$i."
    fi
    success "$i bound to /mnt$i"
done

# Create and mount the USB directory
section "Setting Up USB Mount"
echo "Creating USB mount point in chroot..."
mkdir -p /mnt/usb

echo "Mounting /dev/sdd1 to /mnt/usb..."
if ! mount /dev/sdd1 /mnt/usb; then
    warning "Failed to mount /dev/sdd1 to /mnt/usb. This might be because the device doesn't exist or is already mounted."
    warning "You may need to manually mount the USB drive after entering the chroot environment."
else
    success "USB drive mounted to /mnt/usb"
fi

# Final instructions
section "Chroot Setup Complete"
echo "The chroot environment is now set up. You can enter it with:"
echo -e "${BOLD}sudo chroot /mnt${NC}"
echo
echo "After you're done with the chroot environment, exit it with:"
echo -e "${BOLD}exit${NC}"
echo
echo "Then unmount everything with:"
echo -e "${BOLD}for i in /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys /mnt/run; do sudo umount \$i; done${NC}"
echo -e "${BOLD}sudo umount /mnt/usb${NC}"
echo -e "${BOLD}sudo umount /mnt/boot/efi${NC}"
echo -e "${BOLD}sudo umount /mnt${NC}"
echo
echo "Would you like to enter the chroot environment now? (y/n)"
read -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Entering chroot environment..."
    chroot /mnt
    echo "Exited from chroot environment."
    echo "Remember to unmount everything when you're done!"
else
    echo "You can enter the chroot environment later with: sudo chroot /mnt"
fi

echo
echo -e "${GREEN}${BOLD}Script completed successfully!${NC}"
