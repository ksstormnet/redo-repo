#!/bin/bash

# 01-core-system-setup.sh
# This script installs core system components
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

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

# Define configuration files for user profile
BASH_CONFIG_FILES=(
    "${USER_HOME}/.bashrc"
    "${USER_HOME}/.bash_profile"
    "${USER_HOME}/.bash_aliases"
)

GIT_CONFIG_FILES=(
    "${USER_HOME}/.gitconfig"
    "${USER_HOME}/.gitignore_global"
)

VIM_CONFIG_FILES=(
    "${USER_HOME}/.vimrc"
)

TMUX_CONFIG_FILES=(
    "${USER_HOME}/.tmux.conf"
)

SSH_CONFIG_FILES=(
    "${USER_HOME}/.ssh/config"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for user profile
handle_pre_installation_config "bash" "${BASH_CONFIG_FILES[@]}"
handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
handle_pre_installation_config "vim" "${VIM_CONFIG_FILES[@]}"
handle_pre_installation_config "tmux" "${TMUX_CONFIG_FILES[@]}"
handle_pre_installation_config "ssh" "${SSH_CONFIG_FILES[@]}"

# Upgrade existing packages
section "Upgrading Existing Packages"
apt-get upgrade -y

# === STAGE 2: Core System ===
section "Installing Core System Components"

# Base system utilities
install_packages "Base System Utilities" \
    apt-utils \
    software-properties-common \
    build-essential \
    curl \
    wget \
    git \
    git-all \
    htop \
    nano \
    vim \
    tmux \
    zip \
    unzip \
    p7zip-full \
    plocate \
    net-tools \
    openssh-server \
    gnupg \
    ca-certificates

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
install_packages "GitHub CLI" gh

# LVM tools
install_packages "LVM Tools" \
    lvm2 \
    thin-provisioning-tools \
    system-config-lvm

# System performance and management
install_packages "System Performance & Management" \
    linux-lowlatency \
    linux-tools-common \
    lm-sensors \
    hddtemp \
    tlp \
    powertop \
    smartmontools \
    ubuntustudio-lowlatency-settings \
    rtirq-init

# === STAGE 3: User Profile Basics & Git Configuration ===
section "Setting Up User Profile Basics and Git Configuration"

# Create necessary directories
mkdir -p "${USER_HOME}/.config"
mkdir -p "${USER_HOME}/.local/bin"
mkdir -p "${USER_HOME}/.local/share"

# Ensure .ssh directory exists with proper permissions
mkdir -p "${USER_HOME}/.ssh"
chmod 700 "${USER_HOME}/.ssh"

# Handle configuration files
handle_installed_software_config "bash" "${BASH_CONFIG_FILES[@]}"
handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
handle_installed_software_config "vim" "${VIM_CONFIG_FILES[@]}"
handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"
handle_installed_software_config "ssh" "${SSH_CONFIG_FILES[@]}"

# Set proper permissions for SSH config
if [[ -f "${USER_HOME}/.ssh/config" ]]; then
    chmod 600 "${USER_HOME}/.ssh/config"
fi

# Set proper ownership
set_user_ownership "${USER_HOME}/.config"
set_user_ownership "${USER_HOME}/.local"
set_user_ownership "${USER_HOME}/.ssh"

echo "✓ User profile basics and git configuration set up successfully"

# === STAGE 4: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "bash" "${BASH_CONFIG_FILES[@]}"
check_post_installation_configs "git" "${GIT_CONFIG_FILES[@]}"
check_post_installation_configs "vim" "${VIM_CONFIG_FILES[@]}"
check_post_installation_configs "tmux" "${TMUX_CONFIG_FILES[@]}"
check_post_installation_configs "ssh" "${SSH_CONFIG_FILES[@]}"

# Final system update
apt-get update
apt-get upgrade -y

section "Core System Setup Complete!"
echo "User profile basics and git configurations have been set up."
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
