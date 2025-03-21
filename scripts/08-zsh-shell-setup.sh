#!/bin/bash

# 08-zsh-shell-setup.sh
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
    echo "  $1"
    echo "========================================================"
    echo
}

# Function to install packages with progress indication
install_packages() {
    local description=$1
    shift
    
    echo "Installing: ${description}..."
    apt-get install -y "$@"
    echo "✓ Completed: ${description}"
}

# Function to restore shell configuration from backup
restore_shell_config() {
    local config_name="$1"
    local source_file="$2"
    local target_file="$3"
    
    if [[ -f "${source_file}" ]]; then
        echo "Restoring ${config_name} from backup..."
        
        # Create parent directory if it doesn't exist
        mkdir -p "$(dirname "${target_file}")"
        
        # Backup existing file if it exists and is not a symlink
        if [[ -f "${target_file}" ]] && [[ ! -L "${target_file}" ]]; then
            # Get timestamp for backup
            TIMESTAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")
            mv "${target_file}" "${target_file}.backup-${TIMESTAMP}"
            echo "  Backed up existing file: ${target_file}"
        elif [[ -L "${target_file}" ]]; then
            rm "${target_file}"
            echo "  Removed existing symlink: ${target_file}"
        fi
        
        # Copy configuration file
        cp "${source_file}" "${target_file}"
        
        # Set ownership
        if [[ -n "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}":"${SUDO_USER}" "${target_file}"
        fi
        
        echo "✓ Restored ${config_name} from backup"
        return 0
    fi
    
    echo "No backup found for ${config_name} at ${source_file}"
    return 1
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
curl -sS https://starship.rs/install.sh | sh -s -- -y || true
echo "✓ Installed Starship prompt"

# === STAGE 3: Set ZSH as Default Shell ===
section "Setting ZSH as Default Shell"

# Determine which user to set ZSH for
if [[ -n "${SUDO_USER}" ]]; then
    # Running as sudo, set ZSH for the actual user
    ZSH_PATH=$(command -v zsh) || true
    chsh -s "${ZSH_PATH}" "${SUDO_USER}"
    echo "✓ Set ZSH as default shell for user ${SUDO_USER}"
else
    # Running as root or directly, set ZSH for current user
    ZSH_PATH=$(command -v zsh) || true
    chsh -s "${ZSH_PATH}" "${USER}"
    echo "✓ Set ZSH as default shell for user ${USER}"
fi

# === STAGE 4: Manage ZSH and Starship Configurations ===
section "Managing ZSH and Starship Configurations"

# Determine which user to restore configs for
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
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

# Define backup paths based on the configuration mapping
ZSH_BACKUP=""
STARSHIP_BACKUP=""

# Look for ZSH configuration in backup
if [[ -n "${SHELL_CONFIGS_PATH}" ]] && [[ -f "${SHELL_CONFIGS_PATH}/.zshrc" ]]; then
    ZSH_BACKUP="${SHELL_CONFIGS_PATH}/.zshrc"
fi

# Also check other potential locations
if [[ -z "${ZSH_BACKUP}" ]] && [[ -n "${HOME_CONFIGS_PATH}" ]] && [[ -f "${HOME_CONFIGS_PATH}/.zshrc" ]]; then
    ZSH_BACKUP="${HOME_CONFIGS_PATH}/.zshrc"
fi

if [[ -z "${ZSH_BACKUP}" ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]] && [[ -f "${GENERAL_CONFIGS_PATH}/home/.zshrc" ]]; then
    ZSH_BACKUP="${GENERAL_CONFIGS_PATH}/home/.zshrc"
fi

# Look for Starship configuration in backup
if [[ -n "${GENERAL_CONFIGS_PATH}" ]] && [[ -f "${GENERAL_CONFIGS_PATH}/config_files/.config/starship.toml" ]]; then
    STARSHIP_BACKUP="${GENERAL_CONFIGS_PATH}/config_files/.config/starship.toml"
fi

# Restore ZSH configuration from backup if available
if [[ -n "${ZSH_BACKUP}" ]]; then
    restore_shell_config "ZSH configuration" "${ZSH_BACKUP}" "${USER_HOME}/.zshrc"
    
    # Check for .zsh directory in backup
    if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
        ZSH_DIR_BACKUP=$(find "${BACKUP_CONFIGS_PATH}" -path "*/home/.zsh" -type d -o -path "*/home_configs/.zsh" -type d | head -n 1) || true
        if [[ -n "${ZSH_DIR_BACKUP}" ]]; then
            echo "Restoring .zsh directory from backup..."
            mkdir -p "${USER_HOME}/.zsh"
            cp -r "${ZSH_DIR_BACKUP}"/* "${USER_HOME}/.zsh/" 2>/dev/null || true
            
            # Set ownership
            if [[ -n "${SUDO_USER}" ]]; then
                chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.zsh"
            fi
            
            echo "✓ Restored .zsh directory from backup"
        fi
    fi
else
    echo "No ZSH configuration backup found, will use new configuration."
fi

# Restore Starship configuration from backup if available
if [[ -n "${STARSHIP_BACKUP}" ]]; then
    restore_shell_config "Starship configuration" "${STARSHIP_BACKUP}" "${USER_HOME}/.config/starship.toml"
else
    echo "No Starship configuration backup found, will use default configuration."
    
    # Create a default Starship configuration
    mkdir -p "${USER_HOME}/.config"
    cat > "${USER_HOME}/.config/starship.toml" << 'EOF'
# Default Starship Configuration

[character]
success_symbol = "[➜](bold green) "
error_symbol = "[✗](bold red) "

[cmd_duration]
min_time = 2000
format = "took [$duration](bold yellow) "

[directory]
truncation_length = 5
format = "[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "on [$symbol$branch]($style) "

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'

[package]
disabled = false

[username]
show_always = false
EOF
    
    # Set ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/starship.toml"
    fi
    
    echo "✓ Created default Starship configuration"
fi

# If no .zshrc found or restored, create a default one
if [[ ! -f "${USER_HOME}/.zshrc" ]]; then
    echo "Creating default .zshrc..."
    cat > "${USER_HOME}/.zshrc" << 'EOF'
# Default ZSH Configuration

# Enable colors
autoload -U colors && colors

# History configuration
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt INC_APPEND_HISTORY

# Basic auto/tab completion
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)

# Load plugins if available
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias grep='grep --color=auto'

# Load starship prompt if available
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Load custom configurations if they exist
if [ -d "$HOME/.zsh" ]; then
    for config_file ($HOME/.zsh/*.zsh); do
        source $config_file
    done
fi
EOF
    
    # Set ownership
    if [[ -n "${SUDO_USER}" ]]; then
        chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.zshrc"
    fi
    
    echo "✓ Created default .zshrc"
fi

# Handle configuration files
handle_installed_software_config "zsh" "${ZSH_CONFIG_FILES[@]}"

# Set proper ownership of configuration files
if [[ -n "${SUDO_USER}" ]]; then
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
if [[ -f /usr/bin/batcat ]] && [[ ! -f /usr/local/bin/bat ]]; then
    ln -s /usr/bin/batcat /usr/local/bin/bat
    echo "✓ Created bat symlink"
fi

# Create symlinks for fd (sometimes installed as fdfind)
if [[ -f /usr/bin/fdfind ]] && [[ ! -f /usr/local/bin/fd ]]; then
    ln -s /usr/bin/fdfind /usr/local/bin/fd
    echo "✓ Created fd symlink"
fi

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "zsh" "${ZSH_CONFIG_FILES[@]}"

# Final message
section "ZSH and Shell Enhancements Setup Complete!"
echo "Shell enhancements installed:"
echo "  - ZSH with autosuggestions and syntax highlighting"
echo "  - Starship prompt (cross-shell beautiful prompt)"
echo "  - Modern command-line utilities (bat, exa, ripgrep, etc.)"
echo
echo "Configuration files managed through repository at: /repo/personal/core-configs"
echo
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Configurations were also restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
echo
echo "You'll need to log out and log back in for the shell change to take effect."
