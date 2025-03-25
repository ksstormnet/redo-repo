#!/bin/bash
# ============================================================================
# common.sh
# ----------------------------------------------------------------------------
# Common utility functions for system installer scripts
# This is the main library that sources all other utility scripts
# ============================================================================

# Determine script directory regardless of symlinks
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library modules
# shellcheck disable=SC1091
source "${COMMON_DIR}/log-utils.sh"
# shellcheck disable=SC1091
source "${COMMON_DIR}/state-utils.sh"
# shellcheck disable=SC1091
source "${COMMON_DIR}/package-utils.sh"
# shellcheck disable=SC1091
source "${COMMON_DIR}/system-utils.sh"
# shellcheck disable=SC1091
source "${COMMON_DIR}/ui-utils.sh"
# shellcheck disable=SC1091
source "${COMMON_DIR}/error-utils.sh"

# Global variables
SCRIPT_START_TIME=""
SCRIPT_START_TIME=$(date +%s) || true
SCRIPT_NAME=""
SCRIPT_NAME=$(basename "$0" .sh)
STATE_DIR="/var/cache/system-installer"
# LOG_DIR is used in other scripts that source this file
export LOG_DIR="/var/log/system-installer"

# These variables are set in main-installer.sh and referenced here
# Default values if not set elsewhere
: "${FORCE_MODE:=false}"
: "${AUTO_REBOOT:=false}"
: "${DRY_RUN:=false}"

# Initialize function to be called at the start of each script
function initialize() {
    # Check if running as root
    if [[ ${EUID} -ne 0 ]]; then
        echo "ERROR: This script must be run as root" >&2
        exit 1
    fi
    
    # Initialize state directory
    mkdir -p "${STATE_DIR}"
    
    # Initialize logging
    init_logging
    
    # Log script start
    log_info "Starting script: ${SCRIPT_NAME}"
    log_debug "Command line: $0 $*"
    
    return 0
}

# Set sudo timeout (in seconds)
function set_sudo_timeout() {
    local timeout="${1:-3600}"  # Default to 1 hour
    
    # Set sudo timestamp timeout
    if command -v sudo &> /dev/null; then
        sudo -v
        echo "Defaults timestamp_timeout=${timeout}" | sudo tee /etc/sudoers.d/installer-timeout > /dev/null
        log_debug "Set sudo timeout to ${timeout} seconds"
    fi
    
    return 0
}

# Check if running as root
function check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        log_error "This script must be run as root"
        return 1
    fi
    return 0
}

# Check if running in force mode
function is_force_mode() {
    [[ "${FORCE_MODE}" == "true" ]]
}

# Detect if running in a VM
function is_running_in_vm() {
    if type -p systemd-detect-virt > /dev/null; then
        if systemd-detect-virt -q; then
            # Store command result to avoid masking return value
            local vm_type
            vm_type=$(systemd-detect-virt) || true
            log_debug "Running in a virtual machine: ${vm_type}"
            return 0
        fi
    else
        # Fallback detection method
        if grep -q "^flags.*hypervisor" /proc/cpuinfo; then
            log_debug "Running in a virtual machine (detected via /proc/cpuinfo)"
            return 0
        fi
    fi
    
    log_debug "Not running in a virtual machine"
    return 1
}

# Function to handle reboots
function handle_reboot() {
    local reason="${1:-"Required for changes to take effect"}"
    
    # Create reboot marker with next script to run
    if [[ -n "$2" ]]; then
        echo "$2" > "${STATE_DIR}/next_script"
    fi
    
    touch "${STATE_DIR}/reboot_required"
    
    log_warning "System reboot required: ${reason}"
    
    if [[ "${AUTO_REBOOT}" == "true" ]]; then
        log_info "Auto-reboot is enabled. Rebooting in 5 seconds..."
        sleep 5
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY RUN] Would reboot system now"
        else
            log_info "Rebooting system now"
            reboot
        fi
    else
        log_warning "Please reboot the system when convenient using 'sudo reboot'"
        log_info "After reboot, run this script again to continue installation"
    fi
    
    exit 0
}

# Verify that all required utilities are available
function verify_required_utilities() {
    local required_utilities=("$@")
    local missing_utilities=()
    
    for util in "${required_utilities[@]}"; do
        if ! command -v "${util}" &> /dev/null; then
            missing_utilities+=("${util}")
        fi
    done
    
    if [[ ${#missing_utilities[@]} -gt 0 ]]; then
        log_error "Missing required utilities: ${missing_utilities[*]}"
        log_info "Please install them using: apt install ${missing_utilities[*]}"
        return 1
    fi
    
    return 0
}

# Print elapsed time
function print_elapsed_time() {
    # Declare first, then assign to avoid masking return values
    local end_time
    end_time=$(date +%s) || true
    local duration=$((end_time - SCRIPT_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    
    log_info "Elapsed time: ${hours}h ${minutes}m ${seconds}s"
    return 0
}

# Cleanup function to run at script exit
function cleanup() {
    print_elapsed_time
    log_info "Script ${SCRIPT_NAME} completed with exit code $?"
    return 0
}

# Register the cleanup function to run at exit
trap cleanup EXIT
