#!/bin/bash

# 12-terminal-enhancements.sh
# This script installs additional terminal utilities and enhancements
# Part of the sequential Ubuntu Server to KDE conversion process
# Modified to use restored configurations from /restart/critical_backups

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
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    # shellcheck disable=SC2034
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Check for restored configurations
CONFIG_MAPPING="/restart/critical_backups/config_mapping.txt"
RESTORED_CONFIGS_AVAILABLE=false

if [[ -f "${CONFIG_MAPPING}" ]]; then
    echo "Found restored configuration mapping at ${CONFIG_MAPPING}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING}"
    RESTORED_CONFIGS_AVAILABLE=true
else
    echo "No restored configuration mapping found at ${CONFIG_MAPPING}"
    echo "Will proceed with default configurations."
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

# Check for restored tmux configuration
RESTORED_TMUX_CONF=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    POSSIBLE_TMUX_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.tmux.conf"
        "${HOME_CONFIGS_PATH}/.tmux.conf"
        "${SHELL_CONFIGS_PATH}/.tmux.conf"
    )
    
    for path in "${POSSIBLE_TMUX_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_TMUX_CONF="${path}"
            echo "Found restored tmux configuration at ${RESTORED_TMUX_CONF}"
            break
        fi
    done
fi

# Create a basic tmux configuration if it doesn't exist in the repo or restored configs
if [[ -n "${RESTORED_TMUX_CONF}" ]]; then
    echo "Using restored tmux configuration..."
    cp "${RESTORED_TMUX_CONF}" "${USER_HOME}/.tmux.conf"
    
    # Set proper ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.tmux.conf"
    fi
    echo "✓ Restored tmux configuration from backup"
elif ! handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"; then
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
        if [[ -n "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.tmux.conf"
        fi
        echo "✓ Created basic tmux configuration"
        
        # Now move it to the repo and create a symlink
        handle_installed_software_config "tmux" "${TMUX_CONFIG_FILES[@]}"
    fi
fi

# === STAGE 5: Manage Terminal Utility Configurations ===
section "Managing Terminal Utility Configurations"

# Check for restored ranger configuration
RESTORED_RANGER=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    RANGER_DIR_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/ranger"
        "${HOME_CONFIGS_PATH}/.config/ranger"
    )
    
    for path in "${RANGER_DIR_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found restored ranger configuration at ${path}"
            mkdir -p "${USER_HOME}/.config/ranger"
            cp -r "${path}"/* "${USER_HOME}/.config/ranger/"
            RESTORED_RANGER=true
            break
        fi
    done
    
    if [[ "${RESTORED_RANGER}" = true ]]; then
        # Set proper ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/ranger"
        fi
        echo "✓ Restored ranger configuration from backup"
    fi
fi

# If not restored from backup, handle ranger configuration normally
if [[ "${RESTORED_RANGER}" = false ]]; then
    handle_installed_software_config "ranger" "${RANGER_CONFIG_FILES[@]}"
fi

# Check for restored nnn configuration
RESTORED_NNN=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    NNN_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.nnnrc"
        "${HOME_CONFIGS_PATH}/.nnnrc"
        "${SHELL_CONFIGS_PATH}/.nnnrc"
    )
    
    for path in "${NNN_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored nnn configuration at ${path}"
            cp "${path}" "${USER_HOME}/.nnnrc"
            RESTORED_NNN=true
            break
        fi
    done
    
    if [[ "${RESTORED_NNN}" = true ]]; then
        # Set proper ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.nnnrc"
        fi
        echo "✓ Restored nnn configuration from backup"
    fi
fi

# If not restored from backup, handle nnn configuration normally
if [[ "${RESTORED_NNN}" = false ]]; then
    handle_installed_software_config "nnn" "${NNN_CONFIG_FILES[@]}"
fi

# Check for restored btop configuration
RESTORED_BTOP=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    BTOP_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/btop"
        "${HOME_CONFIGS_PATH}/.config/btop"
    )
    
    for path in "${BTOP_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found restored btop configuration at ${path}"
            mkdir -p "${USER_HOME}/.config/btop"
            cp -r "${path}"/* "${USER_HOME}/.config/btop/"
            RESTORED_BTOP=true
            break
        fi
    done
    
    if [[ "${RESTORED_BTOP}" = true ]]; then
        # Set proper ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/btop"
        fi
        echo "✓ Restored btop configuration from backup"
    fi
fi

# If not restored from backup, handle btop configuration normally
if [[ "${RESTORED_BTOP}" = false ]]; then
    handle_installed_software_config "btop" "${BTOP_CONFIG_FILES[@]}"
fi

# === STAGE 6: Install and Configure Additional Tools ===
section "Installing and Configuring Additional Tools"

# Check for restored configuration for additional tools
RESTORED_TOOLS=()

# Check for zsh customization files
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    # Check for .zshrc
    ZSH_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.zshrc"
        "${HOME_CONFIGS_PATH}/.zshrc"
        "${SHELL_CONFIGS_PATH}/.zshrc"
    )
    
    for path in "${ZSH_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored .zshrc at ${path}"
            cp "${path}" "${USER_HOME}/.zshrc"
            RESTORED_TOOLS+=("zsh")
            # Set proper ownership
            if [[ -n "${SUDO_USER}" ]]; then
                chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.zshrc"
            fi
            break
        fi
    done
    
    # Check for Starship config
    STARSHIP_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/starship.toml"
        "${HOME_CONFIGS_PATH}/.config/starship.toml"
    )
    
    for path in "${STARSHIP_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored starship.toml at ${path}"
            mkdir -p "${USER_HOME}/.config"
            cp "${path}" "${USER_HOME}/.config/starship.toml"
            RESTORED_TOOLS+=("starship")
            # Set proper ownership
            if [[ -n "${SUDO_USER}" ]]; then
                chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/starship.toml"
            fi
            break
        fi
    done
    
    # Check for bat config
    BAT_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/bat"
        "${HOME_CONFIGS_PATH}/.config/bat"
    )
    
    for path in "${BAT_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found restored bat configuration at ${path}"
            mkdir -p "${USER_HOME}/.config/bat"
            cp -r "${path}"/* "${USER_HOME}/.config/bat/"
            RESTORED_TOOLS+=("bat")
            # Set proper ownership
            if [[ -n "${SUDO_USER}" ]]; then
                chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/bat"
            fi
            break
        fi
    done
    
    # Check for fzf config
    FZF_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.fzf.bash"
        "${HOME_CONFIGS_PATH}/.fzf.bash"
        "${SHELL_CONFIGS_PATH}/.fzf.bash"
    )
    
    for path in "${FZF_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored fzf configuration at ${path}"
            cp "${path}" "${USER_HOME}/.fzf.bash"
            # Also check for fzf.zsh
            if [[ -f "${path%/*}/.fzf.zsh" ]]; then
                cp "${path%/*}/.fzf.zsh" "${USER_HOME}/.fzf.zsh"
            fi
            RESTORED_TOOLS+=("fzf")
            # Set proper ownership
            if [[ -n "${SUDO_USER}" ]]; then
                chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.fzf.bash"
                [[ -f "${USER_HOME}/.fzf.zsh" ]] && chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.fzf.zsh"
            fi
            break
        fi
    done
fi

# Create symlinks for bat (sometimes installed as batcat)
if [[ -f /usr/bin/batcat ]] && [[ ! -f /usr/local/bin/bat ]]; then
    ln -s /usr/bin/batcat /usr/local/bin/bat
    echo "✓ Created bat symlink"
fi

# Create symlinks for fd (sometimes installed as fdfind)
if [[ -f /usr/bin/fdfind ]] && [[ ! -f /usr/local/bin/fd ]]; then
    ln -s /usr/bin/fdfind /usr/local/bin/fd
    echo "✓ Created fd symlink"
fi

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "tmux" "${TMUX_CONFIG_FILES[@]}"
if [[ "${RESTORED_RANGER}" = false ]]; then
    check_post_installation_configs "ranger" "${RANGER_CONFIG_FILES[@]}"
fi
if [[ "${RESTORED_NNN}" = false ]]; then
    check_post_installation_configs "nnn" "${NNN_CONFIG_FILES[@]}"
fi
if [[ "${RESTORED_BTOP}" = false ]]; then
    check_post_installation_configs "btop" "${BTOP_CONFIG_FILES[@]}"
fi

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

if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    echo
    echo "Restoration status:"
    echo "  ✓ Configuration files restored from /restart/critical_backups"
    if [[ -n "${RESTORED_TMUX_CONF}" ]]; then
        echo "  ✓ Restored tmux configuration"
    fi
    if [[ "${RESTORED_RANGER}" = true ]]; then
        echo "  ✓ Restored ranger configuration"
    fi
    if [[ "${RESTORED_NNN}" = true ]]; then
        echo "  ✓ Restored nnn configuration"
    fi
    if [[ "${RESTORED_BTOP}" = true ]]; then
        echo "  ✓ Restored btop configuration"
    fi
    for tool in "${RESTORED_TOOLS[@]}"; do
        echo "  ✓ Restored ${tool} configuration"
    done
fi

echo
echo "These tools will help you efficiently manage your system from the terminal."
