#!/usr/bin/env bash
# ============================================================================
# 06-communication.sh
# ----------------------------------------------------------------------------
# Installs communication applications including Zoom, Slack, and Zoiper
# Configures application settings and directories
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
SCRIPT_NAME="06-communication"

# ============================================================================
# Installation Functions
# ============================================================================

# Install Zoom video conferencing
function install_zoom() {
    log_step "Installing Zoom"

    if check_state "${SCRIPT_NAME}_zoom_installed"; then
        log_info "Zoom is already installed. Skipping..."
        return 0
    fi

    # Check if already installed
    if dpkg -l | grep -q "zoom"; then
        log_info "Zoom is already installed via package manager"
        set_state "${SCRIPT_NAME}_zoom_installed"
        return 0
    fi

    # Create temporary directory for download
    # Declare first, then assign to avoid masking return values
    local temp_dir
    temp_dir=$(mktemp -d) || true
    local zoom_deb="${temp_dir}/zoom_amd64.deb"

    # Download Zoom
    log_info "Downloading Zoom..."
    if ! wget -q "https://zoom.us/client/latest/zoom_amd64.deb" -O "${zoom_deb}"; then
        log_error "Failed to download Zoom"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Install Zoom
    log_info "Installing Zoom..."
    if ! dpkg -i "${zoom_deb}" 2>/dev/null; then
        log_warning "Fixing Zoom installation dependencies..."
        if ! apt_fix_broken; then
            log_error "Failed to fix Zoom dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi

        # Try again after fixing dependencies
        if ! dpkg -i "${zoom_deb}" 2>/dev/null; then
            log_error "Failed to install Zoom after fixing dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi
    fi

    # Clean up
    rm -rf "${temp_dir}"

    # Verify installation
    if command -v zoom &>/dev/null || [[ -f "/usr/bin/zoom" ]]; then
        log_success "Zoom installed successfully"
        set_state "${SCRIPT_NAME}_zoom_installed"
        return 0
    else
        log_error "Zoom installation verification failed"
        return 1
    fi
}

# Install Slack using snap
function install_slack() {
    log_step "Installing Slack"

    if check_state "${SCRIPT_NAME}_slack_installed"; then
        log_info "Slack is already installed. Skipping..."
        return 0
    fi

    # Check if snap is installed
    if ! command -v snap &>/dev/null; then
        log_info "Installing snap package manager..."
        if ! apt_install snapd; then
            log_error "Failed to install snap package manager"
            return 1
        fi
    fi

    # Check if Slack is already installed via Snap
    if snap list 2>/dev/null | grep -q "slack"; then
        log_info "Slack is already installed via snap"
        set_state "${SCRIPT_NAME}_slack_installed"
        return 0
    fi

    # Install Slack via Snap
    log_info "Installing Slack via Snap..."
    if ! snap install slack; then
        log_error "Failed to install Slack"
        return 1
    fi

    # Verify installation
    if snap list 2>/dev/null | grep -q "slack"; then
        log_success "Slack installed successfully"
        set_state "${SCRIPT_NAME}_slack_installed"
        return 0
    else
        log_error "Slack installation verification failed"
        return 1
    fi
}

# Install Zoiper VoIP softphone
function install_zoiper() {
    log_step "Installing Zoiper VoIP softphone"

    if check_state "${SCRIPT_NAME}_zoiper_installed"; then
        log_info "Zoiper is already installed. Skipping..."
        return 0
    fi

    # Check if already installed
    if dpkg -l | grep -q "zoiper5"; then
        log_info "Zoiper is already installed via package manager"
        set_state "${SCRIPT_NAME}_zoiper_installed"
        return 0
    fi

    # Create temporary directory for download
    # Declare first, then assign to avoid masking return values
    local temp_dir
    temp_dir=$(mktemp -d) || true
    local zoiper_deb="${temp_dir}/zoiper5.deb"

    # Download Zoiper
    log_info "Downloading Zoiper5..."
    if ! wget -q "https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb" -O "${zoiper_deb}"; then
        log_error "Failed to download Zoiper5"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Install Zoiper
    log_info "Installing Zoiper5..."
    if ! dpkg -i "${zoiper_deb}" 2>/dev/null; then
        log_warning "Fixing Zoiper5 installation dependencies..."
        if ! apt_fix_broken; then
            log_error "Failed to fix Zoiper5 dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi

        # Try again after fixing dependencies
        if ! dpkg -i "${zoiper_deb}" 2>/dev/null; then
            log_error "Failed to install Zoiper5 after fixing dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi
    fi

    # Clean up
    rm -rf "${temp_dir}"

    # Verify installation (zoiper might not be in PATH, so check for the .desktop file)
    if [[ -f "/usr/share/applications/zoiper5.desktop" ]]; then
        log_success "Zoiper5 installed successfully"
        set_state "${SCRIPT_NAME}_zoiper_installed"
        return 0
    else
        log_error "Zoiper5 installation verification failed"
        return 1
    fi
}

# Create configuration directories
function create_config_directories() {
    log_step "Creating configuration directories"

    if check_state "${SCRIPT_NAME}_config_dirs_created"; then
        log_info "Configuration directories already created. Skipping..."
        return 0
    fi

    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_home="${HOME}"
    fi

    # Create config directories for applications
    mkdir -p "${user_home}/.config/zoomus"
    mkdir -p "${user_home}/.config/Slack"

    # Set proper permissions if running as sudo
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/zoomus"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/Slack"
    fi

    set_state "${SCRIPT_NAME}_config_dirs_created"
    log_success "Configuration directories created successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_communication_apps() {
    log_section "Installing Communication Applications"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Communication applications have already been installed. Skipping..."
        return 0
    fi

    # Install prerequisites
    log_step "Installing prerequisites"
    local dependencies=(
        wget
        apt-transport-https
        gnupg2
        snapd
    )

    if ! apt_install "${dependencies[@]}"; then
        log_error "Failed to install dependencies"
        return 1
    fi

    # Install communication applications
    install_zoom || log_warning "Zoom installation encountered issues"
    install_slack || log_warning "Slack installation encountered issues"
    install_zoiper || log_warning "Zoiper installation encountered issues"

    # Create configuration directories
    create_config_directories || log_warning "Failed to create configuration directories"

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Communication applications installed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Call the main function
install_communication_apps

# Return the exit code
exit $?
