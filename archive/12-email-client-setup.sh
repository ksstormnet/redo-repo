#!/bin/bash

# 12-email-client-setup.sh
# This script installs email clients and manages Mailspring configurations
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

# Source the backup configuration mapping if available
if [[ -n "${CONFIG_MAPPING_FILE}" ]] && [[ -f "${CONFIG_MAPPING_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_FILE}"
    echo "✓ Loaded configuration mapping from ${CONFIG_MAPPING_FILE}"
else
    echo "Note: Configuration mapping file not found or not specified."
    echo "Will continue with default configuration locations."
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

# Function to restore configuration from backup
restore_config() {
    local app_name="$1"
    local source_dir="$2"
    local target_dir="$3"
    
    if [[ -d "${source_dir}" ]]; then
        echo "Restoring ${app_name} configuration from backup..."
        
        # Create parent directory if it doesn't exist
        mkdir -p "${target_dir}"
        
        # Copy files, but don't fail if there are issues
        cp -r "${source_dir}"/* "${target_dir}/" 2>/dev/null || true
        
        # Set proper ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown -R "${SUDO_USER}":"${SUDO_USER}" "${target_dir}"
        fi
        
        echo "✓ Restored ${app_name} configuration from backup"
        return 0
    fi
    
    echo "No backup found for ${app_name} at ${source_dir}"
    return 1
}

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

# Define configuration files for Mailspring
MAILSPRING_CONFIG_FILES=(
    "${USER_HOME}/.config/Mailspring/config.json"
    "${USER_HOME}/.config/Mailspring/settings.json"
)

MAILSPRING_DATA_FILES=(
    "${USER_HOME}/.local/share/Mailspring/config.json"
    "${USER_HOME}/.local/share/Mailspring/databases/Account"
    "${USER_HOME}/.local/share/Mailspring/databases/Preferences"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Define backup paths based on the configuration mapping
MAILSPRING_CONFIG_BACKUP=""
MAILSPRING_DATA_BACKUP=""

# Check if we have backup configs from general configs path
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    if [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.config/Mailspring" ]]; then
        MAILSPRING_CONFIG_BACKUP="${GENERAL_CONFIGS_PATH}/config_files/.config/Mailspring"
    fi
    
    if [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.local/share/Mailspring" ]]; then
        MAILSPRING_DATA_BACKUP="${GENERAL_CONFIGS_PATH}/config_files/.local/share/Mailspring"
    fi
fi

# If no general configs path, try other locations
if [[ -z "${MAILSPRING_CONFIG_BACKUP}" ]] && [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for Mailspring config in various potential locations
    for potential_dir in \
        "${BACKUP_CONFIGS_PATH}/configs/Mailspring" \
        "${BACKUP_CONFIGS_PATH}/Mailspring" \
        "${BACKUP_CONFIGS_PATH}/configs/config_files/.config/Mailspring"; do
        if [[ -d "${potential_dir}" ]]; then
            MAILSPRING_CONFIG_BACKUP="${potential_dir}"
            break
        fi
    done
fi

# If no data backup path, try other locations
if [[ -z "${MAILSPRING_DATA_BACKUP}" ]] && [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for Mailspring data in various potential locations
    for potential_dir in \
        "${BACKUP_CONFIGS_PATH}/configs/Mailspring-data" \
        "${BACKUP_CONFIGS_PATH}/Mailspring-data" \
        "${BACKUP_CONFIGS_PATH}/configs/config_files/.local/share/Mailspring"; do
        if [[ -d "${potential_dir}" ]]; then
            MAILSPRING_DATA_BACKUP="${potential_dir}"
            break
        fi
    done
fi

# Set up pre-installation configurations for Mailspring
handle_pre_installation_config "mailspring" "${MAILSPRING_CONFIG_FILES[@]}"
handle_pre_installation_config "mailspring-data" "${MAILSPRING_DATA_FILES[@]}"

# === STAGE 2: Install Mailspring via Snap ===
section "Installing Mailspring Email Client"

# Install Mailspring via snap
echo "Installing Mailspring via snap..."
snap install mailspring
echo "✓ Installed Mailspring via snap"

# === STAGE 3: Manage Mailspring Configuration ===
section "Managing Mailspring Configuration"

# Create necessary directories
mkdir -p "${USER_HOME}/.config/Mailspring"
mkdir -p "${USER_HOME}/.local/share/Mailspring"
mkdir -p "${USER_HOME}/.local/share/Mailspring/databases"

# Restore Mailspring configuration from backup if available
if [[ -n "${MAILSPRING_CONFIG_BACKUP}" ]]; then
    restore_config "Mailspring configuration" "${MAILSPRING_CONFIG_BACKUP}" "${USER_HOME}/.config/Mailspring"
fi

# Restore Mailspring data from backup if available
if [[ -n "${MAILSPRING_DATA_BACKUP}" ]]; then
    restore_config "Mailspring data" "${MAILSPRING_DATA_BACKUP}" "${USER_HOME}/.local/share/Mailspring"
fi

# Handle configuration files
handle_installed_software_config "mailspring" "${MAILSPRING_CONFIG_FILES[@]}"
handle_installed_software_config "mailspring-data" "${MAILSPRING_DATA_FILES[@]}"

# Set proper ownership if running as sudo
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/Mailspring"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.local/share/Mailspring"
fi

# === STAGE 4: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "mailspring" "${MAILSPRING_CONFIG_FILES[@]}"
check_post_installation_configs "mailspring-data" "${MAILSPRING_DATA_FILES[@]}"

section "Email Client Installation Complete!"
echo "Mailspring email client has been installed successfully and configurations have been managed."
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Configurations were also restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
echo
echo "This ensures your settings are tracked and can be easily restored in the future."
