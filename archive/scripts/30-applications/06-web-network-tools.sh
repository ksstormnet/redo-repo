#!/usr/bin/env bash
# ============================================================================
# 06-web-network-tools.sh
# ----------------------------------------------------------------------------
# Installs web and network applications including:
# - FileZilla
# - Remmina
# - Termius
# - Network monitoring and utility tools
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${FORCE_MODE:=false}"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="06-web-network-tools"

# ============================================================================
# Installation Functions
# ============================================================================

# Install FileZilla FTP client
function install_filezilla() {
    log_step "Installing FileZilla FTP client"
    
    if check_state "${SCRIPT_NAME}_filezilla_installed"; then
        log_info "FileZilla is already installed. Skipping..."
        return 0
    fi
    
    # Install FileZilla
    if ! apt_install filezilla; then
        log_error "Failed to install FileZilla"
        return 1
    fi
    
    set_state "${SCRIPT_NAME}_filezilla_installed"
    log_success "FileZilla installed successfully"
    return 0
}

# Install Remmina Remote Desktop client
function install_remmina() {
    log_step "Installing Remmina Remote Desktop client"
    
    if check_state "${SCRIPT_NAME}_remmina_installed"; then
        log_info "Remmina is already installed. Skipping..."
        return 0
    fi
    
    # Add the Remmina PPA for the latest version
    log_info "Adding Remmina PPA"
    if ! add_apt_repository -y ppa:remmina-ppa-team/remmina-next; then
        log_warning "Failed to add Remmina PPA. Falling back to standard repositories."
    else
        apt_update
    fi
    
    # Install Remmina and its plugins
    if ! apt_install remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-spice remmina-plugin-secret; then
        log_error "Failed to install Remmina and its plugins"
        return 1
    fi
    
    set_state "${SCRIPT_NAME}_remmina_installed"
    log_success "Remmina installed successfully"
    return 0
}

# Install Termius SSH client
function install_termius() {
    log_step "Installing Termius SSH client"
    
    if check_state "${SCRIPT_NAME}_termius_installed"; then
        log_info "Termius is already installed. Skipping..."
        return 0
    fi
    
    # Check if snap is installed
    if ! command -v snap &> /dev/null; then
        log_info "Installing snapd package manager"
        if ! apt_install snapd; then
            log_error "Failed to install snapd"
            return 1
        fi
    fi
    
    # Install Termius using snap
    if ! snap install termius-app; then
        log_error "Failed to install Termius"
        return 1
    fi
    
    # Create a desktop shortcut for Termius
    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi
    
    mkdir -p "${user_home}/.local/share/applications"
    
    cat > "${user_home}/.local/share/applications/termius.desktop" << EOF
[Desktop Entry]
Name=Termius
Comment=SSH client
Exec=/snap/bin/termius-app
Icon=/snap/termius-app/current/meta/gui/icon.png
Terminal=false
Type=Application
Categories=Network;RemoteAccess;
EOF
    
    # Set permissions
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "${user_home}/.local/share/applications/termius.desktop"
        chmod +x "${user_home}/.local/share/applications/termius.desktop"
    else
        chmod +x "${user_home}/.local/share/applications/termius.desktop"
    fi
    
    set_state "${SCRIPT_NAME}_termius_installed"
    log_success "Termius installed successfully"
    return 0
}

# WireGuard VPN installation removed as requested

# Install network monitoring and analysis tools
function install_network_tools() {
    log_step "Installing network monitoring and analysis tools"
    
    if check_state "${SCRIPT_NAME}_network_tools_installed"; then
        log_info "Network tools are already installed. Skipping..."
        return 0
    fi
    
    # Install a variety of network tools
    local network_tools=(
        nmap             # Network discovery and security auditing
        wireshark        # Network protocol analyzer
        ethtool          # Display or change Ethernet device settings
        iperf3           # Network performance measurement tool
        mtr              # Network diagnostic tool
        nethogs          # Net top tool
        bmon             # Bandwidth monitor
        speedtest-cli    # Command line interface for testing internet bandwidth
        wavemon          # Wireless monitoring utility
    )
    
    if ! apt_install "${network_tools[@]}"; then
        log_error "Failed to install network tools"
        return 1
    fi
    
    # Give permissions for non-root user to capture packets with Wireshark
    if getent group wireshark &>/dev/null; then
        if [[ -n "${SUDO_USER}" ]]; then
            log_info "Adding user ${SUDO_USER} to the wireshark group"
            usermod -a -G wireshark "${SUDO_USER}"
        fi
    fi
    
    set_state "${SCRIPT_NAME}_network_tools_installed"
    log_success "Network tools installed successfully"
    return 0
}

# Install web development tools
function install_web_tools() {
    log_step "Installing web development tools"
    
    if check_state "${SCRIPT_NAME}_web_tools_installed"; then
        log_info "Web development tools are already installed. Skipping..."
        return 0
    fi
    
    # Install web development tools
    local web_tools=(
        curl             # Command line tool for transferring data
        wget             # Internet file retriever
        git              # Distributed version control
    )
    
    # Check if postman exists in repositories
    if apt_cache_policy postman | grep -q "Candidate:"; then
        web_tools+=(postman)  # API development environment
    else
        log_warning "Postman not found in repositories, not adding to install list"
    fi
    
    if ! apt_install "${web_tools[@]}"; then
        log_error "Failed to install web tools"
        return 1
    fi
    
    set_state "${SCRIPT_NAME}_web_tools_installed"
    log_success "Web development tools installed successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_web_network_tools() {
    log_section "Installing Web and Network Tools"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Web and Network tools have already been installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install applications
    install_filezilla || log_warning "FileZilla installation encountered issues"
    install_remmina || log_warning "Remmina installation encountered issues"
    install_termius || log_warning "Termius installation encountered issues"
    # WireGuard installation removed as requested
    install_network_tools || log_warning "Network tools installation encountered issues"
    install_web_tools || log_warning "Web tools installation encountered issues"
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Web and Network Tools installation completed successfully"
    
    # Remind user to log out and back in for group changes to take effect
    if [[ -n "${SUDO_USER}" ]]; then
        log_warning "You need to log out and back in for group changes to take effect"
    fi
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Call the main function
install_web_network_tools

# Return the exit code
exit $?
