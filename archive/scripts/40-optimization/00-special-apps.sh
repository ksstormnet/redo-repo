#!/usr/bin/env bash
# ============================================================================
# 00-special-apps.sh
# ----------------------------------------------------------------------------
# Installs special applications including:
# - ckb-next for Corsair devices
# - Warp Terminal
# - Elgato StreamDeck software
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
SCRIPT_NAME="00-special-apps"

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
            # Skip in non-interactive mode
            log_info "Skipping ckb-next installation in non-interactive mode"
            return 0
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
    if ! add_apt_repository ppa:tatokis/ckb-next; then
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

# Function to install Elgato StreamDeck software
function install_streamdeck() {
    log_step "Installing Elgato StreamDeck software"
    
    if check_state "${SCRIPT_NAME}_streamdeck_installed"; then
        log_info "StreamDeck software is already installed. Skipping..."
        return 0
    fi
    
    # Install StreamDeck packages
    log_info "Installing StreamDeck packages"
    local streamdeck_packages=(
        python3-elgato-streamdeck
        streamdeck-ui
    )
    
    if ! apt_install "${streamdeck_packages[@]}"; then
        log_error "Failed to install StreamDeck packages"
        return 1
    fi
    
    # Set up udev rules for StreamDeck devices
    log_info "Setting up udev rules for StreamDeck devices"
    
    cat > /etc/udev/rules.d/99-streamdeck.rules << 'EOF'
# Elgato StreamDeck udev rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", GROUP="plugdev", TAG+="uaccess"
EOF
    
    # Reload udev rules
    log_info "Reloading udev rules"
    udevadm control --reload-rules
    udevadm trigger
    
    # Add current user to plugdev group if exists
    if getent group plugdev >/dev/null; then
        if [[ -n "${SUDO_USER}" ]]; then
            log_info "Adding user ${SUDO_USER} to plugdev group"
            usermod -a -G plugdev "${SUDO_USER}"
        fi
    fi
    
    # Configure streamdeck-ui to start at login
    if [[ -n "${SUDO_USER}" ]]; then
        local user_home
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
        mkdir -p "${user_home}/.config/autostart"
        
        cat > "${user_home}/.config/autostart/streamdeck-ui.desktop" << EOF
[Desktop Entry]
Type=Application
Name=StreamDeck UI
Comment=UI for the Elgato Stream Deck
Exec=streamdeck
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
        
        chown "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/autostart/streamdeck-ui.desktop"
    fi
    
    set_state "${SCRIPT_NAME}_streamdeck_installed"
    log_success "StreamDeck software installed successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_special_apps() {
    log_section "Installing Special Applications"
    
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
    
    # Check if ckb-next and Warp Terminal were already installed by the early special apps script
    if check_state "02-special-apps_ckb_next_installed"; then
        log_info "ckb-next was already installed by the early special apps script. Skipping..."
    else
        install_ckb_next || log_warning "ckb-next installation encountered issues or was skipped"
    fi
    
    if check_state "02-special-apps_warp_terminal_installed"; then
        log_info "Warp Terminal was already installed by the early special apps script. Skipping..."
    else
        install_warp_terminal || log_warning "Warp Terminal installation encountered issues"
    fi
    
    # Always install StreamDeck software
    install_streamdeck || log_warning "StreamDeck software installation encountered issues"
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Special applications installation completed successfully"
    
    # Remind user to log out and back in for group changes to take effect
    if [[ -n "${SUDO_USER}" ]]; then
        log_warning "You may need to log out and back in for group changes to take effect"
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
