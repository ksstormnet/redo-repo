#!/bin/bash

# 09-specialized-software.sh
# This script installs specialized software for various tasks and manages configurations
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

# Determine which user to set configs for
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define configuration files for each software category
AUDACITY_CONFIG_FILES=(
    "${USER_HOME}/.config/audacity/audacity.cfg"
)

VLC_CONFIG_FILES=(
    "${USER_HOME}/.config/vlc/vlcrc"
)

VIRTUALBOX_CONFIG_FILES=(
    "${USER_HOME}/.config/VirtualBox/VirtualBox.xml"
)

PINTA_CONFIG_FILES=(
    "${USER_HOME}/.config/pinta/settings.xml"
)

DARKTABLE_CONFIG_FILES=(
    "${USER_HOME}/.config/darktable/darktablerc"
)

CALIBRE_CONFIG_FILES=(
    "${USER_HOME}/.config/calibre/global.py"
    "${USER_HOME}/.config/calibre/preferences.py"
)

OKULAR_CONFIG_FILES=(
    "${USER_HOME}/.config/okularrc"
)

GWENVIEW_CONFIG_FILES=(
    "${USER_HOME}/.config/gwenviewrc"
)

GHOSTWRITER_CONFIG_FILES=(
    "${USER_HOME}/.config/ghostwriter/ghostwriter.conf"
)

FILEZILLA_CONFIG_FILES=(
    "${USER_HOME}/.config/filezilla/filezilla.xml"
)

REMMINA_CONFIG_FILES=(
    "${USER_HOME}/.config/remmina/remmina.pref"
)

ZOOM_CONFIG_FILES=(
    "${USER_HOME}/.config/zoomus.conf"
)

SLACK_CONFIG_FILES=(
    "${USER_HOME}/.config/Slack/config"
)

TERMIUS_CONFIG_FILES=(
    "${USER_HOME}/.config/Termius/config.yaml"
    "${USER_HOME}/.config/Termius/keychain.yaml"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Define backup paths based on the configuration mapping
CONFIG_BACKUPS_BASE=""

# Check if we have backup configs from general configs path
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    if [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.config" ]]; then
        CONFIG_BACKUPS_BASE="${GENERAL_CONFIGS_PATH}/config_files/.config"
    fi
fi

# If no general configs path, try other locations
if [[ -z "${CONFIG_BACKUPS_BASE}" ]] && [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for config directories in various potential locations
    for potential_dir in \
        "${BACKUP_CONFIGS_PATH}/configs/config_files/.config" \
        "${BACKUP_CONFIGS_PATH}/config_files/.config" \
        "${BACKUP_CONFIGS_PATH}/home_configs/.config"; do
        if [[ -d "${potential_dir}" ]]; then
            CONFIG_BACKUPS_BASE="${potential_dir}"
            break
        fi
    done
fi

# Set up pre-installation configurations for software
handle_pre_installation_config "audacity" "${AUDACITY_CONFIG_FILES[@]}"
handle_pre_installation_config "vlc" "${VLC_CONFIG_FILES[@]}"
handle_pre_installation_config "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"
handle_pre_installation_config "pinta" "${PINTA_CONFIG_FILES[@]}"
handle_pre_installation_config "darktable" "${DARKTABLE_CONFIG_FILES[@]}"
handle_pre_installation_config "calibre" "${CALIBRE_CONFIG_FILES[@]}"
handle_pre_installation_config "okular" "${OKULAR_CONFIG_FILES[@]}"
handle_pre_installation_config "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
handle_pre_installation_config "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"
handle_pre_installation_config "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
handle_pre_installation_config "remmina" "${REMMINA_CONFIG_FILES[@]}"
handle_pre_installation_config "zoom" "${ZOOM_CONFIG_FILES[@]}"
handle_pre_installation_config "slack" "${SLACK_CONFIG_FILES[@]}"
handle_pre_installation_config "termius" "${TERMIUS_CONFIG_FILES[@]}"

# === STAGE 2: Audio Production Software ===
section "Installing Audio Production Software"

# Install audio production software
install_packages "Audio Production" \
    audacity \
    jack-tools \
    vlc

# Create directories for configs
mkdir -p "${USER_HOME}/.config/audacity"
mkdir -p "${USER_HOME}/.config/vlc"

# Restore Audacity configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/audacity" ]]; then
    restore_config "Audacity" "${CONFIG_BACKUPS_BASE}/audacity" "${USER_HOME}/.config/audacity"
fi

# Restore VLC configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/vlc" ]]; then
    restore_config "VLC" "${CONFIG_BACKUPS_BASE}/vlc" "${USER_HOME}/.config/vlc"
fi

# Check for custom Audacity configuration script
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    AUDACITY_SCRIPT=$(find "${BACKUP_CONFIGS_PATH}" -name "*audacity*" -type f -executable | head -n 1) || true
    if [[ -n "${AUDACITY_SCRIPT}" ]]; then
        echo "Found custom Audacity configuration script: ${AUDACITY_SCRIPT}"
        echo "Running script to apply specialized Audacity settings..."
        bash "${AUDACITY_SCRIPT}"
        echo "✓ Applied custom Audacity settings"
    fi
fi

# Handle configuration files
handle_installed_software_config "audacity" "${AUDACITY_CONFIG_FILES[@]}"
handle_installed_software_config "vlc" "${VLC_CONFIG_FILES[@]}"

# === STAGE 3: Virtualization Software ===
section "Installing Virtualization Software"

# Install VirtualBox
install_packages "Virtualization" \
    virtualbox \
    virtualbox-qt \
    virtualbox-dkms

# Create directories for configs
mkdir -p "${USER_HOME}/.config/VirtualBox"

# Restore VirtualBox configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/VirtualBox" ]]; then
    restore_config "VirtualBox" "${CONFIG_BACKUPS_BASE}/VirtualBox" "${USER_HOME}/.config/VirtualBox"
fi

# Check for VirtualBox configuration and audio bridge scripts
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    VBOX_SCRIPT=$(find "${BACKUP_CONFIGS_PATH}" -name "*virtualbox*" -type f -executable | head -n 1) || true
    if [[ -n "${VBOX_SCRIPT}" ]]; then
        echo "Found VirtualBox audio bridge script: ${VBOX_SCRIPT}"
        echo "Copying script to /usr/local/bin for later use..."
        cp "${VBOX_SCRIPT}" /usr/local/bin/virtualbox-audio-bridge.sh
        chmod +x /usr/local/bin/virtualbox-audio-bridge.sh
        echo "✓ Installed VirtualBox audio bridge script"
    fi
fi

# Handle configuration files
handle_installed_software_config "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"

# === STAGE 4: Graphics and Design ===
section "Installing Graphics and Design Tools"

# Install graphics and design tools
install_packages "Graphics & Design" \
    darktable

# Install Pinta via snap instead of apt
echo "Installing Pinta via snap..."
snap install pinta
echo "✓ Installed Pinta via snap"

# Create directories for configs
mkdir -p "${USER_HOME}/.config/pinta"
mkdir -p "${USER_HOME}/.config/darktable"

# Restore Pinta configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/pinta" ]]; then
    restore_config "Pinta" "${CONFIG_BACKUPS_BASE}/pinta" "${USER_HOME}/.config/pinta"
fi

# Restore Darktable configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/darktable" ]]; then
    restore_config "Darktable" "${CONFIG_BACKUPS_BASE}/darktable" "${USER_HOME}/.config/darktable"
fi

# Handle configuration files
handle_installed_software_config "pinta" "${PINTA_CONFIG_FILES[@]}"
handle_installed_software_config "darktable" "${DARKTABLE_CONFIG_FILES[@]}"

# === STAGE 5: Office and Productivity ===
section "Installing Office and Productivity Tools"

# Install office and productivity tools
install_packages "Office & Productivity" \
    calibre \
    okular \
    gwenview \
    ghostwriter

# Create directories for configs
mkdir -p "${USER_HOME}/.config/calibre"
mkdir -p "${USER_HOME}/.config/ghostwriter"

# Restore Calibre configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/calibre" ]]; then
    restore_config "Calibre" "${CONFIG_BACKUPS_BASE}/calibre" "${USER_HOME}/.config/calibre"
fi

# Restore Okular configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -f "${CONFIG_BACKUPS_BASE}/okularrc" ]]; then
    cp "${CONFIG_BACKUPS_BASE}/okularrc" "${USER_HOME}/.config/"
    echo "✓ Restored Okular configuration from backup"
    
    # Set proper ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/okularrc"
    fi
fi

# Restore Gwenview configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -f "${CONFIG_BACKUPS_BASE}/gwenviewrc" ]]; then
    cp "${CONFIG_BACKUPS_BASE}/gwenviewrc" "${USER_HOME}/.config/"
    echo "✓ Restored Gwenview configuration from backup"
    
    # Set proper ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/gwenviewrc"
    fi
fi

# Restore Ghostwriter configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/ghostwriter" ]]; then
    restore_config "Ghostwriter" "${CONFIG_BACKUPS_BASE}/ghostwriter" "${USER_HOME}/.config/ghostwriter"
fi

# Handle configuration files
handle_installed_software_config "calibre" "${CALIBRE_CONFIG_FILES[@]}"
handle_installed_software_config "okular" "${OKULAR_CONFIG_FILES[@]}"
handle_installed_software_config "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
handle_installed_software_config "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"

# === STAGE 6: Web and Network Tools ===
section "Installing Web and Network Tools"

# Install web and network tools
install_packages "Web and Network Tools" \
    filezilla \
    remmina

# Create directories for configs
mkdir -p "${USER_HOME}/.config/filezilla"
mkdir -p "${USER_HOME}/.config/remmina"

# Restore FileZilla configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/filezilla" ]]; then
    restore_config "FileZilla" "${CONFIG_BACKUPS_BASE}/filezilla" "${USER_HOME}/.config/filezilla"
fi

# Restore Remmina configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/remmina" ]]; then
    restore_config "Remmina" "${CONFIG_BACKUPS_BASE}/remmina" "${USER_HOME}/.config/remmina"
fi

# Install Termius
echo "Installing Termius..."
if [[ -f /tmp/termius.deb ]]; then
    rm /tmp/termius.deb
fi
wget https://www.termius.com/download/linux/Termius.deb -O /tmp/termius.deb
dpkg -i /tmp/termius.deb || apt-get install -f -y
rm /tmp/termius.deb
echo "✓ Installed Termius"

# Create directory for Termius config
mkdir -p "${USER_HOME}/.config/Termius"

# Restore Termius configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/Termius" ]]; then
    restore_config "Termius" "${CONFIG_BACKUPS_BASE}/Termius" "${USER_HOME}/.config/Termius"
fi

# Handle configuration files
handle_installed_software_config "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
handle_installed_software_config "remmina" "${REMMINA_CONFIG_FILES[@]}"
handle_installed_software_config "termius" "${TERMIUS_CONFIG_FILES[@]}"

# === STAGE 7: Communication Tools ===
section "Installing Communication Tools"

# Install Zoom
echo "Installing Zoom..."
if [[ -f /tmp/zoom_amd64.deb ]]; then
    rm /tmp/zoom_amd64.deb
fi
wget https://zoom.us/client/latest/zoom_amd64.deb -O /tmp/zoom_amd64.deb
dpkg -i /tmp/zoom_amd64.deb || true
apt-get install -f -y
rm /tmp/zoom_amd64.deb
echo "✓ Installed Zoom"

# Install Zoiper5
echo "Installing Zoiper5..."
if [[ -f /tmp/zoiper5.deb ]]; then
    rm /tmp/zoiper5.deb
fi
wget https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb -O /tmp/zoiper5.deb
dpkg -i /tmp/zoiper5.deb || true
apt-get install -f -y
rm /tmp/zoiper5.deb
echo "✓ Installed Zoiper5"

# Install Slack via snap
echo "Installing Slack via snap..."
snap install slack
echo "✓ Installed Slack via snap"

# Create directories for configs
mkdir -p "${USER_HOME}/.config/zoomus"
mkdir -p "${USER_HOME}/.config/Slack"

# Restore Zoom configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -f "${CONFIG_BACKUPS_BASE}/zoomus.conf" ]]; then
    cp "${CONFIG_BACKUPS_BASE}/zoomus.conf" "${USER_HOME}/.config/"
    echo "✓ Restored Zoom configuration from backup"
    
    # Set proper ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/zoomus.conf"
    fi
fi

# Restore Slack configuration from backup if available
if [[ -n "${CONFIG_BACKUPS_BASE}" ]] && [[ -d "${CONFIG_BACKUPS_BASE}/Slack" ]]; then
    restore_config "Slack" "${CONFIG_BACKUPS_BASE}/Slack" "${USER_HOME}/.config/Slack"
fi

# Handle configuration files
handle_installed_software_config "zoom" "${ZOOM_CONFIG_FILES[@]}"
handle_installed_software_config "slack" "${SLACK_CONFIG_FILES[@]}"

# === STAGE 8: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "audacity" "${AUDACITY_CONFIG_FILES[@]}"
check_post_installation_configs "vlc" "${VLC_CONFIG_FILES[@]}"
check_post_installation_configs "virtualbox" "${VIRTUALBOX_CONFIG_FILES[@]}"
check_post_installation_configs "pinta" "${PINTA_CONFIG_FILES[@]}"
check_post_installation_configs "darktable" "${DARKTABLE_CONFIG_FILES[@]}"
check_post_installation_configs "calibre" "${CALIBRE_CONFIG_FILES[@]}"
check_post_installation_configs "okular" "${OKULAR_CONFIG_FILES[@]}"
check_post_installation_configs "gwenview" "${GWENVIEW_CONFIG_FILES[@]}"
check_post_installation_configs "ghostwriter" "${GHOSTWRITER_CONFIG_FILES[@]}"
check_post_installation_configs "filezilla" "${FILEZILLA_CONFIG_FILES[@]}"
check_post_installation_configs "remmina" "${REMMINA_CONFIG_FILES[@]}"
check_post_installation_configs "zoom" "${ZOOM_CONFIG_FILES[@]}"
check_post_installation_configs "slack" "${SLACK_CONFIG_FILES[@]}"
check_post_installation_configs "termius" "${TERMIUS_CONFIG_FILES[@]}"

section "Specialized Software Installation Complete!"
echo "You have installed specialized software for the following categories:"
echo "  - Audio Production (Audacity, VLC, etc.)"
echo "  - Virtualization (VirtualBox)"
echo "  - Graphics & Design (Pinta, Darktable, etc.)"
echo "  - Office & Productivity (Calibre, Okular, Gwenview, Ghostwriter, etc.)"
echo "  - Web & Network Tools (FileZilla, Remmina, Termius)"
echo "  - Communication Tools (Zoom, Zoiper5, Slack)"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo 
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Configurations were also restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
