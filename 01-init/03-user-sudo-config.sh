#!/bin/bash
# ============================================================================
# 03-user-sudo-config.sh
# ----------------------------------------------------------------------------
# Configures the user "scott" for passwordless sudo and sets up the root password
# This script should be run with root privileges
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

# Script name for state management and logging
SCRIPT_NAME="03-user-sudo-config"

# Default to interactive mode if not set
: "${INTERACTIVE:=true}"

# ============================================================================
# User/Sudo Configuration Functions
# ============================================================================

# Configure passwordless sudo for user scott
function configure_passwordless_sudo() {
    log_section "Configuring Passwordless Sudo for User 'scott'"

    if check_state "${SCRIPT_NAME}_passwordless_sudo_configured"; then
        log_info "Passwordless sudo already configured. Skipping..."
        return 0
    fi

    # Check if user exists
    if ! id -u scott &>/dev/null; then
        log_error "User 'scott' does not exist. Please create the user first."
        return 1
    fi

    # Create the sudoers.d directory if it doesn't exist
    if [[ ! -d "/etc/sudoers.d" ]]; then
        log_step "Creating /etc/sudoers.d directory"
        mkdir -p /etc/sudoers.d
        chmod 750 /etc/sudoers.d
    fi

    # Create the sudoers file for user scott
    log_step "Creating sudoers file for user 'scott'"
    echo "scott ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/scott
    chmod 440 /etc/sudoers.d/scott

    # Verify the syntax of the sudoers file
    log_step "Verifying sudoers file syntax"
    if command -v visudo &>/dev/null; then
        if ! visudo -c -f /etc/sudoers.d/scott; then
            log_error "Sudoers file syntax check failed. Removing the file."
            rm -f /etc/sudoers.d/scott
            return 1
        fi
    else
        log_warning "visudo command not found. Skipping syntax check."
    fi

    log_success "Passwordless sudo configured for user 'scott'"
    set_state "${SCRIPT_NAME}_passwordless_sudo_configured"
    return 0
}

# Set the root password
function set_root_password() {
    log_section "Setting Root Password"

    if check_state "${SCRIPT_NAME}_root_password_set"; then
        log_info "Root password already set. Skipping..."
        return 0
    fi

    # Set the root password interactively or non-interactively
    if [[ "${INTERACTIVE}" == "true" ]]; then
        log_step "Setting root password interactively"
        passwd root
    else
        # Use a default password for non-interactive mode
        # IMPORTANT: This is insecure and should be changed in production
        log_step "Setting root password non-interactively"
        local default_password="AdminPassword123!"
        echo "root:${default_password}" | chpasswd

        log_warning "Default root password set to: ${default_password}"
        log_warning "Please change this password immediately for security reasons!"
    fi

    log_success "Root password has been set"
    set_state "${SCRIPT_NAME}_root_password_set"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_user_sudo() {
    log_section "Setting Up User and Sudo Configuration"

    # Configure passwordless sudo for user scott
    if ! configure_passwordless_sudo; then
        log_error "Failed to configure passwordless sudo for user 'scott'"
        return 1
    fi

    # Set the root password
    if ! set_root_password; then
        log_error "Failed to set root password"
        return 1
    fi

    log_success "User sudo configuration completed successfully"
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize the script
initialize

# Check for root privileges
check_root

# Run the main function
setup_user_sudo

# Return the exit code
exit $?
