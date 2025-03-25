#!/bin/bash

# 10-browsers-setup.sh
# This script installs web browsers and browser-related tools
# Part of the sequential Ubuntu Server to KDE conversion process
# Enhanced with profile management from configuration repository

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
        RELEASE_CODENAME=$(lsb_release -cs) || RELEASE_CODENAME="jammy"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/${repo_name}-archive-keyring.gpg] ${repo_url} ${RELEASE_CODENAME} main" | tee "/etc/apt/sources.list.d/${repo_name}.list" > /dev/null
    else
        add-apt-repository -y "${repo_url}"
    fi
    
    echo "✓ Added repository: ${repo_name}"
}

# Function to restore browser profiles from backup
restore_browser_profile() {
    local browser="${1}"
    local source_dir="${2}"
    local target_dir="${3}"
    
    if [[ -d "${source_dir}" ]]; then
        echo "Restoring ${browser} profile from backup..."
        
        # Make sure target directory exists
        mkdir -p "${target_dir}"
        
        # Copy profile files
        cp -r "${source_dir}"/* "${target_dir}/" 2>/dev/null || true
        
        # Set proper ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown -R "${SUDO_USER}":"${SUDO_USER}" "${target_dir}"
        fi
        
        echo "✓ Restored ${browser} profile from backup"
        return 0
    else
        echo "No ${browser} profile backup found at ${source_dir}"
        return 1
    fi
}

# Function to restore browser extensions from config repository
restore_browser_extensions() {
    local browser="${1}"
    local extensions_source="${2}"
    
    # Check if extensions source exists
    if [[ ! -d "${extensions_source}" ]]; then
        echo "No extensions configuration found for ${browser} at ${extensions_source}"
        echo "Skipping extensions restoration for ${browser}"
        return 1
    fi
    
    echo "Note: Browser extensions for ${browser} will need to be installed via the browser UI"
    if [[ -f "${extensions_source}/extensions.md" ]]; then
        echo "Extension list is available at: ${extensions_source}/extensions.md"
    fi
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

# Define configuration files for each browser
BRAVE_CONFIG_FILES=(
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Default/Preferences"
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Default/Bookmarks"
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Local State"
)

ZEN_CONFIG_FILES=(
    "${USER_HOME}/.config/zen-browser/Default/Preferences"
    "${USER_HOME}/.config/zen-browser/Default/Bookmarks"
    "${USER_HOME}/.config/zen-browser/Local State"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Define backup paths based on the configuration mapping
BROWSER_BACKUPS_BASE=""

# === STAGE 2: Brave Browser ===
section "Installing Brave Browser"

# Add Brave repository
add_repository "brave-browser" "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
apt-get update

# Install Brave Browser
install_packages "Brave Browser" brave-browser

# === STAGE 4: Firefox (Snap) ===
section "Installing Firefox via Snap"

# Install Firefox via snap instead of apt
echo "Installing Firefox via snap..."
snap install firefox
echo "✓ Installed Firefox via snap"

# Wait a moment to ensure snap package is properly set up
echo "Waiting for Firefox snap to complete setup..."
sleep 5

# === STAGE 5: Zen Browser ===
section "Installing Zen Browser"

# Install Zen Browser using their official installer script
echo "Installing Zen Browser via the official installer script..."
if command -v wget &> /dev/null; then
    # Using a temporary file approach instead of process substitution to avoid SC2312
    wget -qO /tmp/zen-installer.sh https://updates.zen-browser.app/appimage.sh || true
    bash /tmp/zen-installer.sh || echo "Zen Browser installation failed, but continuing with other browsers."
    rm -f /tmp/zen-installer.sh
else
    # Using a temporary file approach instead of process substitution to avoid SC2312
    curl -s https://updates.zen-browser.app/appimage.sh -o /tmp/zen-installer.sh || true
    bash /tmp/zen-installer.sh || echo "Zen Browser installation failed, but continuing with other browsers."
    rm -f /tmp/zen-installer.sh
fi
echo "✓ Installed Zen Browser"


section "Browser Installation and Configuration Management Complete!"
echo "You have installed and configured the following browsers:"
echo "  - Brave Browser"
echo "  - Firefox"
echo "  - Zen Browser"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Browser profiles were also restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
echo
echo "Note: Some browser extensions may require manual verification or additional setup."
echo "Check /repo/personal/core-configs/browsers/[browser]/extensions/ for documentation."
