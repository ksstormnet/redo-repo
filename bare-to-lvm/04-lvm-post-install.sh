#!/bin/bash

# 04-lvm-post-install-enhanced.sh
# This script performs post-installation setup for the LVM configuration
# including creating directory structures and setting up symlinks

set -e

section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Check if script is run as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Function to configure user access
configure_user_access() {
    section "Configuring User Access"
    
    echo "Setting up passwordless sudo for user scott..."
    echo "scott ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/scott
    chmod 440 /etc/sudoers.d/scott
    
    echo "Setting root password..."
    # Use a predefined password or prompt for one
    echo "root:your_secure_password" | chpasswd
    
    echo "Adding entry to scott's bashrc to switch to root and navigate to USB drive..."
    cat >> /home/scott/.bashrc << EOF

# Auto-switch to root and navigate to USB drive after reboot
if [[ "\$(tty)" = "/dev/tty1" ]]; then
  echo "Switching to root and navigating to USB drive..."
  sudo -i
  cd /media/scott/Restart-Critical
fi
EOF
    
    echo "✓ User access configured successfully"
}

# Function to set up external drive mounts
setup_external_drives() {
    section "Setting Up External Drive Mounts"
    
    echo "Determining UUIDs of external drives..."
    SDB1_UUID=$(blkid -s UUID -o value /dev/sdb1) || true
    SDD1_UUID=$(blkid -s UUID -o value /dev/sdd1) || true
    
    echo "Found drive UUIDs:"
    echo "  /dev/sdb1: ${SDB1_UUID}"
    echo "  /dev/sdd1: ${SDD1_UUID} (will become sdc1 after reboot)"
    
    echo "Creating mount points..."
    mkdir -p /restart
    mkdir -p /data
    
    echo "Adding entries to fstab..."
    cat >> /etc/fstab << EOF
# External drives for system setup
UUID=${SDB1_UUID}  /restart  ext4  defaults  0  2
UUID=${SDD1_UUID}  /data     ext4  defaults  0  2
EOF
    
    echo "Mounting drives..."
    mount /restart
    mount /data
    
    echo "✓ External drives configured successfully"
}

# Function to configure timezone
configure_timezone() {
    section "Configuring Timezone"
    
    echo "Setting timezone to America/Chicago..."
    timedatectl set-timezone America/Chicago
    
    echo "Configuring CLI time display to 24 hours..."
    # For bash
    cat > /etc/profile.d/time-format.sh << EOF
# Set 24-hour time format
export LC_TIME="en_US.UTF-8"
export LANG="en_US.UTF-8"
EOF
    
    # For system-wide settings
    localectl set-locale LC_TIME=en_US.UTF-8
    
    echo "✓ Timezone configured successfully"
}

# Function to create directory structure
setup_directory_structure() {
    section "Setting up directory structure"
    
    echo "Creating directories in /mnt/data..."
    mkdir -p /mnt/data/documents
    mkdir -p /mnt/data/media/music
    mkdir -p /mnt/data/media/videos
    mkdir -p /mnt/data/media/photos
    mkdir -p /mnt/data/projects
    mkdir -p /mnt/data/downloads
    mkdir -p /mnt/data/backups
    
    echo "Creating directories in /var/lib/docker..."
    mkdir -p /var/lib/docker/volumes
    
    echo "Creating directories in /mnt/virtualbox..."
    mkdir -p /mnt/virtualbox/machines
    mkdir -p /mnt/virtualbox/isos
    
    echo "Creating directories in /mnt/models..."
    mkdir -p /mnt/models/huggingface
    mkdir -p /mnt/models/ollama
    mkdir -p /mnt/models/downloads
    
    # Set appropriate permissions
    echo "Setting permissions..."
    chown -R 1000:1000 /mnt/data
    chown -R 1000:1000 /mnt/virtualbox
    chown -R 1000:1000 /mnt/models
    
    echo "✓ Directory structure created successfully"
}

# Function to create symlinks to common locations
setup_symlinks() {
    section "Creating symlinks"
    
    # Get username of the actual user (not root)
    # Use separate commands to avoid masking return values
    local who_output
    who_output=$(who am i) || true
    local awk_output
    awk_output=$(echo "${who_output}" | awk '{print $1}') || true
    
    REAL_USER=$(logname 2>/dev/null || echo "${awk_output}")
    USER_HOME="/home/${REAL_USER}"
    
    if [[ ! -d "${USER_HOME}" ]]; then
        echo "User home directory not found at ${USER_HOME}"
        read -r -p "Enter the path to the user's home directory: " USER_HOME
    fi
    
    echo "Setting up symlinks for user ${REAL_USER} in ${USER_HOME}..."
    
    # Create symlinks only if they don't already exist
    if [[ ! -L "${USER_HOME}/Documents" ]] && [[ ! -e "${USER_HOME}/Documents" ]]; then
        ln -s /mnt/data/documents "${USER_HOME}/Documents"
        echo "✓ Created symlink for Documents"
    else
        echo "Documents directory/symlink already exists, skipping"
    fi
    
    if [[ ! -L "${USER_HOME}/Music" ]] && [[ ! -e "${USER_HOME}/Music" ]]; then
        ln -s /mnt/data/media/music "${USER_HOME}/Music"
        echo "✓ Created symlink for Music"
    else
        echo "Music directory/symlink already exists, skipping"
    fi
    
    if [[ ! -L "${USER_HOME}/Videos" ]] && [[ ! -e "${USER_HOME}/Videos" ]]; then
        ln -s /mnt/data/media/videos "${USER_HOME}/Videos"
        echo "✓ Created symlink for Videos"
    else
        echo "Videos directory/symlink already exists, skipping"
    fi
    
    if [[ ! -L "${USER_HOME}/Pictures" ]] && [[ ! -e "${USER_HOME}/Pictures" ]]; then
        ln -s /mnt/data/media/photos "${USER_HOME}/Pictures"
        echo "✓ Created symlink for Pictures"
    else
        echo "Pictures directory/symlink already exists, skipping"
    fi
    
    if [[ ! -L "${USER_HOME}/Downloads" ]] && [[ ! -e "${USER_HOME}/Downloads" ]]; then
        ln -s /mnt/data/downloads "${USER_HOME}/Downloads"
        echo "✓ Created symlink for Downloads"
    else
        echo "Downloads directory/symlink already exists, skipping"
    fi
    
    if [[ ! -L "${USER_HOME}/Projects" ]] && [[ ! -e "${USER_HOME}/Projects" ]]; then
        ln -s /mnt/data/projects "${USER_HOME}/Projects"
        echo "✓ Created symlink for Projects"
    else
        echo "Projects directory/symlink already exists, skipping"
    fi
    
    # Set correct ownership
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Documents" 2>/dev/null || true
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Music" 2>/dev/null || true
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Videos" 2>/dev/null || true
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Pictures" 2>/dev/null || true
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Downloads" 2>/dev/null || true
    chown -h "${REAL_USER}":"${REAL_USER}" "${USER_HOME}/Projects" 2>/dev/null || true
    
    echo "✓ Symlinks created successfully"
}

# Function to setup additional features
setup_additional_features() {
    section "Setting up additional features"
    
    # Configure Docker to use the LVM volume
    if command -v docker &>/dev/null; then
        echo "Configuring Docker to use /var/lib/docker..."
        
        # Check if Docker service is running
        if systemctl is-active --quiet docker; then
            systemctl stop docker
        fi
        
        # Create Docker daemon config if it doesn't exist
        if [[ ! -f /etc/docker/daemon.json ]]; then
            mkdir -p /etc/docker
            echo '{
  "data-root": "/var/lib/docker"
}' > /etc/docker/daemon.json
            echo "✓ Docker data root configured to use /var/lib/docker"
        else
            # Update existing config
            if grep -q "data-root" /etc/docker/daemon.json; then
                sed -i 's|"data-root": ".*"|"data-root": "/var/lib/docker"|g' /etc/docker/daemon.json
            else
                # Add data-root to existing config
                sed -i 's/{/{\\n  "data-root": "\/var\/lib\/docker",/g' /etc/docker/daemon.json
            fi
            echo "✓ Updated Docker data root in daemon.json"
        fi
        
        # Start Docker service
        systemctl start docker
        echo "✓ Docker service restarted"
    else
        echo "Docker not installed, skipping Docker configuration"
    fi
    
    # Configure VirtualBox default machine folder if installed
    if command -v vboxmanage &>/dev/null; then
        echo "Configuring VirtualBox to use /mnt/virtualbox/machines..."
        
        # Get the current user who will use VirtualBox
        # Use separate commands to avoid masking return values
        local who_output
        who_output=$(who am i) || true
        local awk_output
        awk_output=$(echo "${who_output}" | awk '{print $1}') || true
        
        REAL_USER=$(logname 2>/dev/null || echo "${awk_output}")
        
        # Set the default machine folder for VirtualBox
        sudo -u "${REAL_USER}" vboxmanage setproperty machinefolder /mnt/virtualbox/machines
        echo "✓ VirtualBox machine folder set to /mnt/virtualbox/machines"
    else
        echo "VirtualBox not installed, skipping VirtualBox configuration"
    fi
    
    echo "✓ Additional features setup completed"
}

# Function to verify setup
verify_setup() {
    section "Verifying setup"
    
    # Check mount points
    echo "Checking mount points..."
    MOUNT_CHECK=$(df -h | grep -c "/mnt/") || true
    if [[ "${MOUNT_CHECK}" -ge 3 ]]; then
        echo "✓ Mount points verified"
    else
        echo "⚠ Warning: Some mount points may not be correctly mounted"
        df -h | grep "/dev/mapper/vg_data" || true
    fi
    
    # Check directory structure
    echo "Checking directory structure..."
    DIR_CHECK=0
    for dir in /mnt/data /mnt/virtualbox /mnt/models /var/lib/docker; do
        if [[ -d "${dir}" ]]; then
            ((DIR_CHECK++))
        else
            echo "⚠ Warning: Directory ${dir} not found"
        fi
    done
    
    if [[ "${DIR_CHECK}" -eq 4 ]]; then
        echo "✓ Directory structure verified"
    else
        echo "⚠ Warning: Some directories are missing"
    fi
    
    # Verify symlinks (check at least one)
    # Use separate commands to avoid masking return values
    local who_output
    who_output=$(who am i) || true
    local awk_output
    awk_output=$(echo "${who_output}" | awk '{print $1}') || true
    
    REAL_USER=$(logname 2>/dev/null || echo "${awk_output}")
    USER_HOME="/home/${REAL_USER}"
    
    echo "Checking symlinks..."
    if [[ -L "${USER_HOME}/Documents" ]]; then
        echo "✓ Symlinks verified"
    else
        echo "⚠ Warning: Symlinks may not be set up correctly"
    fi
    
    echo "✓ Verification completed"
}

# Function to show summary
show_summary() {
    section "Setup Summary"
    
    echo "Post-installation setup has been completed!"
    echo
    echo "The following tasks were performed:"
    echo "  - Created directory structure in data volumes"
    echo "  - Set up symlinks in user's home directory"
    echo "  - Configured applications to use LVM volumes"
    echo "  - Verified setup integrity"
    echo
    echo "LVM Storage Configuration:"
    echo "---------------------------"
    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT | grep -E "lvm|NAME" || true
    echo
    echo "Disk Usage:"
    echo "---------------------------"
    df -h | grep -E "Filesystem|vg_data" || true
    echo
    echo "Next Steps:"
    echo "  1. Reboot the system to ensure all changes take effect"
    echo "  2. Use the lvm-monitor.sh script to check space usage"
    echo "  3. For any issues, check system logs or run verify_setup again"
    echo
    echo "Setup process completed successfully!"
}

# Main function
main() {
    section "LVM Post-Installation Setup"
    echo "This script will set up directories, symlinks, and configure"
    echo "applications to use the LVM volumes created earlier."
    echo
    read -r -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Run all setup functions
    configure_user_access      # New function for user access
    setup_external_drives      # New function for external drives
    configure_timezone         # New function for timezone
    setup_directory_structure
    setup_symlinks
    setup_additional_features
    verify_setup
    show_summary
}

# Run the main function
main
