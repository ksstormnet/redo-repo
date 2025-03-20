#!/bin/bash

# 09-browsers-setup.sh
# This script installs web browsers and browser-related tools
# Part of the sequential Ubuntu Server to KDE conversion process
# Enhanced with profile management from configuration repository

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

# Function to restore browser extensions from config repository
restore_browser_extensions() {
    local browser="${1}"
    local extensions_source="/repo/personal/core-configs/browsers/${browser}/extensions"
    
    # Check if extensions source exists
    if [[ ! -d "${extensions_source}" ]]; then
        echo "No extensions configuration found for ${browser} at ${extensions_source}"
        echo "Skipping extensions restoration for ${browser}"
        return 1
    fi
    
    echo "Note: Browser extensions for ${browser} will need to be installed via the browser UI"
    echo "Extension list is available at: ${extensions_source}/extensions.md"
    
    # For Firefox, we can potentially auto-install extensions, but for other browsers, 
    # we mainly need to provide documentation
    if [[ "${browser}" = "firefox" ]] && [[ -f "${extensions_source}/install-extensions.sh" ]]; then
        echo "Firefox extensions installer script found, executing..."
        chmod +x "${extensions_source}/install-extensions.sh"
        if [[ "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" "${extensions_source}/install-extensions.sh"
        else
            "${extensions_source}/install-extensions.sh"
        fi
    fi
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

# Define configuration files for each browser
BRAVE_CONFIG_FILES=(
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Default/Preferences"
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Default/Bookmarks"
    "${USER_HOME}/.config/BraveSoftware/Brave-Browser/Local State"
)

EDGE_CONFIG_FILES=(
    "${USER_HOME}/.config/microsoft-edge/Default/Preferences"
    "${USER_HOME}/.config/microsoft-edge/Default/Bookmarks"
    "${USER_HOME}/.config/microsoft-edge/Local State"
)

FIREFOX_CONFIG_FILES=(
    "${USER_HOME}/snap/firefox/common/.mozilla/firefox/profiles.ini"
    "${USER_HOME}/snap/firefox/common/.mozilla/firefox/*/prefs.js"
    "${USER_HOME}/snap/firefox/common/.mozilla/firefox/*/user.js"
    "${USER_HOME}/snap/firefox/common/.mozilla/firefox/*/bookmarks.html"
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

# Set up pre-installation configurations for browsers
handle_pre_installation_config "brave" "${BRAVE_CONFIG_FILES[@]}"
handle_pre_installation_config "edge" "${EDGE_CONFIG_FILES[@]}"
handle_pre_installation_config "firefox" "${FIREFOX_CONFIG_FILES[@]}"
handle_pre_installation_config "zen" "${ZEN_CONFIG_FILES[@]}"

# === STAGE 2: Brave Browser ===
section "Installing Brave Browser"

# Add Brave repository
add_repository "brave-browser" "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
apt-get update

# Install Brave Browser
install_packages "Brave Browser" brave-browser

# Handle Brave Browser configuration
section "Managing Brave Browser Configuration"
handle_installed_software_config "brave" "${BRAVE_CONFIG_FILES[@]}"
restore_browser_extensions "brave"

# === STAGE 3: Microsoft Edge ===
section "Installing Microsoft Edge"

# Add Microsoft Edge repository
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
apt-get update

# Install Microsoft Edge
install_packages "Microsoft Edge" microsoft-edge-stable

# Handle Microsoft Edge configuration
section "Managing Microsoft Edge Configuration"
handle_installed_software_config "edge" "${EDGE_CONFIG_FILES[@]}"
restore_browser_extensions "edge"

# === STAGE 4: Firefox (Snap) ===
section "Installing Firefox via Snap"

# Install Firefox via snap instead of apt
echo "Installing Firefox via snap..."
snap install firefox
echo "✓ Installed Firefox via snap"

# Wait a moment to ensure snap package is properly set up
echo "Waiting for Firefox snap to complete setup..."
sleep 5

# Handle Firefox configuration
section "Managing Firefox Configuration"
handle_installed_software_config "firefox" "${FIREFOX_CONFIG_FILES[@]}"
restore_browser_extensions "firefox"

# === STAGE 5: Zen Browser ===
section "Installing Zen Browser"

# Install Zen Browser using their official installer script
echo "Installing Zen Browser via the official installer script..."
bash <(curl https://updates.zen-browser.app/appimage.sh)
echo "✓ Installed Zen Browser"

# Handle Zen Browser configuration
section "Managing Zen Browser Configuration"
handle_installed_software_config "zen" "${ZEN_CONFIG_FILES[@]}"
restore_browser_extensions "zen"

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "brave" "${BRAVE_CONFIG_FILES[@]}"
check_post_installation_configs "edge" "${EDGE_CONFIG_FILES[@]}"
check_post_installation_configs "firefox" "${FIREFOX_CONFIG_FILES[@]}"
check_post_installation_configs "zen" "${ZEN_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "Browser Installation and Configuration Management Complete!"
echo "You have installed and configured the following browsers:"
echo "  - Brave Browser (with managed configuration)"
echo "  - Microsoft Edge (with managed configuration)"
echo "  - Firefox (with managed configuration)" 
echo "  - Zen Browser (with managed configuration)"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "Note: Some browser extensions may require manual verification or additional setup."
echo "Check /repo/personal/core-configs/browsers/[browser]/extensions/ for documentation."
