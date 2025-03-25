#!/usr/bin/env bash
# ============================================================================
# 00-common-utilities.sh
# ----------------------------------------------------------------------------
# Installs essential utilities and system tools for daily use
# Uses dependency management to prevent duplicate package installations
# ============================================================================
# shellcheck disable=SC2312,SC2154
# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

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
SCRIPT_NAME="00-common-utilities"

# Register packages that may be installed by earlier scripts
function register_previously_installed_packages() {
    # Skip if dependency management is not available
    if ! command -v register_packages &> /dev/null; then
        return 0
    fi

    # Core packages typically installed by 01-init scripts
    local core_packages=(
        git
        curl
        wget
        htop
        net-tools
        rsync
        apt-transport-https
        ca-certificates
        gnupg
        software-properties-common
    )

    # Register these as already installed
    register_packages "essential" "${core_packages[@]}"
    log_debug "Registered core packages that might already be installed"
}

# ============================================================================
# Installation Functions
# ============================================================================

# Install system utilities
function install_system_utilities() {
    log_section "Installing System Utilities"

    if check_state "${SCRIPT_NAME}_system_utilities_installed"; then
        log_info "System utilities already installed. Skipping..."
        return 0
    fi

    # Register packages that may already be installed
    register_previously_installed_packages

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install system utilities
    log_step "Installing essential system utilities"
    local system_utilities=(
        glances
        neofetch
        inxi
        lm-sensors
        smartmontools
        iotop
        iftop
        dnsutils
        whois
        traceroute
        nmap
        rclone
        unzip
        zip
        gdebi
        gnupg2
    )

    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${system_utilities[@]}"; then
            log_error "Failed to install essential system utilities"
            return 1
        fi
    else
        if ! apt_install "${system_utilities[@]}"; then
            log_error "Failed to install essential system utilities"
            return 1
        fi
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_system_utilities_installed"
    log_success "Essential system utilities installed successfully"

    return 0
}

# Install file management utilities
function install_file_utilities() {
    log_section "Installing File Management Utilities"

    if check_state "${SCRIPT_NAME}_file_utilities_installed"; then
        log_info "File management utilities already installed. Skipping..."
        return 0
    fi

    # Install file management utilities
    log_step "Installing file management utilities"
    local file_utilities=(
        dolphin-plugins
        kio-extras
        kio-gdrive
        kio-fuse
        ark
        krename
        kfind
        kdiff3
        filelight
        baobab
        meld
    )

    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${file_utilities[@]}"; then
            log_error "Failed to install file management utilities"
            return 1
        fi
    else
        if ! apt_install "${file_utilities[@]}"; then
            log_error "Failed to install file management utilities"
            return 1
        fi
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_file_utilities_installed"
    log_success "File management utilities installed successfully"

    return 0
}

# Install network utilities
function install_network_utilities() {
    log_section "Installing Network Utilities"

    if check_state "${SCRIPT_NAME}_network_utilities_installed"; then
        log_info "Network utilities already installed. Skipping..."
        return 0
    fi

    # Register openssh-server if it might have been installed by earlier scripts
    if command -v register_package &> /dev/null; then
        register_package "openssh-server" "network"
        register_package "openssh-client" "network"
        register_package "sshfs" "network"
    fi

    # Install network utilities
    log_step "Installing network utilities"
    local network_utilities=(
        openssh-client
        openssh-server
        filezilla
        sshfs
        network-manager-openvpn
        network-manager-vpnc
        network-manager-openconnect
        krdc
        krfb
        remmina
        remmina-plugin-rdp
        remmina-plugin-vnc
    )

    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "network" "${network_utilities[@]}"; then
            log_error "Failed to install network utilities"
            return 1
        fi
    else
        if ! apt_install "${network_utilities[@]}"; then
            log_error "Failed to install network utilities"
            return 1
        fi
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_network_utilities_installed"
    log_success "Network utilities installed successfully"

    return 0
}

# Install hardware utilities
function install_hardware_utilities() {
    log_section "Installing Hardware Utilities"

    if check_state "${SCRIPT_NAME}_hardware_utilities_installed"; then
        log_info "Hardware utilities already installed. Skipping..."
        return 0
    fi

    # Install hardware utilities
    log_step "Installing hardware utilities"
    local hardware_utilities=(
        hwinfo
        lshw
        usbutils
        pciutils
        nvme-cli
        hdparm
        gparted
        partitionmanager
        gnome-disk-utility
        system-config-printer
        blueman
        pulseaudio-module-bluetooth
        tlp
        powertop
    )

    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${hardware_utilities[@]}"; then
            log_error "Failed to install hardware utilities"
            return 1
        fi
    else
        if ! apt_install "${hardware_utilities[@]}"; then
            log_error "Failed to install hardware utilities"
            return 1
        fi
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_hardware_utilities_installed"
    log_success "Hardware utilities installed successfully"

    return 0
}

# Install terminal utilities
function install_terminal_utilities() {
    log_section "Installing Terminal Utilities"

    if check_state "${SCRIPT_NAME}_terminal_utilities_installed"; then
        log_info "Terminal utilities already installed. Skipping..."
        return 0
    fi

    # Register terminal packages that might be installed by other scripts
    if command -v register_package &> /dev/null; then
        register_package "zsh" "utilities"
        register_package "tmux" "utilities"
    fi

    # Install terminal utilities
    log_step "Installing terminal utilities"
    local terminal_utilities=(
        yakuake
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

    # Use smart install if available
    if command -v smart_install_packages &> /dev/null; then
        if ! smart_install_packages "utilities" "${terminal_utilities[@]}"; then
            log_error "Failed to install terminal utilities"
            return 1
        fi
    else
        if ! apt_install "${terminal_utilities[@]}"; then
            log_error "Failed to install terminal utilities"
            return 1
        fi
    fi

    # Create symlinks for tools with different names in Ubuntu
    log_step "Creating symlinks for terminal tools"

    # Create local bin directory if it doesn't exist
    mkdir -p /usr/local/bin

    # Create symlink for bat (batcat in Ubuntu)
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi

    # Create symlink for fd (fdfind in Ubuntu)
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_terminal_utilities_installed"
    log_success "Terminal utilities installed successfully"

    return 0
}

# ============================================================================
# Configuration Functions
# ============================================================================

# Configure zsh for user
function configure_zsh() {
    log_section "Configuring Zsh Shell"

    if check_state "${SCRIPT_NAME}_zsh_configured"; then
        log_info "Zsh already configured. Skipping..."
        return 0
    fi

    # Check if 09-terminal-tools has already configured ZSH
    if check_state "09-terminal-tools_zsh_installed" || check_state "09-terminal-tools_ohmyzsh_installed"; then
        log_info "ZSH already configured by terminal-tools script. Skipping duplicate configuration."
        set_state "${SCRIPT_NAME}_zsh_configured"
        return 0
    fi

    # Detect main user account
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Skipping Zsh configuration."
        return 0
    fi

    local user_home="/home/${main_user}"

    # Install oh-my-zsh if not already installed
    log_step "Installing Oh My Zsh for ${main_user}"

    if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
        # Clone oh-my-zsh repository
        sudo -u "${main_user}" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        # Check if installation was successful
        if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
            log_warning "Failed to install Oh My Zsh. Skipping Zsh configuration."
            return 0
        fi

        log_info "Oh My Zsh installed successfully"
    else
        log_info "Oh My Zsh already installed"
    fi

    # Configure zsh plugins
    log_step "Configuring Zsh plugins"

    # Backup existing .zshrc if it exists
    if [[ -f "${user_home}/.zshrc" ]]; then
        sudo -u "${main_user}" cp "${user_home}/.zshrc" "${user_home}/.zshrc.backup"
    fi

    # Create .zshrc with customizations
    cat > "${user_home}/.zshrc.tmp" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(
  git
  docker
  docker-compose
  composer
  npm
  node
  python
  pip
  sudo
  history
  z
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load Oh-My-Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt clean'
alias zshconfig='nano ~/.zshrc'
alias ohmyzsh='nano ~/.oh-my-zsh'
alias path='echo $PATH | tr ":" "\n"'

# Auto start tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# Check for custom configuration
if [ -f ~/.zshrc.local ]; then
  source ~/.zshrc.local
fi
EOF

    # Replace .zshrc
    sudo -u "${main_user}" mv "${user_home}/.zshrc.tmp" "${user_home}/.zshrc"

    # Change default shell to zsh for user if it isn't already
    log_step "Setting zsh as default shell for ${main_user}"

    local current_shell
    current_shell=$(getent passwd "${main_user}" | cut -d: -f7)
    if [[ "${current_shell}" != *"zsh"* ]]; then
        chsh -s "$(command -v zsh)" "${main_user}"
        log_info "Default shell changed to zsh for ${main_user}"
    else
        log_info "Default shell is already zsh for ${main_user}"
    fi

    # Install zsh-autosuggestions plugin if not already installed
    if [[ ! -d "${user_home}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
        sudo -u "${main_user}" git clone https://github.com/zsh-users/zsh-autosuggestions.git "${user_home}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    fi

    # Install zsh-syntax-highlighting plugin if not already installed
    if [[ ! -d "${user_home}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        sudo -u "${main_user}" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${user_home}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_zsh_configured"
    log_success "Zsh shell configured successfully"

    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function install_common_utilities() {
    log_section "Installing Common Utilities"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Common utilities have already been installed. Skipping..."
        return 0
    fi

    # Install system utilities
    if ! install_system_utilities; then
        log_error "Failed to install system utilities"
        return 1
    fi

    # Install file management utilities
    if ! install_file_utilities; then
        log_warning "Failed to install file management utilities"
        # Continue anyway
    fi

    # Install network utilities
    if ! install_network_utilities; then
        log_warning "Failed to install network utilities"
        # Continue anyway
    fi

    # Install hardware utilities
    if ! install_hardware_utilities; then
        log_warning "Failed to install hardware utilities"
        # Continue anyway
    fi

    # Install terminal utilities
    if ! install_terminal_utilities; then
        log_warning "Failed to install terminal utilities"
        # Continue anyway
    fi

    # Configure zsh
    if ! configure_zsh; then
        log_warning "Failed to configure zsh"
        # Continue anyway
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Common utilities installation completed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_common_utilities

# Return the exit code
exit $?
