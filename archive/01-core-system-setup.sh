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
if [[ -n "${SUDO_USER}" ]]; then
    set +e
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    set -e
    USER_HOME=${USER_HOME:-"${HOME}"}
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

# Check for restored configurations first and skip pre-installation if found
if [[ -n "${GENERAL_CONFIGS_PATH}" ]] || [[ -n "${SHELL_CONFIGS_PATH}" ]]; then
    echo "Using restored configurations from backup. Skipping pre-installation setup."
else
    # Set up pre-installation configurations for user profile
    handle_pre_installation_config "bash" "${BASH_CONFIG_FILES[@]}"
    handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
    handle_pre_installation_config "vim" "${VIM_CONFIG_FILES[@]}"
    handle_pre_installation_config "tmux" "${TMUX_CONFIG_FILES[@]}"
    handle_pre_installation_config "ssh" "${SSH_CONFIG_FILES[@]}"
fi

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
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg || true
# Get architecture separately to avoid masking return value
ARCH=$(dpkg --print-architecture) || ARCH="amd64"
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
install_packages "GitHub CLI" gh

# LVM tools
install_packages "LVM Tools" \
    lvm2 \
    thin-provisioning-tools \

# System performance and management
install_packages "System Performance & Management" \
    linux-lowlatency \
    linux-tools-common \
    lm-sensors \
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

# Check for restored configurations first
if [[ -n "${SHELL_CONFIGS_PATH}" ]] && [[ -d "${SHELL_CONFIGS_PATH}" ]]; then
    echo "Found restored shell configurations at: ${SHELL_CONFIGS_PATH}"
    
    # Copy restored shell configuration files
    for config_file in .bashrc .bash_profile .bash_aliases .profile; do
        if [[ -f "${SHELL_CONFIGS_PATH}/${config_file}" ]]; then
            # Back up existing file if it exists
            if [[ -f "${USER_HOME}/${config_file}" ]] && [[ ! -L "${USER_HOME}/${config_file}" ]]; then
                TIMESTAMP=$(date +%Y%m%d-%H%M%S) || TIMESTAMP="backup"
                mv "${USER_HOME}/${config_file}" "${USER_HOME}/${config_file}.orig.${TIMESTAMP}"
                echo "Backed up existing ${config_file}"
            fi
            
            # Copy restored file if not already handled by 00-initial-setup.sh
            if [[ ! -f "${USER_HOME}/${config_file}" ]] || [[ ! -L "${USER_HOME}/${config_file}" ]]; then
                cp "${SHELL_CONFIGS_PATH}/${config_file}" "${USER_HOME}/"
                echo "✓ Restored ${config_file} from backup"
            fi
        fi
    done
    
    # Check for Git config files
    for git_config in .gitconfig .gitignore_global .git-credentials; do
        if [[ -f "${SHELL_CONFIGS_PATH}/${git_config}" ]]; then
            # Back up existing file if it exists
            if [[ -f "${USER_HOME}/${git_config}" ]] && [[ ! -L "${USER_HOME}/${git_config}" ]]; then
                TIMESTAMP=$(date +%Y%m%d-%H%M%S) || TIMESTAMP="backup"
                mv "${USER_HOME}/${git_config}" "${USER_HOME}/${git_config}.orig.${TIMESTAMP}"
                echo "Backed up existing ${git_config}"
            fi
            
            # Copy restored file if not already handled by 00-initial-setup.sh
            if [[ ! -f "${USER_HOME}/${git_config}" ]] || [[ ! -L "${USER_HOME}/${git_config}" ]]; then
                cp "${SHELL_CONFIGS_PATH}/${git_config}" "${USER_HOME}/"
                echo "✓ Restored ${git_config} from backup"
            fi
        fi
    done
    
    # Check for Vim config
    if [[ -f "${SHELL_CONFIGS_PATH}/.vimrc" ]]; then
        # Back up existing file if it exists
        if [[ -f "${USER_HOME}/.vimrc" ]] && [[ ! -L "${USER_HOME}/.vimrc" ]]; then
            TIMESTAMP=$(date +%Y%m%d-%H%M%S) || TIMESTAMP="backup"
            mv "${USER_HOME}/.vimrc" "${USER_HOME}/.vimrc.orig.${TIMESTAMP}"
            echo "Backed up existing .vimrc"
        fi
        
        # Copy restored file if not already handled by 00-initial-setup.sh
        if [[ ! -f "${USER_HOME}/.vimrc" ]] || [[ ! -L "${USER_HOME}/.vimrc" ]]; then
            cp "${SHELL_CONFIGS_PATH}/.vimrc" "${USER_HOME}/"
            echo "✓ Restored .vimrc from backup"
        fi
    fi
    
    # Check for Tmux config
    if [[ -f "${SHELL_CONFIGS_PATH}/.tmux.conf" ]]; then
        # Back up existing file if it exists
        if [[ -f "${USER_HOME}/.tmux.conf" ]] && [[ ! -L "${USER_HOME}/.tmux.conf" ]]; then
            TIMESTAMP=$(date +%Y%m%d-%H%M%S) || TIMESTAMP="backup"
            mv "${USER_HOME}/.tmux.conf" "${USER_HOME}/.tmux.conf.orig.${TIMESTAMP}"
            echo "Backed up existing .tmux.conf"
        fi
        
        # Copy restored file
        cp "${SHELL_CONFIGS_PATH}/.tmux.conf" "${USER_HOME}/"
        echo "✓ Restored .tmux.conf from backup"
    fi
    
    echo "✓ Restored configurations from backup"
else
    # If no restored configs, handle configuration files from repo
    handle_installed_software_config "bash" "${BASH_CONFIG_FILES[@]}"
    handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
    handle_installed_software_config "vim" "${VIM_CONFIG_FILES[@]}"
    handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"
    handle_installed_software_config "ssh" "${SSH_CONFIG_FILES[@]}"
    
    echo "✓ Set up configuration files from repository"
fi

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
