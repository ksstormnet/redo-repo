#!/usr/bin/env bash
# ============================================================================
# 05-zsh-shell-setup.sh
# ----------------------------------------------------------------------------
# Installs and configures ZSH shell with Oh My Zsh, Powerlevel10k theme,
# and useful plugins for enhanced productivity
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

# Script name for state management and logging
SCRIPT_NAME="05-zsh-shell-setup"

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
# Installation Functions
# ============================================================================

# Install ZSH and dependencies
function install_zsh() {
    log_step "Installing ZSH shell"
    
    if check_state "${SCRIPT_NAME}_zsh_installed"; then
        log_info "ZSH is already installed. Skipping..."
        return 0
    fi
    
    # Install ZSH and required dependencies
    local zsh_packages=(
        zsh
        zsh-syntax-highlighting
        zsh-autosuggestions
        fonts-powerline
        git
        curl
        wget
    )
    
    log_info "Installing ZSH and dependencies"
    if ! apt_install "${zsh_packages[@]}"; then
        log_error "Failed to install ZSH and dependencies"
        return 1
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

# Set a simple theme instead of Powerlevel10k
function set_simple_theme() {
    log_step "Setting up ZSH theme"
    
    if check_state "${SCRIPT_NAME}_theme_configured"; then
        log_info "ZSH theme is already configured. Skipping..."
        return 0
    fi
    
    # Get user's home directory
    local user_home
    user_home=$(get_user_home)
    
    # Check if Oh My Zsh is installed
    if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
        log_error "Oh My Zsh is not installed. Cannot configure theme."
        return 1
    fi
    
    # Check if starship is installed and configured
    if command -v starship &> /dev/null && [[ -f "${user_home}/.config/starship.toml" ]]; then
        log_info "Starship prompt is already installed and configured"
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
        
        log_info "If you prefer to use starship prompt, install it and create a starship.toml configuration file"
    fi
    
    set_state "${SCRIPT_NAME}_theme_configured"
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

# Configure ZSH for root user
function setup_root_zsh() {
    log_step "Setting up ZSH for root user"
    
    if check_state "${SCRIPT_NAME}_root_zsh_setup"; then
        log_info "ZSH for root user is already set up. Skipping..."
        return 0
    fi
    
    # Check if ZSH is installed
    if ! command -v zsh &> /dev/null; then
        log_error "ZSH is not installed. Cannot set up for root user."
        return 1
    fi
    
    # Install Oh My Zsh for root if not already installed
    if [[ ! -d "/root/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh for root user"
        
        # Get the installer script separately to avoid masking return value
        local installer_script
        installer_script=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) || true
        
        # Install for root
        sh -c "${installer_script}" "" --unattended
        
        if [[ ! -d "/root/.oh-my-zsh" ]]; then
            log_warning "Failed to install Oh My Zsh for root user"
            return 1
        fi
    else
        log_info "Oh My Zsh is already installed for root user"
    fi
    
    # Set simple theme for root
    if [[ -f "/root/.zshrc" ]]; then
        log_info "Setting 'agnoster' as default theme in root's .zshrc"
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' "/root/.zshrc"
    fi
    
    # Create custom settings for root
    log_info "Creating custom ZSH settings for root user"
    
    cat > "/root/.zshrc.custom" << 'EOF'
# Custom ZSH settings for root user

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
alias update='apt update && apt upgrade -y'
alias cleanup='apt autoremove -y && apt clean'
alias zreload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'

# Add custom bin directories to PATH
export PATH="/usr/local/bin:$PATH"
export PATH="/root/bin:$PATH"

# Set a red prompt for root to distinguish from regular user
export PS1="%F{red}%n@%m%f:%F{blue}%~%f# "
EOF
    
    # Source custom settings in root's .zshrc if not already present
    if [[ -f "/root/.zshrc" ]] && ! grep -q "source ~/.zshrc.custom" "/root/.zshrc"; then
        echo '
# Source custom settings
[[ ! -f ~/.zshrc.custom ]] || source ~/.zshrc.custom' >> "/root/.zshrc"
    fi
    
    # Set ZSH as default shell for root
    local zsh_path
    zsh_path=$(command -v zsh) || true
    
    # Check if zsh is in /etc/shells
    if ! grep -q "${zsh_path}" /etc/shells; then
        log_info "Adding ZSH to /etc/shells"
        echo "${zsh_path}" >> /etc/shells
    fi
    
    # Change the default shell for root
    log_info "Changing default shell to ZSH for root user"
    if ! chsh -s "${zsh_path}" root; then
        log_warning "Failed to set ZSH as default shell for root"
        log_info "You can manually set ZSH as default shell for root using: chsh -s ${zsh_path} root"
    else
        log_success "ZSH set as default shell for root user"
    fi
    
    set_state "${SCRIPT_NAME}_root_zsh_setup"
    log_success "ZSH setup for root user completed successfully"
    return 0
}

# Configure additional ZSH settings
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

# Python aliases
alias py='python3'
alias pip='pip3'
alias ve='python3 -m venv venv'
alias va='source venv/bin/activate'
alias vd='deactivate'

# PHP aliases
alias composer='php -d memory_limit=-1 /usr/local/bin/composer'
alias cda='composer dump-autoload'
alias ci='composer install'
alias cu='composer update'
alias cr='composer require'

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
            # shellcheck disable=SC2016
            echo '
# Source custom settings
[[ ! -f ~/.zshrc.custom ]] || source ~/.zshrc.custom' >> "${user_home}/.zshrc"
        fi
    fi
    
    log_success "Additional ZSH settings configured successfully"
    set_state "${SCRIPT_NAME}_settings_configured"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_zsh_shell() {
    log_section "Setting Up ZSH Shell Environment"
    
    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "ZSH shell setup has already been completed. Skipping..."
        return 0
    fi
    
    # Install ZSH
    if ! install_zsh; then
        log_error "Failed to install ZSH shell"
        return 1
    fi
    
    # Install Oh My Zsh
    if ! install_oh_my_zsh; then
        log_error "Failed to install Oh My Zsh"
        return 1
    fi
    
    # Set simple theme
    if ! set_simple_theme; then
        log_warning "Failed to set simple theme"
        # Continue anyway as this is not critical
    fi
    
    # Install ZSH plugins
    if ! install_zsh_plugins; then
        log_warning "Failed to install some ZSH plugins"
        # Continue anyway as this is not critical
    fi
    
    # Configure additional ZSH settings
    if ! configure_zsh_settings; then
        log_warning "Failed to configure some ZSH settings"
        # Continue anyway as this is not critical
    fi
    
    # Set ZSH as default shell
    if ! set_zsh_default; then
        log_warning "Failed to set ZSH as default shell"
        # Continue anyway as this is not critical
    fi
    
    # Setup ZSH for root user
    if ! setup_root_zsh; then
        log_warning "Failed to set up ZSH for root user"
        # Continue anyway as this is not critical
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "ZSH shell setup completed successfully"
    
    log_info "Note: You'll need to log out and back in for all changes to take effect"
    
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
setup_zsh_shell

# Return the exit code
exit $?
