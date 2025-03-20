#!/bin/bash

# 13-appimage-setup.sh
# This script sets up AppImage support and downloads common AppImages
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

# Create AppImage directory structure
mkdir -p "${USER_HOME}/Apps"
mkdir -p "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
mkdir -p "${USER_HOME}/.local/share/applications"

# Set ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/Apps"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/applications"
fi

echo "✓ Created AppImage directories"

# === STAGE 4: Create Helper Scripts ===
section "Creating AppImage Helper Scripts"

# Create bin directory if it doesn't exist
mkdir -p "${USER_HOME}/bin"

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

if [[ "${SUDO_USER}" ]]; then
    chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/bin/add-appimage.sh"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/bin"
fi

echo "✓ Created AppImage helper script at ~/bin/add-appimage.sh"

# === STAGE 5: Manage AppImage Launcher Configurations ===
section "Managing AppImage Launcher Configurations"

# Create config directory if it doesn't exist
mkdir -p "${USER_HOME}/.config/appimagelauncher"
mkdir -p "${USER_HOME}/.local/share/appimagelauncher/integrations"

# Create a default configuration file if it doesn't exist in the repo
if ! handle_installed_software_config "appimage" "${APPIMAGE_CONFIG_FILES[@]}"; then
    # Create a basic default configuration file
    cat > "${USER_HOME}/.config/appimagelauncher/settings.conf" << EOF
[AppImageLauncher]
ask_to_move=true
destination=${USER_HOME}/Apps
enable_daemon=true

[appimagelauncherd]
monitor_mounted_filesystems=false
EOF
    
    echo "✓ Created default AppImage launcher configuration"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "appimage" "${USER_HOME}/.config/appimagelauncher/settings.conf"
fi

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
    
    create_desktop_file "~/Apps/${filename}" "${display_name}" "${icon_name}" "${categories}" "${comment}"
    echo "✓ Downloaded and set up ${display_name}"
}

# Download and setup specific AppImages

# Raindrop.io
download_and_setup_appimage \
    "https://github.com/raindropio/desktop/releases/download/v5.6.9/Raindrop.io-5.6.9-x86_64.AppImage" \
    "Raindrop.AppImage" \
    "Raindrop.io" \
    "raindrop" \
    "Network;WebBrowser;" \
    "All-in-one bookmark manager"

# HeidiSQL
download_and_setup_appimage \
    "https://github.com/HeidiSQL/HeidiSQL/releases/download/12.5.0.6714/HeidiSQL.AppImage" \
    "HeidiSQL.AppImage" \
    "HeidiSQL" \
    "heidisql" \
    "Development;Database;" \
    "MariaDB, MySQL, MS SQL, PostgreSQL and SQLite client"

# ClickUp
download_and_setup_appimage \
    "https://desktop.clickup.com/linux" \
    "ClickUp.AppImage" \
    "ClickUp" \
    "clickup" \
    "Office;ProjectManagement;" \
    "All-in-one productivity platform"

# Rclone Browser
download_and_setup_appimage \
    "https://github.com/kapitainsky/RcloneBrowser/releases/download/1.8.0/rclone-browser-1.8.0-a0b66c8-linux.AppImage" \
    "RcloneBrowser.AppImage" \
    "Rclone Browser" \
    "rclone-browser" \
    "Utility;FileTransfer;" \
    "Simple cross-platform GUI for rclone"

# mdView
download_and_setup_appimage \
    "https://github.com/qjebbs/mdview/releases/download/v1.0.1/mdview-v1.0.1-linux-x86_64.AppImage" \
    "mdView.AppImage" \
    "mdView" \
    "mdview" \
    "Office;Viewer;" \
    "Markdown viewer and presenter"

# ParseHub
download_and_setup_appimage \
    "https://www.parsehub.com/static/client/parsehub-linux.AppImage" \
    "ParseHub.AppImage" \
    "ParseHub" \
    "parsehub" \
    "Development;WebDevelopment;" \
    "Visual web scraping tool"

# Kdenlive
download_and_setup_appimage \
    "https://download.kde.org/stable/kdenlive/23.08/linux/kdenlive-23.08.5-x86_64.AppImage" \
    "Kdenlive.AppImage" \
    "Kdenlive" \
    "kdenlive" \
    "AudioVideo;VideoEditor;" \
    "KDE's non-linear video editor"

# OpenShot
download_and_setup_appimage \
    "https://github.com/OpenShot/openshot-qt/releases/download/v3.1.1/OpenShot-v3.1.1-x86_64.AppImage" \
    "OpenShot.AppImage" \
    "OpenShot Video Editor" \
    "openshot" \
    "AudioVideo;VideoEditor;" \
    "Simple and powerful video editor"

# Standard Notes
download_and_setup_appimage \
    "https://github.com/standardnotes/app/releases/latest/download/standard-notes-linux-x86_64.AppImage" \
    "StandardNotes.AppImage" \
    "Standard Notes" \
    "standard-notes" \
    "Office;TextEditor;" \
    "A simple and private notes app"

# Joplin
download_and_setup_appimage \
    "https://github.com/laurent22/joplin/releases/latest/download/Joplin-x86_64.AppImage" \
    "Joplin.AppImage" \
    "Joplin" \
    "joplin" \
    "Office;TextEditor;" \
    "A note-taking and to-do application with synchronization"

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
if [[ "${SUDO_USER}" ]]; then
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
echo "  - Multiple AppImage applications downloaded and configured"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "To add a new AppImage, use the helper script:"
echo "  ~/bin/add-appimage.sh path/to/AppImage.AppImage \"Display Name\" \"icon-name\" \"Categories\" \"Description\""
