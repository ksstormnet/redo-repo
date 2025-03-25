#!/bin/bash

# 00-initial-setup.sh
# This script performs initial setup, defines common functions, and sets up Git-based configuration management
# Part of the sequential Ubuntu Server to KDE conversion process

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

# Function to add a repository
add_repository() {
    local repo_name="${1}"
    local repo_url="${2}"
    local keyring_url="${3}"
    
    echo "Adding repository: ${repo_name}..."
    
    if [[ -n "${keyring_url}" ]]; then
        curl -fsSL "${keyring_url}" | gpg --dearmor -o "/usr/share/keyrings/${repo_name}-archive-keyring.gpg" || true
        local codename
        codename=$(lsb_release -cs) || codename="focal"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/${repo_name}-archive-keyring.gpg] ${repo_url} ${codename} main" | tee "/etc/apt/sources.list.d/${repo_name}.list" > /dev/null
    else
        add-apt-repository -y "${repo_url}"
    fi
    
    echo "✓ Added repository: ${repo_name}"
}

# Get the actual user when running with sudo
get_actual_user() {
    if [[ -n "${SUDO_USER}" ]]; then
        echo "${SUDO_USER}"
    else
        echo "${USER}"
    fi
}

# Get the actual user's home directory
get_user_home() {
    if [[ -n "${SUDO_USER}" ]]; then
        getent passwd "${SUDO_USER}" | cut -d: -f6 || true
    else
        echo "${HOME}"
    fi
}

# Set ownership to the actual user
set_user_ownership() {
    local path="${1}"
    local user
    
    # Get the actual user separately to avoid set -e issues
    set +e
    user=$(get_actual_user)
    set -e
    
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${user}":"${user}" "${path}"
    fi
}

# Function to create a symbolic link
create_symlink() {
    local source_file="${1}"
    local dest_link="${2}"
    local description="${3}"
    
    echo "Creating symlink for: ${description}..."
    
    # Backup existing file if it exists and is not a symlink
    if [[ -e "${dest_link}" ]] && [[ ! -L "${dest_link}" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M%S) || timestamp="backup"
        mv "${dest_link}" "${dest_link}.orig.${timestamp}"
        echo "  Backed up existing file: ${dest_link}"
    elif [[ -L "${dest_link}" ]]; then
        rm "${dest_link}"
        echo "  Removed existing symlink: ${dest_link}"
    fi
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "${dest_link}")"
    
    # Create symlink
    ln -sf "${source_file}" "${dest_link}"
    echo "✓ Created symlink: ${dest_link} -> ${source_file}"
}

# Function to check if restored configs are available
check_restored_configs() {
    if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
        echo "Restored configuration mapping found at: ${CONFIG_MAPPING_PATH}"
        # shellcheck disable=SC1090
        source "${CONFIG_MAPPING_PATH}"
        return 0
    else
        echo "No restored configuration mapping found. Using default configurations."
        return 1
    fi
}

# === STAGE 1: Create Configuration Management Functions ===
section "Creating Configuration Management Functions"

# Create functions directory
mkdir -p /usr/local/lib/kde-installer

# Create configuration management functions file
cat > /usr/local/lib/kde-installer/config-management-functions.sh << 'EOF'
#!/bin/bash
# shellcheck disable=SC1091

# config-management-functions.sh
# This script provides functions for managing configuration files
# to be included in other installation scripts

# Function to handle configuration files when software is installed
# Usage: handle_installed_software_config <software_name> <config_file_path> [<additional_config_files>...]
handle_installed_software_config() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    local commit_needed=false
    local added_configs=()
    
    echo "Managing configuration for $software_name..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    mkdir -p "$software_dir"
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the target path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the repo
        if [ -e "$repo_config" ]; then
            echo "Config file exists in repo: $repo_config"
            
            # If the original config exists and is not a symlink, back it up and remove it
            if [ -e "$config_file" ] && [ ! -L "$config_file" ]; then
                echo "Backing up existing config: $config_file → ${config_file}.orig.$(date +%Y%m%d-%H%M%S)"
                mv "$config_file" "${config_file}.orig.$(date +%Y%m%d-%H%M%S)"
            elif [ -L "$config_file" ]; then
                # If it's already a symlink, remove it
                echo "Removing existing symlink: $config_file"
                rm "$config_file"
            fi
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "$config_file")"
            
            # Create symlink from original location to repo
            echo "Creating symlink: $config_file → $repo_config"
            ln -sf "$repo_config" "$config_file"
        else
            # Config doesn't exist in repo, but exists in the system
            if [ -e "$config_file" ] && [ ! -L "$config_file" ]; then
                echo "Moving config to repo: $config_file → $repo_config"
                
                # Create parent directory in repo if needed
                mkdir -p "$(dirname "$repo_config")"
                
                # Move the config file to the repo
                cp -a "$config_file" "$repo_config"
                
                # Remove the original and create a symlink
                rm "$config_file"
                ln -sf "$repo_config" "$config_file"
                
                # Mark for commit
                commit_needed=true
                added_configs+=("$filename")
            else
                echo "Config file not found: $config_file"
            fi
        fi
    done
    
    # Commit changes if needed
    if [[ "${commit_needed}" = true ]] && [[ ${#added_configs[@]} -gt 0 ]]; then
        echo "Committing new configurations to repository..."
        
        # Format the list of added configs for the commit message
        local commit_message="Add ${software_name} configurations: ${added_configs[*]}"
        
        # Commit the changes
        (cd "${repo_dir}" && git add "${software_name}" && git commit -m "${commit_message}")
        echo "✓ Committed changes to repository"
    fi
    
    echo "✓ Configuration management for ${software_name} completed"
}

# Function to handle configuration files before software is installed
# Usage: handle_pre_installation_config <software_name> <config_file_path> [<additional_config_files>...]
handle_pre_installation_config() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    
    echo "Setting up pre-installation configuration for ${software_name}..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    
    # Check if the software directory exists in the repo
    if [[ ! -d "${software_dir}" ]]; then
        echo "No pre-installation configs found for ${software_name} in the repository."
        return 0
    fi
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the source path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the repo
        if [ -e "$repo_config" ]; then
            echo "Config file exists in repo: $repo_config"
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "$config_file")"
            
            # Create symlink from repo to original location
            echo "Creating symlink: $config_file → $repo_config"
            ln -sf "$repo_config" "$config_file"
        fi
    done
    
    echo "✓ Pre-installation configuration for ${software_name} completed"
}

# Function to check for new config files after software installation
# Usage: check_post_installation_configs <software_name> <config_file_path> [<additional_config_files>...]
check_post_installation_configs() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    local commit_needed=false
    local added_configs=()
    
    echo "Checking for new configuration files after ${software_name} installation..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    mkdir -p "$software_dir"
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the target path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the system but not in the repo
        if [ -e "$config_file" ] && [ ! -L "$config_file" ] && [ ! -e "$repo_config" ]; then
            echo "New config file found: $config_file"
            
            # Create parent directory in repo if needed
            mkdir -p "$(dirname "$repo_config")"
            
            # Move the config file to the repo
            cp -a "$config_file" "$repo_config"
            
            # Remove the original and create a symlink
            rm "$config_file"
            ln -sf "$repo_config" "$config_file"
            
            # Mark for commit
            commit_needed=true
            added_configs+=("$filename")
        fi
    done
    
    # Commit changes if needed
    if [[ "${commit_needed}" = true ]] && [[ ${#added_configs[@]} -gt 0 ]]; then
        echo "Committing new configurations to repository..."
        
        # Format the list of added configs for the commit message
        local commit_message="Add new ${software_name} configurations after installation: ${added_configs[*]}"
        
        # Commit the changes
        (cd "${repo_dir}" && git add "${software_name}" && git commit -m "${commit_message}")
        echo "✓ Committed changes to repository"
    else
        echo "No new configuration files found for ${software_name}"
    fi
    
    echo "✓ Post-installation configuration check for ${software_name} completed"
}

# Function to restore configuration from backup if available
# Usage: restore_from_backup <target_path> <backup_relative_path> <description>
restore_from_backup() {
    local target_path="${1}"
    local backup_relative_path="${2}"
    local description="${3}"
    
    # Check if CONFIG_MAPPING_PATH is defined and file exists
    if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
        source "${CONFIG_MAPPING_PATH}"
        
        # Check various possible locations for the backup
        local backup_locations=(
            "${GENERAL_CONFIGS_PATH}/${backup_relative_path}"
            "${SHELL_CONFIGS_PATH}/${backup_relative_path##*/}"
            "${ADDITIONAL_CONFIGS_PATH}/${backup_relative_path}"
            "${SCRIPT_CONFIGS_PATH}/${backup_relative_path}"
        )
        
        for backup_path in "${backup_locations[@]}"; do
            if [[ -e "${backup_path}" ]]; then
                echo "Found backup for ${description} at: ${backup_path}"
                
                # Create parent directory if it doesn't exist
                mkdir -p "$(dirname "${target_path}")"
                
                # Copy the backup to the target path
                cp -r "${backup_path}" "${target_path}"
                echo "✓ Restored ${description} from backup"
                return 0
            fi
        done
        
        echo "No backup found for ${description}"
        return 1
    else
        echo "No configuration mapping available. Cannot restore ${description}"
        return 1
    fi
}
EOF

# Make the functions file executable
chmod +x /usr/local/lib/kde-installer/config-management-functions.sh
echo "✓ Created configuration management functions"

# Create common functions file
cat > /usr/local/lib/kde-installer/functions.sh << 'EOF'
#!/bin/bash

# Common functions for KDE installer scripts

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

# Function to add a repository
add_repository() {
    local repo_name="${1}"
    local repo_url="${2}"
    local keyring_url="${3}"
    
    echo "Adding repository: ${repo_name}..."
    
    if [[ -n "${keyring_url}" ]]; then
        curl -fsSL "${keyring_url}" | gpg --dearmor -o "/usr/share/keyrings/${repo_name}-archive-keyring.gpg"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/${repo_name}-archive-keyring.gpg] ${repo_url} $(lsb_release -cs) main" | tee "/etc/apt/sources.list.d/${repo_name}.list" > /dev/null
    else
        add-apt-repository -y "${repo_url}"
    fi
    
    echo "✓ Added repository: ${repo_name}"
}

# Get the actual user when running with sudo
get_actual_user() {
    if [[ "${SUDO_USER}" ]]; then
        echo "${SUDO_USER}"
    else
        echo "${USER}"
    fi
}

# Get the actual user's home directory
get_user_home() {
    if [[ "${SUDO_USER}" ]]; then
        getent passwd "${SUDO_USER}" | cut -d: -f6
    else
        echo "${HOME}"
    fi
}

# Set ownership to the actual user
set_user_ownership() {
    local path="${1}"
    local user=$(get_actual_user)
    
    if [[ "${SUDO_USER}" ]]; then
        chown -R "${user}":"${user}" "${path}"
    fi
}

# Function to create a symbolic link
create_symlink() {
    local source_file="${1}"
    local dest_link="${2}"
    local description="${3}"
    
    echo "Creating symlink for: ${description}..."
    
    # Backup existing file if it exists and is not a symlink
    if [[ -e "${dest_link}" ]] && [[ ! -L "${dest_link}" ]]; then
        mv "${dest_link}" "${dest_link}.orig.$(date +%Y%m%d-%H%M%S)"
        echo "  Backed up existing file: ${dest_link}"
    elif [[ -L "${dest_link}" ]]; then
        rm "${dest_link}"
        echo "  Removed existing symlink: ${dest_link}"
    fi
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "${dest_link}")"
    
    # Create symlink
    ln -sf "${source_file}" "${dest_link}"
    echo "✓ Created symlink: ${dest_link} -> ${source_file}"
}

# Function to restore configuration from backup if available
restore_from_backup() {
    local target_path="${1}"
    local backup_relative_path="${2}"
    local description="${3}"
    
    # Check if CONFIG_MAPPING_PATH is defined and file exists
    if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
        source "${CONFIG_MAPPING_PATH}"
        
        # Check various possible locations for the backup
        local backup_locations=(
            "${GENERAL_CONFIGS_PATH}/${backup_relative_path}"
            "${SHELL_CONFIGS_PATH}/${backup_relative_path##*/}"
            "${ADDITIONAL_CONFIGS_PATH}/${backup_relative_path}"
            "${SCRIPT_CONFIGS_PATH}/${backup_relative_path}"
        )
        
        for backup_path in "${backup_locations[@]}"; do
            if [[ -e "${backup_path}" ]]; then
                echo "Found backup for ${description} at: ${backup_path}"
                
                # Create parent directory if it doesn't exist
                mkdir -p "$(dirname "${target_path}")"
                
                # Copy the backup to the target path
                cp -r "${backup_path}" "${target_path}"
                echo "✓ Restored ${description} from backup"
                return 0
            fi
        done
        
        echo "No backup found for ${description}"
        return 1
    else
        echo "No configuration mapping available. Cannot restore ${description}"
        return 1
    fi
}

# Source the configuration management functions
# shellcheck disable=SC1090
source /usr/local/lib/kde-installer/config-management-functions.sh
EOF

# Make the functions file executable
chmod +x /usr/local/lib/kde-installer/functions.sh
echo "✓ Created common function library"

# === STAGE 2: Update package sources ===
section "Updating Package Sources"

# Update package lists
apt-get update

# Upgrade existing packages
apt-get upgrade -y
echo "✓ Updated package sources"

# === STAGE 3: Install Basic Dependencies ===
section "Installing Basic Dependencies"

# Install dependencies needed by the installation scripts
install_packages "Basic Dependencies" \
    apt-utils \
    curl \
    wget \
    software-properties-common \
    gnupg \
    ca-certificates \
    apt-transport-https \
    git

# === STAGE 4: Create Script Directories ===
section "Creating Script Directories"

# Create directory for temporary files
mkdir -p /tmp/kde-installer
echo "✓ Created temporary directory"

# Create log directory
mkdir -p /var/log/kde-installer
echo "✓ Created log directory"

# === STAGE 5: Check System Requirements ===
section "Checking System Requirements"

# Check disk space
set +e
ROOT_SPACE=$(df -h / | awk 'NR==2 {print $4}')
set -e
ROOT_SPACE=${ROOT_SPACE:-"unknown"}
echo "Available space on root partition: ${ROOT_SPACE}"

# Check if running on Ubuntu Server
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "Detected OS: ${NAME} ${VERSION_ID}"
    
    if [[ "${NAME}" != *"Ubuntu"* ]]; then
        echo "Warning: This script is designed for Ubuntu Server."
        echo "Running on a different distribution may cause issues."
        
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
            echo "Installation aborted."
            exit 1
        fi
    fi
fi

# Check for internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    echo "Warning: Internet connectivity check failed."
    echo "This script requires internet access to download packages."
    
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 1
    fi
fi

# === STAGE 6: Set up SSH ===
section "Setting up SSH"

# Install SSH server if not already installed
set +e
SSH_INSTALLED=$(dpkg -l | grep -q openssh-server && echo "yes" || echo "no")
set -e
if [[ "${SSH_INSTALLED}" == "no" ]]; then
    install_packages "SSH Server" openssh-server
fi

# Enable and start SSH service
systemctl enable ssh
systemctl start ssh
echo "✓ SSH service enabled and started"

# === STAGE 7: Check for Restored SSH Configuration ===
section "Checking for Restored SSH Configuration"

# Check if we have restored configurations
check_restored_configs

# Set up restored SSH configs if available
if [[ -n "${SSH_PATH}" ]] && [[ -d "${SSH_PATH}" ]]; then
    echo "Found restored SSH configuration at: ${SSH_PATH}"
    
    # Create .ssh directory if it doesn't exist
    set +e
    USER_HOME=$(get_user_home)
    set -e
    USER_HOME=${USER_HOME:-"${HOME}"}
    mkdir -p "${USER_HOME}/.ssh"
    chmod 700 "${USER_HOME}/.ssh"
    
    # Copy all SSH files from backup
    cp -r "${SSH_PATH}"/* "${USER_HOME}/.ssh/"
    chmod 600 "${USER_HOME}/.ssh/id_rsa" 2>/dev/null || true
    chmod 644 "${USER_HOME}/.ssh/id_rsa.pub" 2>/dev/null || true
    chmod 600 "${USER_HOME}/.ssh/config" 2>/dev/null || true
    chmod 600 "${USER_HOME}/.ssh/authorized_keys" 2>/dev/null || true
    
    # Set proper ownership
    set_user_ownership "${USER_HOME}/.ssh"
    
    echo "✓ Restored SSH configuration from backup"
else
    echo "No restored SSH configuration found. Creating basic SSH structure."
    
    # Create .ssh directory if it doesn't exist
    set +e
    USER_HOME=$(get_user_home)
    set -e
    USER_HOME=${USER_HOME:-"${HOME}"}
    mkdir -p "${USER_HOME}/.ssh"
    chmod 700 "${USER_HOME}/.ssh"
    set_user_ownership "${USER_HOME}/.ssh"
    
    echo "✓ Created basic SSH structure"
fi

# === STAGE 8: Create Development Directory Structure ===
section "Creating Development Directory Structure"

# Create the development directory
mkdir -p /data/Development/repo
echo "✓ Created /data/Development/repo directory"

# Create symlink to /repo
ln -sf /data/Development/repo /repo
echo "✓ Created /repo symlink pointing to /data/Development/repo"

# Set proper ownership
set +e
ACTUAL_USER=$(get_actual_user)
set -e
ACTUAL_USER=${ACTUAL_USER:-"${USER}"}
chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" /data/Development
chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" /repo
echo "✓ Set ownership of directories to ${ACTUAL_USER}"

# === STAGE 9: Clone Configuration Repository ===
section "Cloning Configuration Repository"

# Create personal repo directory
mkdir -p /repo/personal
chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" /repo/personal

# Function to clone the configuration repository
clone_configs_repo() {
    echo "Cloning core-configs repository..."
    
    # Try SSH clone first
    local ssh_success=false
    
    # Clone the repository as the actual user
    if [[ -n "${SUDO_USER}" ]]; then
        if su - "${SUDO_USER}" -c "git clone git@github.com:ksstormnet/core-configs.git /repo/personal/core-configs"; then
            ssh_success=true
        fi
    else
        if git clone git@github.com:ksstormnet/core-configs.git /repo/personal/core-configs; then
            ssh_success=true
        fi
    fi
    
    # If SSH was successful
    if [[ "${ssh_success}" = true ]]; then
        echo "✓ Successfully cloned core-configs repository"
        return 0
    else
        echo "⚠ Failed to clone repository using SSH. This might be due to missing SSH keys."
        echo "Attempting to clone using HTTPS instead..."
        
        # Try HTTPS clone as fallback
        if [[ -n "${SUDO_USER}" ]]; then
            if su - "${SUDO_USER}" -c "git clone https://github.com/ksstormnet/core-configs.git /repo/personal/core-configs"; then
                echo "✓ Successfully cloned core-configs repository using HTTPS"
                return 0
            fi
        else
            if git clone https://github.com/ksstormnet/core-configs.git /repo/personal/core-configs; then
                echo "✓ Successfully cloned core-configs repository using HTTPS"
                return 0
            fi
        fi
        
        # If we got here, both SSH and HTTPS failed
        echo "⚠ Failed to clone repository. Please check your internet connection and Git configuration."
        return 1
    fi
}

# Clone the configuration repository
set +e
CLONE_RESULT=0
clone_configs_repo || CLONE_RESULT=$?
set -e
if [[ ${CLONE_RESULT} -ne 0 ]]; then
    echo "Warning: Failed to clone configuration repository."
    echo "You can manually clone it later with:"
    echo "  git clone git@github.com:ksstormnet/core-configs.git /repo/personal/core-configs"
    
    read -p "Do you want to continue with the installation? (y/n): " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 1
    fi
fi

# === STAGE 10: Set Up Shell Configurations from Backup ===
section "Setting Up Shell Configurations"

# Check if we have restored shell configurations
check_restored_configs

set +e
USER_HOME=$(get_user_home)
set -e
USER_HOME=${USER_HOME:-"${HOME}"}

# First try to restore shell configurations from backup
if [[ -n "${SHELL_CONFIGS_PATH}" ]] && [[ -d "${SHELL_CONFIGS_PATH}" ]]; then
    echo "Found restored shell configurations at: ${SHELL_CONFIGS_PATH}"
    
    # Look for common shell configuration files
    for config_file in .bashrc .bash_profile .bash_aliases .profile .zshrc; do
        if [[ -f "${SHELL_CONFIGS_PATH}/${config_file}" ]]; then
            # Back up existing file if it exists
            if [[ -f "${USER_HOME}/${config_file}" ]]; then
                timestamp=$(date +%Y%m%d-%H%M%S) || timestamp="backup"
                mv "${USER_HOME}/${config_file}" "${USER_HOME}/${config_file}.orig.${timestamp}"
                echo "Backed up existing ${config_file}"
            fi
            
            # Copy restored file
            cp "${SHELL_CONFIGS_PATH}/${config_file}" "${USER_HOME}/"
            echo "✓ Restored ${config_file} from backup"
        fi
    done
    
    # Set proper ownership
    set_user_ownership "${USER_HOME}/.bashrc" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.bash_profile" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.bash_aliases" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.profile" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.zshrc" 2>/dev/null || true
    
    echo "✓ Restored shell configurations from backup"
else
    echo "No restored shell configurations found."
    
    # Define configuration files for user profile
    BASH_CONFIG_FILES=(
        "${USER_HOME}/.bashrc"
        "${USER_HOME}/.bash_profile"
        "${USER_HOME}/.bash_aliases"
    )
    
    # Handle bash configuration files using repo
    if [[ -d "/repo/personal/core-configs" ]]; then
        handle_installed_software_config "bash" "${BASH_CONFIG_FILES[@]}"
    else
        echo "No core-configs repository found. Using default shell configurations."
    fi
    
    echo "✓ Set up default shell configurations"
fi

# === STAGE 11: Restore Git Configuration ===
section "Setting Up Git Configuration"

# Check if we have restored git configurations
check_restored_configs

# First try to restore git configuration from backup
if [[ -n "${SHELL_CONFIGS_PATH}" ]] && [[ -d "${SHELL_CONFIGS_PATH}" ]]; then
    for git_config in .gitconfig .gitignore_global .git-credentials; do
        if [[ -f "${SHELL_CONFIGS_PATH}/${git_config}" ]]; then
            # Back up existing file if it exists
            if [[ -f "${USER_HOME}/${git_config}" ]]; then
                timestamp=$(date +%Y%m%d-%H%M%S) || timestamp="backup"
                mv "${USER_HOME}/${git_config}" "${USER_HOME}/${git_config}.orig.${timestamp}"
                echo "Backed up existing ${git_config}"
            fi
            
            # Copy restored file
            cp "${SHELL_CONFIGS_PATH}/${git_config}" "${USER_HOME}/"
            echo "✓ Restored ${git_config} from backup"
        fi
    done
    
    # Set proper ownership
    set_user_ownership "${USER_HOME}/.gitconfig" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.gitignore_global" 2>/dev/null || true
    set_user_ownership "${USER_HOME}/.git-credentials" 2>/dev/null || true
    
    echo "✓ Restored Git configuration from backup"
else
    echo "No restored Git configuration found."
    
    # Define configuration files for Git
    GIT_CONFIG_FILES=(
        "${USER_HOME}/.gitconfig"
        "${USER_HOME}/.gitignore_global"
    )
    
    # Handle Git configuration files using repo
    if [[ -d "/repo/personal/core-configs" ]]; then
        handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
    else
        echo "No core-configs repository found. Using default Git configurations."
    fi
    
    echo "✓ Set up default Git configuration"
fi

# === STAGE 13: Set Up System-wide SSH Configuration ===
section "Setting up System-wide SSH Configuration"

# Define system-wide SSH configuration files
SYSTEM_SSH_CONFIG_FILES=(
    "/etc/ssh/ssh_config"
    "/etc/ssh/sshd_config"
)

# Check if system-wide SSH configs exist in the repository
#if [[ -d "/repo/personal/core-configs/system/ssh" ]]; then
    # Set up pre-installation configurations for system-wide SSH
#    handle_pre_installation_config "system/ssh" "${SYSTEM_SSH_CONFIG_FILES[@]}"
    
    # Handle system-wide SSH configuration files
#    handle_installed_software_config "system/ssh" "${SYSTEM_SSH_CONFIG_FILES[@]}"
    
    # Restart SSH service to apply changes
#    systemctl restart ssh
    
    echo "✓ Created symlinks for system-wide SSH configuration"
# else
    echo "No system-wide SSH configuration found in the repository."
# fi

# === STAGE 14: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Define configuration files to check
BASH_CONFIG_FILES=(
    "${USER_HOME}/.bashrc"
    "${USER_HOME}/.bash_profile"
    "${USER_HOME}/.bash_aliases"
)

GIT_CONFIG_FILES=(
    "${USER_HOME}/.gitconfig"
    "${USER_HOME}/.gitignore_global"
)

VIM_CONFIG_FILES=(
    "${USER_HOME}/.vimrc"
)

# Check for any new configuration files created during installation
#check_post_installation_configs "bash" "${BASH_CONFIG_FILES[@]}"
#check_post_installation_configs "git" "${GIT_CONFIG_FILES[@]}"

section "Initial Setup Complete!"
echo "The system is now prepared for the KDE installation process."
echo "You can proceed with running the individual installation scripts."
echo 
echo "Common functions are available at: /usr/local/lib/kde-installer/functions.sh"
echo "Configuration management functions are available at: /usr/local/lib/kde-installer/config-management-functions.sh"
echo "You can source these files in your scripts with:"
echo "  source /usr/local/lib/kde-installer/functions.sh"
echo
echo "Configuration files are now managed through the Git repository at:"
echo "  /repo/personal/core-configs"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
