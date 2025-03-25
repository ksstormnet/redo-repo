#!/bin/bash
# shellcheck disable=SC1091,SC2154,SC2310,SC2311,SC2312,SC2317

# lvm-setup.sh
# Version: 1.0
# Date: March 25, 2025
#
# Consolidated script for LVM setup
# This script handles the complete LVM setup process:
# 1. Wiping existing LVM configuration (if needed)
# 2. Creating physical volumes from NVMe drives
# 3. Creating a volume group
# 4. Creating and formatting logical volumes

# Exit on any error and inherit errexit in command substitutions
set -e
shopt -s inherit_errexit

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
section() {
    echo
    echo -e "${BOLD}========================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BOLD}========================================================${NC}"
    echo
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Cleanup function
cleanup() {
    # Reset terminal attributes to avoid potential issues
    tput sgr0 2>/dev/null || true
    echo "Cleanup complete"
}

# Set up trap to call cleanup function on exit
trap cleanup EXIT

confirm() {
    local prompt="$1"
    local default="$2"

    if [[ "${default}" = "Y" ]]; then
        local options="[Y/n]"
        local default_value="Y"
    else
        local options="[y/N]"
        local default_value="N"
    fi

    read -p "${prompt} ${options}: " -r REPLY
    REPLY=${REPLY:-${default_value}}

    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to display disk size in human-readable format
human_readable_size() {
    local size_bytes="$1"
    local result
    if [[ "${size_bytes}" -gt 1099511627776 ]]; then # TB (1024^4)
        result=$(bc <<< "scale=2; ${size_bytes} / 1099511627776")
        echo "${result} TB"
    elif [[ "${size_bytes}" -gt 1073741824 ]]; then # GB (1024^3)
        result=$(bc <<< "scale=2; ${size_bytes} / 1073741824")
        echo "${result} GB"
    elif [[ "${size_bytes}" -gt 1048576 ]]; then # MB (1024^2)
        result=$(bc <<< "scale=2; ${size_bytes} / 1048576")
        echo "${result} MB"
    elif [[ "${size_bytes}" -gt 1024 ]]; then # KB
        result=$(bc <<< "scale=2; ${size_bytes} / 1024")
        echo "${result} KB"
    else
        echo "${size_bytes} bytes"
    fi
}

# Function to check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command '$1' not found."
        return 1
    fi
    return 0
}

# Check if script is run as root
if [[ "${EUID}" -ne 0 ]]; then
    error "Please run this script as root (use sudo)."
fi

# Display welcome message
section "LVM Setup - Consolidated Script"
echo "This script will set up LVM on your NVMe drives, creating:"
echo "- Physical volumes on all NVMe drives"
echo "- A volume group combining these drives"
echo "- Logical volumes with appropriate RAID levels"
echo "- Formatted filesystems for each volume"
echo

# Check required tools
section "Checking Required Tools"
required_tools=("pvs" "vgs" "pvcreate" "vgcreate" "lvm" "bc" "mkfs.ext4")
missing_tools=0

for tool in "${required_tools[@]}"; do
    if ! check_command "${tool}"; then
        missing_tools=$((missing_tools + 1))
    fi
done

if [[ ${missing_tools} -gt 0 ]]; then
    section "Installing LVM Tools"
    if ! apt update; then
        error "Failed to update package repositories."
    fi

    if ! apt install -y lvm2 bc; then
        error "Failed to install required packages."
    fi
    success "LVM tools installed"
else
    success "All required tools are installed"
fi

# Scan for NVMe drives
section "Scanning for NVMe Drives"
# Use mapfile to safely populate the array
declare -a NVME_DRIVES
# First check if NVMe drives exist
if ls /dev/nvme*n1 &>/dev/null; then
    mapfile -t NVME_DRIVES < <(ls /dev/nvme*n1 2>/dev/null || true)
else
    NVME_DRIVES=()
fi

if [[ ${#NVME_DRIVES[@]} -eq 0 ]]; then
    error "No NVMe drives found. Please check your hardware."
fi

# Count drives and calculate total raw capacity
DRIVE_COUNT=0
TOTAL_RAW_CAPACITY=0

echo "Found the following NVMe drives for LVM setup:"
for drive in "${NVME_DRIVES[@]}"; do
    # Get drive size in bytes
    if ! DRIVE_SIZE=$(blockdev --getsize64 "${drive}" 2>/dev/null); then
        warning "Could not get size for ${drive}"
        continue
    fi

    HUMAN_SIZE=$(human_readable_size "${DRIVE_SIZE}")
    echo "  - ${drive} (${HUMAN_SIZE})"

    DRIVE_COUNT=$((DRIVE_COUNT + 1))
    TOTAL_RAW_CAPACITY=$((TOTAL_RAW_CAPACITY + DRIVE_SIZE))
done

# Convert total raw capacity to human-readable form
TOTAL_HUMAN_CAPACITY=$(human_readable_size "${TOTAL_RAW_CAPACITY}")

echo
echo "Total drives: ${DRIVE_COUNT}"
echo "Combined raw capacity: ${TOTAL_HUMAN_CAPACITY}"
echo

if ! confirm "Are these the correct drives for your LVM setup?" "N"; then
    error "Operation canceled. Please adjust the drive configuration."
fi

# Check if there is an existing LVM configuration
section "Checking Existing LVM Configuration"
PVS_OUTPUT=$(pvs || true)
if echo "${PVS_OUTPUT}" | grep -q -F "${NVME_DRIVES[0]}"; then
    warning "Existing LVM configuration detected on one or more drives."

    if confirm "Do you want to wipe existing LVM configuration? ALL DATA WILL BE LOST!" "N"; then
        section "Wiping Existing LVM Configuration"

        echo "Unmounting any logical volumes..."
        MOUNT_OUTPUT=$(mount || true)
        mounted_lvs=$(echo "${MOUNT_OUTPUT}" | grep "/dev/mapper/vg_data" | awk '{print $1}' || echo "")
        for lv in ${mounted_lvs}; do
            echo "Unmounting ${lv}..."
            umount "${lv}" || warning "Could not unmount ${lv}, may be in use"
        done

        echo "Deactivating and removing volume group..."
        vgchange -an vg_data 2>/dev/null || true
        vgremove -f vg_data 2>/dev/null || true

        echo "Removing physical volumes..."
        for drive in "${NVME_DRIVES[@]}"; do
            echo "Removing physical volume on ${drive}..."
            pvremove -ff "${drive}" 2>/dev/null || true
        done

        echo "Clearing drive signatures..."
        for drive in "${NVME_DRIVES[@]}"; do
            echo "Clearing ${drive}..."
            wipefs -a "${drive}" || warning "Could not clear all signatures on ${drive}"
            success "${drive} cleared"
        done

        success "Existing LVM configuration wiped"
    else
        error "Cannot proceed with existing LVM configuration. Operation canceled."
    fi
fi

# Create physical volumes
section "Creating Physical Volumes"
echo "Creating physical volumes on NVMe drives..."

PV_SUCCESS=0
for drive in "${NVME_DRIVES[@]}"; do
    echo "Creating physical volume on ${drive}..."
    if ! pvcreate "${drive}" -ff; then
        warning "Failed to create physical volume on ${drive}. Will continue with other drives."
    else
        success "Physical volume created on ${drive}"
        PV_SUCCESS=$((PV_SUCCESS + 1))
    fi
done

if [[ ${PV_SUCCESS} -eq 0 ]]; then
    error "Failed to create any physical volumes. Cannot continue."
fi

# Display physical volumes
if ! pvs; then
    warning "Failed to display physical volumes, but continuing anyway."
fi

if [[ ${PV_SUCCESS} -eq ${DRIVE_COUNT} ]]; then
    success "All physical volumes created successfully"
else
    warning "Created ${PV_SUCCESS} out of ${DRIVE_COUNT} physical volumes"
fi

# Create volume group
section "Creating Volume Group"
echo "Creating volume group 'vg_data' combining all NVMe drives..."

# Wait a moment for any system updates to complete
echo "Waiting for system to settle..."
sleep 5

# Create volume group using the NVME_DRIVES array
if ! vgcreate vg_data "${NVME_DRIVES[@]}" -ff; then
    error "Failed to create volume group 'vg_data'"
fi

success "Volume group 'vg_data' created"

# Display volume group information
section "Volume Group Information"
if ! vgdisplay vg_data; then
    warning "Failed to display volume group information, but continuing anyway."
fi

# Check total size and free space
VG_SIZE_BYTES=$(vgs --units b vg_data --noheadings --nosuffix -o vg_size 2>/dev/null || echo "0")
VG_FREE_BYTES=$(vgs --units b vg_data --noheadings --nosuffix -o vg_free 2>/dev/null || echo "0")
VG_SIZE=$(human_readable_size "${VG_SIZE_BYTES}")
VG_FREE=$(human_readable_size "${VG_FREE_BYTES}")

echo "Total volume group size: ${VG_SIZE}"
echo "Available space: ${VG_FREE}"

# Function to create a logical volume with interactive sizing
create_volume() {
    local name="$1"
    local default_size="$2"
    local volume_type="$3"
    local description="$4"

    echo
    echo "======== Creating Volume: ${name} ========"
    echo "Description: ${description}"
    echo "Type: ${volume_type}"
    echo "Default size: ${default_size}G"

    # Prompt for custom size
    read -r -p "Enter size in GB (or press Enter for default ${default_size}G): " size
    size=${size:-${default_size}}

    echo "Creating ${name} (${size}GB ${volume_type})..."

    # Create volume based on type
    case ${volume_type} in
        "raid1")
            lvcreate --type raid1 -m1 -L "${size}G" -n "${name}" vg_data || {
                warning "Failed to create RAID1 volume. Trying standard volume instead."
                lvcreate -L "${size}G" -n "${name}" vg_data || return 1
            }
            ;;
        "raid0")
            # Count available physical volumes for striping
            pv_count=$({ pvs || true; } | grep -c "vg_data")

            # Determine optimal stripe count (use at most pv_count-1 for RAID0)
            if [[ "${pv_count}" -le 2 ]]; then
                stripe_count=1  # Not enough drives for proper striping
                warning "Only ${pv_count} drives available. Using single drive (no striping)."
                lvcreate -L "${size}G" -n "${name}" vg_data || return 1
            else
                # Use at most 6 drives or all available drives, whichever is less
                # Leave one drive as buffer for safety
                max_stripes=6
                stripe_count=$(( pv_count > max_stripes ? max_stripes : pv_count - 1 ))
                echo "Using ${stripe_count} drives for striping..."
                lvcreate --type raid0 -i "${stripe_count}" -L "${size}G" -n "${name}" vg_data || {
                    warning "Failed to create RAID0 volume. Trying standard volume instead."
                    lvcreate -L "${size}G" -n "${name}" vg_data || return 1
                }
            fi
            ;;
        "standard")
            lvcreate -L "${size}G" -n "${name}" vg_data || return 1
            ;;
        *)
            warning "Unknown volume type: ${volume_type}, using standard"
            lvcreate -L "${size}G" -n "${name}" vg_data || return 1
            ;;
    esac

    success "Volume ${name} created"
    return 0
}

# Create logical volumes - from largest to smallest
section "Creating Logical Volumes"
echo "The following logical volumes will be created (in order of creation):"
echo "- lv_data (Remaining space, RAID1): Primary data storage"
echo "- lv_models (800GB, RAID0): AI model storage"
echo "- lv_docker (150GB, RAID0): Docker containers and images"
echo "- lv_virtualbox (150GB, RAID0): VirtualBox VMs"
echo "- lv_home (50GB, RAID1): User home directory"
echo

if ! confirm "Do you want to proceed with creating logical volumes?" "Y"; then
    error "Operation canceled."
fi

# Calculate remaining space for lv_data (leaving ~0.29TB buffer)
TOTAL_FIXED_GB=$((800 + 150 + 150 + 50))
BUFFER_GB=290
VG_FREE_GB=$(echo "scale=0; ${VG_FREE_BYTES}/1024/1024/1024" | bc)
LV_DATA_SIZE=$(( VG_FREE_GB - TOTAL_FIXED_GB - BUFFER_GB ))

if [[ ${LV_DATA_SIZE} -le 0 ]]; then
    error "Not enough space for all volumes. Please reduce sizes or add more drives."
fi

echo "Creating volumes from largest to smallest..."

# Create lv_data with remaining space (minus buffer)
echo "Creating lv_data (${LV_DATA_SIZE} GB RAID1)..."
if ! lvcreate --type raid1 -m1 -L "${LV_DATA_SIZE}G" -n lv_data vg_data; then
    warning "Failed to create RAID1 volume for lv_data. Trying without RAID..."
    if ! lvcreate -L "${LV_DATA_SIZE}G" -n lv_data vg_data; then
        error "Failed to create lv_data volume."
    fi
fi
success "Volume lv_data created"

# Create lv_models (RAID0)
create_volume "lv_models" "800" "raid0" "AI model storage" ||
    error "Failed to create lv_models"

# Create lv_docker (RAID0)
create_volume "lv_docker" "150" "raid0" "Docker containers and images" ||
    error "Failed to create lv_docker"

# Create lv_virtualbox (RAID0)
create_volume "lv_virtualbox" "150" "raid0" "VirtualBox VM storage" ||
    error "Failed to create lv_virtualbox"

# Create lv_home (RAID1)
create_volume "lv_home" "50" "raid1" "User home directory" ||
    error "Failed to create lv_home"

# Display logical volume information
section "Logical Volume Information"
lvs
echo "✓ All logical volumes created"

# Format logical volumes
section "Formatting Logical Volumes"
echo "The following logical volumes will be formatted with ext4:"
echo "- lv_data (mounted at /data)"
echo "- lv_home (mounted at /home/scott)"
echo "- lv_docker (mounted at /docker)"
echo "- lv_virtualbox (mounted at /data/virtualbox)"
echo "- lv_models (mounted at /opt/models)"
echo

if ! confirm "Do you want to proceed with formatting? THIS WILL ERASE ALL DATA!" "N"; then
    warning "Formatting skipped. You'll need to format the volumes manually."
    exit 0
fi

echo "Formatting logical volumes..."

echo "Formatting lv_data..."
mkfs.ext4 -L data -m 0.5 /dev/vg_data/lv_data || warning "Failed to format lv_data"

echo "Formatting lv_home..."
mkfs.ext4 -L home -m 1 /dev/vg_data/lv_home || warning "Failed to format lv_home"

echo "Formatting lv_docker..."
mkfs.ext4 -L docker -m 0.5 /dev/vg_data/lv_docker || warning "Failed to format lv_docker"

echo "Formatting lv_virtualbox..."
mkfs.ext4 -L virtualbox -m 0.5 /dev/vg_data/lv_virtualbox || warning "Failed to format lv_virtualbox"

echo "Formatting lv_models..."
mkfs.ext4 -L models -m 0.5 /dev/vg_data/lv_models || warning "Failed to format lv_models"

success "Logical volumes formatted"

# Final instructions
section "LVM Setup Complete"
echo "The LVM setup is now complete. You can now continue with the Ubuntu Server installation."
echo
echo "When you reach the storage configuration step in the installer:"
echo "1. Choose 'Manual' storage configuration"
echo "2. Make sure to use the existing root filesystem on sda2"
echo "3. Do NOT format any of the logical volumes - we'll set them up after installation"
echo
echo "After the installation completes and you've rebooted:"
echo "1. Run lvm-chroot.sh to configure mount points"
echo "2. After final reboot, run lvm-finish.sh to set up directories and symlinks"
echo
echo "Your logical volumes:"
lvs
echo
echo "Available space remaining:"
vgs --units g vg_data -o vg_free

exit 0
