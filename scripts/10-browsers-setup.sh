#!/bin/bash

# 10-browsers-setup.sh
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
    
    # For Firefox, we can potentially auto-install extensions, but for other browsers, 
    # we mainly need to provide documentation
    if [[ "${browser}" = "firefox" ]] && [[ -f "${extensions_source}/install-extensions.sh" ]]; then
        echo "Firefox extensions installer script found, executing..."
        chmod +x "${extensions_source}/install-extensions.sh"
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" "${extensions_source}/install-extensions.sh"
        else
            "${extensions_source}/install-extensions.sh"
        fi
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

# Define backup paths based on the configuration mapping
BROWSER_BACKUPS_BASE=""

# Check if we have backup configs from general configs path
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    if [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.config" ]]; then
        BROWSER_BACKUPS_BASE="${GENERAL_CONFIGS_PATH}/config_files/.config"
    elif [[ -d "${GENERAL_CONFIGS_PATH}/config_files/browsers" ]]; then
        BROWSER_BACKUPS_BASE="${GENERAL_CONFIGS_PATH}/config_files/browsers"
    fi
fi

# If no general configs path, try other locations
if [[ -z "${BROWSER_BACKUPS_BASE}" ]] && [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for browser directories in various potential locations
    for potential_dir in \
        "${BACKUP_CONFIGS_PATH}/configs/browsers" \
        "${BACKUP_CONFIGS_PATH}/browsers" \
        "${BACKUP_CONFIGS_PATH}/configs/config_files/.config"; do
        if [[ -d "${potential_dir}" ]]; then
            BROWSER_BACKUPS_BASE="${potential_dir}"
            break
        fi
    done
fi

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

# Define Brave profile paths
BRAVE_PROFILE_DIR="${USER_HOME}/.config/BraveSoftware/Brave-Browser"
BRAVE_BACKUP_DIR=""

# Look for Brave backup in various locations
if [[ -n "${BROWSER_BACKUPS_BASE}" ]]; then
    # Check different potential locations
    for potential_dir in \
        "${BROWSER_BACKUPS_BASE}/BraveSoftware/Brave-Browser" \
        "${BROWSER_BACKUPS_BASE}/brave" \
        "${BACKUP_CONFIGS_PATH}/browsers/brave"; do
        if [[ -d "${potential_dir}" ]]; then
            BRAVE_BACKUP_DIR="${potential_dir}"
            break
        fi
    done
fi

# Handle Brave Browser configuration
section "Managing Brave Browser Configuration"

# Create necessary directories
mkdir -p "${BRAVE_PROFILE_DIR}/Default"

# Restore Brave profile from backup if available
if [[ -n "${BRAVE_BACKUP_DIR}" ]]; then
    restore_browser_profile "Brave Browser" "${BRAVE_BACKUP_DIR}" "${BRAVE_PROFILE_DIR}"
fi

# Restore browser extensions
if [[ -n "${BRAVE_BACKUP_DIR}" ]] || [[ -d "/repo/personal/core-configs/browsers/brave/extensions" ]]; then
    # Determine extensions source directory
    EXTENSIONS_SOURCE=""
    if [[ -d "/repo/personal/core-configs/browsers/brave/extensions" ]]; then
        EXTENSIONS_SOURCE="/repo/personal/core-configs/browsers/brave/extensions"
    elif [[ -d "${BACKUP_CONFIGS_PATH}/browsers/brave/extensions" ]]; then
        EXTENSIONS_SOURCE="${BACKUP_CONFIGS_PATH}/browsers/brave/extensions"
    fi
    
    if [[ -n "${EXTENSIONS_SOURCE}" ]]; then
        restore_browser_extensions "brave" "${EXTENSIONS_SOURCE}"
    fi
fi

# Handle configuration files
handle_installed_software_config "brave" "${BRAVE_CONFIG_FILES[@]}"

# === STAGE 3: Microsoft Edge ===
section "Installing Microsoft Edge"

# Add Microsoft Edge repository
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg || true
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
apt-get update

# Install Microsoft Edge
install_packages "Microsoft Edge" microsoft-edge-stable

# Define Edge profile paths
EDGE_PROFILE_DIR="${USER_HOME}/.config/microsoft-edge"
EDGE_BACKUP_DIR=""

# Look for Edge backup in various locations
if [[ -n "${BROWSER_BACKUPS_BASE}" ]]; then
    # Check different potential locations
    for potential_dir in \
        "${BROWSER_BACKUPS_BASE}/microsoft-edge" \
        "${BROWSER_BACKUPS_BASE}/edge" \
        "${BACKUP_CONFIGS_PATH}/browsers/edge"; do
        if [[ -d "${potential_dir}" ]]; then
            EDGE_BACKUP_DIR="${potential_dir}"
            break
        fi
    done
fi

# Handle Microsoft Edge configuration
section "Managing Microsoft Edge Configuration"

# Create necessary directories
mkdir -p "${EDGE_PROFILE_DIR}/Default"

# Restore Edge profile from backup if available
if [[ -n "${EDGE_BACKUP_DIR}" ]]; then
    restore_browser_profile "Microsoft Edge" "${EDGE_BACKUP_DIR}" "${EDGE_PROFILE_DIR}"
fi

# Restore browser extensions
if [[ -n "${EDGE_BACKUP_DIR}" ]] || [[ -d "/repo/personal/core-configs/browsers/edge/extensions" ]]; then
    # Determine extensions source directory
    EXTENSIONS_SOURCE=""
    if [[ -d "/repo/personal/core-configs/browsers/edge/extensions" ]]; then
        EXTENSIONS_SOURCE="/repo/personal/core-configs/browsers/edge/extensions"
    elif [[ -d "${BACKUP_CONFIGS_PATH}/browsers/edge/extensions" ]]; then
        EXTENSIONS_SOURCE="${BACKUP_CONFIGS_PATH}/browsers/edge/extensions"
    fi
    
    if [[ -n "${EXTENSIONS_SOURCE}" ]]; then
        restore_browser_extensions "edge" "${EXTENSIONS_SOURCE}"
    fi
fi

# Handle configuration files
handle_installed_software_config "edge" "${EDGE_CONFIG_FILES[@]}"

# === STAGE 4: Firefox (Snap) ===
section "Installing Firefox via Snap"

# Install Firefox via snap instead of apt
echo "Installing Firefox via snap..."
snap install firefox
echo "✓ Installed Firefox via snap"

# Wait a moment to ensure snap package is properly set up
echo "Waiting for Firefox snap to complete setup..."
sleep 5

# Define Firefox profile paths
FIREFOX_PROFILE_BASE="${USER_HOME}/snap/firefox/common/.mozilla/firefox"
FIREFOX_BACKUP_DIR=""

# Look for Firefox backup in various locations
if [[ -n "${BROWSER_BACKUPS_BASE}" ]]; then
    # Check different potential locations
    for potential_dir in \
        "${BROWSER_BACKUPS_BASE}/.mozilla/firefox" \
        "${BROWSER_BACKUPS_BASE}/firefox" \
        "${BACKUP_CONFIGS_PATH}/browsers/firefox"; do
        if [[ -d "${potential_dir}" ]]; then
            FIREFOX_BACKUP_DIR="${potential_dir}"
            break
        fi
    done
fi

# Handle Firefox configuration
section "Managing Firefox Configuration"

# Create necessary directories
mkdir -p "${FIREFOX_PROFILE_BASE}"

# Restore Firefox profile from backup if available
if [[ -n "${FIREFOX_BACKUP_DIR}" ]]; then
    restore_browser_profile "Firefox" "${FIREFOX_BACKUP_DIR}" "${FIREFOX_PROFILE_BASE}"
fi

# Restore browser extensions
if [[ -n "${FIREFOX_BACKUP_DIR}" ]] || [[ -d "/repo/personal/core-configs/browsers/firefox/extensions" ]]; then
    # Determine extensions source directory
    EXTENSIONS_SOURCE=""
    if [[ -d "/repo/personal/core-configs/browsers/firefox/extensions" ]]; then
        EXTENSIONS_SOURCE="/repo/personal/core-configs/browsers/firefox/extensions"
    elif [[ -d "${BACKUP_CONFIGS_PATH}/browsers/firefox/extensions" ]]; then
        EXTENSIONS_SOURCE="${BACKUP_CONFIGS_PATH}/browsers/firefox/extensions"
    fi
    
    if [[ -n "${EXTENSIONS_SOURCE}" ]]; then
        restore_browser_extensions "firefox" "${EXTENSIONS_SOURCE}"
    fi
fi

# Handle configuration files
handle_installed_software_config "firefox" "${FIREFOX_CONFIG_FILES[@]}"

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
echo "✓ Attempted to install Zen Browser"

# Define Zen profile paths
ZEN_PROFILE_DIR="${USER_HOME}/.config/zen-browser"
ZEN_BACKUP_DIR=""

# Look for Zen backup in various locations
if [[ -n "${BROWSER_BACKUPS_BASE}" ]]; then
    # Check different potential locations
    for potential_dir in \
        "${BROWSER_BACKUPS_BASE}/zen-browser" \
        "${BROWSER_BACKUPS_BASE}/zen" \
        "${BACKUP_CONFIGS_PATH}/browsers/zen"; do
        if [[ -d "${potential_dir}" ]]; then
            ZEN_BACKUP_DIR="${potential_dir}"
            break
        fi
    done
fi

# Handle Zen Browser configuration
section "Managing Zen Browser Configuration"

# Create necessary directories if Zen Browser was successfully installed
if [[ -e "/usr/local/bin/zen-browser" ]] || [[ -e "${USER_HOME}/Applications/zen-browser" ]]; then
    mkdir -p "${ZEN_PROFILE_DIR}/Default"
    
    # Restore Zen profile from backup if available
    if [[ -n "${ZEN_BACKUP_DIR}" ]]; then
        restore_browser_profile "Zen Browser" "${ZEN_BACKUP_DIR}" "${ZEN_PROFILE_DIR}"
    fi
    
    # Restore browser extensions
    if [[ -n "${ZEN_BACKUP_DIR}" ]] || [[ -d "/repo/personal/core-configs/browsers/zen/extensions" ]]; then
        # Determine extensions source directory
        EXTENSIONS_SOURCE=""
        if [[ -d "/repo/personal/core-configs/browsers/zen/extensions" ]]; then
            EXTENSIONS_SOURCE="/repo/personal/core-configs/browsers/zen/extensions"
        elif [[ -d "${BACKUP_CONFIGS_PATH}/browsers/zen/extensions" ]]; then
            EXTENSIONS_SOURCE="${BACKUP_CONFIGS_PATH}/browsers/zen/extensions"
        fi
        
        if [[ -n "${EXTENSIONS_SOURCE}" ]]; then
            restore_browser_extensions "zen" "${EXTENSIONS_SOURCE}"
        fi
    fi
    
    # Handle configuration files
    handle_installed_software_config "zen" "${ZEN_CONFIG_FILES[@]}"
fi

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "brave" "${BRAVE_CONFIG_FILES[@]}"
check_post_installation_configs "edge" "${EDGE_CONFIG_FILES[@]}"
check_post_installation_configs "firefox" "${FIREFOX_CONFIG_FILES[@]}"
check_post_installation_configs "zen" "${ZEN_CONFIG_FILES[@]}"

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
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Browser profiles were also restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
echo
echo "Note: Some browser extensions may require manual verification or additional setup."
echo "Check /repo/personal/core-configs/browsers/[browser]/extensions/ for documentation."
