#!/bin/bash

# 00-lvm-wipe.sh
# This script wipes all LVM configuration from NVMe drives

set -e

section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

section "LVM Configuration Wipe"
echo "WARNING: This will remove ALL LVM configuration including volume groups"
echo "and logical volumes. ALL DATA WILL BE LOST!"
echo
read -r -p "Are you sure you want to proceed? (Type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
    echo "Operation canceled."
    exit 1
fi

section "Unmounting Logical Volumes"
# Get all mounted logical volumes from vg_data
mounted_lvs=$(mount | grep "/dev/mapper/vg_data" | awk '{print $1}')

for lv in $mounted_lvs; do
    echo "Unmounting $lv..."
    umount "$lv" || echo "Could not unmount $lv, may be in use"
done

section "Removing Volume Group"
vgchange -an vg_data 2>/dev/null || true
vgremove -f vg_data 2>/dev/null || true

section "Removing Physical Volumes"
NVME_DRIVES=$(ls /dev/nvme*n1 2>/dev/null || echo "")
for drive in $NVME_DRIVES; do
    echo "Removing physical volume on $drive..."
    pvremove -ff "$drive" 2>/dev/null || true
done

section "Clearing Drive Signatures"
for drive in $NVME_DRIVES; do
    echo "Clearing $drive..."
    wipefs -a "$drive"
    echo "✓ $drive cleared"
done

section "Verification"
echo "Verifying drives are clear of signatures..."
for drive in $NVME_DRIVES; do
    SIGNATURES=$(wipefs -n "$drive" | grep -cv "offset")
    if [ "$SIGNATURES" -gt 0 ]; then
        echo "WARNING: $drive still has some signatures."
        wipefs -n "$drive"
    else
        echo "✓ $drive is clear of signatures"
    fi
done

section "LVM Configuration Wiping Complete"
echo "All LVM configuration has been removed from your NVMe drives."
echo "You can now proceed with a fresh installation using 00-lvm-prepare.sh"
