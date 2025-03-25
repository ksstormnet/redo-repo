#!/bin/bash

# 02-lvm-logical-volumes-enhanced.sh
# This script creates and formats logical volumes for the LVM setup with interactive sizing
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

# Function to display available space and usage
show_space_info() {
    # Get VG size in bytes for precise calculations
    VG_SIZE_B=$(vgs --units b vg_data --noheadings --nosuffix -o vg_size)
    VG_FREE_B=$(vgs --units b vg_data --noheadings --nosuffix -o vg_free)
    VG_USED_B=$(( VG_SIZE_B - VG_FREE_B ))
    
    # Convert to GB with 2 decimal precision
    VG_SIZE_GB=$(echo "scale=2; $VG_SIZE_B/1024/1024/1024" | bc)
    VG_FREE_GB=$(echo "scale=2; $VG_FREE_B/1024/1024/1024" | bc)
    VG_USED_GB=$(echo "scale=2; $VG_USED_B/1024/1024/1024" | bc)
    
    # Calculate usage percentage
    USAGE_PCT=$(echo "scale=2; ($VG_USED_B * 100) / $VG_SIZE_B" | bc)
    
    echo "Volume Group Space Information:"
    echo "----------------------------------------------"
    echo "Total Size:     ${VG_SIZE_GB} GB"
    echo "Used Space:     ${VG_USED_GB} GB (${USAGE_PCT}%)"
    echo "Free Space:     ${VG_FREE_GB} GB"
    echo "----------------------------------------------"
}

# Function to create a logical volume with interactive sizing
create_volume() {
    local name=$1
    local default_size=$2
    local volume_type=$3
    local description=$4
    
    echo
    echo "======== Creating Volume: $name ========"
    echo "Description: $description"
    echo "Type: $volume_type"
    echo "Default size: ${default_size}G"
    
    # Show current space usage
    show_space_info
    
    # Prompt for custom size
    read -r -p "Enter size in GB (or press Enter for default ${default_size}G): " size
    size=${size:-$default_size}
    
    echo "Creating $name (${size}GB, $volume_type)..."
    
    # Create volume based on type
    case $volume_type in
        "raid1")
            lvcreate --type raid1 -m1 -L "${size}G" -n "$name" vg_data
            ;;
        "raid0")
            # Count available physical volumes for striping
            pv_count=$(pvs | grep -c "vg_data")
            
            # Determine optimal stripe count (use at most pv_count-1 for RAID0)
            # This ensures we don't try to stripe across more drives than available
            if [ "$pv_count" -le 2 ]; then
                stripe_count=1  # Not enough drives for proper striping
                echo "WARNING: Only $pv_count drives available. Using single drive (no striping)."
                lvcreate -L "${size}G" -n "$name" vg_data
            else
                # Use at most 6 drives or all available drives, whichever is less
                # Leave one drive as buffer for safety
                max_stripes=6
                stripe_count=$(( pv_count > max_stripes ? max_stripes : pv_count - 1 ))
                echo "Using $stripe_count drives for striping..."
                lvcreate --type raid0 -i "$stripe_count" -L "${size}G" -n "$name" vg_data
            fi
            ;;
        "standard")
            lvcreate -L "${size}G" -n "$name" vg_data
            ;;
    esac
    
    echo "✓ Volume $name created"
    
    # Show updated space information
    show_space_info
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "Enhanced LVM Logical Volumes Setup"
echo "This script will interactively create and format logical volumes."
echo "You'll be able to specify custom sizes for each volume and monitor space usage."
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

# Display recommended volume configuration
section "Recommended Logical Volume Configuration"
echo "The following logical volumes are recommended:"
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
echo "You'll be able to customize the size of each volume during creation."
echo

# Show initial space information
section "Available Space"
show_space_info

read -p "Do you want to proceed with creating logical volumes? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# Create logical volumes interactively
section "Creating Logical Volumes"

# Create striped volumes for performance
echo "Creating striped volumes for performance..."
create_volume "lv_docker" "250" "raid0" "Docker containers and images"
create_volume "lv_virtualbox" "150" "raid0" "Virtual machine storage"
create_volume "lv_models" "600" "raid0" "AI model storage for LLM inference"

# Create mirrored volumes for critical data
create_volume "lv_home" "50" "raid1" "User profiles and config files"
create_volume "lv_data" "2000" "raid1" "User documents, media, and project files"

# Create standard volume
echo "Creating standard volume..."
create_volume "lv_var" "50" "standard" "System logs and temporary files"

# Display logical volume information
section "Logical Volume Information"
lvs
echo "✓ All logical volumes created"

# Format logical volumes
section "Formatting Logical Volumes"
echo "The following logical volumes will be formatted with ext4 filesystem:"
echo "  - lv_home"
echo "  - lv_docker"
echo "  - lv_virtualbox"
echo "  - lv_models"
echo "  - lv_data"
echo "  - lv_var"
echo

read -p "Do you want to proceed with formatting? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Formatting skipped. You'll need to format the volumes manually."
    exit 0
fi

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
echo "Final space allocation:"
show_space_info
echo "You can now proceed to the next script: 03-lvm-mount-config.sh"
