#!/bin/bash

# 16-final-cleanup.sh
# This script performs final system cleanup and optimization
# Part of the sequential Ubuntu Server to KDE conversion process
# Modified to protect symlinked configurations from /repo/personal/core-configs/
# And to reference restored configurations from /restart/critical_backups/

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

# Function to safely clean directories without removing symlinks
safe_clean_directory() {
    local dir="${1}"
    local description="${2}"
    
    if [[ -d "${dir}" ]]; then
        echo "Safely cleaning ${description} at ${dir}..."
        # Find and remove only regular files, preserving symlinks
        find "${dir}" -type f -not -path "*/\.*" -mtime +30 -delete 2>/dev/null || true
        echo "✓ Cleaned ${description} (preserving symlinks)"
    fi
}

# Function to check if a path is a symlink to core-configs
is_core_config_symlink() {
    local path="${1}"
    
    if [[ -L "${path}" ]]; then
        local link_target
        link_target=$(readlink "${path}") || true
        if [[ "${link_target}" == "/repo/personal/core-configs/"* ]]; then
            return 0  # True, it is a core-configs symlink
        fi
    fi
    return 1  # False, not a core-configs symlink
}

# Function to safely clean a file without removing core-configs symlinks
safe_clean_file() {
    local file="${1}"
    local is_symlink
    
    # Check if it's a core-configs symlink separately to avoid SC2310
    is_symlink=0
    # Run the function separately to avoid SC2310
    # Store the result in a variable to avoid SC2310
    local result
    # Temporarily disable set -e
    set +e
    is_core_config_symlink "${file}"
    result=$?
    # Re-enable set -e
    set -e
    if [[ ${result} -eq 0 ]]; then
        is_symlink=1
    fi
    
    if [[ -f "${file}" ]] && [[ ${is_symlink} -eq 0 ]]; then
        rm -f "${file}"
        echo "✓ Removed: ${file}"
    elif [[ ${is_symlink} -eq 1 ]]; then
        echo "✓ Preserved core-configs symlink: ${file}"
    fi
}

# Check for restored configurations
RESTORED_CONFIGS="/restart/critical_backups/config_mapping.txt"

if [[ -f "${RESTORED_CONFIGS}" ]]; then
    echo "Found restored configuration mapping file"
    # shellcheck disable=SC1090
    source "${RESTORED_CONFIGS}"
    
    if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
        echo "Using restored configurations from ${GENERAL_CONFIGS_PATH}"
    fi
fi

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

# Define configuration files for summary documents
SUMMARY_FILES=(
    "${USER_HOME}/kde-setup-summary.md"
    "${USER_HOME}/symlinked-configurations.md"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for summary documents
handle_pre_installation_config "summary-docs" "${SUMMARY_FILES[@]}"

# === STAGE 2: Remove Unnecessary Packages ===
section "Removing Unnecessary Packages"

# Clean up unnecessary dependencies
apt-get autoremove -y
echo "✓ Removed unnecessary dependencies"

# Clean apt cache
apt-get clean
echo "✓ Cleaned package cache"

# === STAGE 3: System Optimization ===
section "Optimizing System"

# Install additional cleanup tools
install_packages "Cleanup Tools" \
    bleachbit \
    localepurge

# Clean up system journal
journalctl --vacuum-time=7d
echo "✓ Cleaned up system journal"

# Clean up temporary directories without affecting symlinks
section "Safely Cleaning Temporary Files"

# Check for and protect core-configs symlinks
echo "Checking for symlinked configurations before cleanup..."
SYMLINK_COUNT=0
CORE_CONFIG_SYMLINK_COUNT=0

while IFS= read -r symlink; do
    SYMLINK_COUNT=$((SYMLINK_COUNT + 1))
    link_target=$(readlink "${symlink}") || true
    if [[ "${link_target}" == "/repo/personal/core-configs/"* ]]; then
        CORE_CONFIG_SYMLINK_COUNT=$((CORE_CONFIG_SYMLINK_COUNT + 1))
        echo "Protected: ${symlink} -> ${link_target}"
    fi
done < <(find "${USER_HOME}" -type l 2>/dev/null || true)

echo "Found ${SYMLINK_COUNT} total symlinks, including ${CORE_CONFIG_SYMLINK_COUNT} from core-configs"

# Safely clean thumbnail cache
safe_clean_directory "${USER_HOME}/.cache/thumbnails" "thumbnail cache"

# Clean other caches while preserving symlinks
safe_clean_directory "${USER_HOME}/.cache/mozilla" "Mozilla cache"
safe_clean_directory "${USER_HOME}/.cache/chromium" "Chromium cache"
safe_clean_directory "${USER_HOME}/.cache/google-chrome" "Chrome cache"

# Clean up old log files but preserve symlinks
find "${USER_HOME}/.local/share/xorg" -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true
echo "✓ Cleaned up old log files"

# === STAGE 4: System Update ===
section "Performing Final System Update"

# Update package lists one more time
apt-get update

# Upgrade all packages
apt-get upgrade -y
echo "✓ Upgraded all packages"

# Update locate database
updatedb
echo "✓ Updated locate database"

# === STAGE 5: Create Final Setup Summary ===
section "Creating Setup Summary"

# Create a summary file
SUMMARY_FILE="${USER_HOME}/kde-setup-summary.md"

# Get information about restored configurations
RESTORED_INFO=""
if [[ -n "${RESTORED_CONFIGS}" ]]; then
    RESTORED_INFO="- Configurations restored from critical backup at /restart/critical_backups/"
    if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
        RESTORED_INFO="${RESTORED_INFO}\n- Restored configuration files from ${GENERAL_CONFIGS_PATH}"
    fi
    if [[ -n "${SHELL_CONFIGS_PATH}" ]]; then
        RESTORED_INFO="${RESTORED_INFO}\n- Restored shell configurations from ${SHELL_CONFIGS_PATH}"
    fi
    if [[ -n "${SSH_PATH}" ]]; then
        RESTORED_INFO="${RESTORED_INFO}\n- Restored SSH configuration from ${SSH_PATH}"
    fi
fi

# Get current date and time
current_date=$(date +"%Y-%m-%d %H:%M:%S") || true
current_hostname=$(hostname) || true
current_kernel=$(uname -r) || true

cat > "${SUMMARY_FILE}" << EOF
# KDE Plasma Desktop Installation Summary

## System Information
- **Date**: ${current_date}
- **Hostname**: ${current_hostname}
- **Kernel**: ${current_kernel}
- **User**: ${ACTUAL_USER}

## Installed Components
- Core System Utilities
- Professional Audio Setup with PipeWire
- NVIDIA RTX Optimized Drivers
- KDE Plasma Desktop Environment
- Development Tools (PHP, Node.js, Docker)
- Code Editors (VS Code, Zed)
- ZSH with Shell Enhancements
- Specialized Software for Various Tasks
- Web Browsers (Brave, Edge, Firefox)
- Ollama for Local LLM Inference
- Mailspring Email Client
- Terminal Enhancements
- AppImage Support with Common Applications
- KDE Custom Settings

## Configuration Management
- Symlinked configurations from /repo/personal/core-configs/ have been preserved
- Total symlinks preserved: ${CORE_CONFIG_SYMLINK_COUNT}
EOF

# Add restored info if available
if [[ -n "${RESTORED_INFO}" ]]; then
    echo -e "${RESTORED_INFO}" >> "${SUMMARY_FILE}"
fi

cat >> "${SUMMARY_FILE}" << EOF

## Next Steps
1. **Reboot your system** to complete the setup: \`sudo systemctl reboot\`
2. After reboot, ensure all services are running correctly
3. Verify that your symlinked configurations are working properly
4. Configure your desktop environment to your preferences
5. Consider running \`bleachbit\` as your user for additional cleanup (avoid cleaning symlinked configs)

## Additional Resources
- KDE Documentation: https://docs.kde.org/
- Ubuntu Documentation: https://help.ubuntu.com/

## Notes
- If you encounter any issues, most configurations can be found in ~/.config/
- Logs can be viewed with \`journalctl\` or in /var/log/
- System services can be managed with \`systemctl\`
- Your symlinked configurations are in /repo/personal/core-configs/
EOF

# Set proper ownership of the summary file
if [[ -n "${SUDO_USER}" ]]; then
    chown "${SUDO_USER}":"${SUDO_USER}" "${SUMMARY_FILE}"
fi

echo "✓ Created setup summary at ${SUMMARY_FILE}"

# === STAGE 6: Document Symlinked Configurations ===
section "Documenting Symlinked Configurations"

SYMLINKS_FILE="${USER_HOME}/symlinked-configurations.md"

cat > "${SYMLINKS_FILE}" << EOF
# Symlinked Configurations

This document lists all symlinks from your home directory to /repo/personal/core-configs/,
which were preserved during the cleanup process.

## Core Configuration Symlinks
EOF

# Find and document all symlinks to core-configs
symlinks_found=$(find "${USER_HOME}" -type l 2>/dev/null || true)
while IFS= read -r symlink; do
    target=$(readlink "${symlink}") || true
    if [[ "${target}" == "/repo/personal/core-configs/"* ]]; then
        echo "- \`${symlink}\` -> \`${target}\`" >> "${SYMLINKS_FILE}"
    fi
done <<< "${symlinks_found}"

# Add section for restored configurations if available
if [[ -n "${RESTORED_CONFIGS}" ]]; then
    cat >> "${SYMLINKS_FILE}" << EOF

## Restored Configurations
The following paths were used to restore configurations from the backup:
EOF
    
    if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
        echo "- General configurations: \`${GENERAL_CONFIGS_PATH}\`" >> "${SYMLINKS_FILE}"
    fi
    if [[ -n "${SHELL_CONFIGS_PATH}" ]]; then
        echo "- Shell configurations: \`${SHELL_CONFIGS_PATH}\`" >> "${SYMLINKS_FILE}"
    fi
    if [[ -n "${SSH_PATH}" ]]; then
        echo "- SSH configuration: \`${SSH_PATH}\`" >> "${SYMLINKS_FILE}"
    fi
    if [[ -n "${DATABASE_PATH}" ]]; then
        echo "- Database dumps: \`${DATABASE_PATH}\`" >> "${SYMLINKS_FILE}"
    fi
fi

# Set proper ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown "${SUDO_USER}":"${SUDO_USER}" "${SYMLINKS_FILE}"
fi
echo "✓ Created symlinked configurations document at ${SYMLINKS_FILE}"

# Handle configuration files
handle_installed_software_config "summary-docs" "${SUMMARY_FILES[@]}"

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "summary-docs" "${SUMMARY_FILES[@]}"

section "Installation Complete!"
echo "KDE Plasma Desktop has been installed over Ubuntu Server."
echo "The system has been cleaned up and optimized, while preserving your symlinked configurations."
echo "A summary of the installation has been created at ~/kde-setup-summary.md"
echo "A list of preserved symlinked configurations is available at ~/symlinked-configurations.md"
echo

if [[ -n "${RESTORED_CONFIGS}" ]]; then
    echo "Your configurations have been successfully restored from the critical backup"
    echo "located at /restart/critical_backups/."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
fi

echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "You should reboot your system to complete the setup."
echo "Command: sudo systemctl reboot"
