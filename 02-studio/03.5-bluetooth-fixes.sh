#!/bin/bash
# Bluetooth fixes for Ubuntu Studio systems
# This script addresses the "br-connection-profile-unavailable" error
# and other Bluetooth audio issues when using PipeWire

# Source common library functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$(realpath "${SCRIPT_DIR}/../lib")"
source "${LIB_DIR}/common.sh" || exit 1

# Script header
header "Bluetooth Audio Fixes"
info "Applying fixes for Bluetooth audio connection issues"

# Install required Bluetooth packages
info "Installing Bluetooth support packages..."
apt_install_if_needed \
    bluez \
    bluez-tools \
    bluez-firmware \
    bluez-hcidump \
    pulseaudio-module-bluetooth \
    libspa-0.2-bluetooth

# Create directory for PipeWire configuration
info "Setting up PipeWire Bluetooth configuration..."
sudo mkdir -p /etc/pipewire/pipewire.conf.d/

# Create PipeWire Bluetooth configuration
cat > /tmp/20-bluetooth-fixes.conf << 'EOF'
# Bluetooth configuration for PipeWire
# Fixes "br-connection-profile-unavailable" errors

context.modules = [
    {   name = libpipewire-module-bluetooth
        args = {
            # Enable standard high-quality codecs
            bluez5.msbc-support = true
            bluez5.sbc-xq-support = true
            # AAC codec at variable bitrate (0=variable, 1-5=fixed)
            bluez5.a2dp.aac.bitratemode = 0
            # LDAC codec quality (auto, high, mid, low)
            bluez5.a2dp.ldac.quality = auto
            # Enable faster reconnection
            bluez5.hw-volume = true
            # Enable all roles for maximum compatibility
            bluez5.roles = [ a2dp_sink a2dp_source hsp_hs hsp_ag hfp_hf hfp_ag ]
            # Set connection timeout to a higher value
            bluez5.connect-timeout = 30
        }
        flags = [ ifexists nofail ]
    }
]
EOF

sudo mv /tmp/20-bluetooth-fixes.conf /etc/pipewire/pipewire.conf.d/

# Create directory for Bluetooth configuration
info "Configuring Bluetooth reconnection settings..."
sudo mkdir -p /etc/bluetooth/conf.d/

# Create Bluetooth power management configuration
cat > /tmp/audio-connection-fixes.conf << 'EOF'
[General]
# Fix profile availability
Enable=Source,Sink,Media,Socket
JustWorksRepairing = always
FastConnectable = true

[Policy]
# Improve connection reliability
AutoEnable=true
ReconnectAttempts=10
ReconnectIntervals=1,2,4,8,16,32,64
EOF

sudo mv /tmp/audio-connection-fixes.conf /etc/bluetooth/conf.d/

# Modify USB power management for audio devices
info "Optimizing USB power management for audio devices..."
cat > /tmp/99-audio-usb.conf << 'EOF'
# USB audio device optimization

# Prevent USB autosuspend for audio devices only
options snd-usb-audio autosuspend=0

# Set a reasonable delay for other USB devices
options usbcore autosuspend_delay_ms=1000
EOF

sudo mv /tmp/99-audio-usb.conf /etc/modprobe.d/

# Create user-level wireplumber configuration directory
info "Creating WirePlumber configuration for better device detection..."
mkdir -p ~/.config/wireplumber/main.lua.d/

# Create Bluetooth connection fix for WirePlumber
cat > /tmp/51-bluetooth-profile-fix.lua << 'EOF'
-- Fix for Bluetooth profile unavailable issue

bluetooth_rules = {
  -- Enable standard codecs
  ["bluez5.enable-sbc-xq"] = true,
  ["bluez5.enable-msbc"] = true,
  ["bluez5.enable-hw-volume"] = true,

  -- Fix profile availability issues
  ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]",
  ["bluez5.codecs"] = "[ sbc sbc_xq ldac aac ]",

  -- Enable auto-switching
  ["bluez5.autoswitch"] = true
}

load_script("bluetooth.lua", bluetooth_rules)
EOF

# Install for current user
cp /tmp/51-bluetooth-profile-fix.lua ~/.config/wireplumber/main.lua.d/

# Install system-wide for new users
sudo mkdir -p /etc/wireplumber/main.lua.d/
sudo cp /tmp/51-bluetooth-profile-fix.lua /etc/wireplumber/main.lua.d/

# Create udev rules for automatic detection
info "Setting up automatic Bluetooth device detection..."
cat > /tmp/89-bluetooth-detection.rules << 'EOF'
# Enhanced detection for Bluetooth audio devices

# Automatically restart audio services when Bluetooth devices connect
SUBSYSTEM=="bluetooth", ATTR{address}=="?*:?*:?*:?*:?*:?*", ACTION=="add", RUN+="/bin/systemctl --user restart pipewire pipewire-pulse"

# Fix for reconnection issues
SUBSYSTEM=="bluetooth", ACTION=="add", RUN+="/bin/sh -c 'echo enabled > /sys$devpath/power/wakeup'"
EOF

sudo mv /tmp/89-bluetooth-detection.rules /etc/udev/rules.d/

# Reload udev rules
info "Applying configuration changes..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# Restart services
info "Restarting Bluetooth services..."
sudo systemctl restart bluetooth
sleep 2
systemctl --user restart pipewire pipewire-pulse || true

# Final notes
success "Bluetooth fixes applied."
info "For more detailed troubleshooting, see /mnt/usb/bluetooth-troubleshooting.md"
info "If you still experience issues, try: sudo reboot"
