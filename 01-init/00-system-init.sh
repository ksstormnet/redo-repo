#!/bin/bash
# ============================================================================
# 00-system-init.sh
# ----------------------------------------------------------------------------
# Entry point for the system installation process
# This script initializes the environment, restores critical configurations,
# and prepares the system for subsequent installation steps.
# Uses dependency management to track and prevent duplicate package installations
# ============================================================================

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
else
    echo "WARNING: dependency-utils.sh library not found at ${LIB_DIR}"
    # Continue anyway as dependency management is optional for this script
fi

# INTERACTIVE may be set in common.sh, but set a default if not
: "${INTERACTIVE:=false}"

# ============================================================================
# System Verification Function
# ============================================================================
function verify_system_compatibility() {
    log_section "Verifying System Compatibility"

    # Check Ubuntu version
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        log_error "This script requires Ubuntu 24.04"
        return 1
    fi

    # Check for minimum disk space (20GB free)
    local free_space
    free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//') || true
    if [[ ${free_space} -lt 20 ]]; then
        log_error "Insufficient disk space. At least 20GB required, but only ${free_space}GB available."
        return 1
    fi

    # Check for internet connectivity
    if ! is_internet_connected; then
        log_error "No internet connectivity detected"
        return 1
    fi

    log_success "System compatibility check passed"
    return 0
}

# ============================================================================
# Create Necessary Directories
# ============================================================================
function create_directories() {
    log_section "Creating System Directories"

    local user_home
    user_home=$(get_user_home)

    # Create essential directories
    log_step "Creating essential user directories"
    local essential_dirs=(
        "${user_home}/.config"
        "${user_home}/.local/bin"
        "${user_home}/.local/share"
        "${user_home}/Projects"
        "${user_home}/Downloads/installers"
    )

    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_info "Creating directory: ${dir}"
            mkdir -p "${dir}"
        else
            log_debug "Directory already exists: ${dir}"
        fi
    done

    # Fix permissions if running as sudo
    if [[ -n "${SUDO_USER}" ]]; then
        log_step "Setting correct permissions"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.local"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/Projects"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/Downloads"
    fi

    log_success "Directories created successfully"
    return 0
}

# ============================================================================
# Install Essential Packages
# ============================================================================
function install_essential_packages() {
    log_section "Installing Essential Packages"

    if check_state "essential_packages_installed"; then
        log_info "Essential packages already installed. Skipping..."
        return 0
   fi

    # List of essential packages for basic functionality
    local essential_packages=(
        rsync
        git
        curl
        wget
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        software-properties-common
        python3-pip
        htop
        net-tools
    )

    log_step "Installing essential packages"
    if ! apt_install "${essential_packages[@]}"; then
        log_error "Failed to install essential packages"
        return 1
    fi

    # Register these packages in dependency system if available
    if command -v init_dependency_tracking &> /dev/null; then
        # Initialize dependency tracking
        init_dependency_tracking

        # Register the essential packages we just installed
        log_debug "Registering essential packages in dependency system"
        register_packages "essential" "${essential_packages[@]}"
    fi

    set_state "essential_packages_installed"
    log_success "Essential packages installed successfully"
    return 0
}

# ============================================================================
# Configuration Restoration Functions
# ============================================================================

# Function to fix permissions and ownership of restored files
function fix_permissions_and_ownership() {
    log_step "Fixing permissions and ownership"

    local user_home
    user_home=$(get_user_home)

    # Set correct permissions for SSH files
    if [[ -d "${user_home}/.ssh" ]]; then
        log_info "Setting correct permissions for SSH files"
        chmod 700 "${user_home}/.ssh"
        find "${user_home}/.ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
        find "${user_home}/.ssh" -type f -name "*.pub" -exec chmod 644 {} \;
        find "${user_home}/.ssh" -type f -name "config" -exec chmod 600 {} \;
        find "${user_home}/.ssh" -type f -name "known_hosts" -exec chmod 600 {} \;
    fi

    # Set correct ownership if running as sudo
    if [[ -n "${SUDO_USER}" ]]; then
        # Fix ownership of critical directories and files
        log_info "Setting correct ownership for user directories"
        local critical_dirs=(
            "${user_home}/.ssh"
            "${user_home}/.config"
            "${user_home}/.local"
        )

        for dir in "${critical_dirs[@]}"; do
            if [[ -d "${dir}" ]]; then
                chown -R "${SUDO_USER}:${SUDO_USER}" "${dir}"
            fi
        done

        local critical_files=(
            "${user_home}/.gitconfig"
            "${user_home}/.git-credentials"
            "${user_home}/.zshrc"
            "${user_home}/.bashrc"
            "${user_home}/.bash_profile"
            "${user_home}/.profile"
        )

        for file in "${critical_files[@]}"; do
            if [[ -f "${file}" ]]; then
                chown "${SUDO_USER}:${SUDO_USER}" "${file}"
            fi
        done
    fi

    log_success "Permissions and ownership fixed successfully"
    return 0
}

# Function to restore critical configurations from backup
function restore_critical_configs() {
    log_section "Restoring Critical Configurations"

    if check_state "critical_configs_restored"; then
        log_info "Critical configurations already restored. Skipping..."
        return 0
    fi

    local config_backup_dir="/restart/config-backup"
    local user_home
    user_home=$(get_user_home)

    # Check if the backup directory exists
    if [[ ! -d "${config_backup_dir}" ]]; then
        log_warning "Backup directory ${config_backup_dir} not found. Skipping configuration restoration."
        return 1
    fi

    # Only create a backup if this is the first run of the script
    log_step "Checking for existing critical configurations"

    # Only backup what's needed and hasn't been backed up before
    local need_backup=false

    for path in ".ssh" ".gitconfig" ".zshrc" ".bashrc"; do
        if [[ -e "${user_home}/${path}" && ! -e "${user_home}/${path}.pre-restore" ]]; then
            need_backup=true
            break
        fi
    done

    if [[ "${need_backup}" == "true" ]]; then
        log_info "Backing up existing critical configurations with .pre-restore suffix"

        # Backup only if the file exists and doesn't have a backup already
        for path in ".ssh" ".gitconfig" ".zshrc" ".bashrc"; do
            if [[ -e "${user_home}/${path}" && ! -e "${user_home}/${path}.pre-restore" ]]; then
                if [[ -d "${user_home}/${path}" ]]; then
                    cp -a "${user_home}/${path}" "${user_home}/${path}.pre-restore"
                else
                    cp "${user_home}/${path}" "${user_home}/${path}.pre-restore"
                fi
                log_info "Created backup: ${user_home}/${path}.pre-restore"
            fi
        done
    else
        log_info "No existing critical configurations to backup"
    fi

    # Define critical paths to restore
    log_step "Restoring critical configuration files"
    local critical_paths=(
        "/home/scott/.ssh/"
        "/home/scott/.gitconfig"
        "/home/scott/.zshrc"
        "/home/scott/.bashrc"
        "/home/scott/.profile"
    )

    # Use rsync to copy only critical files (quietly)
    for path in "${critical_paths[@]}"; do
        local source_path="${config_backup_dir}${path}"
        if [[ -e "${source_path}" ]]; then
            log_info "Restoring ${path}"
            if ! rsync -q -a "${source_path}" "${path}" 2>/dev/null; then
                log_warning "Failed to restore ${path}"
            fi
        else
            log_debug "Backup for ${path} not found in ${config_backup_dir}"
        fi
    done

    log_success "All configurations restored from ${config_backup_dir}"

    # Fix ownership for user files
    log_step "Setting correct ownership for user files"
    if [[ -d "/home/scott" ]]; then
        chown -R scott:scott /home/scott
        log_info "Set ownership of /home/scott to scott:scott"
    fi

    # Set correct permissions and ownership
    fix_permissions_and_ownership

    # Mark as completed
    set_state "critical_configs_restored"
    log_success "Critical configurations restored successfully"
    return 0
}

# ============================================================================
# SSH Setup Function
# ============================================================================
function setup_ssh() {
    log_section "Setting Up SSH"

    if check_state "ssh_setup_completed"; then
        log_info "SSH already set up. Skipping..."
        return 0
    fi

    local user_home
    user_home=$(get_user_home)

    # First check if SSH keys exist in the backup location
    local backup_ssh_dir="/restart/config-backup/home/scott/.ssh"
    if [[ -d "${backup_ssh_dir}" ]] && [[ -f "${backup_ssh_dir}/id_rsa" || -f "${backup_ssh_dir}/id_ed25519" ]]; then
        log_step "Found SSH keys in backup location"

        # Ensure SSH directory exists with correct permissions
        if [[ ! -d "${user_home}/.ssh" ]]; then
            mkdir -p "${user_home}/.ssh"
        fi

        # Copy SSH keys from backup
        log_info "Restoring SSH keys from backup"
        if ! rsync -q -a "${backup_ssh_dir}/" "${user_home}/.ssh/" 2>/dev/null; then
            log_warning "Failed to restore SSH keys from backup, will generate new ones"
        else
            log_success "SSH keys restored from backup"

            # Set correct permissions
            chmod 700 "${user_home}/.ssh"
            find "${user_home}/.ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
            find "${user_home}/.ssh" -type f -name "*.pub" -exec chmod 644 {} \;
            find "${user_home}/.ssh" -type f -name "config" -exec chmod 600 {} \;
            find "${user_home}/.ssh" -type f -name "known_hosts" -exec chmod 600 {} \;

            # Set correct ownership if running as sudo
            if [[ -n "${SUDO_USER}" ]]; then
                chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.ssh"
            fi

            # We have restored the keys, so we can skip the key generation
            goto_ssh_service_setup=true
        fi
    else
        log_info "No SSH keys found in backup location"
        goto_ssh_service_setup=false
    fi

    # If we didn't restore keys from backup, proceed with normal setup
    if [[ "${goto_ssh_service_setup}" != "true" ]]; then
        # Ensure SSH directory exists with correct permissions
        if [[ ! -d "${user_home}/.ssh" ]]; then
            log_step "Creating SSH directory"
            mkdir -p "${user_home}/.ssh"
            chmod 700 "${user_home}/.ssh"

            if [[ -n "${SUDO_USER}" ]]; then
                chown "${SUDO_USER}:${SUDO_USER}" "${user_home}/.ssh"
            fi
        fi

        # Check for existing SSH keys
        log_step "Checking for existing SSH keys"
        if [[ ! -f "${user_home}/.ssh/id_rsa" && ! -f "${user_home}/.ssh/id_ed25519" ]]; then
            log_warning "No SSH keys found. Creating a new SSH key."

            # Get hostname for SSH key comment
            local hostname_str
            hostname_str=$(hostname) || true

            # Create a new SSH key
            if [[ -n "${SUDO_USER}" ]]; then
                # Run as the actual user
                log_command "Creating new SSH key" "sudo -u \"${SUDO_USER}\" ssh-keygen -t ed25519 -f \"${user_home}/.ssh/id_ed25519\" -N \"\" -C \"${SUDO_USER}@${hostname_str}\""
            else
                # Get current user for SSH key comment
                local whoami_str
                whoami_str=$(whoami) || true

                log_command "Creating new SSH key" "ssh-keygen -t ed25519 -f \"${user_home}/.ssh/id_ed25519\" -N \"\" -C \"${whoami_str}@${hostname_str}\""
            fi

            log_info "New SSH key created:"
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" cat "${user_home}/.ssh/id_ed25519.pub"
            else
                cat "${user_home}/.ssh/id_ed25519.pub"
            fi

            log_warning "Please add this key to your GitHub/GitLab account before continuing."

            # Ask user to confirm they've added the key
            if [[ "${INTERACTIVE}" == "true" ]]; then
                if ! prompt_yes_no "Have you added the SSH key to your accounts?" "n"; then
                    log_error "SSH key must be added to proceed with git operations"
                    return 1
                fi
            fi
        else
            log_info "Found existing SSH keys"
        fi
    fi

    # Ensure SSH service is running
    log_step "Ensuring SSH service is running"
    if ! is_service_running ssh; then
        log_info "Starting SSH service"
        systemctl start ssh
        systemctl enable ssh
    else
        log_info "SSH service is already running"
    fi

    set_state "ssh_setup_completed"
    log_success "SSH setup completed successfully"
    return 0
}

# ============================================================================
# Console Setup Function
# ============================================================================
function configure_console() {
    log_section "Configuring Console Font and Settings"

    if check_state "console_setup_completed"; then
        log_info "Console already configured. Skipping..."
        return 0
    fi

    # Install console-setup package if not already installed
    log_step "Ensuring console-setup is installed"
    if ! dpkg -l console-setup &>/dev/null; then
        if ! apt_install console-setup; then
            log_warning "Failed to install console-setup"
            return 1
        fi
    fi

    # Configure console setup interactively if in interactive mode
    if [[ "${INTERACTIVE}" == "true" ]]; then
        log_step "Running interactive console setup"
        log_info "Please select your preferred font size and other console settings in the dialog."
        if ! dpkg-reconfigure console-setup; then
            log_warning "Console setup configuration failed"
            return 1
        fi
    else
        log_step "Setting console font to a larger size for better readability"
        # Set non-interactive environment variable
        export DEBIAN_FRONTEND=noninteractive
        # Set a larger console font non-interactively
        cat > /etc/default/console-setup << EOF
# Console font and keymap setup
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Lat15"
FONTFACE="Terminus"
FONTSIZE="12x24"
VIDEOMODE=
EOF
        # Apply settings
        if ! setupcon --force; then
            log_warning "Failed to apply console settings"
            # Continue anyway
        fi
    fi

    set_state "console_setup_completed"
    log_success "Console configuration completed successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function init_system() {
    log_section "Initializing Installation Environment"

    # Verify system compatibility first, exit if not compatible
    if ! verify_system_compatibility; then
        log_error "System verification failed. Cannot continue installation."
        return 1
    fi

    # Restore critical configs FIRST - before any other setup
    if ! restore_critical_configs; then
        log_warning "Failed to restore critical configurations, continuing anyway"
        # Non-fatal error, continue
    fi

    # Update system
    log_step "Updating system packages"
    if ! apt_update; then
        log_error "Failed to update system packages"
        return 1
    fi

    # Install essential packages
    if ! install_essential_packages; then
        log_error "Failed to install essential packages"
        return 1
    fi

    # Create directories
    if ! create_directories; then
        log_error "Failed to create necessary directories"
        return 1
    fi

    # Configure console font and settings
    if ! configure_console; then
        log_warning "Failed to configure console, continuing anyway"
        # Non-fatal error, continue
    fi

    # Setup SSH - only if not already set up from restored configs
    if ! check_state "ssh_setup_completed"; then
        if ! setup_ssh; then
            log_warning "Failed to complete SSH setup, continuing anyway"
            # Non-fatal error, continue
        fi
    else
        log_info "SSH already set up from restored configurations. Skipping SSH setup."
    fi

    log_success "System initialization completed successfully!"
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize the script
initialize

# Run the main function
init_system

# Return the exit code
exit $?
