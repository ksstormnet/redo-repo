#!/usr/bin/env bash
# ============================================================================
# 09-terminal-tools.sh
# ----------------------------------------------------------------------------
# Installs terminal utilities and ZSH shell environment with Oh My Zsh
# Enhances terminal productivity with tools, plugins, and configurations
# Includes tmux, starship, zsh, and various utilities for development
# Uses dependency management to prevent duplicate package installations
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${INTERACTIVE:=false}"
: "${FORCE_MODE:=false}"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Source dependency management utilities
if [[ -f "${LIB_DIR}/dependency-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/dependency-utils.sh"

    # Initialize dependency tracking
    init_dependency_tracking
else
    echo "WARNING: dependency-utils.sh library not found at ${LIB_DIR}"
    # Continue anyway as dependency management is optional for this script
fi

# Script name for state management and logging
SCRIPT_NAME="09-terminal-tools"

# Check if common utilities script has been run
function is_common_utilities_installed() {
    if check_state "00-common-utilities_completed"; then
        log_info "Common utilities already installed by 00-common-utilities.sh script"
        return 0
    fi

    if check_state "00-common-utilities_terminal_utilities_installed"; then
        log_info "Terminal utilities already installed by 00-common-utilities.sh script"
        return 0
    fi

    return 1
}

# Register packages that may already be installed by common utilities
function register_common_terminal_packages() {
    # Skip if dependency management is not available
    if ! command -v register_packages &> /dev/null; then
        return 0
    fi

    # Common terminal utilities that might be installed by 00-common-utilities.sh
    local common_terminal_utilities=(
        tmux
        screen
        mc
        ranger
        fzf
        bat
        ripgrep
        fd-find
        tree
        ncdu
        jq
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
    )

    # Register these as already installed
    register_packages "utilities" "${common_terminal_utilities[@]}"
    log_debug "Registered common terminal utilities that might already be installed"
}

# ============================================================================
# Helper Functions
# ============================================================================

# Get the actual user's home directory
function get_user_home() {
    if [[ -n "${SUDO_USER}" ]]; then
        getent passwd "${SUDO_USER}" | cut -d: -f6
    else
        echo "${HOME}"
    fi
}

# Check if ZSH is the default shell for the user
function is_zsh_default_shell() {
    local user
    # Use proper if-then-else instead of ternary-like expression
    if [[ -n "${SUDO_USER}" ]]; then
        user="${SUDO_USER}"
    else
        user=$(whoami)
    fi

    local user_shell
    user_shell=$(getent passwd "${user}" | cut -d: -f7)

    [[ "${user_shell}" == *"zsh"* ]]
}

# ============================================================================
# Terminal Utilities Installation
# ============================================================================

# Install terminal utilities (multiplexers, file managers, etc.)
function install_terminal_utilities() {
    log_step "Installing core terminal utilities"

    if check_state "${SCRIPT_NAME}_core_utils_installed"; then
        log_info "Core terminal utilities already installed. Skipping..."
        return 0
    fi

    # Register common packages that might be installed by 00-common-utilities
    register_common_terminal_packages

    # Check if common utilities has installed these packages
    if is_common_utilities_installed; then
        log_info "Basic terminal utilities already installed by 00-common-utilities script"
        log_info "Installing only additional terminal utilities not covered by common utilities"
    else
        log_info "Common utilities script has not been run, installing all terminal utilities"
    fi

    # Terminal multiplexers - Use smart install if available
    log_info "Installing terminal multiplexers"
    local terminal_multiplexers=(
        tmux
        screen
    )

    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${terminal_multiplexers[@]}"; then
            log_warning "Some terminal multiplexers could not be installed"
        fi
    else
        if ! apt_install "${terminal_multiplexers[@]}"; then
            log_warning "Failed to install terminal multiplexers"
        fi
    fi

    # File managers - Use smart install if available
    log_info "Installing terminal file managers"
    local file_managers=(
        mc    # Midnight Commander
        ranger # Vim-inspired file manager
        nnn   # Fast and lightweight file manager
    )

    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${file_managers[@]}"; then
            log_warning "Some file managers could not be installed"
        fi
    else
        if ! apt_install "${file_managers[@]}"; then
            log_warning "Failed to install some file managers"
        fi
    fi

    # System monitoring tools - Use smart install if available
    log_info "Installing system monitoring tools"
    local monitoring_tools=(
        btop   # Resource monitor with mouse support
        htop   # Interactive process viewer
        glances # System monitoring tool
        iotop  # I/O monitoring
        iftop  # Network bandwidth monitoring
        ncdu   # Disk usage analyzer
        dstat  # System resource statistics
    )

    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${monitoring_tools[@]}"; then
            log_warning "Some monitoring tools could not be installed"
        fi
    else
        if ! apt_install "${monitoring_tools[@]}"; then
            log_warning "Failed to install some system monitoring tools"
        fi
    fi

    set_state "${SCRIPT_NAME}_core_utils_installed"
    log_success "Core terminal utilities installed successfully"
    return 0
}

# Install search and text processing tools
function install_search_tools() {
    log_step "Installing search and text processing tools"

    if check_state "${SCRIPT_NAME}_search_tools_installed"; then
        log_info "Search tools already installed. Skipping..."
        return 0
    fi

    # Check if common utilities has installed some of these packages
    if is_common_utilities_installed; then
        log_info "Some search tools may already be installed by common utilities script"
    fi

    # Register common packages that might be installed by 00-common-utilities
    register_common_terminal_packages

    # Search tools - Use smart install if available
    local search_tools=(
        ripgrep              # Fast grep alternative
        fzf                  # Fuzzy finder
        silversearcher-ag    # Faster alternative to grep
        fd-find              # Simple, fast alternative to find
        bat                  # Cat clone with syntax highlighting
        exa                  # Modern replacement for ls
        jq                   # Command-line JSON processor
        tldr                 # Simplified man pages
        direnv               # Directory-based environment switcher
    )

    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${search_tools[@]}"; then
            log_warning "Some search tools could not be installed"
        fi
    else
        if ! apt_install "${search_tools[@]}"; then
            log_warning "Failed to install some search tools"
        fi
    fi

    set_state "${SCRIPT_NAME}_search_tools_installed"
    log_success "Search and text processing tools installed successfully"
    return 0
}

# Create symbolic links for tools with different names in Ubuntu
function create_symbolic_links() {
    log_step "Creating symbolic links for terminal tools"

    if check_state "${SCRIPT_NAME}_links_created"; then
        log_info "Symbolic links already created. Skipping..."
        return 0
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Create .local/bin directory if it doesn't exist
    local bin_dir="${user_home}/.local/bin"
    mkdir -p "${bin_dir}"

    # Create symbolic link for bat (installed as batcat on Ubuntu)
    if command -v batcat &> /dev/null; then
        log_info "Creating symbolic link for bat"
        # Use command -v instead of which
        local batcat_path
        batcat_path=$(command -v batcat) || true
        ln -sf "${batcat_path}" "${bin_dir}/bat"
    else
        log_warning "batcat is not installed, cannot create symbolic link"
    fi

    # Create symbolic link for fd (installed as fdfind on Ubuntu)
    if command -v fdfind &> /dev/null; then
        log_info "Creating symbolic link for fd"
        # Use command -v instead of which
        local fdfind_path
        fdfind_path=$(command -v fdfind) || true
        ln -sf "${fdfind_path}" "${bin_dir}/fd"
    else
        log_warning "fdfind is not installed, cannot create symbolic link"
    fi

    # Create symbolic link for exa (if it exists)
    if command -v exa &> /dev/null; then
        log_info "Creating symbolic links for exa as ls replacements"
        # Use command -v instead of which
        local exa_path
        exa_path=$(command -v exa) || true
        ln -sf "${exa_path}" "${bin_dir}/ll"
        ln -sf "${exa_path}" "${bin_dir}/la"

        # Create a script for 'l' with common exa options
        cat > "${bin_dir}/l" << 'EOF'
#!/bin/bash
exa --long --header --git "$@"
EOF
        chmod +x "${bin_dir}/l"
    fi

    # Fix permissions on the bin directory
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${bin_dir}"
    fi

    # Ensure bin directory is in the PATH
    local profile_file="${user_home}/.profile"
    # shellcheck disable=SC2016
    local path_entry='export PATH="$HOME/.local/bin:$PATH"'

    if [[ -f "${profile_file}" ]] && ! grep -q "${path_entry}" "${profile_file}"; then
        log_info "Adding .local/bin to PATH in .profile"
        {
            echo ""
            echo "# Add .local/bin to PATH"
            echo "${path_entry}"
        } >> "${profile_file}"
    fi

    set_state "${SCRIPT_NAME}_links_created"
    log_success "Symbolic links created successfully"
    return 0
}

# ============================================================================
# Tmux Configuration
# ============================================================================

# Install and configure tmux plugins
function configure_tmux() {
    log_step "Configuring tmux"

    if check_state "${SCRIPT_NAME}_tmux_configured"; then
        log_info "tmux already configured. Skipping..."
        return 0
    fi

    # Check if tmux is installed
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed. Cannot configure tmux."
        return 1
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Install Tmux Plugin Manager if not already installed
    local tmux_plugin_dir="${user_home}/.tmux/plugins/tpm"

    if [[ ! -d "${tmux_plugin_dir}" ]]; then
        log_info "Installing Tmux Plugin Manager"

        # Clone the TPM repository
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" mkdir -p "$(dirname "${tmux_plugin_dir}")"
            if ! sudo -u "${SUDO_USER}" git clone https://github.com/tmux-plugins/tpm "${tmux_plugin_dir}"; then
                log_warning "Failed to install Tmux Plugin Manager"
                # Continue anyway as this is not critical
            else
                log_info "Tmux Plugin Manager installed successfully"
            fi
        else
            mkdir -p "$(dirname "${tmux_plugin_dir}")"
            if ! git clone https://github.com/tmux-plugins/tpm "${tmux_plugin_dir}"; then
                log_warning "Failed to install Tmux Plugin Manager"
                # Continue anyway as this is not critical
            else
                log_info "Tmux Plugin Manager installed successfully"
            fi
        fi
    else
        log_info "Tmux Plugin Manager already installed"
    fi

    # Create basic tmux configuration if it doesn't exist
    local tmux_conf="${user_home}/.tmux.conf"

    if [[ ! -f "${tmux_conf}" ]]; then
        log_info "Creating basic tmux configuration"

        # Create a basic tmux configuration file
        cat > "${tmux_conf}.tmp" << 'EOF'
# ==========================
# ===  General settings  ===
# ==========================

set -g default-terminal "screen-256color"
set -g history-limit 20000
set -g buffer-limit 20
set -g display-time 1500
set -g remain-on-exit off
set -g repeat-time 300
setw -g allow-rename off
setw -g automatic-rename off
setw -g aggressive-resize on

# Change prefix key to C-a, easier to type
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Set parent terminal title to reflect current window in tmux session
set -g set-titles on
set -g set-titles-string "#I:#W"

# Start index of window/pane with 1
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support
set -g mouse on

# ==========================
# ===   Key bindings     ===
# ==========================

# Reload tmux configuration
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Split panes
bind | split-window -h
bind - split-window -v

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# ==========================
# ===   Theme and colors  ===
# ==========================

# Status bar
set -g status-style fg=white,bg=black
set -g status-interval 10
set -g status-left-length 30
set -g status-right-length 60
set -g status-left "#[fg=green](#S) #(whoami) "
set -g status-right "#[fg=yellow]%d %b %Y #[fg=green]%H:%M"

# Window status
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
setw -g window-status-current-style fg=black,bg=green

# Pane border
set -g pane-border-style fg=white
set -g pane-active-border-style fg=green

# Message text
set -g message-style fg=black,bg=green

# ==========================
# ===   Plugin Manager   ===
# ==========================

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'

# Plugin settings
set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF

        # Move the temporary file to the actual location with correct permissions
        if [[ -n "${SUDO_USER}" ]]; then
            mv "${tmux_conf}.tmp" "${tmux_conf}"
            chown "${SUDO_USER}:${SUDO_USER}" "${tmux_conf}"
        else
            mv "${tmux_conf}.tmp" "${tmux_conf}"
        fi

        log_info "Basic tmux configuration created"
    else
        log_info "tmux configuration already exists, skipping creation"
    fi

    # Install tmux plugins
    log_info "Installing tmux plugins"
    if [[ -n "${SUDO_USER}" ]]; then
        if ! sudo -u "${SUDO_USER}" bash -c "TMUX_PLUGIN_MANAGER_PATH=\"${user_home}/.tmux/plugins/\" \"${tmux_plugin_dir}/scripts/install_plugins.sh\" > /dev/null 2>&1"; then
            log_warning "Failed to install tmux plugins"
            # Continue anyway as this is not critical
        else
            log_info "tmux plugins installed successfully"
        fi
    else
        if ! TMUX_PLUGIN_MANAGER_PATH="${user_home}/.tmux/plugins/" "${tmux_plugin_dir}/scripts/install_plugins.sh" > /dev/null 2>&1; then
            log_warning "Failed to install tmux plugins"
            # Continue anyway as this is not critical
        else
            log_info "tmux plugins installed successfully"
        fi
    fi

    set_state "${SCRIPT_NAME}_tmux_configured"
    log_success "tmux configured successfully"
    return 0
}

# ============================================================================
# Starship Prompt Installation
# ============================================================================

# Install and configure Starship prompt
function install_starship() {
    log_step "Installing Starship prompt"

    if check_state "${SCRIPT_NAME}_starship_installed"; then
        log_info "Starship prompt already installed. Skipping..."
        return 0
    fi

    # Check for curl as it's needed for installation
    if ! command -v curl &> /dev/null; then
        log_info "Installing curl (required for Starship installation)"
        if ! apt_install curl; then
            log_error "Failed to install curl, cannot continue with Starship installation"
            return 1
        fi
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Install Starship
    log_info "Installing Starship prompt"
    if [[ -n "${SUDO_USER}" ]]; then
        # Install for the real user (not root)
        if ! sudo -u "${SUDO_USER}" bash -c "curl -sS https://starship.rs/install.sh | sh -s -- --yes"; then
            log_error "Failed to install Starship prompt"
            return 1
        fi
    else
        # Install for current user
        if ! curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
            log_error "Failed to install Starship prompt"
            return 1
        fi
    fi

    # Check if Starship is installed
    if ! command -v starship &> /dev/null; then
        log_error "Starship installation verification failed"
        return 1
    fi

    # Configure Starship for Bash
    log_info "Configuring Starship for Bash"
    local bash_rc="${user_home}/.bashrc"

    if [[ -f "${bash_rc}" ]]; then
        # Check if Starship is already configured in .bashrc
        if ! grep -q "starship init bash" "${bash_rc}"; then
            # Add Starship initialization to .bashrc
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" bash -c "echo -e '\n# Initialize Starship prompt\neval \"\$(starship init bash)\"' >> \"${bash_rc}\""
            else
                # shellcheck disable=SC2016
                echo -e '\n# Initialize Starship prompt\neval "$(starship init bash)"' >> "${bash_rc}"
            fi
            log_info "Added Starship initialization to .bashrc"
        else
            log_info "Starship already configured in .bashrc"
        fi
    else
        log_warning ".bashrc not found, cannot configure Starship for Bash"
    fi

    # Create default Starship configuration
    log_info "Creating Starship configuration"
    local starship_config_dir="${user_home}/.config"
    local starship_config="${starship_config_dir}/starship.toml"

    if [[ ! -f "${starship_config}" ]]; then
        # Ensure the config directory exists
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" mkdir -p "${starship_config_dir}"
        else
            mkdir -p "${starship_config_dir}"
        fi

        # Create basic Starship configuration
        cat > "${starship_config}.tmp" << 'EOF'
# Get editor completions based on the config schema
"$schema" = 'https://starship.rs/config-schema.json'

# Don't print a new line at the start of the prompt
add_newline = true

# A minimal left prompt
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$python\
$nodejs\
$php\
$cmd_duration\
$line_break\
$character"""

# Show command duration if it takes more than 3 seconds
[cmd_duration]
min_time = 3000
show_milliseconds = false

# Replace the "❯" symbol in the prompt with "→"
[character]
success_symbol = "[→](bold green)"
error_symbol = "[→](bold red)"

# Directory
[directory]
truncation_length = 3
fish_style_pwd_dir_length = 1

# Git settings
[git_branch]
symbol = "🌱 "

[git_status]
ahead = "⇡${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
behind = "⇣${count}"
EOF

        # Move the temporary file to the actual location with correct permissions
        if [[ -n "${SUDO_USER}" ]]; then
            mv "${starship_config}.tmp" "${starship_config}"
            chown "${SUDO_USER}:${SUDO_USER}" "${starship_config}"
        else
            mv "${starship_config}.tmp" "${starship_config}"
        fi

        log_info "Created default Starship configuration"
    else
        log_info "Starship configuration already exists, skipping creation"
    fi

    # Get Starship version for logging
    # Declare first, then assign to avoid masking return values
    local starship_version
    starship_version=$(starship --version) || true
    log_success "Starship prompt ${starship_version} installed and configured successfully"

    set_state "${SCRIPT_NAME}_starship_installed"
    return 0
}

# ============================================================================
# ZSH Installation and Configuration
# ============================================================================

# Install ZSH and dependencies
function install_zsh() {
    log_step "Installing ZSH shell"

    if check_state "${SCRIPT_NAME}_zsh_installed"; then
        log_info "ZSH is already installed. Skipping..."
        return 0
    fi

    # Check if ZSH is already installed by 00-common-utilities
    if is_common_utilities_installed && command -v zsh &> /dev/null; then
        log_info "ZSH already installed by common utilities script"
        set_state "${SCRIPT_NAME}_zsh_installed"
        return 0
    fi

    # Register packages that might be installed by other scripts
    if command -v register_packages &> /dev/null; then
        log_debug "Registering common packages that might already be installed"
        register_packages "essential" "git" "curl" "wget"
    fi

    # Install ZSH and required dependencies
    local zsh_packages=(
        zsh
        zsh-syntax-highlighting
        zsh-autosuggestions
        fonts-powerline
    )

    log_info "Installing ZSH and dependencies"
    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${zsh_packages[@]}"; then
            log_error "Failed to install ZSH and dependencies"
            return 1
        fi
    else
        if ! apt_install "${zsh_packages[@]}"; then
            log_error "Failed to install ZSH and dependencies"
            return 1
        fi
    fi

    # Verify installation
    if ! command -v zsh &> /dev/null; then
        log_error "ZSH installation verification failed"
        return 1
    fi

    # Get ZSH version for logging
    # Declare first, then assign to avoid masking return values
    local zsh_version
    zsh_version=$(zsh --version) || true
    log_success "ZSH ${zsh_version} installed successfully"

    set_state "${SCRIPT_NAME}_zsh_installed"
    return 0
}

# Install Oh My Zsh framework
function install_oh_my_zsh() {
    log_step "Installing Oh My Zsh"

    if check_state "${SCRIPT_NAME}_ohmyzsh_installed"; then
        log_info "Oh My Zsh is already installed. Skipping..."
        return 0
    fi

    # Check if Oh My Zsh is already installed by 00-common-utilities
    if check_state "00-common-utilities_zsh_configured"; then
        log_info "Oh My Zsh already installed by common utilities script"
        set_state "${SCRIPT_NAME}_ohmyzsh_installed"
        return 0
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Check if Oh My Zsh is already installed
    if [[ -d "${user_home}/.oh-my-zsh" ]]; then
        log_info "Oh My Zsh is already installed"
        set_state "${SCRIPT_NAME}_ohmyzsh_installed"
        return 0
    fi

    # Backup existing .zshrc file if it exists
    if [[ -f "${user_home}/.zshrc" ]]; then
        log_info "Backing up existing .zshrc file"
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" cp "${user_home}/.zshrc" "${user_home}/.zshrc.pre-oh-my-zsh.backup"
        else
            cp "${user_home}/.zshrc" "${user_home}/.zshrc.pre-oh-my-zsh.backup"
        fi
    fi

    # Install Oh My Zsh
    log_info "Downloading and installing Oh My Zsh"

    # Get the installer script separately to avoid masking return value
    local installer_script
    installer_script=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) || true

    # Run as the appropriate user
    if [[ -n "${SUDO_USER}" ]]; then
        # Install for the real user, not root
        sudo -u "${SUDO_USER}" sh -c "${installer_script}" "" --unattended
    else
        # Install for current user
        sh -c "${installer_script}" "" --unattended
    fi

    # Check if installation was successful
    if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
        log_error "Oh My Zsh installation failed"
        return 1
    fi

    log_success "Oh My Zsh installed successfully"
    set_state "${SCRIPT_NAME}_ohmyzsh_installed"
    return 0
}

# Install ZSH plugins
function install_zsh_plugins() {
    log_step "Installing ZSH plugins"

    if check_state "${SCRIPT_NAME}_plugins_installed"; then
        log_info "ZSH plugins already installed. Skipping..."
        return 0
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Check if Oh My Zsh is installed
    if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
        log_error "Oh My Zsh is not installed. Cannot install plugins."
        return 1
    fi

    # Custom plugins directory
    local custom_plugins_dir="${user_home}/.oh-my-zsh/custom/plugins"

    # Make sure custom plugins directory exists
    if [[ ! -d "${custom_plugins_dir}" ]]; then
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" mkdir -p "${custom_plugins_dir}"
        else
            mkdir -p "${custom_plugins_dir}"
        fi
    fi

    # Function to install a custom plugin
    function install_custom_plugin() {
        local plugin_name="$1"
        local plugin_repo="$2"
        local plugin_dir="${custom_plugins_dir}/${plugin_name}"

        # Skip if already installed
        if [[ -d "${plugin_dir}" ]]; then
            log_info "Plugin ${plugin_name} already installed"
            return 0
        fi

        log_info "Installing plugin: ${plugin_name}"
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" git clone "https://github.com/${plugin_repo}" "${plugin_dir}"
        else
            git clone "https://github.com/${plugin_repo}" "${plugin_dir}"
        fi

        if [[ ! -d "${plugin_dir}" ]]; then
            log_warning "Failed to install plugin: ${plugin_name}"
            return 1
        fi

        return 0
    }

    # Install custom plugins
    install_custom_plugin "zsh-autosuggestions" "zsh-users/zsh-autosuggestions"
    install_custom_plugin "zsh-syntax-highlighting" "zsh-users/zsh-syntax-highlighting"
    install_custom_plugin "zsh-completions" "zsh-users/zsh-completions"
    install_custom_plugin "zsh-history-substring-search" "zsh-users/zsh-history-substring-search"

    # Update plugins in .zshrc
    log_info "Updating plugins in .zshrc"

    # Define the new plugins line with essential plugins for development
    local plugins_line="plugins=(git docker docker-compose npm node vscode history extract z zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)"

    # Update plugins in .zshrc
    if [[ -n "${SUDO_USER}" ]]; then
        sudo -u "${SUDO_USER}" sed -i 's/^plugins=.*/'"${plugins_line}"'/g' "${user_home}/.zshrc"
    else
        sed -i 's/^plugins=.*/'"${plugins_line}"'/g' "${user_home}/.zshrc"
    fi

    # Make sure the completions are properly configured
    if ! grep -q "autoload -U compinit && compinit" "${user_home}/.zshrc"; then
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" bash -c "echo '
# Load completions
autoload -U compinit && compinit' >> \"${user_home}/.zshrc\""
        else
            echo '
# Load completions
autoload -U compinit && compinit' >> "${user_home}/.zshrc"
        fi
    fi

    log_success "ZSH plugins installed and configured successfully"
    set_state "${SCRIPT_NAME}_plugins_installed"
    return 0
}

# Configure ZSH with Starship prompt
function configure_zsh_prompt() {
    log_step "Configuring ZSH prompt"

    if check_state "${SCRIPT_NAME}_zsh_prompt_configured"; then
        log_info "ZSH prompt already configured. Skipping..."
        return 0
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Check if Oh My Zsh is installed
    if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
        log_error "Oh My Zsh is not installed. Cannot configure prompt."
        return 1
    fi

    # Check if starship is installed and configured
    if command -v starship &> /dev/null && [[ -f "${user_home}/.config/starship.toml" ]]; then
        log_info "Starship prompt is installed and configured"
        log_info "Setting ZSH_THEME to an empty string to use starship instead"

        # Replace ZSH_THEME in .zshrc with an empty theme
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME=""/g' "${user_home}/.zshrc"
        else
            sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME=""/g' "${user_home}/.zshrc"
        fi

        # Make sure starship is initialized in .zshrc
        if ! grep -q "eval \"\$(starship init zsh)\"" "${user_home}/.zshrc"; then
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" bash -c "echo '
# Initialize starship prompt
eval \"\$(starship init zsh)\"' >> \"${user_home}/.zshrc\""
            else
                echo "
# Initialize starship prompt
eval \"\$(starship init zsh)\"" >> "${user_home}/.zshrc"
            fi
        fi

        log_success "ZSH configured to use starship prompt"
    else
        # Update the .zshrc file to use a simple theme
        log_info "Setting 'agnoster' as default theme in .zshrc"

        # Replace ZSH_THEME in .zshrc
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "${user_home}/.zshrc"
        else
            sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "${user_home}/.zshrc"
        fi

        log_info "If you prefer to use starship prompt later, install it using the install_starship function"
    fi

    set_state "${SCRIPT_NAME}_zsh_prompt_configured"
    log_success "ZSH prompt configured successfully"
    return 0
}

# Set ZSH as default shell
function set_zsh_default() {
    log_step "Setting ZSH as default shell"

    if check_state "${SCRIPT_NAME}_default_shell_set"; then
        log_info "ZSH is already set as default shell. Skipping..."
        return 0
    fi

    # Check if ZSH is already the default shell
    if is_zsh_default_shell; then
        log_info "ZSH is already the default shell"
        set_state "${SCRIPT_NAME}_default_shell_set"
        return 0
    fi

    # Check if the script is run in interactive mode
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Do you want to set ZSH as your default shell?" "y"; then
            log_info "Skipping setting ZSH as default shell by user request"
            return 0
        fi
    fi

    # Get user who will have their shell changed
    local target_user
    # Use proper if-then-else instead of ternary-like expression
    if [[ -n "${SUDO_USER}" ]]; then
        target_user="${SUDO_USER}"
    else
        target_user=$(whoami)
    fi

    # Get zsh path separately to avoid masking return value
    local zsh_path
    zsh_path=$(command -v zsh) || true

    # Check if zsh is in /etc/shells
    if ! grep -q "${zsh_path}" /etc/shells; then
        log_info "Adding ZSH to /etc/shells"
        echo "${zsh_path}" >> /etc/shells
    fi

    # Change the default shell
    log_info "Changing default shell to ZSH for user ${target_user}"
    if ! chsh -s "${zsh_path}" "${target_user}"; then
        log_error "Failed to set ZSH as default shell"
        log_info "You can manually set ZSH as default shell using: chsh -s ${zsh_path}"
        return 1
    fi

    log_success "ZSH set as default shell for user ${target_user}"
    set_state "${SCRIPT_NAME}_default_shell_set"
    log_warning "You'll need to log out and back in for the shell change to take effect"
    return 0
}

# Configure ZSH settings with useful customizations
function configure_zsh_settings() {
    log_step "Configuring additional ZSH settings"

    if check_state "${SCRIPT_NAME}_settings_configured"; then
        log_info "Additional ZSH settings already configured. Skipping..."
        return 0
    fi

    # Get user's home directory
    local user_home
    user_home=$(get_user_home)

    # Create a custom settings file
    local custom_settings="${user_home}/.zshrc.custom"
    local custom_settings_tmp="${user_home}/.zshrc.custom.tmp"

    log_info "Creating custom ZSH settings"

    cat > "${custom_settings_tmp}" << 'EOF'
# Custom ZSH settings for development environment

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Navigation improvements
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Completion improvements
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt COMPLETE_IN_WORD
unsetopt MENU_COMPLETE
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt clean'
alias zreload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'

# Development aliases
alias g='git'
alias gc='git commit -m'
alias gs='git status'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gcb='git checkout -b'
alias ga='git add'
alias gaa='git add .'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dcrestart='docker-compose restart'
alias dclogs='docker-compose logs -f'

# Node.js aliases
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias ns='npm start'
alias nt='npm test'
alias nr='npm run'
alias nb='npm run build'
alias nd='npm run dev'

# Add custom bin directories to PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# NVM setup (if installed)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF

    # Move the temporary file to the actual location with correct permissions
    if [[ -n "${SUDO_USER}" ]]; then
        mv "${custom_settings_tmp}" "${custom_settings}"
        chown "${SUDO_USER}:${SUDO_USER}" "${custom_settings}"
    else
        mv "${custom_settings_tmp}" "${custom_settings}"
    fi

    # Source custom settings in .zshrc if not already present
    if ! grep -q "source ~/.zshrc.custom" "${user_home}/.zshrc"; then
        if [[ -n "${SUDO_USER}" ]]; then
            sudo -u "${SUDO_USER}" bash -c "echo '
# Source custom settings
[[ ! -f ~/.zshrc.custom ]] || source ~/.zshrc.custom' >> \"${user_home}/.zshrc\""
        else
            echo '
# Source custom settings
[[ ! -f ~/.zshrc.custom ]] || source ~/.zshrc.custom' >> "${user_home}/.zshrc"
        fi
    fi

    set_state "${SCRIPT_NAME}_settings_configured"
    log_success "Additional ZSH settings configured successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_terminal_tools() {
    log_section "Installing Terminal Tools and ZSH Environment"

    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Terminal tools and ZSH environment setup has already been completed. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install terminal utilities
    if ! install_terminal_utilities; then
        log_error "Failed to install core terminal utilities"
        return 1
    fi

    # Install search tools
    if ! install_search_tools; then
        log_warning "Failed to install some search tools"
        # Continue anyway as these are not critical
    fi

    # Create symbolic links
    if ! create_symbolic_links; then
        log_warning "Failed to create some symbolic links"
        # Continue anyway as these are not critical
    fi

    # Configure tmux
    if ! configure_tmux; then
        log_warning "Failed to configure tmux"
        # Continue anyway as this is not critical
    fi

    # Install Starship prompt
    if ! install_starship; then
        log_warning "Failed to install Starship prompt"
        # Continue anyway as this is not critical
    fi

    # Install ZSH
    if ! install_zsh; then
        log_error "Failed to install ZSH shell"
        return 1
    fi

    # Install Oh My Zsh
    if ! install_oh_my_zsh; then
        log_warning "Failed to install Oh My Zsh"
        # Continue anyway as this is not critical
    fi

    # Install ZSH plugins
    if ! install_zsh_plugins; then
        log_warning "Failed to install some ZSH plugins"
        # Continue anyway as these are not critical
    fi

    # Configure ZSH prompt
    if ! configure_zsh_prompt; then
        log_warning "Failed to configure ZSH prompt"
        # Continue anyway as this is not critical
    fi

    # Configure ZSH settings
    if ! configure_zsh_settings; then
        log_warning "Failed to configure some ZSH settings"
        # Continue anyway as these are not critical
    fi

    # Set ZSH as default shell
    if ! set_zsh_default; then
        log_warning "Failed to set ZSH as default shell"
        # Continue anyway as this is not critical
    fi

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Terminal tools and ZSH environment setup completed successfully"

    log_info "Note: Some changes require a new terminal session or system login to take effect"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
setup_terminal_tools

# Return the exit code
exit $?
