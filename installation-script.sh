#!/bin/bash

# Ubuntu Server to KDE Installation Script
# This script installs KDE over Ubuntu Server in a staged approach

# Exit on any error
set -e

# Display a section header
section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Function to install packages with progress indication
install_packages() {
    local description=$1
    shift
    
    echo "Installing: $description..."
    apt-get install -y "$@"
    echo "✓ Completed: $description"
}

# Function to add a repository
add_repository() {
    local repo_name=$1
    local repo_url=$2
    local keyring_url=$3
    
    echo "Adding repository: $repo_name..."
    
    if [ -n "$keyring_url" ]; then
        curl -fsSL "$keyring_url" | gpg --dearmor -o "/usr/share/keyrings/$repo_name-archive-keyring.gpg"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/$repo_name-archive-keyring.gpg] $repo_url $(lsb_release -cs) main" | tee "/etc/apt/sources.list.d/$repo_name.list" > /dev/null
    else
        add-apt-repository -y "$repo_url"
    fi
    
    echo "✓ Added repository: $repo_name"
}

# Update package lists
section "Updating Package Lists"
apt-get update

# Upgrade existing packages
section "Upgrading Existing Packages"
apt-get upgrade -y

# === STAGE 1: Core System ===
section "Installing Core System Components"

# Base system utilities
install_packages "Base System Utilities" \
    apt-utils \
    software-properties-common \
    build-essential \
    curl \
    wget \
    git \
    git-all \
    htop \
    nano \
    vim \
    tmux \
    zip \
    unzip \
    p7zip-full \
    plocate \
    net-tools \
    openssh-server \
    gnupg \
    ca-certificates

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
install_packages "GitHub CLI" gh

# LVM tools
install_packages "LVM Tools" \
    lvm2 \
    thin-provisioning-tools \
    system-config-lvm

# System performance and management
install_packages "System Performance & Management" \
    linux-generic \
    linux-tools-common \
    lm-sensors \
    hddtemp \
    tlp \
    powertop \
    smartmontools

# === STAGE 2: Sound System ===
section "Setting Up Audio System"

# Install PipeWire audio system (modern replacement for PulseAudio)
install_packages "PipeWire Audio System" \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    pipewire-audio \
    wireplumber

# Audio utilities and Sox with MP3 support
install_packages "Audio Utilities" \
    rtkit \
    sox \
    libsox-fmt-mp3

# === STAGE 3: Graphics Drivers ===
section "Installing Graphics Drivers"

# Add Graphics Drivers PPA
add-apt-repository -y ppa:graphics-drivers/ppa
apt-get update

# Install Nvidia drivers
install_packages "NVIDIA Drivers" \
    nvidia-driver-535 \
    nvidia-settings \
    nvidia-prime
section "Installing KDE Desktop Environment"

# Install minimal KDE Plasma
install_packages "KDE Plasma Desktop" \
    kubuntu-desktop \
    plasma-desktop \
    sddm

# Install basic KDE applications
install_packages "Basic KDE Applications" \
    dolphin \
    konsole \
    kate \
    ark \
    kdeconnect \
    plasma-nm \
    plasma-pa \
    print-manager \
    elisa \
    krusader \
    kcalc \
    ksystemlog \
    partitionmanager \
    kompare

# Install screenshot and clipboard utility
install_packages "Screenshot Utility" \
    flameshot

# === STAGE 5: Development Tools ===
section "Installing Development Tools"

# PHP Repository (Ondrej)
add-apt-repository -y ppa:ondrej/php
apt-get update

# Programming languages and tools
install_packages "Programming Languages" \
    gcc \
    g++ \
    openjdk-17-jdk \
    python3-full \
    python3-pip \
    python3-dev \
    nodejs \
    npm

# PHP 8.4 with WordPress development packages
install_packages "PHP 8.4 for WordPress" \
    php8.4 \
    php8.4-cli \
    php8.4-common \
    php8.4-curl \
    php8.4-fpm \
    php8.4-gd \
    php8.4-intl \
    php8.4-mbstring \
    php8.4-mysql \
    php8.4-opcache \
    php8.4-xml \
    php8.4-zip \
    php8.4-bcmath \
    php8.4-imagick

# Install Composer
section "Installing Composer"
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo "ERROR: Invalid composer installer checksum"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
echo "✓ Installed Composer"

# Install WP-CLI
section "Installing WP-CLI"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
echo "✓ Installed WP-CLI"

# Development environments
install_packages "Development Environments" \
    docker.io \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin

# Cloudflare Wrangler
npm install -g wrangler
echo "✓ Installed Cloudflare Wrangler"

# === STAGE 5: Code Editors ===
section "Installing Code Editors"

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
apt-get update
install_packages "Visual Studio Code" code

# Zed Editor
curl -fsSL https://zed.dev/deb/key.asc | gpg --dearmor -o /usr/share/keyrings/zed-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/zed-archive-keyring.gpg] https://zed.dev/deb/ stable main" | tee /etc/apt/sources.list.d/zed.list > /dev/null
apt-get update
install_packages "Zed Editor" zed

# === STAGE 6: ZSH and Shell Enhancements ===
section "Installing ZSH and Shell Enhancements"

# ZSH and related tools
install_packages "ZSH Setup" \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting

# Install Starship prompt
curl -sS https://starship.rs/install.sh | sh -s -- -y
echo "✓ Installed Starship prompt"

# Set ZSH as default shell for current user
chsh -s $(which zsh) $USER
echo "✓ Set ZSH as default shell"

# === STAGE 7: Specialized Software ===
section "Installing Specialized Software"

# Audio production software
install_packages "Audio Production" \
    audacity \
    jack-tools \
    vlc \
    windsurf

# Install VirtualBox
install_packages "Virtualization" \
    virtualbox \
    virtualbox-qt \
    virtualbox-dkms

# Graphics and design
install_packages "Graphics & Design" \
    gimp \
    inkscape \
    krita \
    darktable \
    pinta

# Office and productivity
install_packages "Office & Productivity" \
    libreoffice \
    calibre \
    okular \
    gwenview \
    ghostwriter \
    remarkable \
    typora

# Web and network tools
install_packages "Web and Network Tools" \
    firefox \
    filezilla \
    remmina

# === STAGE 8: Browsers ===
section "Installing Browsers"

# Add Brave repository
add_repository "brave-browser" "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
apt-get update
install_packages "Brave Browser" brave-browser

# Microsoft Edge
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
apt-get update
install_packages "Microsoft Edge" microsoft-edge-stable

# Zen Browser
# Note: Zen Browser installation may require manual steps or visit to their website
echo "Zen Browser: Please install manually from https://www.zen-browser.com/"

# === STAGE 9: Install Ollama for Local LLM ===
section "Installing Ollama for Local LLM"

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
echo "✓ Installed Ollama"

# === STAGE 10: Install Email Client ===
section "Installing Mailspring Email Client"

# Add Mailspring
wget https://updates.getmailspring.com/download?platform=linuxDeb -O mailspring.deb
dpkg -i mailspring.deb
apt-get install -f -y
rm mailspring.deb
echo "✓ Installed Mailspring"

# === STAGE 11: Terminal Enhancements ===
section "Installing Terminal Enhancements"

# Terminal utilities
install_packages "Terminal Utilities" \
    bat \
    exa \
    fd-find \
    ripgrep \
    jq \
    fzf \
    neofetch

# Install Warp Terminal
curl -fsSL https://app.warp.dev/download?package=deb | bash
echo "✓ Installed Warp Terminal"

# === STAGE 13: AppImage Setup ===
section "Setting Up AppImage Support"

# Create AppImage directory structure
mkdir -p ~/Apps
mkdir -p ~/.local/share/icons/hicolor/256x256/apps
mkdir -p ~/.local/share/applications

# Install AppImage tools
install_packages "AppImage Tools" \
    libfuse2 \
    wget \
    curl \
    appimagelauncher

# Function to create desktop file for an AppImage
create_desktop_file() {
    local appimage_path="$1"
    local display_name="$2"
    local icon_name="$3"
    local categories="$4"
    local comment="$5"
    
    local appimage_filename=$(basename "$appimage_path")
    local appimage_name="${appimage_filename%.*}"
    
    cat > ~/.local/share/applications/${appimage_name}.desktop << EOF
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

# Function to download and setup an AppImage
download_and_setup_appimage() {
    local url="$1"
    local filename="$2"
    local display_name="$3"
    local icon_name="$4"
    local categories="$5"
    local comment="$6"
    
    echo "Downloading ${display_name}..."
    wget -q --show-progress -O ~/Apps/"${filename}" "${url}"
    chmod +x ~/Apps/"${filename}"
    
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
    "https://www.heidisql.com/downloads/releases/HeidiSQL_12.6_64_Portable.zip" \
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

# Extract icons from AppImages for better integration
echo "Extracting icons from AppImages..."
cd ~/Apps
for appimage in *.AppImage; do
    echo "Extracting icon from $appimage..."
    ./$appimage --appimage-extract >/dev/null 2>&1 || true
    
    # Try to find and copy the icon
    icon_name="${appimage%.*}"
    find squashfs-root -name "*.png" -o -name "*.svg" | grep -i icon | head -n 1 | xargs -I{} cp {} ~/.local/share/icons/hicolor/256x256/apps/$icon_name.png 2>/dev/null || true
    
    # Clean up extracted files
    rm -rf squashfs-root
done
cd - >/dev/null

# Create a helper script for adding new AppImages later
cat > ~/add-appimage.sh << 'EOF'
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

chmod +x ~/add-appimage.sh
echo "✓ Created AppImage helper script at ~/add-appimage.sh"

# === STAGE 15: Configure KDE Settings ===
section "Configuring KDE Settings"

# Configure Meta key to open main menu
mkdir -p ~/.config
cat > ~/.config/kwinrc << EOF
[ModifierOnlyShortcuts]
Meta=org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,ShowDesktopGrid
EOF

cat > ~/.config/khotkeysrc << EOF
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

# Ensure proper permissions
chown -R $USER:$USER ~/.config/
echo "✓ Configured Meta key to open application launcher"

# === STAGE 16: Configuration Backups ===
section "Setting Up Configuration Backup Directories"

# Create a directory for configuration backups
mkdir -p ~/config-backups/{browsers,git,code-editors,email}
echo "✓ Created configuration backup directories at ~/config-backups/"
echo "  - Place browser configurations in ~/config-backups/browsers/"
echo "  - Place git configurations in ~/config-backups/git/"
echo "  - Place code editor settings in ~/config-backups/code-editors/"
echo "  - Place email client settings in ~/config-backups/email/"

# === STAGE 17: Final Cleanup ===
section "Performing Final System Cleanup"

# Clean up
apt-get autoremove -y
apt-get clean

# Update locate database
updatedb

section "Installation Complete!"
echo "KDE Plasma Desktop has been installed over Ubuntu Server."
echo "You may need to restore your configurations from backups."
echo "You may need to reboot your system to complete the setup."
echo "Command: sudo systemctl reboot"
