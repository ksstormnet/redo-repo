#!/usr/bin/env bash
# ============================================================================
# 12-root-zsh-config.sh
# ----------------------------------------------------------------------------
# Configures ZSH for the root user by copying user configuration
# This script should be run with root privileges
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default for force mode
: "${FORCE_MODE:=false}"  # Default to not forcing reinstallation

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="12-root-zsh-config"

# ============================================================================
# Root ZSH Configuration Functions
# ============================================================================

# Install ZSH for root user
function install_root_zsh() {
    log_section "Installing ZSH for Root User"

    if check_state "${SCRIPT_NAME}_root_zsh_installed"; then
        log_info "Root ZSH already installed. Skipping..."
        return 0
    fi

    # Check if ZSH is already installed
    if ! command -v zsh &> /dev/null; then
        log_step "Installing ZSH"
        if ! apt_install zsh zsh-syntax-highlighting zsh-autosuggestions; then
            log_error "Failed to install ZSH and plugins"
            return 1
        fi
    else
        log_info "ZSH is already installed"
    fi

    # Get ZSH path and add to shells if needed
    local zsh_path
    zsh_path=$(command -v zsh)

    if ! grep -q "${zsh_path}" /etc/shells; then
        log_step "Adding ZSH to /etc/shells"
        echo "${zsh_path}" >> /etc/shells
    fi

    # Set ZSH as root's shell
    log_step "Setting ZSH as root's shell"
    if ! chsh -s "${zsh_path}" root; then
        log_error "Failed to set ZSH as root's shell"
        return 1
    fi

    set_state "${SCRIPT_NAME}_root_zsh_installed"
    log_success "ZSH installed and set as root's shell"
    return 0
}

# Install Starship for root
function install_root_starship() {
    log_section "Installing Starship for Root User"

    if check_state "${SCRIPT_NAME}_root_starship_installed"; then
        log_info "Root Starship already installed. Skipping..."
        return 0
    fi

    # Check if Starship is installed for regular user
    if ! command -v starship &> /dev/null; then
        log_step "Installing Starship"
        if ! curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
            log_error "Failed to install Starship"
            return 1
        fi
    else
        log_info "Starship is already installed"
    fi

    # Create root's config directory
    mkdir -p /root/.config

    # Check if regular user has a Starship config
    log_step "Configuring Starship for root"
    local user_starship_config="/home/scott/.config/starship.toml"
    local root_starship_config="/root/.config/starship.toml"

    if [[ -f "${user_starship_config}" ]]; then
        # Copy config from regular user
        cp "${user_starship_config}" "${root_starship_config}"
        log_info "Copied Starship configuration from regular user"
    else
        # Create basic config for root
        cat > "${root_starship_config}" << 'EOF'
# Root user Starship configuration

# Add a custom prefix to prompt (helps identify root shell)
format = "$shell$username$hostname$directory$git_branch$git_status$cmd_duration$character"

# Show username in red for root
[username]
style_root = "bold red"
style_user = "bold red"
format = "[$user]($style) "
show_always = true

# Hostname - show always for root
[hostname]
format = "at [$hostname](bold yellow) "
ssh_only = false

# Shell indicator
[shell]
format = "[$indicator](bold red) "
bash_indicator = "BASH"
zsh_indicator = "ZSH"
disabled = false

# Directory
[directory]
truncation_length = 3
fish_style_pwd_dir_length = 1

[character]
success_symbol = "[#](bold green)"
error_symbol = "[#](bold red)"
EOF
        log_info "Created custom Starship configuration for root"
    fi

    # Update root's .zshrc or create it
    log_step "Updating root's .zshrc for Starship"
    local root_zshrc="/root/.zshrc"

    if [[ ! -f "${root_zshrc}" ]]; then
        # Create basic .zshrc for root
        cat > "${root_zshrc}" << 'EOF'
# Root .zshrc configuration

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

# Basic autocompletion
autoload -Uz compinit
compinit

# Load plugins if available
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Basic aliases for root
alias ll='ls -alF'
alias la='ls -A'
alias l='ls --color=auto -CF'
alias vi='vim'
alias apt-get='apt'
alias cls='clear'
alias grep='grep --color=auto'
alias please='sudo'
alias root='cd ~'
alias update='apt update && apt upgrade'
alias install='apt install'
alias remove='apt remove'
alias autoremove='apt autoremove'

# Initialize starship prompt
eval "$(starship init zsh)"
EOF
        log_info "Created new .zshrc for root"
    else
        # Update existing .zshrc
        if ! grep -q "starship init zsh" "${root_zshrc}"; then
            echo "
# Initialize starship prompt
eval \"\$(starship init zsh)\"" >> "${root_zshrc}"
            log_info "Added Starship initialization to existing .zshrc"
        else
            log_info "Starship initialization already in .zshrc"
        fi
    fi

    set_state "${SCRIPT_NAME}_root_starship_installed"
    log_success "Starship installed and configured for root"
    return 0
}

# Copy ZSH configuration from user to root
function copy_zsh_config() {
    log_section "Copying ZSH Configuration from User to Root"

    if check_state "${SCRIPT_NAME}_zsh_config_copied"; then
        log_info "ZSH configuration already copied. Skipping..."
        return 0
    fi

    # Source directories
    local user_zsh_dir="/home/scott/.zsh"
    local user_oh_my_zsh="/home/scott/.oh-my-zsh"

    # Check if user has Oh My Zsh
    if [[ -d "${user_oh_my_zsh}" ]]; then
        log_step "Setting up Oh My Zsh for root"

        # Check if root already has Oh My Zsh
        if [[ ! -d "/root/.oh-my-zsh" ]]; then
            # Install Oh My Zsh for root
            log_info "Installing Oh My Zsh for root"
            # Execute curl and Oh My Zsh installer separately to avoid masking return value
            local install_script
            install_script=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh || true)
            if [[ -n "${install_script}" ]]; then
                RUNZSH=no sh -c "${install_script}" "" --unattended
            else
                log_error "Failed to download Oh My Zsh install script"
                return 1
            fi
        else
            log_info "Oh My Zsh already installed for root"
        fi

        # Copy useful Oh My Zsh plugins
        log_step "Setting up Oh My Zsh plugins for root"

        # Custom plugins directory
        local root_plugins_dir="/root/.oh-my-zsh/custom/plugins"
        mkdir -p "${root_plugins_dir}"

        # User plugins that might be installed
        if [[ -d "${user_oh_my_zsh}/custom/plugins/zsh-autosuggestions" ]]; then
            if [[ ! -d "${root_plugins_dir}/zsh-autosuggestions" ]]; then
                git clone https://github.com/zsh-users/zsh-autosuggestions "${root_plugins_dir}/zsh-autosuggestions"
            fi
        fi

        if [[ -d "${user_oh_my_zsh}/custom/plugins/zsh-syntax-highlighting" ]]; then
            if [[ ! -d "${root_plugins_dir}/zsh-syntax-highlighting" ]]; then
                git clone https://github.com/zsh-users/zsh-syntax-highlighting "${root_plugins_dir}/zsh-syntax-highlighting"
            fi
        fi

        if [[ -d "${user_oh_my_zsh}/custom/plugins/zsh-completions" ]]; then
            if [[ ! -d "${root_plugins_dir}/zsh-completions" ]]; then
                git clone https://github.com/zsh-users/zsh-completions "${root_plugins_dir}/zsh-completions"
            fi
        fi

        # Update plugins in root's .zshrc
        if [[ -f "/root/.zshrc" ]]; then
            sed -i "s/^plugins=.*/plugins=(git sudo docker apt)/g" /root/.zshrc
            log_info "Updated plugins in root's .zshrc"
        fi
    fi

    # Copy user's .zsh directory if it exists
    if [[ -d "${user_zsh_dir}" ]]; then
        log_step "Copying user's .zsh directory to root"
        mkdir -p /root/.zsh
        cp -r "${user_zsh_dir}"/* /root/.zsh/ 2>/dev/null || true
        log_info "Copied .zsh directory from user to root"
    fi

    # Copy other useful configurations
    if [[ -f "/home/scott/.zshrc.custom" ]]; then
        log_step "Copying user's custom ZSH configuration"
        cp "/home/scott/.zshrc.custom" "/root/.zshrc.custom"

        # Source custom settings in root's .zshrc if not already present
        if [[ -f "/root/.zshrc" ]] && ! grep -q "source ~/.zshrc.custom" "/root/.zshrc"; then
            echo '
# Source custom settings
[[ ! -f ~/.zshrc.custom ]] || source ~/.zshrc.custom' >> "/root/.zshrc"
        fi
    fi

    set_state "${SCRIPT_NAME}_zsh_config_copied"
    log_success "ZSH configuration copied from user to root"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_root_zsh() {
    log_section "Setting Up ZSH for Root User"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Root ZSH has already been set up. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install ZSH for root
    if ! install_root_zsh; then
        log_error "Failed to install ZSH for root"
        return 1
    fi

    # Install Starship for root
    if ! install_root_starship; then
        log_warning "Failed to install Starship for root"
        # Continue anyway as this is not critical
    fi

    # Copy ZSH configuration
    if ! copy_zsh_config; then
        log_warning "Failed to copy some ZSH configuration"
        # Continue anyway as this is not critical
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Root ZSH configuration completed successfully"

    log_info "Note: Some changes require a new terminal session for root to take effect"
    log_info "Try: sudo -i to open a new root shell with ZSH"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Call the main function
setup_root_zsh

# Return the exit code
exit $?
