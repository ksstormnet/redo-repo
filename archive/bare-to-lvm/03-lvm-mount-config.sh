#!/bin/bash

# 03-lvm-mount-config-enhanced.sh
# This script configures mount points and fstab for the LVM setup
# Run this after 02-lvm-logical-volumes-enhanced.sh in the chroot environment
#
# Enhancements:
# - Improved error handling
# - Better user interaction
# - Dynamic mount point configuration
# - Additional validation checks
# - Enhanced logging

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

# Function to confirm actions
confirm() {
    local prompt="$1"
    local default="$2"
    
    if [ "$default" = "Y" ]; then
        local options="[Y/n]"
        local default_value="Y"
    else
        local options="[y/N]"
        local default_value="N"
    fi
    
    read -p "$prompt $options: " -r REPLY
    REPLY=${REPLY:-$default_value}
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if a volume exists
volume_exists() {
    lvs --noheadings -o lv_name,vg_name | grep -q "\s*$1\s*vg_data"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root (use sudo)."
fi

# Display welcome message
section "LVM Mount Configuration (Enhanced)"
echo "This script will configure mount points and fstab for your LVM volumes."
echo "NOTE: This script should be run from within a chroot environment after"
echo "you have mounted your new system's root partition and chrooted into it."
echo
echo "For example:"
echo "  1. Mount your root partition: sudo mount /dev/vg_data/lv_root /mnt"
echo "  2. Mount EFI partition: sudo mount /dev/sdX1 /mnt/boot/efi"
echo "  3. Set up bind mounts: for i in /dev /dev/pts /proc /sys /run; do sudo mount -B \$i /mnt\$i; done"
echo "  4. Chroot into system: sudo chroot /mnt"
echo "  5. Then run this script"
echo

# Check if we're in a chroot environment
if ! confirm "Are you in a chroot environment of your new system?" "N"; then
    warning "Please set up and enter a chroot environment first."
    exit 1
fi

# Check if LVM tools are installed in the chroot
if ! command_exists lvs; then
    section "Installing LVM Tools"
    echo "LVM tools not found. Installing..."
    
    if ! apt update; then
        error "Failed to update package repository. Check your internet connection."
    fi
    
    if ! apt install -y lvm2; then
        error "Failed to install LVM tools. Please install them manually."
    fi
    
    success "LVM tools installed"
fi

# Verify logical volumes exist
section "Verifying Logical Volumes"
if ! lvs | grep -q vg_data; then
    error "No logical volumes found in vg_data. Please run previous scripts first."
fi

echo "Found the following logical volumes:"
lvs -o lv_name,lv_size,lv_attr,vg_name --separator " | " --noheadings | grep vg_data
echo

# Define the volumes and their mount points
declare -A volumes=(
    ["lv_home"]="/home"
    ["lv_docker"]="/var/lib/docker"
    ["lv_virtualbox"]="/data/virtualbox"
    ["lv_data"]="/data"
    ["lv_models"]="/opt/models"
    ["lv_var"]="/var"
)

# Validate all volumes exist
section "Validating Logical Volumes"
missing_volumes=0
for vol in "${!volumes[@]}"; do
    if volume_exists "$vol"; then
        success "Volume $vol exists"
    else
        warning "Volume $vol does not exist"
        missing_volumes=$((missing_volumes + 1))
    fi
done

if [ $missing_volumes -gt 0 ]; then
    if ! confirm "Some volumes are missing. Continue anyway?" "N"; then
        error "Please create all required logical volumes first."
    fi
fi

# Create necessary mount points
section "Creating Mount Points"
echo "Creating mount points for logical volumes..."

for mount_point in "${volumes[@]}"; do
    if [ ! -d "$mount_point" ]; then
        mkdir -p "$mount_point"
        success "Mount point $mount_point created"
    else
        success "Mount point $mount_point already exists"
    fi
done

# Special handling for /var volume
if volume_exists "lv_var"; then
    section "Migrating /var Content"
    echo "Mounting new /var volume temporarily..."
    
    mkdir -p /var_new
    if ! mount /dev/vg_data/lv_var /var_new; then
        error "Failed to mount /dev/vg_data/lv_var to /var_new"
    fi
    
    echo "Copying existing /var content to new volume..."
    # Use rsync to preserve permissions and links
    if ! rsync -avxHAX /var/ /var_new/; then
        umount /var_new
        rmdir /var_new
        error "Failed to copy /var content to new volume"
    fi
    
    echo "Unmounting temporary mount point..."
    if ! umount /var_new; then
        warning "Failed to unmount /var_new. Will try to continue..."
    fi
    
    if ! rmdir /var_new; then
        warning "Failed to remove /var_new directory. Will try to continue..."
    fi
    
    success "/var data migrated successfully"
fi

# Configure fstab
section "Configuring fstab"
echo "Backing up existing fstab..."
cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d%H%M%S)"
success "Backup created: /etc/fstab.backup.$(date +%Y%m%d%H%M%S)"

echo "Would you like to customize mount options for each volume?"
if confirm "Use default options (defaults,0,2) for all volumes?" "Y"; then
    use_defaults=true
    echo "Using default mount options for all volumes"
else
    use_defaults=false
    echo "You'll be prompted for mount options for each volume"
fi

echo "Adding LVM mount points to fstab..."
echo -e "\n# LVM mount points - Added by 03-lvm-mount-config-enhanced.sh on $(date)" >> /etc/fstab

for vol in "${!volumes[@]}"; do
    if volume_exists "$vol"; then
        mount_point="${volumes[$vol]}"
        
        if [ "$use_defaults" = true ]; then
            options="defaults"
            dump="0"
            pass="2"
        else
            echo
            echo "Configuring mount options for $vol mounted at $mount_point"
            read -r -p "Enter mount options (default: defaults): " options
            options=${options:-defaults}
            
            read -r -p "Enter dump value (0-1, default: 0): " dump
            dump=${dump:-0}
            
            read -r -p "Enter pass value (0-2, default: 2): " pass
            pass=${pass:-2}
        fi
        
        # Add the entry to fstab
        echo "/dev/vg_data/$vol $mount_point ext4 $options $dump $pass" >> /etc/fstab
        success "Added $vol to fstab"
    fi
done

echo "New fstab entries:"
grep vg_data /etc/fstab
success "fstab updated"

# Update initramfs
section "Updating Initramfs"
echo "Updating initramfs to include LVM modules..."
if ! update-initramfs -u; then
    error "Failed to update initramfs. Please update it manually."
fi
success "Initramfs updated"

# Post-install instructions
section "Mount Configuration Complete"
echo "Mount configuration is complete. You can finish your installation and reboot."
echo
echo "After rebooting into your new system, run the final script:"
echo "04-lvm-post-install-enhanced.sh"
echo
echo "Important post-chroot steps:"
echo "1. Exit the chroot environment: type 'exit'"
echo "2. Unmount everything:"
echo "   for i in /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys /mnt/run; do sudo umount \$i; done"
echo "   sudo umount /mnt/boot/efi"
echo "   sudo umount /mnt"
echo "3. Reboot: sudo reboot"
echo

# Offer to test mount the volumes
section "Optional: Test Mount Points"
if confirm "Would you like to test mount the volumes to verify fstab entries?" "N"; then
    echo "Testing mount points..."
    
    mount -a -v 2>&1 | grep vg_data || true
    
    # Check if all volumes are mounted
    all_mounted=true
    for vol in "${!volumes[@]}"; do
        if volume_exists "$vol"; then
            mount_point="${volumes[$vol]}"
            if ! mount | grep -q "$mount_point"; then
                warning "$mount_point is not mounted"
                all_mounted=false
            else
                success "$mount_point is mounted correctly"
            fi
        fi
    done
    
    if [ "$all_mounted" = true ]; then
        success "All LVM volumes mounted successfully"
    else
        warning "Some volumes failed to mount. Check fstab entries and volume availability."
    fi
fi

echo
echo -e "${GREEN}${BOLD}Script completed successfully!${NC}"
echo "You may now continue with post-installation steps."
