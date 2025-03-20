#!/bin/bash

# 04-kde-desktop-install.sh
# This script installs the KDE Plasma desktop environment over Ubuntu Server
# and manages KDE configurations using the repository
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

# Define configuration files for KDE
KDE_CONFIG_FILES=(
    "${USER_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"
    "${USER_HOME}/.config/kdeglobals"
    "${USER_HOME}/.config/kwinrc"
    "${USER_HOME}/.config/kwinrulesrc"
    "${USER_HOME}/.config/kglobalshortcutsrc"
    "${USER_HOME}/.config/khotkeysrc"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for KDE
handle_pre_installation_config "kde" "${KDE_CONFIG_FILES[@]}"

# === STAGE 2: KDE Plasma Desktop Environment ===
section "Installing KDE Desktop Environment"

# Install complete Kubuntu desktop
install_packages "Kubuntu Desktop" kubuntu-desktop

# Remove unwanted applications
section "Removing Unwanted KDE Applications"

apt-get remove -y \
    kmail \
    kontact \
    kaddressbook \
    korganizer \
    akregator \
    dragonplayer \
    k3b \
    kamoso \
    kmahjongg \
    kmines \
    ksudoku \
    konversation \
    kopete

# Mark packages as manually removed so they don't get reinstalled
apt-mark auto \
    kmail \
    kontact \
    kaddressbook \
    korganizer \
    akregator \
    dragonplayer \
    k3b \
    kamoso \
    kmahjongg \
    kmines \
    ksudoku \
    konversation \
    kopete

# Make sure no orphaned dependencies remain
apt-get autoremove -y

# === STAGE 3: Additional KDE Applications ===
section "Installing Additional KDE Applications"

# Install additional applications not included or replacing defaults
install_packages "Additional KDE Applications" \
    flameshot \
    krusader \
    dupeguru \
    partitionmanager \
    kompare

# === STAGE 4: Manage KDE Configuration ===
section "Managing KDE Configuration"

# Create the KDE config directories if they don't exist
mkdir -p "${USER_HOME}/.config"
mkdir -p "${USER_HOME}/.local/share/plasma"
mkdir -p "${USER_HOME}/.local/share/color-schemes"
mkdir -p "${USER_HOME}/.local/share/konsole"
mkdir -p "${USER_HOME}/.local/share/aurorae/themes"

# Handle configuration files
handle_installed_software_config "kde" "${KDE_CONFIG_FILES[@]}"

# Configure Meta key to open main menu if kwinrc doesn't exist in the repo
if ! handle_installed_software_config "kde" "${USER_HOME}/.config/kwinrc"; then
    # Create a basic default configuration file
    cat > "${USER_HOME}/.config/kwinrc" << EOF
[ModifierOnlyShortcuts]
Meta=org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,ShowDesktopGrid
EOF
    
    echo "✓ Created default KWin configuration"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "kde" "${USER_HOME}/.config/kwinrc"
fi

# Configure keyboard shortcuts if khotkeysrc doesn't exist in the repo
if ! handle_installed_software_config "kde" "${USER_HOME}/.config/khotkeysrc"; then
    # Create a basic default configuration file
    cat > "${USER_HOME}/.config/khotkeysrc" << EOF
[General]
AllowMerge=false

[Data]
DataCount=1

[Data_1]
Comment=KMenuEdit Global Shortcuts
DataCount=1
Enabled=true
Name=KMenuEdit
SystemGroup=1
Type=ACTION_DATA_GROUP

[Data_1Conditions]
Comment=
ConditionsCount=0

[Data_1_1]
Comment=Comment
Enabled=true
Name=Meta to open Application Launcher
Type=SIMPLE_ACTION_DATA

[Data_1_1Actions]
ActionsCount=1

[Data_1_1Actions0]
CommandURL=plasma-dash
Type=COMMAND_URL

[Data_1_1Conditions]
Comment=
ConditionsCount=0

[Data_1_1Triggers]
Comment=Simple_action
TriggersCount=1

[Data_1_1Triggers0]
Key=Meta
Type=SHORTCUT
Uuid={5464fcc8-95a3-4e6c-a6c6-f303fef22525}
EOF
    
    echo "✓ Created default keyboard shortcuts configuration"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "kde" "${USER_HOME}/.config/khotkeysrc"
fi

# Ensure proper permissions
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/"
fi

echo "✓ Configured KDE settings"

# === STAGE 5: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "kde" "${KDE_CONFIG_FILES[@]}"

section "KDE Desktop Installation Complete!"
echo "You now have a customized KDE Plasma desktop environment installed with your configurations."
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "You may need to reboot your system to complete the setup."
echo "Command: sudo systemctl reboot"
