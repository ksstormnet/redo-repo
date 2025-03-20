#!/bin/bash

# 06-code-editors-setup.sh
# This script installs code editors and related development tools
# and manages editor configurations through a central repository
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

# Function to restore VSCode extensions
restore_vscode_extensions() {
    local extensions_file="$1"
    
    echo "Restoring VS Code extensions..."
    
    # Check if extensions list file exists
    if [ ! -f "$extensions_file" ]; then
        echo "⚠️ Extensions list file not found: $extensions_file"
        echo "Skipping VS Code extensions installation"
        return 1
    fi
    
    # Install extensions
    while read -r extension; do
        # Skip empty lines and comments
        if [[ -z "$extension" || "$extension" == \#* ]]; then
            continue
        fi
        
        echo "Installing extension: $extension"
        if [ "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" code --install-extension "$extension"
        else
            code --install-extension "$extension"
        fi
    done < "$extensions_file"
    
    echo "✓ VS Code extensions installed"
    return 0
}

# Determine user home directory
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    USER_HOME="${HOME}"
fi

# Define configuration files to manage
VSCODE_CONFIG_FILES=(
    "${USER_HOME}/.config/Code/User/settings.json"
    "${USER_HOME}/.config/Code/User/keybindings.json"
)

ZED_CONFIG_FILES=(
    "${USER_HOME}/.config/zed/settings.json"
    "${USER_HOME}/.config/zed/keymap.json"
)

KATE_CONFIG_FILES=(
    "${USER_HOME}/.config/katerc"
    "${USER_HOME}/.config/kateschemarc"
)

NANO_CONFIG_FILES=(
    "${USER_HOME}/.config/nano/nanorc"
)

MICRO_CONFIG_FILES=(
    "${USER_HOME}/.config/micro/settings.json"
    "${USER_HOME}/.config/micro/bindings.json"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for editors
handle_pre_installation_config "vscode" "${VSCODE_CONFIG_FILES[@]}"
handle_pre_installation_config "zed" "${ZED_CONFIG_FILES[@]}"
handle_pre_installation_config "kate" "${KATE_CONFIG_FILES[@]}"
handle_pre_installation_config "nano" "${NANO_CONFIG_FILES[@]}"
handle_pre_installation_config "micro" "${MICRO_CONFIG_FILES[@]}"

# === STAGE 2: VS Code ===
section "Installing Visual Studio Code"

# Add the VS Code repository
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
apt-get update

# Install VS Code
install_packages "Visual Studio Code" code

# Manage VS Code configuration
VSCODE_EXTENSIONS_LIST="/repo/personal/core-configs/vscode/extensions.txt"

# Handle VS Code configuration files
handle_installed_software_config "vscode" "${VSCODE_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/Code"
fi

# Install extensions if the list file exists
if [ -f "$VSCODE_EXTENSIONS_LIST" ]; then
    restore_vscode_extensions "$VSCODE_EXTENSIONS_LIST"
fi

# === STAGE 3: Zed Editor ===
section "Installing Zed Editor"

# Add the Zed Editor repository
curl -fsSL https://zed.dev/deb/key.asc | gpg --dearmor -o /usr/share/keyrings/zed-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/zed-archive-keyring.gpg] https://zed.dev/deb/ stable main" | tee /etc/apt/sources.list.d/zed.list > /dev/null
apt-get update

# Install Zed Editor
install_packages "Zed Editor" zed

# Handle Zed Editor configuration
handle_installed_software_config "zed" "${ZED_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/zed"
fi

# === STAGE 4: Additional Text Editors ===
section "Installing Additional Text Editors"

# Install Kate editor (if not already installed with KDE)
dpkg -l | grep -q "kate" || install_packages "Kate Editor" kate

# Handle Kate configuration
handle_installed_software_config "kate" "${KATE_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/katerc"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/kateschemarc"
fi

# Remove Vim if installed
section "Removing Vim"
echo "Checking if Vim is installed..."

if dpkg -l | grep -q "vim"; then
    echo "Vim is installed. Removing..."
    apt-get remove -y vim vim-gtk3 vim-runtime vim-common vim-tiny
    apt-get autoremove -y
    echo "✓ Vim has been removed"
    
    # Remove any Vim configuration files
    if [[ -d "${USER_HOME}/.vim" ]]; then
        echo "Removing Vim configuration directory..."
        rm -rf "$USER_HOME/.vim"
    fi
    
    if [[ -f "${USER_HOME}/.vimrc" ]]; then
        echo "Removing .vimrc file..."
        rm -f "$USER_HOME/.vimrc"
    fi
    
    echo "✓ Vim configuration files have been removed"
else
    echo "✓ Vim is not installed"
fi

# === STAGE 5: Terminal Editors ===
section "Installing Terminal-based Editors"

# Install Nano and Micro editors
install_packages "Additional terminal editors" nano micro

# Handle Nano configuration
handle_installed_software_config "nano" "${NANO_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/nano"
fi

# Handle Micro configuration
handle_installed_software_config "micro" "${MICRO_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/micro"
fi

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "vscode" "${VSCODE_CONFIG_FILES[@]}"
check_post_installation_configs "zed" "${ZED_CONFIG_FILES[@]}"
check_post_installation_configs "kate" "${KATE_CONFIG_FILES[@]}"
check_post_installation_configs "nano" "${NANO_CONFIG_FILES[@]}"
check_post_installation_configs "micro" "${MICRO_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "Code Editors Setup Complete!"
echo "You now have the following code editors installed with managed configurations:"
echo "  - Visual Studio Code (command: code)"
echo "  - Zed Editor (command: zed)"
echo "  - Kate (KDE's advanced text editor)"
echo "  - Nano (simple terminal editor)"
echo "  - Micro (modern terminal editor)"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
