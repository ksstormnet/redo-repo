#!/bin/bash

# 08-specialized-software.sh
# This script installs specialized software for various tasks and manages configurations
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source the configuration management functions
# shellcheck disable=SC1090
if [[ -n "${CONFIG_FUNCTIONS_PATH}" ]] && [[ -f "${CONFIG_FUNCTIONS_PATH}" ]]; then
    source "${CONFIG_FUNCTIONS_PATH}"
else
    echo "ERROR: Configuration management functions not found."
    echo "Please ensure the CONFIG_FUNCTIONS_PATH environment variable is set correctly."
    exit 1
fi

# Display a section header
section() {
    echo
    echo "========================================================"
    echo "  ${1}"
    echo "========================================================"
    echo
}

# Function to install packages with progress indication
install_packages() {
    local description="${1}"
    shift
    
    echo "Installing: ${description}..."
    apt-get install -y "$@"
    echo "✓ Completed: ${description}"
}

# Function to add a repository
add_repository() {
    local repo_name="${1}"
    local repo_url="${2}"
    local keyring_url="${3}"
    
    echo "Adding repository: ${repo_name}..."
    
    if [[ -n "${keyring_url}" ]]; then
        curl -fsSL "${keyring_url}" | gpg --dearmor -o "/usr/share/keyrings/${repo_name}-archive-keyring.gpg"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/${repo_name}-archive-keyring.gpg] ${repo_url} $(lsb_release -cs) main" | tee "/etc/apt/sources.list.d/${repo_name}.list" > /dev/null
    else
        add-apt-repository -y "${repo_url}"
    fi
    
    echo "✓ Added repository: ${repo_name}"
}

# Determine which user to set configs for
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define configuration files for each software category
AUDACITY_CONFIG_FILES=(
    "${USER_HOME}/.config/audacity/audacity.cfg"
)

VLC_CONFIG_FILES=(
    "${USER_HOME}/.config/vlc/vlcrc"
)

VIRTUALBOX_CONFIG_FILES=(
    "${USER_HOME}/.config/VirtualBox/VirtualBox.xml"
)

PINTA_CONFIG_FILES=(
    "${USER_HOME}/.config/pinta/settings.xml"
)

DARKTABLE_CONFIG_FILES=(
    "${USER_HOME}/.config/darktable/darktablerc"
)

CALIBRE_CONFIG_FILES=(
    "${USER_HOME}/.config/calibre/global.py"
    "${USER_HOME}/.config/calibre/preferences.py"
)

OKULAR_CONFIG_FILES=(
    "${USER_HOME}/.config/okularrc"
)

GWENVIEW_CONFIG_FILES=(
    "${USER_HOME}/.config/gwenviewrc"
)

GHOSTWRITER_CONFIG_FILES=(
    "${USER_HOME}/.config/ghostwriter/ghostwriter.conf"
)

FILEZILLA_CONFIG_FILES=(
    "${USER_HOME}/.config/filezilla/filezilla.xml"
)

REMMINA_CONFIG_FILES=(
    "${USER_HOME}/.config/remmina/remmina.pref"
)

ZOOM_CONFIG_FILES=(
    "${USER_HOME}/.config/zoomus.conf"
)

SLACK_CONFIG_FILES=(
    "${USER_HOME}/.config/Slack/config"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for software
handle_pre_installation_config "audacity" "${AUDACITY_CONFIG_FILES[@]}"
handle_pre_installation_config "vlc" "${VLC_CONFIG_FILES[@]}"
handle_pre_installation_config "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"
handle_pre_installation_config "pinta" "${PINTA_CONFIG_FILES[@]}"
handle_pre_installation_config "darktable" "${DARKTABLE_CONFIG_FILES[@]}"
handle_pre_installation_config "calibre" "${CALIBRE_CONFIG_FILES[@]}"
handle_pre_installation_config "okular" "${OKULAR_CONFIG_FILES[@]}"
handle_pre_installation_config "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
handle_pre_installation_config "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"
handle_pre_installation_config "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
handle_pre_installation_config "remmina" "${REMMINA_CONFIG_FILES[@]}"
handle_pre_installation_config "zoom" "${ZOOM_CONFIG_FILES[@]}"
handle_pre_installation_config "slack" "${SLACK_CONFIG_FILES[@]}"

# === STAGE 2: Audio Production Software ===
section "Installing Audio Production Software"

# Install audio production software
install_packages "Audio Production" \
    audacity \
    jack-tools \
    vlc

# Handle configuration files
handle_installed_software_config "audacity" "${AUDACITY_CONFIG_FILES[@]}"
handle_installed_software_config "vlc" "${VLC_CONFIG_FILES[@]}"

# === STAGE 3: Virtualization Software ===
section "Installing Virtualization Software"

# Install VirtualBox
install_packages "Virtualization" \
    virtualbox \
    virtualbox-qt \
    virtualbox-dkms

# Handle configuration files
handle_installed_software_config "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"

# === STAGE 4: Graphics and Design ===
section "Installing Graphics and Design Tools"

# Install graphics and design tools
install_packages "Graphics & Design" \
    darktable

# Install Pinta via snap instead of apt
echo "Installing Pinta via snap..."
snap install pinta
echo "✓ Installed Pinta via snap"

# Handle configuration files
handle_installed_software_config "pinta" "${PINTA_CONFIG_FILES[@]}"
handle_installed_software_config "darktable" "${DARKTABLE_CONFIG_FILES[@]}"

# === STAGE 5: Office and Productivity ===
section "Installing Office and Productivity Tools"

# Install office and productivity tools
install_packages "Office & Productivity" \
    calibre \
    okular \
    gwenview \
    ghostwriter

# Handle configuration files
handle_installed_software_config "calibre" "${CALIBRE_CONFIG_FILES[@]}"
handle_installed_software_config "okular" "${OKULAR_CONFIG_FILES[@]}"
handle_installed_software_config "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
handle_installed_software_config "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"

# === STAGE 6: Web and Network Tools ===
section "Installing Web and Network Tools"

# Install web and network tools
install_packages "Web and Network Tools" \
    filezilla \
    remmina

# Handle configuration files
handle_installed_software_config "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
handle_installed_software_config "remmina" "${REMMINA_CONFIG_FILES[@]}"

# === STAGE 7: Communication Tools ===
section "Installing Communication Tools"

# Install Zoom
echo "Installing Zoom..."
wget https://zoom.us/client/latest/zoom_amd64.deb -O /tmp/zoom_amd64.deb
dpkg -i /tmp/zoom_amd64.deb
apt-get install -f -y
rm /tmp/zoom_amd64.deb
echo "✓ Installed Zoom"

# Install Zoiper5
echo "Installing Zoiper5..."
wget https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb -O /tmp/zoiper5.deb
dpkg -i /tmp/zoiper5.deb
apt-get install -f -y
rm /tmp/zoiper5.deb
echo "✓ Installed Zoiper5"

# Install Slack via snap
echo "Installing Slack via snap..."
snap install slack
echo "✓ Installed Slack via snap"

# Handle configuration files
handle_installed_software_config "zoom" "${ZOOM_CONFIG_FILES[@]}"
handle_installed_software_config "slack" "${SLACK_CONFIG_FILES[@]}"

# === STAGE 8: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "audacity" "${AUDACITY_CONFIG_FILES[@]}"
check_post_installation_configs "vlc" "${VLC_CONFIG_FILES[@]}"
check_post_installation_configs "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"
check_post_installation_configs "pinta" "${PINTA_CONFIG_FILES[@]}"
check_post_installation_configs "darktable" "${DARKTABLE_CONFIG_FILES[@]}"
check_post_installation_configs "calibre" "${CALIBRE_CONFIG_FILES[@]}"
check_post_installation_configs "okular" "${OKULAR_CONFIG_FILES[@]}"
check_post_installation_configs "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
check_post_installation_configs "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"
check_post_installation_configs "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
check_post_installation_configs "remmina" "${REMMINA_CONFIG_FILES[@]}"
check_post_installation_configs "zoom" "${ZOOM_CONFIG_FILES[@]}"
check_post_installation_configs "slack" "${SLACK_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "Specialized Software Installation Complete!"
echo "You have installed specialized software for the following categories:"
echo "  - Audio Production (Audacity, VLC, etc.)"
echo "  - Virtualization (VirtualBox)"
echo "  - Graphics & Design (Pinta, Darktable, etc.)"
echo "  - Office & Productivity (Calibre, Okular, Gwenview, Ghostwriter, etc.)"
echo "  - Web & Network Tools (FileZilla, Remmina)"
echo "  - Communication Tools (Zoom, Zoiper5, Slack)"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
