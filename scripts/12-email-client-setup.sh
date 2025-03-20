#!/bin/bash

# 11-email-client-setup.sh
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

# Handle configuration files
handle_installed_software_config "mailspring" "${MAILSPRING_CONFIG_FILES[@]}"
handle_installed_software_config "mailspring-data" "${MAILSPRING_DATA_FILES[@]}"

# Set proper ownership if running as sudo
if [[ "${SUDO_USER}" ]]; then
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
echo "This ensures your settings are tracked and can be easily restored in the future."
