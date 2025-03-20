#!/bin/bash

# 14-kde-settings-configuration.sh
# This script configures additional KDE settings and manages user-specific customizations
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
    echo "  $1"
    echo "========================================================"
    echo
}

# Determine user home directory
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    # ACTUAL_USER is used in other scripts, keeping for consistency
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define KDE configuration files to manage
KDE_CONFIG_FILES=(
    "${USER_HOME}/.config/kwinrc"
    "${USER_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"
    "${USER_HOME}/.config/kdeglobals"
    "${USER_HOME}/.config/kcminputrc"
    "${USER_HOME}/.config/khotkeysrc"
    "${USER_HOME}/.config/dolphinrc"
    "${USER_HOME}/.config/powermanagementprofilesrc"
)

# Define KDE local files to manage
KDE_LOCAL_FILES=(
    "${USER_HOME}/.local/share/plasma/desktoptheme"
    "${USER_HOME}/.local/share/plasma/look-and-feel"
    "${USER_HOME}/.local/share/color-schemes"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for KDE
handle_pre_installation_config "kde" "${KDE_CONFIG_FILES[@]}"
handle_pre_installation_config "kde-local" "${KDE_LOCAL_FILES[@]}"

# === STAGE 2: Configure KDE Settings ===
section "Configuring KDE Settings"

# Ensure config directory exists
mkdir -p "${USER_HOME}/.config"

# Configure Meta key to open main menu
cat > "${USER_HOME}/.config/kwinrc" << EOF
[ModifierOnlyShortcuts]
Meta=org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,ShowDesktopGrid
EOF

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

# Set a clean default panel layout
mkdir -p "${USER_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

# === STAGE 3: Configure Additional KDE Settings ===
section "Setting Additional KDE Preferences"

# Create KDE theme configuration directories
mkdir -p "${USER_HOME}/.local/share/plasma/desktoptheme"
mkdir -p "${USER_HOME}/.local/share/plasma/look-and-feel"
mkdir -p "${USER_HOME}/.local/share/color-schemes"

# Configure KWin to use OpenGL
cat > "${USER_HOME}/.config/kwinrc" << EOF
[Compositing]
GLCore=true
GLPreferBufferSwap=a
GLTextureFilter=1
OpenGLIsUnsafe=false
Backend=OpenGL
EOF

# Configure default applications
mkdir -p "${USER_HOME}/.config/mimeapps.list"

# === STAGE 4: Manage User-Specific KDE Customizations ===
section "Managing User-Specific KDE Customizations"

# Handle KDE configuration files
handle_installed_software_config "kde" "${KDE_CONFIG_FILES[@]}"

# Handle KDE local files
handle_installed_software_config "kde-local" "${KDE_LOCAL_FILES[@]}"

# === STAGE 5: Configure Specific Settings ===
section "Configuring Specific KDE Settings"

# Setup keyboard repeat rate
mkdir -p "${USER_HOME}/.config/kcminputrc"
cat > "${USER_HOME}/.config/kcminputrc" << EOF
[Keyboard]
RepeatDelay=250
RepeatRate=30
EOF

# Configure Dolphin file manager
mkdir -p "${USER_HOME}/.config/dolphinrc"
cat > "${USER_HOME}/.config/dolphinrc" << EOF
[General]
Version=202
ViewPropsTimestamp=2023,7,1,12,0,0

[IconsMode]
PreviewSize=128

[KFileDialog Settings]
Places Icons Auto-resize=false
Places Icons Static Size=32

[KPropertiesDialog]
Height 1080=558
Width 1920=427

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled

[PreviewSettings]
Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,svgthumbnail
EOF

# Configure Power Management for desktop
mkdir -p "${USER_HOME}/.config/powermanagementprofilesrc"
cat > "${USER_HOME}/.config/powermanagementprofilesrc" << EOF
[AC]
icon=battery-charging

[AC][DPMSControl]
idleTime=900
lockBeforeTurnOff=0

[AC][DimDisplay]
idleTime=600000

[AC][HandleButtonEvents]
lidAction=1
powerButtonAction=16
powerDownAction=16

[Battery]
icon=battery-060

[Battery][DPMSControl]
idleTime=300
lockBeforeTurnOff=0

[Battery][DimDisplay]
idleTime=120000

[Battery][HandleButtonEvents]
lidAction=1
powerButtonAction=16
powerDownAction=16

[LowBattery]
icon=battery-low

[LowBattery][DPMSControl]
idleTime=120
lockBeforeTurnOff=0

[LowBattery][DimDisplay]
idleTime=60000

[LowBattery][HandleButtonEvents]
lidAction=1
powerButtonAction=16
powerDownAction=16
EOF

# Ensure proper permissions
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/"
fi

echo "✓ Configured KDE settings"

# === STAGE 5: Implement System-Wide KDE Defaults ===
section "Implementing System-Wide KDE Defaults"

# Create system-wide KDE defaults
mkdir -p /etc/skel/.config

# Copy base configurations to skeleton directory for new users
cp "${USER_HOME}/.config/kwinrc" /etc/skel/.config/
cp "${USER_HOME}/.config/kcminputrc" /etc/skel/.config/
cp "${USER_HOME}/.config/dolphinrc" /etc/skel/.config/
cp "${USER_HOME}/.config/powermanagementprofilesrc" /etc/skel/.config/

echo "✓ System-wide KDE defaults configured"

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "kde" "${KDE_CONFIG_FILES[@]}"
check_post_installation_configs "kde-local" "${KDE_LOCAL_FILES[@]}"

section "KDE Settings Configuration Complete!"
echo "KDE settings have been configured with the following changes:"
echo "  - Meta key configured to open application launcher"
echo "  - OpenGL rendering enabled for KWin"
echo "  - User-specific configurations managed through repository"
echo "  - Keyboard, file manager, and power management settings configured"
echo "  - System-wide defaults established for new users"
echo
echo "Note: Some settings may require logging out and back in to take effect."
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
