#!/usr/bin/env bash
# ============================================================================
# 02-special-apps.sh
# ----------------------------------------------------------------------------
# Installs special applications early in the process:
# - ckb-next for Corsair devices (with yellow keyboard configuration)
# - Warp Terminal (for continuing installation after KDE starts)
# ============================================================================

# shellcheck disable=SC1091,SC2154

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="02-special-apps"

# ============================================================================
# Installation Functions
# ============================================================================

# Function to detect Corsair devices
function detect_corsair_devices() {
    log_step "Detecting Corsair devices"
    
    # Check for Corsair devices via USB
    if lsusb | grep -i "Corsair" > /dev/null; then
        log_info "Corsair devices detected via lsusb"
        return 0
    fi
    
    # Alternative detection method using hwinfo if available
    if command -v hwinfo > /dev/null; then
        if hwinfo --usb | grep -i "Corsair" > /dev/null; then
            log_info "Corsair devices detected via hwinfo"
            return 0
        fi
    fi
    
    log_warning "No Corsair devices detected"
    return 1
}

# Function to install ckb-next
function install_ckb_next() {
    log_step "Installing ckb-next for Corsair devices"
    
    if check_state "${SCRIPT_NAME}_ckb_next_installed"; then
        log_info "ckb-next is already installed. Skipping..."
        return 0
    fi
    
    # Detect Corsair devices before installation
    if ! detect_corsair_devices; then
        log_warning "No Corsair devices detected. Installation of ckb-next is optional."
        
        # Ask for confirmation in interactive mode
        if [[ "${INTERACTIVE}" == "true" ]]; then
            if ! prompt_yes_no "Do you want to install ckb-next anyway?" "n"; then
                log_info "Skipping ckb-next installation by user choice"
                return 0
            fi
        else
            # Always install in non-interactive mode
            log_info "Installing ckb-next despite no devices detected (non-interactive mode)"
        fi
    fi
    
    # Install required dependencies
    log_info "Installing dependencies for ckb-next"
    local dependencies=(
        build-essential
        cmake
        libudev-dev
        qt5-default
        zlib1g-dev
        libpulse-dev
        libquazip5-dev
        libqt5x11extras5-dev
        libxcb-screensaver0-dev
        libxcb-ewmh-dev
        libxcb1-dev
        qttools5-dev
    )
    
    if ! apt_install "${dependencies[@]}"; then
        log_warning "Failed to install some ckb-next dependencies"
    fi
    
    # Add ckb-next PPA and install
    log_info "Adding ckb-next PPA"
    if ! add_apt_repository -y ppa:tatokis/ckb-next; then
        log_warning "Failed to add ckb-next PPA. Will try direct installation."
    else
        # Update package lists
        if ! apt_update; then
            log_warning "Failed to update package lists. Continuing anyway."
        fi
        
        # Install ckb-next from PPA
        if apt_install ckb-next; then
            log_success "ckb-next installed successfully from PPA"
            set_state "${SCRIPT_NAME}_ckb_next_installed"
            
            # Enable and start the service
            log_info "Enabling and starting ckb-next service"
            systemctl enable ckb-next
            systemctl start ckb-next
            
            return 0
        else
            log_warning "Failed to install ckb-next from PPA. Trying alternative methods."
        fi
    fi
    
    # Fall back to manual compilation if package installation fails
    log_warning "Trying to compile ckb-next from source"
    
    # Create temporary directory for building
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}" || return 1
    
    # Clone the repository
    log_info "Cloning ckb-next repository"
    if ! git clone --depth=1 https://github.com/ckb-next/ckb-next.git; then
        log_error "Failed to clone ckb-next repository"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Build and install
    cd ckb-next || return 1
    log_info "Building ckb-next from source"
    
    local nproc_count
    nproc_count=$(nproc)
    if ! mkdir -p build && cd build && cmake .. && make -j"${nproc_count}"; then
        log_error "Failed to build ckb-next"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    log_info "Installing ckb-next from source"
    if ! make install; then
        log_error "Failed to install ckb-next"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Clean up
    cd || return 1
    rm -rf "${temp_dir}"
    
    # Enable and start the service
    log_info "Enabling and starting ckb-next service"
    if ! systemctl enable ckb-next; then
        log_warning "Failed to enable ckb-next service. You may need to start it manually."
    fi
    
    if ! systemctl start ckb-next; then
        log_warning "Failed to start ckb-next service. You may need to start it manually."
    fi
    
    set_state "${SCRIPT_NAME}_ckb_next_installed"
    log_success "ckb-next installed successfully from source"
    return 0
}

# Function to configure ckb-next with yellow keyboard
function configure_ckb_next_yellow() {
    log_step "Configuring ckb-next with yellow full brightness"
    
    if check_state "${SCRIPT_NAME}_ckb_next_configured"; then
        log_info "ckb-next already configured. Skipping..."
        return 0
    fi
    
    # Check if ckb-next is installed
    if ! command -v ckb-next &> /dev/null; then
        log_warning "ckb-next not installed. Cannot configure."
        return 1
    fi
    
    # Wait for ckb-next service to be fully started
    log_info "Waiting for ckb-next service to be ready..."
    sleep 5
    
    # Create ckb-next config directory if it doesn't exist
    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi
    
    local ckb_config_dir="${user_home}/.config/ckb-next"
    mkdir -p "${ckb_config_dir}"
    
    # Create a basic profile with yellow full brightness
    log_info "Creating yellow keyboard profile"
    cat > "${ckb_config_dir}/ckb-next.conf" << EOF
[General]
Animation/Duration=1000
Animation/Enabled=false
DisableBuiltinKbd=false
DisableFirstRunDialog=true
GeometryMode=0
MacroNotifyInstant=false
MacroRepeatNotify=false
NumRows=6
QuietMode=false
ScrollSpeed=1
StartMinimized=false
StartupDelay=1000
TrayIcon=true

[Devices/0]
Brightness=100
DpiX=1000
DpiY=1000
FwAutoCheck=true
HwDpi=1000
HwDpiX=1000
HwDpiY=1000
MacroDelay=20
Name=Default Profile

[Devices/0/Lighting]
KeyColor=#ffff00
EOF
    
    # Set ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${ckb_config_dir}"
    fi
    
    # Restart ckb-next service to apply changes
    log_info "Restarting ckb-next service to apply changes"
    systemctl restart ckb-next
    
    set_state "${SCRIPT_NAME}_ckb_next_configured"
    log_success "ckb-next configured with yellow full brightness"
    return 0
}

# Function to install Warp Terminal
function install_warp_terminal() {
    log_step "Installing Warp Terminal"
    
    if check_state "${SCRIPT_NAME}_warp_terminal_installed"; then
        log_info "Warp Terminal is already installed. Skipping..."
        return 0
    fi
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}" || return 1
    
    # Download and install Warp Terminal
    local warp_version="v0.2023.07.18.08.02.stable_01"
    local warp_deb="warp-terminal_${warp_version}_amd64.deb"
    local warp_url="https://releases.warp.dev/stable/${warp_version}/${warp_deb}"
    
    log_info "Downloading Warp Terminal from ${warp_url}"
    
    # Try wget first, then curl as fallback
    if ! wget -q "${warp_url}" -O "${warp_deb}"; then
        log_warning "Failed to download Warp Terminal with wget. Trying curl..."
        
        if ! curl -sSL "${warp_url}" -o "${warp_deb}"; then
            log_error "Failed to download Warp Terminal. Please check your internet connection."
            rm -rf "${temp_dir}"
            return 1
        fi
    fi
    
    # Verify download
    if [[ ! -f "${warp_deb}" ]]; then
        log_error "Warp Terminal package not found. Installation failed."
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Install the package
    log_info "Installing Warp Terminal package"
    if ! dpkg -i "${warp_deb}"; then
        log_warning "Initial Warp Terminal installation failed. Fixing dependencies..."
        
        # Fix dependencies and retry
        if ! apt_fix_broken; then
            log_error "Failed to fix dependencies for Warp Terminal"
            rm -rf "${temp_dir}"
            return 1
        fi
        
        # Try again after fixing dependencies
        if ! dpkg -i "${warp_deb}"; then
            log_error "Failed to install Warp Terminal after fixing dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi
    fi
    
    # Clean up
    cd || return 1
    rm -rf "${temp_dir}"
    
    set_state "${SCRIPT_NAME}_warp_terminal_installed"
    log_success "Warp Terminal installed successfully"
    return 0
}

# Function to configure Warp Terminal autostart
function configure_warp_autostart() {
    log_step "Configuring Warp Terminal to autostart after KDE login"
    
    if check_state "${SCRIPT_NAME}_warp_autostart_configured"; then
        log_info "Warp Terminal autostart already configured. Skipping..."
        return 0
    fi
    
    # Get user's home directory
    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi
    
    # Create autostart directory if it doesn't exist
    local autostart_dir="${user_home}/.config/autostart"
    mkdir -p "${autostart_dir}"
    
    # Create autostart entry for Warp Terminal
    log_info "Creating autostart entry for Warp Terminal"
    cat > "${autostart_dir}/warp-terminal.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Warp Terminal
Comment=Terminal for continuing installation
Exec=warp-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF
    
    # Set ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${autostart_dir}"
    fi
    
    set_state "${SCRIPT_NAME}_warp_autostart_configured"
    log_success "Warp Terminal configured to autostart after KDE login"
    return 0
}

# Function to create installation continuation script
function create_continuation_script() {
    log_step "Creating installation continuation script"
    
    if check_state "${SCRIPT_NAME}_continuation_script_created"; then
        log_info "Installation continuation script already created. Skipping..."
        return 0
    fi
    
    # Get user's home directory
    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi
    
    # Create script directory if it doesn't exist
    local script_dir="${user_home}/bin"
    mkdir -p "${script_dir}"
    
    # Create the continuation script
    log_info "Creating continuation script"
    cat > "${script_dir}/continue-install.sh" << 'EOF'
#!/bin/bash

echo "============================================================"
echo "  Installation Continuation Script"
echo "============================================================"
echo
echo "The KDE desktop environment has been installed successfully."
echo "To continue with the installation process, run:"
echo
echo "  sudo /media/scott/Restart-Critical/scripts/main-installer.sh --phase 20-development,30-applications,40-optimization"
echo
echo "This will continue the installation with the remaining phases:"
echo "  - Development tools"
echo "  - Applications"
echo "  - System optimization"
echo
echo "Press Enter to copy this command to clipboard..."
read -r
echo -n "sudo /media/scott/Restart-Critical/scripts/main-installer.sh --phase 20-development,30-applications,40-optimization" | xclip -selection clipboard
echo "Command copied to clipboard! You can paste it with Ctrl+Shift+V"
echo "============================================================"
EOF
    
    # Make the script executable
    chmod +x "${script_dir}/continue-install.sh"
    
    # Set ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "${script_dir}/continue-install.sh"
    fi
    
    # Add to Warp Terminal configuration to run this script on startup
    mkdir -p "${user_home}/.config/warp-terminal"
    echo "run_command=${script_dir}/continue-install.sh" >> "${user_home}/.config/warp-terminal/config"
    
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/warp-terminal"
    fi
    
    # Create desktop shortcut for continuation script
    local desktop_dir="${user_home}/Desktop"
    mkdir -p "${desktop_dir}"
    
    cat > "${desktop_dir}/continue-install.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Continue Installation
Comment=Continue the system installation process
Exec=${script_dir}/continue-install.sh
Terminal=true
Icon=system-software-install
Categories=System;
EOF
    
    chmod +x "${desktop_dir}/continue-install.desktop"
    
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "${desktop_dir}/continue-install.desktop"
    fi
    
    set_state "${SCRIPT_NAME}_continuation_script_created"
    log_success "Installation continuation script created"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_special_apps() {
    log_section "Installing Special Applications (Early)"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Special applications have already been installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install applications
    install_ckb_next || log_warning "ckb-next installation encountered issues or was skipped"
    configure_ckb_next_yellow || log_warning "ckb-next configuration encountered issues"
    install_warp_terminal || log_warning "Warp Terminal installation encountered issues"
    configure_warp_autostart || log_warning "Warp Terminal autostart configuration encountered issues"
    create_continuation_script || log_warning "Continuation script creation encountered issues"
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Special applications installation completed successfully"
    
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

# Parse command line arguments
FORCE_MODE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE="true"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Call the main function
install_special_apps

# Return the exit code
exit $?
