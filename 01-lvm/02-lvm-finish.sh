#!/bin/bash

# lvm-finish.sh
# Version: 1.0
# Date: March 25, 2025
#
# This script completes the LVM setup by creating user directories, setting up symlinks,
# configuring passwordless sudo, and setting up the root password.
# Run this script after the first boot into your newly installed system.

# Exit on any error
set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
section() {
    echo
    echo -e "${BOLD}========================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BOLD}========================================================${NC}"
    echo
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Set up trap for cleanup
cleanup() {
    # Nothing specific to clean up in this script
    :
}

trap cleanup EXIT

confirm() {
    local prompt="$1"
    local default="$2"
    
    if [[ "$default" = "Y" ]]; then
        local options="[Y/n]"
        local default_value="Y"
    else
        local options="[y/N]"
        local default_value="N"
    fi
    
    read -p "$prompt $options: " -r REPLY
    REPLY=${REPLY:-$default_value}
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if script is run as root
if [[ "$EUID" -ne 0 ]]; then
    error "Please run this script as root (use sudo)."
fi

# Display welcome message
section "LVM Final Setup"
echo "This script completes the LVM setup by:"
echo "1. Setting up passwordless sudo for user scott"
echo "2. Configuring the root password"
echo "3. Creating the directory structure in /data"
echo "4. Setting up symlinks in /home/scott"
echo "5. Verifying the system configuration"
echo

# Verify LVM setup
section "Verifying LVM Setup"
echo "Checking if LVM volumes are properly mounted..."

required_mounts=("/home/scott" "/docker" "/data" "/data/virtualbox" "/opt/models")
missing_mounts=0

for mount_point in "${required_mounts[@]}"; do
    if ! mount | grep -q " ${mount_point} "; then
        warning "The ${mount_point} volume is not mounted."
        missing_mounts=$((missing_mounts + 1))
    else
        success "${mount_point} is properly mounted"
    fi
done

if [[ $missing_mounts -gt 0 ]]; then
    warning "$missing_mounts mount points are missing."
    if ! confirm "Do you want to try mounting all volumes from fstab?" "Y"; then
        error "Cannot continue without all volumes mounted."
    else
        if ! mount -a; then
            error "Failed to mount all volumes. Please check your fstab configuration."
        else
            success "All volumes mounted successfully"
        fi
    fi
fi

# Check if user scott exists
if ! id -u scott &>/dev/null; then
    warning "User 'scott' does not exist."
    if confirm "Do you want to create user 'scott' now?" "Y"; then
        if ! adduser scott; then
            error "Failed to create user 'scott'."
        else
            success "User 'scott' created"
        fi
    else
        error "Cannot continue without user 'scott'."
    fi
else
    success "User 'scott' exists"
fi

# Configure passwordless sudo for scott
section "Configuring Passwordless Sudo"
echo "Setting up passwordless sudo for user scott..."

if [[ ! -d /etc/sudoers.d ]]; then
    mkdir -p /etc/sudoers.d
    chmod 750 /etc/sudoers.d
fi

echo "scott ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/scott
chmod 440 /etc/sudoers.d/scott

success "Passwordless sudo configured for user scott"

# Set root password
section "Setting Root Password"
echo "Setting up the root password..."

if confirm "Do you want to set the root password now?" "Y"; then
    while ! passwd root; do
        warning "Password setting failed. Please try again."
    done
    success "Root password set"
else
    warning "Root password not set. You may want to set it manually later."
fi

# Create directory structure
section "Creating Directory Structure"
echo "Creating directory structure in /data..."

# Main directories - use -p to avoid errors if directory exists
mkdir -p /data/Documents
mkdir -p /data/Development/repo
mkdir -p /data/Music
mkdir -p /data/Pictures
mkdir -p /data/Video
mkdir -p /data/Archive

# Special links for repo
if ! ln -sf /data/Development/repo /repo; then
    warning "Failed to create symlink at /repo"
fi

if ! ln -sf /data/Development/repo /home/scott/repo; then
    warning "Failed to create symlink at /home/scott/repo"
fi

if ! ln -sf /data/Development/repo /root/repo; then
    warning "Failed to create symlink at /root/repo"
fi

# Set permissions
if ! chown -R scott:scott /data; then
    warning "Failed to set ownership on /data"
else
    success "Ownership set on /data"
fi

if ! chmod -R 755 /data; then
    warning "Failed to set permissions on /data"
fi

if ! chmod -R 700 /data/Archive; then  # More restrictive for Archive
    warning "Failed to set restrictive permissions on /data/Archive"
fi

success "Directory structure created"

# Create symlinks
section "Creating Symlinks"
echo "Creating symlinks in /home/scott..."

# Ensure we have the home directory
if [[ ! -d "/home/scott" ]]; then
    error "Home directory /home/scott does not exist. Please check user creation."
fi

# Create symlinks with error handling
create_symlink() {
    local source="$1"
    local target="$2"
    
    if [[ -e "$target" && ! -L "$target" ]]; then
        warning "Target $target exists and is not a symlink. Moving to ${target}.bak"
        mv "$target" "${target}.bak"
    fi
    
    if ! ln -sf "$source" "$target"; then
        warning "Failed to create symlink from $source to $target"
        return 1
    fi
    return 0
}

# Create all symlinks
create_symlink "/data/Documents" "/home/scott/Documents"
create_symlink "/data/Development" "/home/scott/Development"
create_symlink "/data/Music" "/home/scott/Music"
create_symlink "/data/Pictures" "/home/scott/Pictures"
create_symlink "/data/Video" "/home/scott/Video"
create_symlink "/data/Archive" "/home/scott/Archive"

# Set ownership of symlinks
chown -h scott:scott /home/scott/Documents
chown -h scott:scott /home/scott/Development
chown -h scott:scott /home/scott/Music
chown -h scott:scott /home/scott/Pictures
chown -h scott:scott /home/scott/Video
chown -h scott:scott /home/scott/Archive
chown -h scott:scott /home/scott/repo

success "Symlinks created"

# Configure Docker
section "Configuring Docker"
echo "Configuring Docker to use both /docker and /var/lib/docker..."

# Ensure the symlink exists and is correct
if [[ ! -L "/var/lib/docker" ]]; then
    if [[ -d "/var/lib/docker" ]]; then
        # If it's a directory, move its contents to /docker
        echo "Moving existing Docker data to /docker..."
        if [[ "$(ls -A /var/lib/docker 2>/dev/null)" ]]; then
            cp -a /var/lib/docker/. /docker/
            rm -rf /var/lib/docker
        else
            rmdir /var/lib/docker
        fi
    fi
    
    # Create the symlink
    if ! ln -sf /docker /var/lib/docker; then
        warning "Failed to create Docker symlink"
    else
        success "Docker symlink created"
    fi
else
    success "Docker symlink already exists"
fi

# If Docker is installed, configure and restart it
if command -v docker &>/dev/null; then
    echo "Docker is installed. Configuring it to use the new location..."
    
    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        systemctl stop docker
    fi
    
    # Create or update Docker daemon config
    mkdir -p /etc/docker
    
    if [[ -f /etc/docker/daemon.json ]]; then
        # Backup existing config
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
        
        # Update data-root if it exists, otherwise add it
        if grep -q "data-root" /etc/docker/daemon.json; then
            sed -i 's|"data-root": ".*"|"data-root": "/docker"|g' /etc/docker/daemon.json
        else
            # Simple JSON manipulation to add data-root
            sed -i '1s/{/{\'$'\n  "data-root": "\/docker",/' /etc/docker/daemon.json
        fi
    else
        # Create new config file
        echo '{
  "data-root": "/docker",
  "storage-driver": "overlay2"
}' > /etc/docker/daemon.json
    fi
    
    # Start Docker service
    systemctl start docker
    success "Docker configured to use /docker"
else
    echo "Docker is not installed. No Docker configuration needed."
fi

# Configure VirtualBox
section "Configuring VirtualBox"
echo "Configuring VirtualBox to use /data/virtualbox..."

if command -v vboxmanage &>/dev/null; then
    echo "VirtualBox is installed. Configuring default machine folder..."
    
    # Set the default machine folder for all users
    if ! sudo -u scott vboxmanage setproperty machinefolder /data/virtualbox; then
        warning "Failed to set VirtualBox machine folder. You may need to do this manually."
    else
        success "VirtualBox configured to use /data/virtualbox"
    fi
else
    echo "VirtualBox is not installed. No VirtualBox configuration needed."
fi

# Final verification
section "Final Verification"
echo "Performing final system verification..."

# Check mount points
echo "Checking mount points..."
mount | grep "vg_data"

# Check symlinks
echo "Checking symlinks..."
ls -la /home/scott | grep -E "Documents|Development|Music|Pictures|Video|Archive|repo"
ls -la /var/lib | grep docker
ls -la / | grep repo

# Check directory structure
echo "Checking directory structure..."
ls -la /data

# Display disk usage
echo "Disk usage:"
df -h | grep -E "Filesystem|vg_data"

section "Setup Complete"
echo "The LVM setup is now complete! Your system is configured with:"
echo "- LVM volumes for optimal data organization and performance"
echo "- Directory structure for development and personal files"
echo "- Symlinks for easy access to your data"
echo "- Docker and VirtualBox configured to use dedicated storage"
echo "- Passwordless sudo for user scott"
echo
echo "You can now start using your system!"

exit 0
