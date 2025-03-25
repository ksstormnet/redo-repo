#!/bin/bash

# 14-appimage-setup.sh
# This script sets up AppImage support and downloads common AppImages
# Fixed for Ubuntu 24.04 compatibility
# Simplified to remove config management and focus on successful installations

# Exit on any error
set -e

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
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    ACTUAL_USER="${USER}"
fi

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Setup AppImage Support ===
section "Setting Up AppImage Support"

# Install required packages for AppImage in Ubuntu 24.04
echo "Installing libfuse2 for AppImage support in Ubuntu 24.04..."
install_packages "AppImage Support (libfuse libraries)" \
    libfuse2t64 \
    fuse3

# === STAGE 2: Install AppImageLauncher manually ===
section "Installing AppImageLauncher"

# Create a temporary directory for downloading AppImageLauncher
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Download the latest AppImageLauncher .deb for amd64
echo "Downloading AppImageLauncher..."
wget -q --show-progress https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb

# Install AppImageLauncher and its dependencies
echo "Installing AppImageLauncher..."
apt-get install -y ./appimagelauncher_*.deb || {
    echo "Installing AppImageLauncher dependencies..."
    apt-get install -f -y
    apt-get install -y ./appimagelauncher_*.deb || {
        echo "WARNING: Could not install AppImageLauncher package. Continuing without it."
    }
}

# Clean up temporary directory
cd - >/dev/null
rm -rf "${TEMP_DIR}"

# === STAGE 3: Create AppImage Directory Structure ===
section "Creating AppImage Directory Structure"

# Create AppImage directory structure
mkdir -p "${USER_HOME}/Apps"
mkdir -p "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
mkdir -p "${USER_HOME}/.local/share/applications"

# Set ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/Apps"
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/.local/share/icons/hicolor/256x256/apps"
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/.local/share/applications"
fi

echo "✓ Created AppImage directories"

# === STAGE 4: Create Helper Scripts ===
section "Creating AppImage Helper Scripts"

# Create bin directory if it doesn't exist
mkdir -p "${USER_HOME}/bin"

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

# Create Apps directory if it doesn't exist
mkdir -p ~/Apps

# Copy the AppImage to Applications folder
cp "$APPIMAGE_PATH" ~/Apps/
chmod +x ~/Apps/"$APPIMAGE_FILENAME"

# If icon is a path to an image, copy it to icons directory
if [ -f "$ICON_PATH" ]; then
    mkdir -p ~/.local/share/icons/hicolor/256x256/apps
    ICON_NAME="${ICON_PATH##*/}"
    ICON_NAME="${ICON_NAME%.*}"
    cp "$ICON_PATH" ~/.local/share/icons/hicolor/256x256/apps/"$ICON_NAME".png
else
    # Use the provided icon name
    ICON_NAME="$ICON_PATH"
fi

# Create desktop file
mkdir -p ~/.local/share/applications
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

# Set proper ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/bin/add-appimage.sh"
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/bin"
fi

# === STAGE 5: Install Wine for Windows-based AppImages ===
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

# === STAGE 6: Download and Setup AppImages ===
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
    wget -q --show-progress -O "${USER_HOME}/Apps/${filename}" "${url}" || {
        echo "Warning: Failed to download ${display_name}. Skipping..."
        return 1
    }
    
    chmod +x "${USER_HOME}/Apps/${filename}"
    
    # Create desktop file
    cat > "${USER_HOME}/.local/share/applications/${filename%.AppImage}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${display_name}
Exec=${USER_HOME}/Apps/${filename}
Icon=${icon_name}
Comment=${comment}
Categories=${categories}
Terminal=false
X-AppImage-Integrate=false
EOF
    
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/Apps/${filename}"
        chown "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/.local/share/applications/${filename%.AppImage}.desktop"
    fi
    
    echo "✓ Downloaded and set up ${display_name}"
}

# Download and setup ClickUp
download_and_setup_appimage \
    "https://desktop.clickup.com/linux" \
    "ClickUp.AppImage" \
    "ClickUp" \
    "clickup" \
    "Office;ProjectManagement;" \
    "All-in-one productivity platform"

# Download and setup Rclone Browser
download_and_setup_appimage \
    "https://github.com/kapitainsky/RcloneBrowser/releases/download/1.8.0/rclone-browser-1.8.0-a0b66c6-linux-i386.AppImage" \
    "RcloneBrowser.AppImage" \
    "Rclone Browser" \
    "rclone-browser" \
    "Utility;FileTransfer;" \
    "Simple cross-platform GUI for rclone"

# Download and setup mdView
download_and_setup_appimage \
    "https://github.com/c3er/mdview/releases/download/v3.2.0/mdview-3.2.0-x86_64.AppImage" \
    "mdView.AppImage" \
    "mdView" \
    "mdview" \
    "Office;Viewer;" \
    "Markdown viewer and presenter"

# Download and setup ParseHub
download_and_setup_appimage \
    "https://parsehub.com/static/client/ParseHub.AppImage" \
    "ParseHub.AppImage" \
    "ParseHub" \
    "parsehub" \
    "Development;WebDevelopment;" \
    "Visual web scraping tool"

# Download and setup Kdenlive
download_and_setup_appimage \
    "https://download.kde.org/stable/kdenlive/23.08/linux/kdenlive-23.08.5-x86_64.AppImage" \
    "Kdenlive.AppImage" \
    "Kdenlive" \
    "kdenlive" \
    "AudioVideo;VideoEditor;" \
    "KDE's non-linear video editor"

# Download and setup OpenShot
download_and_setup_appimage \
    "https://github.com/OpenShot/openshot-qt/releases/download/v3.1.1/OpenShot-v3.1.1-x86_64.AppImage" \
    "OpenShot.AppImage" \
    "OpenShot Video Editor" \
    "openshot" \
    "AudioVideo;VideoEditor;" \
    "Simple and powerful video editor"

# Download and setup Standard Notes
download_and_setup_appimage \
    "https://github.com/standardnotes/app/releases/download/%40standardnotes%2Fdesktop%403.195.25/standard-notes-3.195.25-linux-x86_64.AppImage" \
    "StandardNotes.AppImage" \
    "Standard Notes" \
    "standard-notes" \
    "Office;TextEditor;" \
    "A simple and private notes app"

# Download and setup Joplin
download_and_setup_appimage \
    "https://github.com/laurent22/joplin/releases/download/v3.2.13/Joplin-3.2.13.AppImage" \
    "Joplin.AppImage" \
    "Joplin" \
    "joplin" \
    "Office;TextEditor;" \
    "A note-taking and to-do application with synchronization"

# === STAGE 7: Extract Icons from AppImages ===
section "Extracting Icons from AppImages"

# Extract icons from AppImages for better integration
echo "Extracting icons from AppImages..."
cd "${USER_HOME}/Apps" || exit
for appimage in *.AppImage; do
    # Skip if no AppImages exist
    [[ -e "$appimage" ]] || continue
    
    echo "Extracting icon from ${appimage}..."
    ./"${appimage}" --appimage-extract >/dev/null 2>&1 || {
        echo "Warning: Could not extract ${appimage}. Skipping..."
        continue
    }
    
    # Try to find and copy the icon
    icon_name="${appimage%.*}"
    FOUND_ICON=$(find squashfs-root -name "*.png" -o -name "*.svg" | grep -i icon | head -n 1 || true)
    if [[ -n "${FOUND_ICON}" ]]; then
        cp "${FOUND_ICON}" "${USER_HOME}/.local/share/icons/hicolor/256x256/apps/${icon_name}.png" 2>/dev/null || true
    fi
    
    # Clean up extracted files
    rm -rf squashfs-root
done

# Set proper ownership of all AppImage files
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/Apps/"
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/.local/share/icons/"
    chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/.local/share/applications/"
fi

section "AppImage Setup Complete!"
echo "AppImage support has been set up with the following components:"
echo "  - libfuse2t64 installed for Ubuntu 24.04 AppImage support"
echo "  - AppImageLauncher installed manually"
echo "  - AppImage directories created at ~/Apps"
echo "  - Helper script installed at ~/bin/add-appimage.sh"
echo "  - Standard AppImage applications downloaded and configured"
echo
echo "To add a new AppImage, use the helper script:"
echo "  ~/bin/add-appimage.sh path/to/AppImage.AppImage \"Display Name\" \"icon-name\" \"Categories\" \"Description\""
