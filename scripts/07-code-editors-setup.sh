#!/bin/bash

# 06-code-editors-setup.sh
# This script installs code editors and related development tools
# and manages editor configurations through a central repository
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

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

# Check if we have restored configurations
if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
    echo "Found restored configuration mapping at: ${CONFIG_MAPPING_PATH}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_PATH}"
fi

# Define shell configs path if not already defined
if [[ -z "${SHELL_CONFIGS_PATH}" ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    SHELL_CONFIGS_PATH="${GENERAL_CONFIGS_PATH}/home"
fi

# Define configuration files for each editor
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

# Function to restore VSCode extensions from backup
restore_vscode_extensions_from_backup() {
    local backup_path="$1"
    
    if [[ -f "${backup_path}" ]]; then
        echo "Found VSCode extensions list at: ${backup_path}"
        
        # Install extensions
        while IFS= read -r extension || [[ -n "${extension}" ]]; do
            # Skip empty lines and comments
            if [[ -z "${extension}" || "${extension}" == \#* ]]; then
                continue
            fi
            
            echo "Installing extension: ${extension}"
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" code --install-extension "${extension}"
            else
                code --install-extension "${extension}"
            fi
        done < "${backup_path}"
        
        echo "✓ VSCode extensions installed from backup"
        return 0
    else
        echo "No VSCode extensions list found at: ${backup_path}"
        return 1
    fi
}

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Check for restored editor configurations
RESTORED_EDITOR_CONFIGS=false
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    echo "Checking for restored editor configurations..."
    
    # Check for VSCode configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/Code" ]]; then
        echo "Found restored VSCode configuration"
        RESTORED_VSCODE=true
        RESTORED_EDITOR_CONFIGS=true
    else
        echo "No restored VSCode configuration found"
        RESTORED_VSCODE=false
    fi
    
    # Check for Zed configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/zed" ]]; then
        echo "Found restored Zed configuration"
        RESTORED_ZED=true
        RESTORED_EDITOR_CONFIGS=true
    else
        echo "No restored Zed configuration found"
        RESTORED_ZED=false
    fi
    
    # Check for Kate configs
    if [[ -f "${GENERAL_CONFIGS_PATH}/config/katerc" ]] || [[ -f "${GENERAL_CONFIGS_PATH}/config/kateschemarc" ]]; then
        echo "Found restored Kate configuration"
        RESTORED_KATE=true
        RESTORED_EDITOR_CONFIGS=true
    else
        echo "No restored Kate configuration found"
        RESTORED_KATE=false
    fi
    
    # Check for Nano configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/nano" ]] || [[ -f "${SHELL_CONFIGS_PATH}/.nanorc" ]]; then
        echo "Found restored Nano configuration"
        RESTORED_NANO=true
        RESTORED_EDITOR_CONFIGS=true
    else
        echo "No restored Nano configuration found"
        RESTORED_NANO=false
    fi
    
    # Check for Micro configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/micro" ]]; then
        echo "Found restored Micro configuration"
        RESTORED_MICRO=true
        RESTORED_EDITOR_CONFIGS=true
    else
        echo "No restored Micro configuration found"
        RESTORED_MICRO=false
    fi
    
    if [[ "${RESTORED_EDITOR_CONFIGS}" = true ]]; then
        echo "Will use restored editor configurations where possible."
    else
        echo "No restored editor configurations found."
    fi
else
    echo "No restored configuration mapping found. Using default configurations."
    RESTORED_VSCODE=false
    RESTORED_ZED=false
    RESTORED_KATE=false
    RESTORED_NANO=false
    RESTORED_MICRO=false
fi

# Set up pre-installation configurations only if no restored configs found
if [[ "${RESTORED_VSCODE}" = false ]]; then
    handle_pre_installation_config "vscode" "${VSCODE_CONFIG_FILES[@]}"
fi

if [[ "${RESTORED_ZED}" = false ]]; then
    handle_pre_installation_config "zed" "${ZED_CONFIG_FILES[@]}"
fi

if [[ "${RESTORED_KATE}" = false ]]; then
    handle_pre_installation_config "kate" "${KATE_CONFIG_FILES[@]}"
fi

if [[ "${RESTORED_NANO}" = false ]]; then
    handle_pre_installation_config "nano" "${NANO_CONFIG_FILES[@]}"
fi

if [[ "${RESTORED_MICRO}" = false ]]; then
    handle_pre_installation_config "micro" "${MICRO_CONFIG_FILES[@]}"
fi

# === STAGE 2: VS Code ===
section "Installing Visual Studio Code"

# Add the VS Code repository
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg || true
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
apt-get update

# Install VS Code
install_packages "Visual Studio Code" code

# Create necessary directories
mkdir -p "${USER_HOME}/.config/Code/User"

# === STAGE 3: Restore or Set Up VS Code Configuration ===
section "Setting Up VS Code Configuration"

# Check for restored VSCode configurations
if [[ "${RESTORED_VSCODE}" = true ]] && [[ -d "${GENERAL_CONFIGS_PATH}/config/Code" ]]; then
    echo "Restoring VSCode configuration from backup..."
    
    # Create parent directory if it doesn't exist
    mkdir -p "${USER_HOME}/.config/Code"
    
    # Copy User directory with settings
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/Code/User" ]]; then
        cp -r "${GENERAL_CONFIGS_PATH}/config/Code/User" "${USER_HOME}/.config/Code/"
        echo "✓ Restored VSCode User settings"
    fi
    
    # Check for VSCode extensions list
    VSCODE_EXTENSIONS="${GENERAL_CONFIGS_PATH}/vscode/extensions.txt"
    if [[ -f "${VSCODE_EXTENSIONS}" ]]; then
        echo "Found VSCode extensions list in backup"
        restore_vscode_extensions_from_backup "${VSCODE_EXTENSIONS}"
    else
        # Try alternative locations
        ALT_EXTENSIONS="${GENERAL_CONFIGS_PATH}/config/Code/extensions.txt"
        if [[ -f "${ALT_EXTENSIONS}" ]]; then
            echo "Found VSCode extensions list in alternative location"
            restore_vscode_extensions_from_backup "${ALT_EXTENSIONS}"
        else
            echo "No VSCode extensions list found in backup"
        fi
    fi
else
    # Handle VS Code configuration files from repo
    handle_installed_software_config "vscode" "${VSCODE_CONFIG_FILES[@]}"
    
    # Look for extensions list in repo
    if [[ -d "/repo/personal/core-configs" ]]; then
        VSCODE_EXTENSIONS_LIST="/repo/personal/core-configs/vscode/extensions.txt"
        if [[ -f "${VSCODE_EXTENSIONS_LIST}" ]]; then
            echo "Found VSCode extensions list in repository"
            restore_vscode_extensions_from_backup "${VSCODE_EXTENSIONS_LIST}"
        else
            echo "No VSCode extensions list found in repository"
        fi
    fi
fi

# Set proper ownership for VS Code configuration
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/Code"
fi

# === STAGE 4: Zed Editor ===
section "Installing Zed Editor"

# Add the Zed Editor repository
curl -fsSL https://zed.dev/deb/key.asc | gpg --dearmor -o /usr/share/keyrings/zed-archive-keyring.gpg || true
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/zed-archive-keyring.gpg] https://zed.dev/deb/ stable main" | tee /etc/apt/sources.list.d/zed.list > /dev/null
apt-get update

# Install Zed Editor
install_packages "Zed Editor" zed

# Create necessary directories
mkdir -p "${USER_HOME}/.config/zed"

# === STAGE 5: Restore or Set Up Zed Editor Configuration ===
section "Setting Up Zed Editor Configuration"

# Check for restored Zed configurations
if [[ "${RESTORED_ZED}" = true ]] && [[ -d "${GENERAL_CONFIGS_PATH}/config/zed" ]]; then
    echo "Restoring Zed configuration from backup..."
    
    # Create parent directory if it doesn't exist
    mkdir -p "${USER_HOME}/.config/zed"
    
    # Copy all config files
    cp -r "${GENERAL_CONFIGS_PATH}/config/zed"/* "${USER_HOME}/.config/zed/"
    echo "✓ Restored Zed configuration"
else
    # Handle Zed Editor configuration files from repo
    handle_installed_software_config "zed" "${ZED_CONFIG_FILES[@]}"
fi

# Set proper ownership for Zed configuration
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/zed"
fi

# === STAGE 6: Additional Text Editors ===
section "Installing Additional Text Editors"

# Install Kate editor (if not already installed with KDE)
if ! dpkg -l | grep -q "kate" || true; then
    install_packages "Kate Editor" kate
fi

# Create necessary directories
mkdir -p "${USER_HOME}/.config"

# === STAGE 7: Restore or Set Up Kate Configuration ===
section "Setting Up Kate Configuration"

# Check for restored Kate configurations
if [[ "${RESTORED_KATE}" = true ]]; then
    echo "Restoring Kate configuration from backup..."
    
    # Restore katerc if found
    if [[ -f "${GENERAL_CONFIGS_PATH}/config/katerc" ]]; then
        cp "${GENERAL_CONFIGS_PATH}/config/katerc" "${USER_HOME}/.config/"
        echo "✓ Restored Kate configuration file (katerc)"
    fi
    
    # Restore kateschemarc if found
    if [[ -f "${GENERAL_CONFIGS_PATH}/config/kateschemarc" ]]; then
        cp "${GENERAL_CONFIGS_PATH}/config/kateschemarc" "${USER_HOME}/.config/"
        echo "✓ Restored Kate schema configuration file (kateschemarc)"
    fi
else
    # Handle Kate configuration files from repo
    handle_installed_software_config "kate" "${KATE_CONFIG_FILES[@]}"
fi

# Set proper ownership for Kate configuration
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/katerc" 2>/dev/null || true
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/kateschemarc" 2>/dev/null || true
fi

# Remove Vim if installed
section "Removing Vim"
echo "Checking if Vim is installed..."

if dpkg -l | grep -q "vim" || true; then
    echo "Vim is installed. Removing..."
    apt-get remove -y vim vim-gtk3 vim-runtime vim-common vim-tiny
    apt-get autoremove -y
    echo "✓ Vim has been removed"
    
    # Remove any Vim configuration files
    if [[ -d "${USER_HOME}/.vim" ]]; then
        echo "Removing Vim configuration directory..."
        rm -rf "${USER_HOME}/.vim"
    fi
    
    if [[ -f "${USER_HOME}/.vimrc" ]] && [[ ! -L "${USER_HOME}/.vimrc" ]]; then
        echo "Removing .vimrc file..."
        rm -f "${USER_HOME}/.vimrc"
    fi
    
    echo "✓ Vim configuration files have been removed"
else
    echo "✓ Vim is not installed"
fi

# === STAGE 8: Terminal Editors ===
section "Installing Terminal-based Editors"

# Install Nano and Micro editors
install_packages "Additional terminal editors" nano micro

# Create necessary directories
mkdir -p "${USER_HOME}/.config/nano"
mkdir -p "${USER_HOME}/.config/micro"

# === STAGE 9: Restore or Set Up Nano Configuration ===
section "Setting Up Nano Configuration"

# Check for restored Nano configurations
if [[ "${RESTORED_NANO}" = true ]]; then
    echo "Restoring Nano configuration from backup..."
    
    # Check for config dir in backup
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/nano" ]]; then
        mkdir -p "${USER_HOME}/.config/nano"
        cp -r "${GENERAL_CONFIGS_PATH}/config/nano"/* "${USER_HOME}/.config/nano/"
        echo "✓ Restored Nano configuration directory"
    fi
    
    # Check for .nanorc in shell configs
    if [[ -f "${SHELL_CONFIGS_PATH}/.nanorc" ]]; then
        cp "${SHELL_CONFIGS_PATH}/.nanorc" "${USER_HOME}/"
        echo "✓ Restored .nanorc file"
    fi
else
    # Handle Nano configuration files from repo
    handle_installed_software_config "nano" "${NANO_CONFIG_FILES[@]}"
fi

# Set proper ownership for Nano configuration
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/nano"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.nanorc" 2>/dev/null || true
fi

# === STAGE 10: Restore or Set Up Micro Configuration ===
section "Setting Up Micro Configuration"

# Check for restored Micro configurations
if [[ "${RESTORED_MICRO}" = true ]] && [[ -d "${GENERAL_CONFIGS_PATH}/config/micro" ]]; then
    echo "Restoring Micro configuration from backup..."
    
    mkdir -p "${USER_HOME}/.config/micro"
    cp -r "${GENERAL_CONFIGS_PATH}/config/micro"/* "${USER_HOME}/.config/micro/"
    echo "✓ Restored Micro configuration"
else
    # Handle Micro configuration files from repo
    handle_installed_software_config "micro" "${MICRO_CONFIG_FILES[@]}"
fi

# Set proper ownership for Micro configuration
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/micro"
fi

# === STAGE 11: Check for New Configuration Files ===
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

if [[ "${RESTORED_EDITOR_CONFIGS}" = true ]]; then
    echo "Your restored editor configurations have been applied from the backup."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
    echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
    echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
    echo "  - Any changes to configurations should be made in the repository"
fi
