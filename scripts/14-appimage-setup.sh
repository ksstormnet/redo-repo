#!/bin/bash

# 13-appimage-setup.sh
# This script sets up AppImage support and downloads common AppImages
# Part of the sequential Ubuntu Server to KDE conversion process
# Modified to use restored configurations from critical backup

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

# Check for restored configurations
RESTORED_CONFIGS="/restart/critical_backups/config_mapping.txt"
RESTORED_APPIMAGES_PATH=""
RESTORED_APPIMAGE_LAUNCHER_CONFIG=""

if [[ -f "${RESTORED_CONFIGS}" ]]; then
    echo "Found restored configuration mapping file"
    # shellcheck disable=SC1090
    source "${RESTORED_CONFIGS}"
    
    # Check for specific AppImage configuration paths
    if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
        if [[ -d "${GENERAL_CONFIGS_PATH}/home/.local/share/applications" ]]; then
            RESTORED_APPIMAGES_PATH="${GENERAL_CONFIGS_PATH}/home/.local/share/applications"
            echo "Found restored .desktop files at ${RESTORED_APPIMAGES_PATH}"
        fi
        
        if [[ -d "${GENERAL_CONFIGS_PATH}/home/.config/appimagelauncher" ]]; then
            RESTORED_APPIMAGE_LAUNCHER_CONFIG="${GENERAL_CONFIGS_PATH}/home/.config/appimagelauncher"
            echo "Found restored AppImage Launcher configuration at ${RESTORED_APPIMAGE_LAUNCHER_CONFIG}"
        fi
    fi
fi

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

# Define configuration files for AppImage Launcher
APPIMAGE_CONFIG_FILES=(
    "${USER_HOME}/.config/appimagelauncher/settings.conf"
    "${USER_HOME}/.local/share/appimagelauncher/integrations/integrations.json"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# If we have restored configurations, copy them to the right locations before handling configs
if [[ -n "${RESTORED_APPIMAGE_LAUNCHER_CONFIG}" ]]; then
    echo "Restoring AppImage Launcher configuration from backup..."
    mkdir -p "${USER_HOME}/.config/appimagelauncher"
    if [[ -f "${RESTORED_APPIMAGE_LAUNCHER_CONFIG}/settings.conf" ]]; then
        cp -f "${RESTORED_APPIMAGE_LAUNCHER_CONFIG}/settings.conf" "${USER_HOME}/.config/appimagelauncher/"
        echo "✓ Restored AppImage Launcher settings"
    fi
fi

# Set up pre-installation configurations for AppImage Launcher
handle_pre_installation_config "appimage" "${APPIMAGE_CONFIG_FILES[@]}"

# === STAGE 2: Setup AppImage Support ===
section "Setting Up AppImage Support"

# Install required packages for AppImage
install_packages "AppImage Support" \
    libfuse2 \
    fuse \
    appimagelauncher

# === STAGE 3: Create AppImage Directory Structure ===
section "Creating AppImage Directory Structure"

# Check if we have a restored Apps directory
RESTORED_APPS_DIR=""
if [[ -n "${GENERAL_CONFIGS_PATH}" ]] && [[ -d "${GENERAL_CONFIGS_PATH}/home/Apps" ]]; then
    RESTORED_APPS_DIR="${GENERAL_CONFIGS_PATH}/home/Apps"
    echo "Found restored Apps directory at ${RESTORED_APPS_DIR}"
fi

# Create AppImage directory structure
mkdir -p "${USER_HOME}/Apps"
mkdir -p "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
mkdir -p "${USER_HOME}/.local/share/applications"

# Restore AppImages if they exist
if [[ -n "${RESTORED_APPS_DIR}" ]] && [[ -d "${RESTORED_APPS_DIR}" ]]; then
    echo "Restoring AppImages from backup..."
    cp -rf "${RESTORED_APPS_DIR}"/* "${USER_HOME}/Apps/" 2>/dev/null || true
    echo "✓ Restored AppImages from backup"
    
    # Make them executable again
    find "${USER_HOME}/Apps" -name "*.AppImage" -exec chmod +x {} \;
fi

# Restore .desktop files if they exist
if [[ -n "${RESTORED_APPIMAGES_PATH}" ]] && [[ -d "${RESTORED_APPIMAGES_PATH}" ]]; then
    echo "Restoring .desktop files from backup..."
    cp -f "${RESTORED_APPIMAGES_PATH}"/*.desktop "${USER_HOME}/.local/share/applications/" 2>/dev/null || true
    echo "✓ Restored .desktop files from backup"
fi

# Set ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/Apps"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/applications"
fi

echo "✓ Created AppImage directories"

# === STAGE 4: Create Helper Scripts ===
section "Creating AppImage Helper Scripts"

# Create bin directory if it doesn't exist
mkdir -p "${USER_HOME}/bin"

# Check for restored helper scripts
RESTORED_BIN_DIR=""
if [[ -n "${GENERAL_CONFIGS_PATH}" ]] && [[ -d "${GENERAL_CONFIGS_PATH}/home/bin" ]]; then
    RESTORED_BIN_DIR="${GENERAL_CONFIGS_PATH}/home/bin"
    echo "Found restored bin directory at ${RESTORED_BIN_DIR}"
fi

# Restore add-appimage.sh if it exists, otherwise create a new one
if [[ -n "${RESTORED_BIN_DIR}" ]] && [[ -f "${RESTORED_BIN_DIR}/add-appimage.sh" ]]; then
    echo "Restoring add-appimage.sh from backup..."
    cp -f "${RESTORED_BIN_DIR}/add-appimage.sh" "${USER_HOME}/bin/"
    chmod +x "${USER_HOME}/bin/add-appimage.sh"
    echo "✓ Restored add-appimage.sh from backup"
else
    # Function to create desktop file for an AppImage
    create_desktop_file() {
        local appimage_path="${1}"
        local display_name="${2}"
        local icon_name="${3}"
        local categories="${4}"
        local comment="${5}"
        
        local appimage_filename
        appimage_filename=$(basename "${appimage_path}")
        local appimage_name="${appimage_filename%.*}"
        
        cat > "${USER_HOME}/.local/share/applications/${appimage_name}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${display_name}
Exec=${appimage_path}
Icon=${icon_name}
Comment=${comment}
Categories=${categories}
Terminal=false
X-AppImage-Integrate=false
EOF
        
        echo "✓ Created desktop file for ${display_name}"
    }

    # Create a helper script for adding new AppImages
    cat > "${USER_HOME}/bin/add-appimage.sh" << 'EOF'
#!/bin/bash

if [ $# -lt 5 ]; then
    echo "Usage: $0 path/to/AppImage.AppImage \"Display Name\" \"icon-path.png\" \"Categories\" \"Description\""
    echo "Example: $0 ~/Downloads/App.AppImage \"My App\" \"myapp-icon\" \"Development;Utility;\" \"A useful application\""
    exit 1
fi

APPIMAGE_PATH="$1"
DISPLAY_NAME="$2"
ICON_PATH="$3"
CATEGORIES="$4"
COMMENT="$5"

APPIMAGE_FILENAME=$(basename "$APPIMAGE_PATH")
APPIMAGE_NAME="${APPIMAGE_FILENAME%.*}"

# Copy the AppImage to Applications folder
cp "$APPIMAGE_PATH" ~/Apps/
chmod +x ~/Apps/"$APPIMAGE_FILENAME"

# If icon is a path to an image, copy it to icons directory
if [ -f "$ICON_PATH" ]; then
    ICON_NAME="${ICON_PATH##*/}"
    ICON_NAME="${ICON_NAME%.*}"
    cp "$ICON_PATH" ~/.local/share/icons/hicolor/256x256/apps/"$ICON_NAME".png
else
    # Use the provided icon name
    ICON_NAME="$ICON_PATH"
fi

# Create desktop file
cat > ~/.local/share/applications/${APPIMAGE_NAME}.desktop << EOD
[Desktop Entry]
Type=Application
Name=${DISPLAY_NAME}
Exec=~/Apps/${APPIMAGE_FILENAME}
Icon=${ICON_NAME}
Comment=${COMMENT}
Categories=${CATEGORIES}
Terminal=false
X-AppImage-Integrate=false
EOD

echo "✓ Added AppImage: ${DISPLAY_NAME}"
echo "✓ Desktop file created at: ~/.local/share/applications/${APPIMAGE_NAME}.desktop"
EOF

    chmod +x "${USER_HOME}/bin/add-appimage.sh"
    echo "✓ Created AppImage helper script at ~/bin/add-appimage.sh"
fi

# Set proper ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/bin/add-appimage.sh"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/bin"
fi

# === STAGE 5: Manage AppImage Launcher Configurations ===
section "Managing AppImage Launcher Configurations"

# Create config directory if it doesn't exist
mkdir -p "${USER_HOME}/.config/appimagelauncher"
mkdir -p "${USER_HOME}/.local/share/appimagelauncher/integrations"

# Handle configuration files
handle_installed_software_config "appimage" "${APPIMAGE_CONFIG_FILES[@]}"

# === STAGE 6: Install Wine for Windows-based AppImages ===
section "Installing Wine for Windows-based AppImages"

# Install Wine dependencies
install_packages "Wine Dependencies" \
    wine64 \
    winetricks \
    winbind

# Install Wine platform via snap
echo "Installing Wine platform via snap..."
snap install wine-platform-6-staging
snap install wine-platform-runtime
echo "✓ Installed Wine platform via snap"

# === STAGE 7: Download and Setup AppImages ===
section "Downloading and Setting Up AppImages"

# Check if we already have AppImages
existing_appimages=$(find "${USER_HOME}/Apps" -name "*.AppImage" | wc -l) || true

if [[ ${existing_appimages} -gt 0 ]]; then
    echo "Found ${existing_appimages} existing AppImages in ~/Apps"
    echo "Skipping download of default AppImages"
else
    # Function to download and setup an AppImage
    download_and_setup_appimage() {
        local url="${1}"
        local filename="${2}"
        local display_name="${3}"
        local icon_name="${4}"
        local categories="${5}"
        local comment="${6}"
        
        echo "Downloading ${display_name}..."
        wget -q --show-progress -O "${USER_HOME}/Apps/${filename}" "${url}"
        chmod +x "${USER_HOME}/Apps/${filename}"
        
        create_desktop_file "${USER_HOME}/Apps/${filename}" "${display_name}" "${icon_name}" "${categories}" "${comment}"
        echo "✓ Downloaded and set up ${display_name}"
    }

    # Download and setup specific AppImages
    download_and_setup_appimage \
        "https://github.com/raindropio/desktop/releases/download/v5.6.9/Raindrop.io-5.6.9-x86_64.AppImage" \
        "Raindrop.AppImage" \
        "Raindrop.io" \
        "raindrop" \
        "Network;WebBrowser;" \
        "All-in-one bookmark manager"

    download_and_setup_appimage \
        "https://github.com/HeidiSQL/HeidiSQL/releases/download/12.5.0.6714/HeidiSQL.AppImage" \
        "HeidiSQL.AppImage" \
        "HeidiSQL" \
        "heidisql" \
        "Development;Database;" \
        "MariaDB, MySQL, MS SQL, PostgreSQL and SQLite client"

    download_and_setup_appimage \
        "https://desktop.clickup.com/linux" \
        "ClickUp.AppImage" \
        "ClickUp" \
        "clickup" \
        "Office;ProjectManagement;" \
        "All-in-one productivity platform"

    download_and_setup_appimage \
        "https://github.com/kapitainsky/RcloneBrowser/releases/download/1.8.0/rclone-browser-1.8.0-a0b66c8-linux.AppImage" \
        "RcloneBrowser.AppImage" \
        "Rclone Browser" \
        "rclone-browser" \
        "Utility;FileTransfer;" \
        "Simple cross-platform GUI for rclone"

    download_and_setup_appimage \
        "https://github.com/qjebbs/mdview/releases/download/v1.0.1/mdview-v1.0.1-linux-x86_64.AppImage" \
        "mdView.AppImage" \
        "mdView" \
        "mdview" \
        "Office;Viewer;" \
        "Markdown viewer and presenter"

    download_and_setup_appimage \
        "https://www.parsehub.com/static/client/parsehub-linux.AppImage" \
        "ParseHub.AppImage" \
        "ParseHub" \
        "parsehub" \
        "Development;WebDevelopment;" \
        "Visual web scraping tool"

    download_and_setup_appimage \
        "https://download.kde.org/stable/kdenlive/23.08/linux/kdenlive-23.08.5-x86_64.AppImage" \
        "Kdenlive.AppImage" \
        "Kdenlive" \
        "kdenlive" \
        "AudioVideo;VideoEditor;" \
        "KDE's non-linear video editor"

    download_and_setup_appimage \
        "https://github.com/OpenShot/openshot-qt/releases/download/v3.1.1/OpenShot-v3.1.1-x86_64.AppImage" \
        "OpenShot.AppImage" \
        "OpenShot Video Editor" \
        "openshot" \
        "AudioVideo;VideoEditor;" \
        "Simple and powerful video editor"

    download_and_setup_appimage \
        "https://github.com/standardnotes/app/releases/latest/download/standard-notes-linux-x86_64.AppImage" \
        "StandardNotes.AppImage" \
        "Standard Notes" \
        "standard-notes" \
        "Office;TextEditor;" \
        "A simple and private notes app"

    download_and_setup_appimage \
        "https://github.com/laurent22/joplin/releases/latest/download/Joplin-x86_64.AppImage" \
        "Joplin.AppImage" \
        "Joplin" \
        "joplin" \
        "Office;TextEditor;" \
        "A note-taking and to-do application with synchronization"
fi

# === STAGE 8: Extract Icons from AppImages ===
section "Extracting Icons from AppImages"

# Extract icons from AppImages for better integration
echo "Extracting icons from AppImages..."
cd "${USER_HOME}/Apps" || exit
for appimage in *.AppImage; do
    echo "Extracting icon from ${appimage}..."
    ./"${appimage}" --appimage-extract >/dev/null 2>&1 || true
    
    # Try to find and copy the icon
    icon_name="${appimage%.*}"
    find squashfs-root -name "*.png" -o -name "*.svg" | grep -i icon | head -n 1 | xargs -I{} cp {} "${USER_HOME}/.local/share/icons/hicolor/256x256/apps/${icon_name}.png" 2>/dev/null || true
    
    # Clean up extracted files
    rm -rf squashfs-root
done

# Set proper ownership of all AppImage files
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/Apps/"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/icons/"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/applications/"
fi

# === STAGE 9: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "appimage" "${APPIMAGE_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "AppImage Setup Complete!"
echo "AppImage support has been set up with the following components:"
echo "  - AppImage directories created at ~/Apps"
echo "  - Helper script installed at ~/bin/add-appimage.sh"
echo "  - AppImage launcher settings managed through the repository"

if [[ -n "${RESTORED_APPS_DIR}" ]]; then
    echo "  - AppImages restored from backup"
else
    echo "  - Standard AppImage applications downloaded and configured"
fi

echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "To add a new AppImage, use the helper script:"
echo "  ~/bin/add-appimage.sh path/to/AppImage.AppImage \"Display Name\" \"icon-name\" \"Categories\" \"Description\""
