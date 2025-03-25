#!/bin/bash
# PipeWire audio system configuration options
# Allows choosing between Ubuntu Studio default configuration
# and a customized optimized configuration

# Source common library functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$(realpath "${SCRIPT_DIR}/../lib")"
source "${LIB_DIR}/common.sh" || exit 1
source "${LIB_DIR}/ui-utils.sh" || exit 1

# Script header
header "PipeWire Audio Configuration Options"
info "Choose between Ubuntu Studio defaults or optimized audio configuration"

# Ask user what configuration they want
whiptail_yesno "Audio System Configuration" \
    "Ubuntu Studio comes with a pre-configured audio system optimized for content creation.\\n\\n\
    Our script by default applies ADDITIONAL optimizations that can improve performance but may affect\
    device compatibility (especially with some Bluetooth devices).\\n\\n\
    Would you like to apply our additional optimizations?\\n\
    * YES = Apply our optimizations (lower latency, but might affect device compatibility)\\n\
    * NO = Keep Ubuntu Studio defaults (may better support unusual hardware)" \
    "--defaultno"

USE_CUSTOM_AUDIO=$?

if [ $USE_CUSTOM_AUDIO -eq 0 ]; then
    # User chose YES - apply our optimizations
    info "Applying custom audio optimizations..."

    # Check if our Bluetooth fixes script was already run
    if [ -f "/etc/pipewire/pipewire.conf.d/20-bluetooth-fixes.conf" ]; then
        info "Bluetooth fixes already applied, keeping configuration."
    else
        info "You may want to run the Bluetooth fixes script if you use Bluetooth audio devices:"
        info "Run: sudo ${SCRIPT_DIR}/03.5-bluetooth-fixes.sh"
    fi

    # Create a flag file to indicate we're using custom audio config
    touch /etc/pipewire/.custom_audio_enabled

    success "Custom audio optimizations enabled."
    warning "If you experience audio device detection issues, run this script again and select NO."
else
    # User chose NO - reset to Ubuntu Studio defaults
    info "Reverting to Ubuntu Studio default audio configuration..."

    # Remove our custom configurations
    sudo rm -f /etc/pipewire/pipewire.conf.d/10-device-detection.conf 2>/dev/null
    sudo rm -f /etc/pipewire/pipewire.conf.d/20-bluetooth-fixes.conf 2>/dev/null
    sudo rm -f /etc/pipewire/pipewire.conf.d/30-autoswitch.conf 2>/dev/null
    sudo rm -f /etc/bluetooth/conf.d/audio-connection-fixes.conf 2>/dev/null
    sudo rm -f /etc/bluetooth/conf.d/audio-fix.conf 2>/dev/null

    # Remove custom user configs
    rm -rf ~/.config/wireplumber/bluetooth.lua.d/* 2>/dev/null
    rm -rf ~/.config/wireplumber/main.lua.d/51-bluetooth-profile-fix.lua 2>/dev/null
    sudo rm -f /etc/wireplumber/main.lua.d/51-bluetooth-profile-fix.lua 2>/dev/null

    # Reset config files to defaults
    sudo cp -f /usr/share/pipewire/pipewire.conf /etc/pipewire/ 2>/dev/null

    # Keep only the USB power management optimization
    if [ ! -f "/etc/modprobe.d/99-audio-usb.conf" ]; then
        cat > /tmp/99-audio-usb.conf << 'EOF'
# USB audio device optimization

# Prevent USB autosuspend for audio devices only
options snd-usb-audio autosuspend=0

# Set a reasonable delay for other USB devices
options usbcore autosuspend_delay_ms=1000
EOF
        sudo mv /tmp/99-audio-usb.conf /etc/modprobe.d/
    fi

    # Remove the custom audio flag
    sudo rm -f /etc/pipewire/.custom_audio_enabled

    # Restart services
    sudo systemctl restart bluetooth
    systemctl --user restart pipewire pipewire-pulse || true

    success "Ubuntu Studio default audio configuration restored."
    info "This should provide better compatibility with a wide range of audio devices."
fi

info "You should reboot your system for changes to take full effect:"
info "Run: sudo reboot"
