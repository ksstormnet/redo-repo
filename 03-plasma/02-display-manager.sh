#!/usr/bin/env bash
# ============================================================================
# 02-display-manager.sh
# ----------------------------------------------------------------------------
# Installs and configures the SDDM display manager for KDE Plasma
# Sets up auto-login and theme customization
# ============================================================================

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

# Script name for state management and logging
SCRIPT_NAME="02-display-manager"

# Default values
ENABLE_AUTOLOGIN=false
AUTOLOGIN_USER=""

# ============================================================================
# Command Line Argument Processing
# ============================================================================

# Display help information
function show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure SDDM display manager for KDE Plasma"
    echo
    echo "Options:"
    echo "  --autologin=USER   Enable automatic login for USER"
    echo "  --help             Display this help message and exit"
    echo
}

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --autologin=*)
                ENABLE_AUTOLOGIN=true
                AUTOLOGIN_USER="${1#*=}"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Log selected options
    if [[ "${ENABLE_AUTOLOGIN}" == "true" ]]; then
        log_info "Automatic login will be enabled for user: ${AUTOLOGIN_USER}"
    fi
}

# ============================================================================
# SDDM Installation Functions
# ============================================================================

# Install SDDM display manager
function install_sddm() {
    log_section "Installing SDDM Display Manager"
    
    if check_state "${SCRIPT_NAME}_sddm_installed"; then
        log_info "SDDM already installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install SDDM and related packages
    log_step "Installing SDDM packages"
    local sddm_packages=(
        sddm
        sddm-theme-breeze
        kde-config-sddm
    )
    
    if ! apt_install "${sddm_packages[@]}"; then
        log_error "Failed to install SDDM packages"
        return 1
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_sddm_installed"
    log_success "SDDM display manager installed successfully"
    
    return 0
}

# Configure SDDM display manager
function configure_sddm() {
    log_section "Configuring SDDM Display Manager"
    
    if check_state "${SCRIPT_NAME}_sddm_configured"; then
        log_info "SDDM already configured. Skipping..."
        return 0
    fi
    
    # Create SDDM configuration directory if it doesn't exist
    log_step "Creating SDDM configuration directory"
    mkdir -p /etc/sddm.conf.d
    
    # Create main SDDM configuration file
    log_step "Creating SDDM configuration file"
    cat > /etc/sddm.conf.d/00-kde-studio.conf << EOF
[Theme]
Current=breeze
CursorTheme=breeze_cursors
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MaximumUid=60000
MinimumUid=1000

[X11]
ServerArguments=-nolisten tcp
EnableHiDPI=true

[Wayland]
EnableHiDPI=true

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=on
EOF
    
    # Configure autologin if requested
    if [[ "${ENABLE_AUTOLOGIN}" == "true" && -n "${AUTOLOGIN_USER}" ]]; then
        log_step "Configuring automatic login for user: ${AUTOLOGIN_USER}"
        
        # Verify user exists
        if id "${AUTOLOGIN_USER}" &>/dev/null; then
            # Create autologin configuration
            cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=${AUTOLOGIN_USER}
Session=plasma
Relogin=false
EOF
            log_success "Automatic login configured for user: ${AUTOLOGIN_USER}"
        else
            log_warning "User ${AUTOLOGIN_USER} does not exist. Skipping autologin configuration."
        fi
    fi
    
    # Set SDDM as default display manager
    log_step "Setting SDDM as default display manager"
    
    # Check if we have any other display managers installed
    local other_dm_installed=false
    for dm in gdm3 lightdm xdm; do
        if dpkg -l | grep -q "^ii  ${dm} "; then
            other_dm_installed=true
            break
        fi
    done
    
    # If another display manager is installed, use debconf to set SDDM as default
    if [[ "${other_dm_installed}" == "true" ]]; then
        log_info "Other display managers detected. Using debconf to set SDDM as default."
        
        # Use debconf to set SDDM as default
        echo "/usr/bin/sddm" > /etc/X11/default-display-manager
        echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections
        
        # Reconfigure display manager packages
        for dm in sddm gdm3 lightdm xdm; do
            if dpkg -l | grep -q "^ii  ${dm} "; then
                echo "${dm} shared/default-x-display-manager select sddm" | debconf-set-selections
                DEBIAN_FRONTEND=noninteractive dpkg-reconfigure "${dm}" || true
            fi
        done
    else
        # Just set SDDM as default directly
        echo "/usr/bin/sddm" > /etc/X11/default-display-manager
    fi
    
    # Enable SDDM service
    log_info "Enabling SDDM service"
    systemctl enable sddm
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_sddm_configured"
    log_success "SDDM display manager configured successfully"
    
    return 0
}

# ============================================================================
# Theme Configuration
# ============================================================================

# Configure SDDM theme
function configure_sddm_theme() {
    log_section "Configuring SDDM Theme"
    
    if check_state "${SCRIPT_NAME}_theme_configured"; then
        log_info "SDDM theme already configured. Skipping..."
        return 0
    fi
    
    # Ensure the Breeze theme is installed
    log_step "Ensuring Breeze theme is installed"
    if ! apt_install sddm-theme-breeze; then
        log_warning "Failed to install Breeze theme for SDDM"
        # Continue anyway as the default theme might still work
    fi
    
    # Create avatar icons directory for users
    log_step "Setting up avatar icons for users"
    local faces_dir="/usr/share/sddm/faces"
    mkdir -p "${faces_dir}"
    
    # Find all local users with home directories
    local users=()
    while IFS=: read -r username _ userid _ _ homedir _; do
        if [[ "${userid}" -ge 1000 && "${userid}" -lt 60000 && -d "${homedir}" ]]; then
            users+=("${username}")
        fi
    done < /etc/passwd
    
    # Create default avatar symlinks for users
    for user in "${users[@]}"; do
        if [[ ! -f "${faces_dir}/${user}.face.icon" ]]; then
            log_info "Creating avatar symlink for user: ${user}"
            ln -sf "/usr/share/sddm/faces/.face.icon" "${faces_dir}/${user}.face.icon"
        fi
    done
    
    # Copy default avatar icon if it doesn't exist
    if [[ ! -f "${faces_dir}/.face.icon" ]]; then
        # Try to find a default avatar from various locations
        local default_avatar=""
        for avatar in "/usr/share/pixmaps/faces/user_icon.png" "/usr/share/icons/breeze/places/64/user-identity.svg"; do
            if [[ -f "${avatar}" ]]; then
                default_avatar="${avatar}"
                break
            fi
        done
        
        if [[ -n "${default_avatar}" ]]; then
            log_info "Copying default avatar from: ${default_avatar}"
            cp "${default_avatar}" "${faces_dir}/.face.icon"
        else
            log_warning "Could not find a default avatar icon"
        fi
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_theme_configured"
    log_success "SDDM theme configured successfully"
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_display_manager() {
    log_section "Setting Up Display Manager"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Display manager has already been set up. Skipping..."
        return 0
    fi
    
    # Install SDDM
    if ! install_sddm; then
        log_error "Failed to install SDDM display manager"
        return 1
    fi
    
    # Configure SDDM
    if ! configure_sddm; then
        log_warning "Failed to configure SDDM display manager"
        # Continue anyway as basic functionality should still work
    fi
    
    # Configure SDDM theme
    if ! configure_sddm_theme; then
        log_warning "Failed to configure SDDM theme"
        # Continue anyway as this is not critical
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Display manager setup completed successfully"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Parse command line arguments
parse_args "$@"

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
setup_display_manager

# Return the exit code
exit $?
