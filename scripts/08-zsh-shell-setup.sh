#!/bin/bash

# 07-zsh-shell-setup.sh
# This script installs ZSH and shell enhancements
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
    echo "  $1"
    echo "========================================================"
    echo
}

# Function to install packages with progress indication
install_packages() {
    local description=$1
    shift
    
    echo "Installing: $description..."
    apt-get install -y "$@"
    echo "✓ Completed: $description"
}

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: ZSH Installation ===
section "Installing ZSH and Basic Plugins"

# Install ZSH and basic plugins
install_packages "ZSH and Plugins" \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting

# === STAGE 2: Starship Prompt ===
section "Installing Starship Prompt"

# Install Starship prompt (cross-shell prompt)
curl -sS https://starship.rs/install.sh | sh -s -- -y
echo "✓ Installed Starship prompt"

# === STAGE 3: Set ZSH as Default Shell ===
section "Setting ZSH as Default Shell"

# Determine which user to set ZSH for
if [[ "${SUDO_USER}" ]]; then
    # Running as sudo, set ZSH for the actual user
    chsh -s "$(which zsh)" "${SUDO_USER}"
    echo "✓ Set ZSH as default shell for user ${SUDO_USER}"
else
    # Running as root or directly, set ZSH for current user
    chsh -s "$(which zsh)" "${USER}"
    echo "✓ Set ZSH as default shell for user ${USER}"
fi

# === STAGE 4: Manage ZSH and Starship Configurations ===
section "Managing ZSH and Starship Configurations"

# Determine which user to restore configs for
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    USER_HOME="${HOME}"
fi

# Ensure .config directory exists
mkdir -p "${USER_HOME}/.config"

# Define configuration files to manage
ZSH_CONFIG_FILES=(
    "${USER_HOME}/.zshrc"
    "${USER_HOME}/.config/starship.toml"
)

# Handle configuration files
handle_installed_software_config "zsh" "${ZSH_CONFIG_FILES[@]}"

# Set proper ownership of configuration files
if [[ "${SUDO_USER}" ]]; then
    chown -h "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.zshrc" 2>/dev/null || true
    chown -h "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/starship.toml" 2>/dev/null || true
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.zsh" 2>/dev/null || true
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config" 2>/dev/null || true
fi

# === STAGE 5: Terminal Enhancements ===
section "Installing Terminal Enhancements"

# Install modern terminal utilities
install_packages "Terminal Utilities" \
    bat \
    exa \
    fd-find \
    ripgrep \
    jq \
    fzf \
    neofetch

# Create symlinks for bat (sometimes installed as batcat)
if [ -f /usr/bin/batcat ] && [ ! -f /usr/local/bin/bat ]; then
    ln -s /usr/bin/batcat /usr/local/bin/bat
    echo "✓ Created bat symlink"
fi

# Create symlinks for fd (sometimes installed as fdfind)
if [ -f /usr/bin/fdfind ] && [ ! -f /usr/local/bin/fd ]; then
    ln -s /usr/bin/fdfind /usr/local/bin/fd
    echo "✓ Created fd symlink"
fi

# === STAGE 6: Install Warp Terminal ===
section "Installing Warp Terminal"

# Install Warp Terminal
curl -fsSL https://app.warp.dev/download?package=deb | bash
echo "✓ Installed Warp Terminal"

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "zsh" "${ZSH_CONFIG_FILES[@]}"

# Final message
section "ZSH and Shell Enhancements Setup Complete!"
echo "Shell enhancements installed:"
echo "  - ZSH with autosuggestions and syntax highlighting"
echo "  - Starship prompt (cross-shell beautiful prompt)"
echo "  - Modern command-line utilities (bat, exa, ripgrep, etc.)"
echo "  - Warp Terminal"
echo
echo "Configuration files managed through repository at: /repo/personal/core-configs"
echo
echo "You'll need to log out and log back in for the shell change to take effect."
