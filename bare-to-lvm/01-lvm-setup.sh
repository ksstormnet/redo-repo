#!/bin/bash

# 01-lvm-setup-enhanced.sh
# This script creates physical volumes and a volume group for LVM setup
# with dynamic NVMe drive handling, error checking, and space monitoring
# Run this after 00-lvm-prepare.sh

# Exit on any error
set -e

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display section headers
section() {
    echo
    echo "========================================================"
    echo -e "  ${BLUE}$1${NC}"
    echo "========================================================"
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

# Function to display error messages
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command '$1' not found."
        return 1
    fi
    return 0
}

# Function to display disk size in human-readable format
human_readable_size() {
    local size_bytes=$1
    if [ "$size_bytes" -gt 1099511627776 ]; then # TB (1024^4)
        echo "$(bc <<< "scale=2; $size_bytes / 1099511627776") TB"
    elif [ "$size_bytes" -gt 1073741824 ]; then # GB (1024^3)
        echo "$(bc <<< "scale=2; $size_bytes / 1073741824") GB"
    elif [ "$size_bytes" -gt 1048576 ]; then # MB (1024^2)
        echo "$(bc <<< "scale=2; $size_bytes / 1048576") MB"
    elif [ "$size_bytes" -gt 1024 ]; then # KB
        echo "$(bc <<< "scale=2; $size_bytes / 1024") KB"
    else
        echo "$size_bytes bytes"
    fi
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "Enhanced LVM Volume Group Setup"
echo "This script will create physical volumes and set up the volume group."
echo "It will dynamically detect and use all available NVMe drives."
echo "Make sure you've already run 00-lvm-prepare.sh before continuing."
echo

read -r -p "Have you run 00-lvm-prepare.sh? (y/n): " -n 1
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Please run 00-lvm-prepare.sh first."
    exit 1
fi

# Configure console font size
section "Console Font Configuration"
echo "Let's configure the console font for better visibility."
echo "This will open the console setup utility where you can select a larger font."
echo "Recommended: Select 'UTF-8', then 'Terminus', then a larger size like '16x32'."
echo

read -r -p "Configure console font now? (y/n): " -n 1
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! dpkg-reconfigure console-setup; then
        warning "Failed to configure console font, but continuing anyway."
    else
        success "Console font configured successfully"
    fi
fi

# Check required tools
section "Checking Required Tools"
required_tools=("pvs" "vgs" "pvcreate" "vgcreate" "lvm" "bc")
missing_tools=0

for tool in "${required_tools[@]}"; do
    if ! check_command "$tool"; then
        missing_tools=$((missing_tools + 1))
    fi
done

if [ $missing_tools -gt 0 ]; then
    section "Installing LVM Tools"
    if ! apt update; then
        error "Failed to update package repositories."
        exit 1
    fi
    
    if ! apt install -y lvm2 bc; then
        error "Failed to install required packages."
        exit 1
    fi
    success "LVM tools installed"
else
    success "All required tools are installed"
fi

# Scan for NVMe drives
section "Scanning for NVMe Drives"
# Use mapfile to safely populate the array
if ! mapfile -t NVME_DRIVES < <(ls /dev/nvme*n1 2>/dev/null); then
    NVME_DRIVES=()
fi

if [ ${#NVME_DRIVES[@]} -eq 0 ]; then
    error "No NVMe drives found. Please check your hardware."
    exit 1
fi

# Count drives and calculate total raw capacity
DRIVE_COUNT=0
TOTAL_RAW_CAPACITY=0

echo "Found the following NVMe drives for LVM setup:"
for drive in "${NVME_DRIVES[@]}"; do
    # Get drive size in bytes
    if ! DRIVE_SIZE=$(blockdev --getsize64 "$drive" 2>/dev/null); then
        warning "Could not get size for $drive"
        continue
    fi
    
    HUMAN_SIZE=$(human_readable_size "$DRIVE_SIZE")
    echo "  - $drive ($HUMAN_SIZE)"
    
    DRIVE_COUNT=$((DRIVE_COUNT + 1))
    TOTAL_RAW_CAPACITY=$((TOTAL_RAW_CAPACITY + DRIVE_SIZE))
done

# Convert total raw capacity to human-readable form
TOTAL_HUMAN_CAPACITY=$(human_readable_size "$TOTAL_RAW_CAPACITY")

echo
echo "Total drives: $DRIVE_COUNT"
echo "Combined raw capacity: $TOTAL_HUMAN_CAPACITY"
echo

read -r -p "Are these the correct drives for your LVM setup? (y/n): " -n 1
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Operation canceled. Please adjust the script to match your drive configuration."
    exit 1
fi

# Create physical volumes
section "Creating Physical Volumes"
echo "Creating physical volumes on NVMe drives..."

PV_SUCCESS=0
for drive in "${NVME_DRIVES[@]}"; do
    echo "Creating physical volume on $drive..."
    if ! pvcreate "$drive" -ff; then
        warning "Failed to create physical volume on $drive. Will continue with other drives."
    else
        success "Physical volume created on $drive"
        PV_SUCCESS=$((PV_SUCCESS + 1))
    fi
done

if [ $PV_SUCCESS -eq 0 ]; then
    error "Failed to create any physical volumes. Cannot continue."
    exit 1
fi

# Display physical volumes
if ! pvs; then
    warning "Failed to display physical volumes, but continuing anyway."
fi

if [ $PV_SUCCESS -eq $DRIVE_COUNT ]; then
    success "All physical volumes created successfully"
else
    warning "Created $PV_SUCCESS out of $DRIVE_COUNT physical volumes"
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
    exit 1
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
VG_SIZE=$(human_readable_size "$VG_SIZE_BYTES")
VG_FREE=$(human_readable_size "$VG_FREE_BYTES")

echo "Total volume group size: $VG_SIZE"
echo "Available space: $VG_FREE"

# Calculate and display efficiency metrics
if [ "$TOTAL_RAW_CAPACITY" -gt 0 ] && [ "$VG_SIZE_BYTES" -gt 0 ]; then
    EFFICIENCY=$(bc <<< "scale=2; ($VG_SIZE_BYTES * 100) / $TOTAL_RAW_CAPACITY")
    echo "LVM space efficiency: ${EFFICIENCY}% of raw drive capacity"
    
    if (( $(bc <<< "$EFFICIENCY < 90") )); then
        warning "LVM space efficiency is below 90%. Some space is reserved for LVM metadata."
    fi
fi

section "LVM Volume Group Setup Complete"
success "The volume group 'vg_data' has been successfully created."
echo "Available space for logical volumes: $VG_FREE"
echo "You can now proceed to the next script: 02-lvm-logical-volumes.sh"
echo
echo "To monitor your LVM setup, you can use these commands:"
echo "  - pvs: Display physical volume information"
echo "  - vgs: Display volume group information"
echo "  - vgdisplay vg_data: Display detailed volume group information"
