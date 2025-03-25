#!/usr/bin/env bash
# ============================================================================
# 03-terminal-enhancements.sh
# ----------------------------------------------------------------------------
# Installs terminal utilities and enhancements for a better CLI experience
# Includes tools like tmux, ranger, btop, ripgrep, fzf, bat, fd-find, etc.
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${FORCE_MODE:=false}"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="03-terminal-enhancements"

# ============================================================================
# Utility Installation Functions
# ============================================================================

# Install terminal utilities (multiplexers, file managers, etc.)
function install_terminal_utilities() {
    log_step "Installing core terminal utilities"
    
    if check_state "${SCRIPT_NAME}_core_utils_installed"; then
        log_info "Core terminal utilities already installed. Skipping..."
        return 0
    fi
    
    # Terminal multiplexers
    log_info "Installing terminal multiplexers"
    local terminal_multiplexers=(
        tmux
        screen
    )
    
    if ! apt_install "${terminal_multiplexers[@]}"; then
        log_error "Failed to install terminal multiplexers"
        return 1
    fi
    
    # File managers
    log_info "Installing terminal file managers"
    local file_managers=(
        mc    # Midnight Commander
        ranger # Vim-inspired file manager
        nnn   # Fast and lightweight file manager
    )
    
    if ! apt_install "${file_managers[@]}"; then
        log_warning "Failed to install some file managers"
        # Continue anyway as these are not critical
    fi
    
    # System monitoring tools
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
    
    if ! apt_install "${monitoring_tools[@]}"; then
        log_warning "Failed to install some system monitoring tools"
        # Continue anyway as these are not critical
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
    
    # Search tools
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
    
    if ! apt_install "${search_tools[@]}"; then
        log_warning "Failed to install some search tools"
        # Continue anyway as these are not critical
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
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_home="${HOME}"
    fi
    
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
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_home="${HOME}"
    fi
    
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
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_home="${HOME}"
    fi
    
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
    
    # Configure Starship for ZSH if installed
    log_info "Checking for ZSH installation"
    local zsh_rc="${user_home}/.zshrc"
    if command -v zsh &> /dev/null && [[ -f "${zsh_rc}" ]]; then
        log_info "Configuring Starship for ZSH"
        
        # Check if Starship is already configured in .zshrc
        if ! grep -q "starship init zsh" "${zsh_rc}"; then
            # Add Starship initialization to .zshrc
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" bash -c "echo -e '\n# Initialize Starship prompt\neval \"\$(starship init zsh)\"' >> \"${zsh_rc}\""
            else
                # shellcheck disable=SC2016
                echo -e '\n# Initialize Starship prompt\neval "$(starship init zsh)"' >> "${zsh_rc}"
            fi
            log_info "Added Starship initialization to .zshrc"
        else
            log_info "Starship already configured in .zshrc"
        fi
    else
        log_info "ZSH not installed or .zshrc not found, skipping ZSH configuration"
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
# Main Function
# ============================================================================

function install_terminal_enhancements() {
    log_section "Installing Terminal Enhancements"
    
    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Terminal enhancements have already been installed. Use --force to reinstall."
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
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Terminal enhancements installed successfully"
    
    log_info "Note: Some changes require a new terminal session to take effect"
    
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
install_terminal_enhancements

# Return the exit code
exit $?
