#!/bin/bash

# 12-terminal-enhancements.sh
# This script installs additional terminal utilities and enhancements
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

# Define configuration files for each terminal utility
TMUX_CONFIG_FILES=(
    "${USER_HOME}/.tmux.conf"
)

RANGER_CONFIG_FILES=(
    "${USER_HOME}/.config/ranger/rc.conf"
    "${USER_HOME}/.config/ranger/rifle.conf"
    "${USER_HOME}/.config/ranger/scope.sh"
)

NNN_CONFIG_FILES=(
    "${USER_HOME}/.nnnrc"
)

BTOP_CONFIG_FILES=(
    "${USER_HOME}/.config/btop/btop.conf"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for terminal utilities
handle_pre_installation_config "tmux" "${TMUX_CONFIG_FILES[@]}"
handle_pre_installation_config "ranger" "${RANGER_CONFIG_FILES[@]}"
handle_pre_installation_config "nnn" "${NNN_CONFIG_FILES[@]}"
handle_pre_installation_config "btop" "${BTOP_CONFIG_FILES[@]}"

# === STAGE 2: Additional Terminal Utilities ===
section "Installing Additional Terminal Utilities"

# Install more advanced terminal utilities
install_packages "Advanced Terminal Utilities" \
    tmux \
    ncdu \
    htop \
    glances \
    duf \
    nnn \
    ranger \
    mc \
    iotop \
    dstat \
    mtr \
    nmap \
    iftop

# Replace the apt install of btop with snap
echo "Installing btop via snap..."
snap install btop
echo "✓ Installed btop via snap"

# === STAGE 3: Install Additional Shell Utilities ===
section "Installing Additional Shell Utilities"

# Install more shell utilities
install_packages "Shell Utilities" \
    entr \
    pv \
    parallel \
    rsync \
    nload \
    bmon \
    stress \
    plocate \
    inxi

# === STAGE 4: Setup Default Tmux Configuration ===
section "Setting Up Default Tmux Configuration"

# Create a basic tmux configuration if it doesn't exist in the repo
if ! handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"; then
    # Create a basic tmux.conf if it doesn't exist
    if [[ ! -f "${USER_HOME}/.tmux.conf" ]]; then
        cat > "${USER_HOME}/.tmux.conf" << 'EOF'
# Enable mouse support
set -g mouse on

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Improve colors
set -g default-terminal "screen-256color"

# Increase scrollback buffer size
set -g history-limit 50000

# Set prefix to Ctrl+Space
unbind C-b
set -g prefix C-Space
bind Space send-prefix

# Split panes using | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D
EOF
        
        # Set proper ownership
        if [[ "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.tmux.conf"
        fi
        echo "✓ Created basic tmux configuration"
        
        # Now move it to the repo and create a symlink
        handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"
    fi
fi

# === STAGE 5: Manage Terminal Utility Configurations ===
section "Managing Terminal Utility Configurations"

# Handle configuration files for terminal utilities
handle_installed_software_config "ranger" "${RANGER_CONFIG_FILES[@]}"
handle_installed_software_config "nnn" "${NNN_CONFIG_FILES[@]}"
handle_installed_software_config "btop" "${BTOP_CONFIG_FILES[@]}"

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "tmux" "${TMUX_CONFIG_FILES[@]}"
check_post_installation_configs "ranger" "${RANGER_CONFIG_FILES[@]}"
check_post_installation_configs "nnn" "${NNN_CONFIG_FILES[@]}"
check_post_installation_configs "btop" "${BTOP_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "Terminal Enhancements Installation Complete!"
echo "You have installed the following terminal enhancements:"
echo "  - System monitoring tools (htop, btop, glances, iotop, dstat)"
echo "  - File management tools (ranger, nnn, mc)"
echo "  - Network monitoring (mtr, nmap, iftop, nload, bmon)"
echo "  - Disk usage analyzers (ncdu, duf)"
echo "  - Process automation (entr, parallel)"
echo "  - Tmux configuration with customizations"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "These tools will help you efficiently manage your system from the terminal."
