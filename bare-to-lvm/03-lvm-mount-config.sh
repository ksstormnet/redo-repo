#!/bin/bash

# 03-lvm-mount-config.sh
# This script configures mount points and fstab for the LVM setup
# Run this after 02-lvm-logical-volumes.sh in the chroot environment

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
section "LVM Mount Configuration"
echo "This script will configure mount points and fstab for your LVM volumes."
echo "NOTE: This script should be run from within a chroot environment after"
echo "you have mounted your new system's root partition and chrooted into it."
echo
echo "For example:"
echo "  1. Mount your root partition: sudo mount /dev/sda2 /mnt"
echo "  2. Mount EFI partition: sudo mount /dev/sda1 /mnt/boot/efi"
echo "  3. Set up bind mounts: for i in /dev /dev/pts /proc /sys /run; do sudo mount -B \$i /mnt\$i; done"
echo "  4. Chroot into system: sudo chroot /mnt"
echo "  5. Then run this script"
echo

read -p "Are you in a chroot environment of your new system? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please set up and enter a chroot environment first."
    exit 1
fi

# Check if LVM tools are installed in the chroot
if ! command -v lvs &> /dev/null; then
    section "Installing LVM Tools"
    apt update
    apt install -y lvm2
    echo "✓ LVM tools installed"
fi

# Verify logical volumes exist
section "Verifying Logical Volumes"
if ! lvs | grep -q vg_data; then
    echo "No logical volumes found in vg_data. Please run previous scripts first."
    exit 1
fi

echo "Found the following logical volumes:"
lvs
echo

# Create necessary mount points
section "Creating Mount Points"
echo "Creating mount points for logical volumes..."

mkdir -p /home
mkdir -p /var/lib/docker
mkdir -p /VirtualBox
mkdir -p /data
mkdir -p /opt/models

echo "✓ Mount points created"

echo "Mounting new /var volume temporarily..."
mkdir -p /var_new
mount /dev/vg_data/lv_var /var_new

echo "Copying existing /var content to new volume..."
# Use rsync to preserve permissions and links
rsync -avxHAX /var/ /var_new/

echo "Unmounting temporary mount point..."
umount /var_new
rmdir /var_new

echo "✓ /var data migrated successfully"


# Configure fstab
section "Configuring fstab"
echo "Backing up existing fstab..."
cp /etc/fstab /etc/fstab.backup

echo "Adding LVM mount points to fstab..."
cat >> /etc/fstab << EOF
# LVM mount points
/dev/vg_data/lv_home     /home           ext4    defaults        0       2
/dev/vg_data/lv_docker   /var/lib/docker ext4    defaults        0       2
/dev/vg_data/lv_virtualbox /VirtualBox   ext4    defaults        0       2
/dev/vg_data/lv_models   /opt/models     ext4    defaults        0       2
/dev/vg_data/lv_data     /data           ext4    defaults        0       2
/dev/vg_data/lv_var      /var            ext4    defaults        0       2
EOF

echo "New fstab entries:"
grep vg_data /etc/fstab
echo "✓ fstab updated"

# Update initramfs
section "Updating Initramfs"
echo "Updating initramfs to include LVM modules..."
update-initramfs -u
echo "✓ Initramfs updated"

section "Mount Configuration Complete"
echo "Mount configuration is complete. You can finish your installation and reboot."
echo
echo "After rebooting into your new system, run the final script:"
echo "04-lvm-post-install.sh"
echo
echo "Important post-chroot steps:"
echo "1. Exit the chroot environment: type 'exit'"
echo "2. Unmount everything:"
echo "   for i in /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys /mnt/run; do sudo umount \$i; done"
echo "   sudo umount /mnt/boot/efi"
echo "   sudo umount /mnt"
echo "3. Reboot: sudo reboot"
