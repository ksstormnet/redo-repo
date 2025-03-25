#!/usr/bin/env bash
# ============================================================================
# 03-audio-firmware.sh
# ----------------------------------------------------------------------------
# Installs necessary firmware packages for audio hardware
# Checks for connected audio devices and installs appropriate firmware
# Configures advanced audio hardware settings
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PARENT_DIR/lib"

# Source the common library functions
if [[ -f "$LIB_DIR/common.sh" ]]; then
    source "$LIB_DIR/common.sh"
else
    echo "ERROR: common.sh library not found at $LIB_DIR"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="03-audio-firmware"

# ============================================================================
# Audio Device Detection
# ============================================================================

# Detect connected audio devices
function detect_audio_devices() {
    log_section "Detecting Audio Devices"
    
    # Ensure we have necessary packages installed
    if ! command -v lsusb &>/dev/null || ! command -v aplay &>/dev/null; then
        log_step "Installing required packages for hardware detection"
        apt_install usbutils alsa-utils hwinfo
    fi
    
    # List PCI audio devices
    log_step "Detecting PCI audio devices"
    log_info "PCI audio devices:"
    lspci | grep -i 'audio\|sound' || echo "No PCI audio devices detected"
    
    # List USB audio devices
    log_step "Detecting USB audio devices"
    log_info "USB audio devices:"
    lsusb | grep -i 'audio\|midi' || echo "No USB audio devices detected"
    
    # List ALSA audio devices
    log_step "Detecting ALSA audio devices"
    log_info "ALSA audio devices:"
    aplay -l || echo "No ALSA audio devices detected"
    
    return 0
}

# ============================================================================
# Firmware Installation
# ============================================================================

# Install audio firmware packages
function install_audio_firmware() {
    log_section "Installing Audio Firmware Packages"
    
    if check_state "${SCRIPT_NAME}_firmware_installed"; then
        log_info "Audio firmware packages have already been installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install common firmware packages
    log_step "Installing common firmware packages"
    local common_firmware=(
        firmware-linux
        firmware-linux-nonfree
        linux-firmware
        alsa-firmware-loaders
    )
    
    if ! apt_install "${common_firmware[@]}"; then
        log_warning "Failed to install some common firmware packages"
        # Continue anyway as some packages might not be available
    fi
    
    # Check if we're using non-free repositories
    if grep -q "non-free" /etc/apt/sources.list || [ -f /etc/apt/sources.list.d/*non-free* ]; then
        log_step "Installing non-free firmware packages"
        
        # Install additional non-free firmware
        local nonfree_firmware=(
            firmware-misc-nonfree
        )
        
        if ! apt_install "${nonfree_firmware[@]}"; then
            log_warning "Failed to install some non-free firmware packages"
            # Continue anyway as some packages might not be available
        fi
    else
        log_warning "Non-free repositories not enabled. Some firmware may not be available."
        log_info "To enable non-free repositories, edit your apt sources.list or consider using apt-add-repository."
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_firmware_installed"
    log_success "Audio firmware packages installed successfully"
    
    return 0
}

# Install specialized audio firmware based on detected hardware
function install_specialized_firmware() {
    log_section "Installing Specialized Audio Firmware"
    
    if check_state "${SCRIPT_NAME}_specialized_firmware_installed"; then
        log_info "Specialized audio firmware has already been installed. Skipping..."
        return 0
    fi
    
    # Check for specific hardware and install appropriate firmware
    
    # Check for Focusrite Scarlett interfaces
    if lsusb | grep -i "focusrite\|scarlett" &>/dev/null; then
        log_step "Focusrite device detected, installing appropriate firmware"
        
        # Install alsa-firmware with support for Focusrite devices
        if ! apt_install alsa-firmware-loaders; then
            log_warning "Failed to install alsa-firmware-loaders for Focusrite"
        fi
    fi
    
    # Check for RME interfaces
    if lsusb | grep -i "rme\|fireface" &>/dev/null || lspci | grep -i "rme" &>/dev/null; then
        log_step "RME device detected, installing appropriate firmware"
        
        # Install firmware for RME devices
        if ! apt_install alsa-firmware; then
            log_warning "Failed to install alsa-firmware for RME"
        fi
    fi
    
    # Check for MOTU interfaces
    if lsusb | grep -i "motu" &>/dev/null; then
        log_step "MOTU device detected, installing appropriate firmware"
        
        # Install firmware for MOTU devices (if available)
        if apt-cache search "motu" | grep -i "firmware" &>/dev/null; then
            if ! apt_install $(apt-cache search "motu" | grep -i "firmware" | awk '{print $1}'); then
                log_warning "Failed to install MOTU firmware"
            fi
        else
            log_warning "No specific MOTU firmware package found in repositories"
        fi
    fi
    
    # Check for Behringer/XMOS interfaces
    if lsusb | grep -i "behringer\|xmos" &>/dev/null; then
        log_step "Behringer/XMOS device detected, ensuring firmware support"
        
        # Install generic USB audio firmware
        if ! apt_install linux-firmware; then
            log_warning "Failed to install linux-firmware for Behringer/XMOS"
        fi
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_specialized_firmware_installed"
    log_success "Specialized audio firmware installed successfully"
    
    return 0
}

# ============================================================================
# Audio Hardware Configuration
# ============================================================================

# Configure advanced audio hardware settings
function configure_audio_hardware() {
    log_section "Configuring Audio Hardware Settings"
    
    if check_state "${SCRIPT_NAME}_hardware_configured"; then
        log_info "Audio hardware settings have already been configured. Skipping..."
        return 0
    fi
    
    # Create asound.conf template for better USB audio support
    log_step "Creating asound.conf template for improved USB audio support"
    
    cat > /etc/asound.conf << 'EOF'
# Global ALSA configuration for professional audio

# Increased buffer and period sizes for better performance
defaults.pcm.!card {
    @args [ CARD ]
    @args.CARD {
        type string
    }
    type hw
    card $CARD
    hint.description "Default Audio Device"
}

# USB audio specific settings
defaults.pcm.!usb {
    # Increase buffer size for USB audio interfaces
    period_size 1024
    buffer_size 8192
    rate 48000
    format S32_LE
}

# Default rate
defaults.pcm.!rate 48000

# Default format
defaults.pcm.!format S32_LE

# Hints
defaults.ctl.card 0
EOF
    
    # Create modprobe configuration for better USB audio support
    log_step "Creating modprobe configuration for USB audio"
    
    # Create modprobe directory if it doesn't exist
    mkdir -p /etc/modprobe.d
    
    cat > /etc/modprobe.d/snd-usb-audio.conf << 'EOF'
# Modprobe options for USB audio devices

# More verbose errors
options snd-usb-audio index=0 vid=0x0000,0x0000 pid=0x0000,0x0000 enable=1,1 nrpacks=1

# Increase buffer size for USB audio
options snd-usb-audio nrpacks=1
# Disable power management for USB audio devices
options snd_usb_audio power_save=0
# Disable autosuspend for USB audio devices
options usbcore autosuspend=-1
EOF
    
    # Create udev rules for audio devices
    log_step "Creating udev rules for audio devices"
    
    # Create udev rules directory if it doesn't exist
    mkdir -p /etc/udev/rules.d
    
    cat > /etc/udev/rules.d/90-audio-hardware.rules << 'EOF'
# USB audio devices - disable power management
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", ATTR{bInterfaceClass}=="01", ATTR{bInterfaceSubClass}=="01", TEST=="power/control", ATTR{power/control}="on"

# Set the devices containing audio interfaces to use high-bandwidth transfers as a default
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", ATTR{bInterfaceClass}=="01", ATTR{bInterfaceSubClass}=="01", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

# XMOS USB audio devices
ATTRS{idVendor}=="20b1", ATTRS{idProduct}=="*", GROUP="audio", ENV{PULSE_PROFILE_SET}="mixer-pro.conf"

# Focusrite Scarlett devices
ATTRS{idVendor}=="1235", GROUP="audio", ENV{PULSE_PROFILE_SET}="mixer-pro.conf"

# RME devices
ATTRS{idVendor}=="1398", GROUP="audio", ENV{PULSE_PROFILE_SET}="mixer-pro.conf"

# MOTU devices
ATTRS{idVendor}=="07fd", GROUP="audio", ENV{PULSE_PROFILE_SET}="mixer-pro.conf"

# Behringer devices
ATTRS{idVendor}=="1397", GROUP="audio", ENV{PULSE_PROFILE_SET}="mixer-pro.conf"
EOF
    
    # Reload udev rules
    log_info "Reloading udev rules"
    if command -v udevadm &>/dev/null; then
        udevadm control --reload-rules
        udevadm trigger
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_hardware_configured"
    log_success "Audio hardware settings configured successfully"
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_audio_firmware() {
    log_section "Setting Up Audio Firmware and Hardware Support"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Audio firmware and hardware setup has already been completed. Skipping..."
        return 0
    fi
    
    # Detect audio devices
    detect_audio_devices
    
    # Install audio firmware packages
    if ! install_audio_firmware; then
        log_warning "Failed to install some audio firmware packages"
        # Continue anyway since specialized firmware might still work
    fi
    
    # Install specialized firmware based on detected hardware
    if ! install_specialized_firmware; then
        log_warning "Failed to install some specialized firmware"
        # Continue anyway
    fi
    
    # Configure audio hardware
    if ! configure_audio_hardware; then
        log_warning "Failed to configure some audio hardware settings"
        # Continue anyway
    fi
    
    # Create a reboot marker for the main installer
    touch "${STATE_DIR}/reboot_required"
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Audio firmware and hardware setup completed successfully"
    log_warning "A system reboot is recommended to apply all firmware and hardware settings"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
setup_audio_firmware

# Return the exit code
exit $?
