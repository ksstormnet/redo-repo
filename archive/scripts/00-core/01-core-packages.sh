#!/bin/bash
# ============================================================================
# 01-core-packages.sh
# ----------------------------------------------------------------------------
# Install essential system packages required for basic functionality
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

# FORCE_MODE may be set in common.sh, but set a default if not
: "${FORCE_MODE:=false}"

# Script name for state management and logging
SCRIPT_NAME="01-core-packages"

# Main function to install core packages
function install_core_packages() {
    log_section "Installing Core System Packages"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Core packages have already been installed. Skipping..."
        return 0
    fi

    # 1. Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # 2. Install essential system packages
    log_step "Installing essential system packages"
    local essential_system=(
        apt-transport-https
        ca-certificates
        curl
        dnsutils
        gnupg
        lsb-release
        net-tools
        openssh-server
        rsync
        software-properties-common
        ufw
        wget
    )

    if ! apt_install "${essential_system[@]}"; then
        log_error "Failed to install essential system packages"
        return 1
    fi

    # 3. Install system utilities
    log_step "Installing system utilities"
    local system_utils=(
        htop
        glances
        neofetch
        iotop
        iftop
        lm-sensors
        mtr
        ncdu
        nfs-common
        parted
        smartmontools
        tmux
        tree
        vim
        whois
    )

    if ! apt_install "${system_utils[@]}"; then
        log_error "Failed to install system utilities"
        return 1
    fi

    # 4. Install archive utilities
    log_step "Installing archive utilities"
    local archive_utils=(
        p7zip-full
        p7zip-rar
        unrar
        unzip
        zip
        gzip
        tar
        xz-utils
    )

    if ! apt_install "${archive_utils[@]}"; then
        log_error "Failed to install archive utilities"
        return 1
    fi

    # 5. Network security tools
    log_step "Installing network security tools"
    local network_tools=(
        ssh
        sshfs
        nmap
        tcpdump
        traceroute
        netcat-traditional
        iperf3
    )

    if ! apt_install "${network_tools[@]}"; then
        log_error "Failed to install network tools"
        return 1
    fi

    # 6. Set up firewall defaults
    log_step "Setting up UFW (Uncomplicated Firewall)"
    if command -v ufw &> /dev/null; then
        # Allow SSH connections
        log_info "Configuring firewall to allow SSH connections"
        if ! ufw allow ssh; then
            log_warning "Failed to configure UFW to allow SSH"
        fi

        # Enable firewall
        log_info "Enabling firewall"
        if ! echo "y" | ufw enable; then
            log_warning "Failed to enable UFW"
        else
            log_success "UFW configured successfully with SSH allowed"
        fi
    else
        log_warning "UFW not installed, skipping firewall configuration"
    fi

    # 7. Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Core packages installation completed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize the script
initialize

# Set the sudo password timeout to 1 hour (3600 seconds) to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_core_packages

# Return the exit code
exit $?
