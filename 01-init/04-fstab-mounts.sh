#!/bin/bash
# ============================================================================
# 04-fstab-mounts.sh
# ----------------------------------------------------------------------------
# Configures /etc/fstab to mount /dev/sdb1 and /dev/sdd1 by UUID
# Mounts them to /restart and /mnt/usb respectively
# This script should be run with root privileges
# ============================================================================

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="04-fstab-mounts"

# ============================================================================
# Functions
# ============================================================================

# Get UUID for a device path
function get_device_uuid() {
    local device_path="$1"
    local uuid

    # Check if device exists
    if [[ ! -b "${device_path}" ]]; then
        log_error "Device ${device_path} does not exist or is not a block device"
        return 1
    fi

    # Get UUID using blkid
    uuid=$(blkid -s UUID -o value "${device_path}")
    if [[ -z "${uuid}" ]]; then
        log_error "Could not determine UUID for ${device_path}"
        return 1
    fi

    echo "${uuid}"
    return 0
}

# Create mount point if it doesn't exist
function create_mount_point() {
    local mount_point="$1"

    if [[ ! -d "${mount_point}" ]]; then
        log_step "Creating mount point: ${mount_point}"
        if ! mkdir -p "${mount_point}"; then
            log_error "Failed to create mount point: ${mount_point}"
            return 1
        fi
    else
        log_debug "Mount point already exists: ${mount_point}"
    fi

    return 0
}

# Add entry to /etc/fstab
function add_fstab_entry() {
    local uuid="$1"
    local mount_point="$2"
    local fs_type="$3"
    local mount_options="$4"
    local dump="$5"
    local fsck="$6"

    # Backup fstab
    if [[ ! -f "/etc/fstab.backup" ]]; then
        log_step "Backing up /etc/fstab to /etc/fstab.backup"
        cp /etc/fstab /etc/fstab.backup
    fi

    # Check if entry already exists
    if grep -q "UUID=${uuid}" /etc/fstab; then
        log_step "Updating existing fstab entry for UUID=${uuid}"
        # Remove existing entry
        sed -i "/UUID=${uuid}/d" /etc/fstab
    else
        log_step "Adding new fstab entry for UUID=${uuid}"
    fi

    # Add new entry
    echo "UUID=${uuid} ${mount_point} ${fs_type} ${mount_options} ${dump} ${fsck}" >> /etc/fstab

    # Verify fstab syntax
    if ! mountpoint -q "${mount_point}"; then
        log_step "Testing mount for ${mount_point}"
        if ! mount "${mount_point}"; then
            log_error "Failed to mount ${mount_point}. Reverting fstab changes."
            cp /etc/fstab.backup /etc/fstab
            return 1
        else
            log_info "Successfully mounted ${mount_point}"
        fi
    else
        log_info "${mount_point} is already mounted"
    fi

    return 0
}

# Configure fstab entries for required mounts
function configure_fstab_entries() {
    log_section "Configuring fstab Entries for Required Mounts"

    if check_state "${SCRIPT_NAME}_fstab_configured"; then
        log_info "fstab entries already configured. Skipping..."
        return 0
    fi

    # Define devices to mount
    local restart_device="/dev/sdb1"
    local usb_device="/dev/sdd1"

    # Define mount points
    local restart_mount="/restart"
    local usb_mount="/mnt/usb"

    # Create mount points
    log_step "Creating mount points"
    create_mount_point "${restart_mount}" || return 1
    create_mount_point "${usb_mount}" || return 1

    # Get UUIDs
    log_step "Getting device UUIDs"
    local restart_uuid
    restart_uuid=$(get_device_uuid "${restart_device}")
    if [[ $? -ne 0 || -z "${restart_uuid}" ]]; then
        # Try to manually find the device by partition label or size if UUID detection fails
        log_warning "Could not determine UUID automatically. Checking alternative methods..."

        # Check for devices with label 'restart'
        local labeled_device
        labeled_device=$(blkid -L "restart")
        if [[ -n "${labeled_device}" ]]; then
            restart_uuid=$(blkid -s UUID -o value "${labeled_device}")
            if [[ -n "${restart_uuid}" ]]; then
                log_info "Found restart device by label: ${labeled_device} with UUID: ${restart_uuid}"
            fi
        else
            log_error "Could not determine UUID for ${restart_device}. Please provide it manually."
            return 1
        fi
    fi

    local usb_uuid
    usb_uuid=$(get_device_uuid "${usb_device}")
    if [[ $? -ne 0 || -z "${usb_uuid}" ]]; then
        # Try to manually find the device by partition label or size
        log_warning "Could not determine UUID automatically. Checking alternative methods..."

        # Check for devices with label 'usb' or 'USB'
        local labeled_device
        labeled_device=$(blkid -L "usb" || blkid -L "USB")
        if [[ -n "${labeled_device}" ]]; then
            usb_uuid=$(blkid -s UUID -o value "${labeled_device}")
            if [[ -n "${usb_uuid}" ]]; then
                log_info "Found USB device by label: ${labeled_device} with UUID: ${usb_uuid}"
            fi
        else
            log_error "Could not determine UUID for ${usb_device}. Please provide it manually."
            return 1
        fi
    fi

    log_info "Detected restart device UUID: ${restart_uuid}"
    log_info "Detected USB device UUID: ${usb_uuid}"

    # Add fstab entries
    log_step "Adding fstab entries"

    # Add restart entry (defaults, dump=0, fsck=2)
    add_fstab_entry "${restart_uuid}" "${restart_mount}" "ext4" "defaults,noatime" "0" "2" || return 1

    # Add USB entry (defaults, dump=0, fsck=2)
    add_fstab_entry "${usb_uuid}" "${usb_mount}" "ext4" "defaults,noatime" "0" "2" || return 1

    # Mark as completed
    set_state "${SCRIPT_NAME}_fstab_configured"
    log_success "fstab entries configured successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_fstab_mounts() {
    log_section "Setting Up fstab Mounts"

    # Configure fstab entries
    if ! configure_fstab_entries; then
        log_error "Failed to configure fstab entries"
        return 1
    fi

    log_success "fstab mounts configuration completed successfully"
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize the script
initialize

# Check for root privileges
check_root

# Run the main function
setup_fstab_mounts

# Return the exit code
exit $?
