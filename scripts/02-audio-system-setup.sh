#!/bin/bash

# 02-audio-system-setup.sh
# This script sets up the optimized audio system
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

# Determine user home directory
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define configuration files for audio system
PIPEWIRE_CONFIG_FILES=(
    "${USER_HOME}/.config/pipewire/pipewire.conf"
    "${USER_HOME}/.config/pipewire/client.conf"
    "${USER_HOME}/.config/pipewire/client-rt.conf"
    "${USER_HOME}/.config/pipewire/jack.conf"
)

WIREPLUMBER_CONFIG_FILES=(
    "${USER_HOME}/.config/wireplumber/wireplumber.conf"
    "${USER_HOME}/.config/wireplumber/main.lua.d/51-alsa-custom.lua"
)

ALSA_CONFIG_FILES=(
    "${USER_HOME}/.asoundrc"
)

JACK_CONFIG_FILES=(
    "${USER_HOME}/.config/jack/conf.xml"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for audio system
handle_pre_installation_config "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
handle_pre_installation_config "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
handle_pre_installation_config "alsa" "${ALSA_CONFIG_FILES[@]}"
handle_pre_installation_config "jack" "${JACK_CONFIG_FILES[@]}"

# === STAGE 2: PipeWire Audio System ===
section "Setting Up Professional Audio System"

# Install PipeWire audio system (modern replacement for PulseAudio)
install_packages "PipeWire Audio System" \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    pipewire-audio \
    wireplumber \
    ubuntustudio-audio-core \
    ubuntustudio-pipewire-config

# Audio utilities and Sox with MP3 support
install_packages "Audio Utilities" \
    rtkit \
    sox \
    libsox-fmt-mp3

# Set up realtime privileges for audio
section "Configuring Realtime Audio Privileges"

# Check if the audio group exists, create it if not
getent group audio > /dev/null || groupadd audio

# Add current user to audio group if running as sudo
if [[ "${SUDO_USER}" ]]; then
    usermod -a -G audio "${SUDO_USER}"
    echo "✓ Added user ${SUDO_USER} to audio group"
fi

# Set up limits for realtime audio
cat > /etc/security/limits.d/99-realtime-audio.conf << EOF
# Realtime Audio Configuration
@audio   -  rtprio     95
@audio   -  memlock    unlimited
EOF

echo "✓ Configured realtime audio privileges"

# Set up IRQ priorities for audio
section "Configuring IRQ Priorities for Audio"

# Ensure rtirq service is enabled
systemctl enable rtirq
systemctl start rtirq

echo "✓ Enabled rtirq service for audio IRQ prioritization"

# === STAGE 3: Manage Audio Configuration Files ===
section "Managing Audio Configuration Files"

# Create required directories if they don't exist
mkdir -p "${USER_HOME}/.config/pipewire"
mkdir -p "${USER_HOME}/.config/wireplumber"
mkdir -p "${USER_HOME}/.config/jack"

# Handle configuration files
handle_installed_software_config "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
handle_installed_software_config "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
handle_installed_software_config "alsa" "${ALSA_CONFIG_FILES[@]}"
handle_installed_software_config "jack" "${JACK_CONFIG_FILES[@]}"

# Set proper ownership for all configuration directories
set_user_ownership "${USER_HOME}/.config/pipewire"
set_user_ownership "${USER_HOME}/.config/wireplumber"
set_user_ownership "${USER_HOME}/.config/jack"
[[ -f "${USER_HOME}/.asoundrc" ]] && set_user_ownership "${USER_HOME}/.asoundrc"

echo "✓ Managed all audio configurations"

# Restart PipeWire services to apply configurations
echo "Restarting PipeWire services to apply configurations..."
if [[ "${SUDO_USER}" ]]; then
    systemctl --user -M "${SUDO_USER}@.host" restart pipewire pipewire-pulse wireplumber || true
else
    systemctl --user restart pipewire pipewire-pulse wireplumber || true
fi
echo "✓ Restarted PipeWire services"

# === STAGE 4: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
check_post_installation_configs "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
check_post_installation_configs "alsa" "${ALSA_CONFIG_FILES[@]}"
check_post_installation_configs "jack" "${JACK_CONFIG_FILES[@]}"

section "Audio System Setup Complete!"
echo "A professional audio system with PipeWire has been set up and configured."
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "Note: You may need to log out and back in for group changes to take effect."
echo "Command: sudo systemctl reboot"
