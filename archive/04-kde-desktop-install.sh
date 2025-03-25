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
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Check if we have restored configurations
if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
    echo "Found restored configuration mapping at: ${CONFIG_MAPPING_PATH}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_PATH}"
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

# Check for restored KDE configurations
RESTORED_KDE_CONFIGS=false
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    echo "Checking for restored KDE configurations..."
    
    KDE_CONFIG_PATH="${GENERAL_CONFIGS_PATH}/config"
    if [[ -d "${KDE_CONFIG_PATH}" ]]; then
        # Look for common KDE configuration files
        for config_file in plasma-org.kde.plasma.desktop-appletsrc kdeglobals kwinrc kwinrulesrc kglobalshortcutsrc khotkeysrc; do
            if [[ -f "${KDE_CONFIG_PATH}/${config_file}" ]]; then
                echo "Found restored KDE configuration: ${config_file}"
                RESTORED_KDE_CONFIGS=true
            fi
        done
    fi
    
    if [[ "${RESTORED_KDE_CONFIGS}" = true ]]; then
        echo "Will use restored KDE configurations where possible."
    else
        echo "No restored KDE configurations found. Will use default configurations."
    fi
fi

# Set up pre-installation configurations for KDE if no restored configs found
if [[ "${RESTORED_KDE_CONFIGS}" = false ]]; then
    handle_pre_installation_config "kde" "${KDE_CONFIG_FILES[@]}"
fi

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

# Check for restored KDE configurations and apply them
if [[ "${RESTORED_KDE_CONFIGS}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    echo "Restoring KDE configurations from backup..."
    
    KDE_CONFIG_PATH="${GENERAL_CONFIGS_PATH}/config"
    
    # Copy restored KDE configurations
    for config_file in plasma-org.kde.plasma.desktop-appletsrc kdeglobals kwinrc kwinrulesrc kglobalshortcutsrc khotkeysrc; do
        if [[ -f "${KDE_CONFIG_PATH}/${config_file}" ]]; then
            # Backup existing file if it exists
            if [[ -f "${USER_HOME}/.config/${config_file}" ]] && [[ ! -L "${USER_HOME}/.config/${config_file}" ]]; then
                TIMESTAMP=$(date +%Y%m%d-%H%M%S) || TIMESTAMP="backup"
                mv "${USER_HOME}/.config/${config_file}" "${USER_HOME}/.config/${config_file}.orig.${TIMESTAMP}"
                echo "Backed up existing ${config_file}"
            fi
            
            # Copy restored file
            cp "${KDE_CONFIG_PATH}/${config_file}" "${USER_HOME}/.config/"
            echo "✓ Restored ${config_file} from backup"
        fi
    done
    
    # Check for KDE themes and other assets
    KDE_ASSETS_PATH="${GENERAL_CONFIGS_PATH}/local/share"
    if [[ -d "${KDE_ASSETS_PATH}" ]]; then
        # Look for plasma themes
        if [[ -d "${KDE_ASSETS_PATH}/plasma" ]]; then
            mkdir -p "${USER_HOME}/.local/share/plasma"
            cp -r "${KDE_ASSETS_PATH}/plasma"/* "${USER_HOME}/.local/share/plasma/"
            echo "✓ Restored plasma themes from backup"
        fi
        
        # Look for color schemes
        if [[ -d "${KDE_ASSETS_PATH}/color-schemes" ]]; then
            mkdir -p "${USER_HOME}/.local/share/color-schemes"
            cp -r "${KDE_ASSETS_PATH}/color-schemes"/* "${USER_HOME}/.local/share/color-schemes/"
            echo "✓ Restored color schemes from backup"
        fi
        
        # Look for Konsole profiles
        if [[ -d "${KDE_ASSETS_PATH}/konsole" ]]; then
            mkdir -p "${USER_HOME}/.local/share/konsole"
            cp -r "${KDE_ASSETS_PATH}/konsole"/* "${USER_HOME}/.local/share/konsole/"
            echo "✓ Restored Konsole profiles from backup"
        fi
        
        # Look for window decoration themes
        if [[ -d "${KDE_ASSETS_PATH}/aurorae" ]]; then
            mkdir -p "${USER_HOME}/.local/share/aurorae"
            cp -r "${KDE_ASSETS_PATH}/aurorae"/* "${USER_HOME}/.local/share/aurorae/"
            echo "✓ Restored window decoration themes from backup"
        fi
    fi
    
    echo "✓ Restored KDE configurations from backup"
else
    # Handle configuration files using repo
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
fi

# Ensure proper permissions
if [[ -n "${SUDO_USER}" ]]; then
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
if [[ "${RESTORED_KDE_CONFIGS}" = true ]]; then
    echo "Your restored KDE configurations have been applied from the backup."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
    echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
    echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
    echo "  - Any changes to configurations should be made in the repository"
fi
echo
echo "You may need to reboot your system to complete the setup."
echo "Command: sudo systemctl reboot"
