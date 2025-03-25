#!/bin/bash
# ============================================================================
# system_utils.sh
# ----------------------------------------------------------------------------
# System utilities for installer scripts
# Provides functions for system information, hardware detection, etc.
# ============================================================================

# STATE_DIR should be defined in common.sh, but set a default if not
: "${STATE_DIR:=/var/cache/system-installer}"
# XDG_SESSION_TYPE may not be set in all environments
: "${XDG_SESSION_TYPE:=x11}"

# Get system information
function get_system_info() {
    log_section "System Information"
    
    # OS Information - break down complex commands to avoid masking return values
    local os_info
    if ! os_info=$(lsb_release -ds 2>/dev/null); then
        # Alternative method if lsb_release fails
        local pretty_name
        pretty_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d '\"') || true
        os_info="${pretty_name:-Unknown OS}"
    fi
    log_info "Operating System: ${os_info}"
    
    # Get kernel info
    local kernel_info
    kernel_info=$(uname -sr) || true
    log_info "Kernel: ${kernel_info}"
    
    # Hardware Information - break down complex commands
    local cpu_info
    cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//') || true
    log_info "CPU: ${cpu_info}"
    
    # Get memory info
    local memory_info
    memory_info=$(free -h | grep Mem | awk '{print $2}') || true
    log_info "Memory: ${memory_info}"
    
    # Disk Information
    log_info "Disk Space:"
    df -h / | grep -v Filesystem || true
    
    # Network Information
    log_info "Network Interfaces:"
    ip -br addr show | grep -v "lo" || true
    
    return 0
}

# Detect if system is using UEFI or BIOS
function is_uefi_system() {
    if [[ -d "/sys/firmware/efi" ]]; then
        log_debug "System is using UEFI"
        return 0
    else
        log_debug "System is using legacy BIOS"
        return 1
    fi
}

# Detect if system has NVIDIA GPU
function has_nvidia_gpu() {
    # Store result to avoid masking return value
    local lspci_result
    lspci_result=$(lspci) || true
    
    if echo "${lspci_result}" | grep -i nvidia &> /dev/null; then
        log_debug "NVIDIA GPU detected"
        return 0
    else
        log_debug "No NVIDIA GPU detected"
        return 1
    fi
}

# Detect if system has AMD GPU
function has_amd_gpu() {
    # Store result to avoid masking return value
    local lspci_result
    lspci_result=$(lspci) || true
    
    if echo "${lspci_result}" | grep -iE "amd|radeon" &> /dev/null; then
        log_debug "AMD GPU detected"
        return 0
    else
        log_debug "No AMD GPU detected"
        return 1
    fi
}

# Detect if system has Intel integrated graphics
function has_intel_gpu() {
    # Store result to avoid masking return value
    local lspci_result
    lspci_result=$(lspci) || true
    
    if echo "${lspci_result}" | grep -i "intel.*graphics" &> /dev/null; then
        log_debug "Intel integrated graphics detected"
        return 0
    else
        log_debug "No Intel integrated graphics detected"
        return 1
    fi
}

# Detect if system is a laptop
function is_laptop() {
    # Check if battery exists
    if [[ -d /sys/class/power_supply/BAT0 || -d /sys/class/power_supply/BAT1 ]]; then
        log_debug "System is a laptop (battery detected)"
        return 0
    fi
    
    # Check DMI for chassis type - avoid masking return value
    local dmidecode_path
    dmidecode_path=$(command -v dmidecode) || true
    
    if [[ -x "${dmidecode_path}" ]]; then
        local chassis_info
        chassis_info=$(dmidecode -t chassis) || true
        
        if echo "${chassis_info}" | grep -i "notebook\|laptop\|portable" &> /dev/null; then
            log_debug "System is a laptop (DMI chassis type)"
            return 0
        fi
    fi
    
    log_debug "System is not a laptop"
    return 1
}

# Detect system architecture
function get_system_architecture() {
    local arch
    arch=$(dpkg --print-architecture) || true
    echo "${arch}"
    log_debug "System architecture: ${arch}"
    return 0
}

# Check if system needs a reboot
function system_needs_reboot() {
    if [[ -f /var/run/reboot-required ]]; then
        log_debug "System needs reboot (/var/run/reboot-required exists)"
        return 0
    fi
    
    if [[ -f "${STATE_DIR}/reboot_required" ]]; then
        log_debug "System needs reboot (installer reboot marker exists)"
        return 0
    fi
    
    log_debug "System does not need a reboot"
    return 1
}

# Check system RAM
function get_system_memory() {
    # Break down complex command to avoid masking return value
    local free_output
    free_output=$(free -m) || true
    
    local memory
    memory=$(echo "${free_output}" | grep "Mem:" | awk '{print $2}') || true
    echo "${memory}"
    log_debug "System memory: ${memory}MB"
    return 0
}

# Check if a service is running
function is_service_running() {
    local service_name="$1"
    
    if systemctl is-active --quiet "${service_name}"; then
        log_debug "Service ${service_name} is running"
        return 0
    else
        log_debug "Service ${service_name} is not running"
        return 1
    fi
}

# Check if system is connected to the internet
function is_internet_connected() {
    if ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
        log_debug "System is connected to the internet"
        return 0
    else
        log_debug "System is not connected to the internet"
        return 1
    fi
}

# Check if system is using systemd
function is_using_systemd() {
    if [[ -d /run/systemd/system ]]; then
        log_debug "System is using systemd"
        return 0
    else
        log_debug "System is not using systemd"
        return 1
    fi
}

# Get CPU information
function get_cpu_info() {
    # Break down complex commands to avoid masking return values
    local cpu_info
    cpu_info=$(grep "model name" /proc/cpuinfo) || true
    
    local cpu_model
    cpu_model=$(echo "${cpu_info}" | head -1 | cut -d: -f2 | sed 's/^[ \t]*//') || true
    
    local cpu_cores
    cpu_cores=$(grep -c "processor" /proc/cpuinfo) || true
    
    echo "Model: ${cpu_model}, Cores: ${cpu_cores}"
    log_debug "CPU info: Model=${cpu_model}, Cores=${cpu_cores}"
    return 0
}

# Get disk information
function get_disk_info() {
    local disk="$1"
    
    if [[ -z "${disk}" ]]; then
        disk="/dev/sda"
    fi
    
    if [[ -b "${disk}" ]]; then
        log_debug "Disk information for ${disk}:"
        lsblk "${disk}" -o NAME,SIZE,FSTYPE,MOUNTPOINT,MODEL
        return 0
    else
        log_error "Disk ${disk} not found"
        return 1
    fi
}

# Check if a package repository is enabled
function is_repository_enabled() {
    local repo="$1"
    
    if grep -r "^deb.*${repo}" /etc/apt/sources.list /etc/apt/sources.list.d/ &> /dev/null; then
        log_debug "Repository ${repo} is enabled"
        return 0
    else
        log_debug "Repository ${repo} is not enabled"
        return 1
    fi
}

# Check if user exists
function user_exists() {
    local username="$1"
    
    if id "${username}" &> /dev/null; then
        log_debug "User ${username} exists"
        return 0
    else
        log_debug "User ${username} does not exist"
        return 1
    fi
}

# Check if group exists
function group_exists() {
    local groupname="$1"
    
    if getent group "${groupname}" &> /dev/null; then
        log_debug "Group ${groupname} exists"
        return 0
    else
        log_debug "Group ${groupname} does not exist"
        return 1
    fi
}

# Get current user's home directory
function get_user_home() {
    local username="${1:-${SUDO_USER}}"
    
    if [[ -z "${username}" ]]; then
        username="$(whoami)"
    fi
    
    local homedir
    homedir=$(getent passwd "${username}" | cut -d: -f6) || true
    
    echo "${homedir}"
    log_debug "Home directory for ${username}: ${homedir}"
    return 0
}

# Check if running under Wayland or X11
function is_wayland_session() {
    if [[ "${XDG_SESSION_TYPE}" == "wayland" ]]; then
        log_debug "Session is running under Wayland"
        return 0
    else
        log_debug "Session is not running under Wayland (likely X11)"
        return 1
    fi
}

# Detect and configure CPU governor
function set_cpu_governor() {
    local governor="${1:-performance}"
    
    if ! command -v cpupower &> /dev/null; then
        log_info "Installing cpupower package"
        apt_install linux-tools-common linux-tools-generic
    fi
    
    log_info "Setting CPU governor to ${governor}"
    if ! cpupower frequency-set -g "${governor}"; then
        log_warning "Failed to set CPU governor to ${governor}, trying alternative method"
        
        # Alternative method: directly write to sysfs
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [[ -f "${cpu}" ]]; then
                echo "${governor}" > "${cpu}"
            fi
        done
    fi
    
    log_success "CPU governor set to ${governor}"
    return 0
}

# Get current CPU governor
function get_cpu_governor() {
    local cpu="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    
    if [[ -f "${cpu}" ]]; then
        # Use command substitution instead of cat
        local governor
        governor=$(< "${cpu}")
        echo "${governor}"
        return 0
    else
        log_error "Could not determine CPU governor"
        return 1
    fi
}

# Verify system meets minimum requirements
function verify_system_requirements() {
    local min_memory="$1"  # in MB
    local min_disk="$2"    # in MB
    
    # Default values if not provided
    min_memory=${min_memory:-2048}  # 2GB RAM
    min_disk=${min_disk:-10240}     # 10GB disk space
    
    log_section "Verifying System Requirements"
    
    # Check RAM - break down complex command to avoid masking return value
    local free_output
    free_output=$(free -m) || true
    
    local memory
    memory=$(echo "${free_output}" | grep "Mem:" | awk '{print $2}') || true
    
    if [[ "${memory}" -lt "${min_memory}" ]]; then
        log_error "Insufficient memory: ${memory}MB (minimum ${min_memory}MB required)"
        return 1
    fi
    log_info "Memory: ${memory}MB (✓)"
    
    # Check disk space - break down complex command
    local df_output
    df_output=$(df -m /) || true
    
    local disk_space
    disk_space=$(echo "${df_output}" | awk 'NR==2 {print $4}') || true
    
    if [[ "${disk_space}" -lt "${min_disk}" ]]; then
        log_error "Insufficient disk space: ${disk_space}MB (minimum ${min_disk}MB required)"
        return 1
    fi
    log_info "Disk space: ${disk_space}MB (✓)"
    
    # Check internet connection
    if ! is_internet_connected; then
        log_error "No internet connection detected"
        return 1
    fi
    log_info "Internet connection: Connected (✓)"
    
    log_success "System meets all requirements"
    return 0
}
