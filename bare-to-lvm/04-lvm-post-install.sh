#!/bin/bash

# 04-lvm-post-install.sh
# This script performs post-installation configuration for the LVM setup
# Run this after booting into your new system

# Exit on any error
set -e

# Function to display section headers
section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "LVM Post-Installation Configuration"
echo "This script will set up the data directory structure and XDG user directories."
echo "You should run this after booting into your new system."
echo

# Check if logical volumes are properly mounted
section "Verifying LVM Mounts"
echo "Checking if logical volumes are properly mounted..."

if ! mount | grep -q "/dev/mapper/vg_data-lv_home on /home"; then
    echo "ERROR: /home volume is not mounted. Please check your fstab configuration."
    exit 1
fi

if ! mount | grep -q "/dev/mapper/vg_data-lv_data on /data"; then
    echo "ERROR: /data volume is not mounted. Please check your fstab configuration."
    exit 1
fi

echo "✓ LVM volumes are properly mounted"

# Create data directory structure
section "Creating Data Directory Structure"
echo "Creating directory structure in /data..."

mkdir -p /data/Documents
mkdir -p /data/Pictures
mkdir -p /data/Videos
mkdir -p /data/Music
mkdir -p /data/Projects
mkdir -p /data/Development
mkdir -p /data/Downloads
mkdir -p /data/Backups

echo "✓ Data directory structure created"

# Determine the actual user
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER="$(whoami)"
    if [ "$ACTUAL_USER" == "root" ]; then
        read -r -p "Enter the username to set as owner of /data directories: " ACTUAL_USER
        
        # Verify the user exists
        if ! id "$ACTUAL_USER" &>/dev/null; then
            echo "User $ACTUAL_USER does not exist. Creating user..."
            useradd -m "$ACTUAL_USER"
            passwd "$ACTUAL_USER"
        fi
    fi
fi

# Set ownership
section "Setting Ownership"
echo "Setting ownership of /data directories to $ACTUAL_USER..."

chown -R "$ACTUAL_USER:$ACTUAL_USER" /data
chmod -R 755 /data

echo "✓ Ownership set to $ACTUAL_USER"

# Configure XDG user directories
section "Configuring XDG User Directories"
echo "Setting up XDG user directories for $ACTUAL_USER..."

USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
mkdir -p "$USER_HOME/.config"

cat > "$USER_HOME/.config/user-dirs.dirs" << EOF
XDG_DESKTOP_DIR="$USER_HOME/Desktop"
XDG_DOWNLOAD_DIR="/data/Downloads"
XDG_TEMPLATES_DIR="$USER_HOME/Templates"
XDG_PUBLICSHARE_DIR="$USER_HOME/Public"
XDG_DOCUMENTS_DIR="/data/Documents"
XDG_MUSIC_DIR="/data/Music"
XDG_PICTURES_DIR="/data/Pictures"
XDG_VIDEOS_DIR="/data/Videos"
EOF

chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.config/user-dirs.dirs"

echo "✓ XDG user directories configured"

# Create basic user directories if they don't exist
mkdir -p "$USER_HOME/Desktop"
mkdir -p "$USER_HOME/Templates"
mkdir -p "$USER_HOME/Public"
chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/Desktop" "$USER_HOME/Templates" "$USER_HOME/Public"

# Update XDG user directories
if command -v xdg-user-dirs-update &> /dev/null; then
    echo "Updating XDG user directories..."
    sudo -u "$ACTUAL_USER" xdg-user-dirs-update
    echo "✓ XDG user directories updated"
else
    echo "Note: xdg-user-dirs-update command not found. This is normal if you haven't installed the desktop environment yet."
    echo "The directories will be properly recognized when you install and log into KDE."
fi

section "LVM Post-Installation Configuration Complete"
echo "Your LVM setup is now complete and configured!"
echo
echo "Key directories:"
echo "  - Personal Documents: /data/Documents"
echo "  - Downloads: /data/Downloads"
echo "  - Projects: /data/Projects"
echo "  - Development: /data/Development"
echo
echo "You can now proceed with the installation of your desktop environment"
echo "and additional software using your automation scripts."
