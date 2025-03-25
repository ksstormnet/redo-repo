#!/usr/bin/env bash
# ============================================================================
# 00-kde-install.sh
# ----------------------------------------------------------------------------
# Installs and configures the KDE Plasma desktop environment
# Provides options for minimal, standard, or full installation
# Configures display manager and session settings
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
SCRIPT_NAME="00-kde-install"

# Default installation type
KDE_INSTALLATION_TYPE="minimal"  # Options: minimal, standard, full
SKIP_SDDM=false

# Default values for variables that might be referenced but not assigned
: "${INTERACTIVE:=false}"
: "${FORCE_MODE:=false}"
: "${STATE_DIR:=/var/cache/system-installer}"

# ============================================================================
# Command Line Argument Processing
# ============================================================================

# Display help information
function show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Install KDE Plasma desktop environment"
    echo
    echo "Options:"
    echo "  --minimal       Install minimal KDE Plasma desktop (default)"
    echo "  --standard      Install standard KDE Plasma desktop"
    echo "  --full          Install full KDE Plasma desktop with all KDE applications"
    echo "  --no-sddm       Do not install SDDM display manager"
    echo "  --help          Display this help message and exit"
    echo
}

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --minimal)
                KDE_INSTALLATION_TYPE="minimal"
                shift
                ;;
            --standard)
                KDE_INSTALLATION_TYPE="standard"
                shift
                ;;
            --full)
                KDE_INSTALLATION_TYPE="full"
                shift
                ;;
            --no-sddm)
                SKIP_SDDM=true
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
    log_info "Selected KDE installation type: ${KDE_INSTALLATION_TYPE}"
    if [[ "${SKIP_SDDM}" == "true" ]]; then
        log_info "SDDM installation will be skipped"
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

# Install minimal KDE Plasma desktop
function install_kde_plasma_minimal() {
    log_step "Installing minimal KDE Plasma desktop environment"
    
    if check_state "${SCRIPT_NAME}_minimal_installed"; then
        log_info "Minimal KDE Plasma desktop already installed. Skipping..."
        return 0
    fi
    
    # Core Plasma desktop packages
    local minimal_packages=(
        plasma-desktop
        plasma-nm
        plasma-pa
        kscreen
        dolphin
        konsole
        systemsettings
        kinfocenter
        kde-config-screenlocker
        kde-config-sddm
        kde-config-gtk-style
        powerdevil
        bluedevil
        khotkeys
        kmenuedit
    )
    
    # Install the packages
    if ! apt_install "${minimal_packages[@]}"; then
        log_error "Failed to install minimal KDE Plasma packages"
        return 1
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_minimal_installed"
    log_success "Minimal KDE Plasma desktop installed successfully"
    return 0
}

# Install standard KDE Plasma desktop
function install_kde_plasma_standard() {
    log_step "Installing standard KDE Plasma desktop environment"
    
    if check_state "${SCRIPT_NAME}_standard_installed"; then
        log_info "Standard KDE Plasma desktop already installed. Skipping..."
        return 0
    fi
    
    # Install minimal first if needed
    if ! check_state "${SCRIPT_NAME}_minimal_installed"; then
        if ! install_kde_plasma_minimal; then
            log_error "Failed to install minimal KDE Plasma desktop"
            return 1
        fi
    fi
    
    # Standard Plasma desktop additional packages
    local standard_packages=(
        plasma-widgets-addons
        plasma-wallpapers-addons
        kwin-addons
        kdeplasma-addons
        kubuntu-wallpapers
        gwenview
        okular
        ark
        kate
        yakuake
        discover
        plasma-discover-backend-snap
        plasma-discover-backend-flatpak
        print-manager
        kdeconnect
        plasma-browser-integration
        breeze-gtk-theme
        kde-spectacle
    )
    
    # Install the packages
    if ! apt_install "${standard_packages[@]}"; then
        log_error "Failed to install standard KDE Plasma packages"
        return 1
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_standard_installed"
    log_success "Standard KDE Plasma desktop installed successfully"
    return 0
}

# Install full KDE Plasma desktop
function install_kde_plasma_full() {
    log_step "Installing full KDE Plasma desktop environment"
    
    if check_state "${SCRIPT_NAME}_full_installed"; then
        log_info "Full KDE Plasma desktop already installed. Skipping..."
        return 0
    fi
    
    # Install standard first if needed
    if ! check_state "${SCRIPT_NAME}_standard_installed"; then
        if ! install_kde_plasma_standard; then
            log_error "Failed to install standard KDE Plasma desktop"
            return 1
        fi
    fi
    
    # Full Plasma desktop additional packages
    local full_packages=(
        kde-full
        elisa
        k3b
        kamoso
        kdegames-card-data-kf5
        kolourpaint
        kpat
        kruler
        kteatime
        kdegraphics
        kdegames
        kdeutils
        kmail
        kontact
        korganizer
        akregator
        kaddressbook
        kwrite
        konversation
        krfb
        krdc
        plasma-workspace-wayland
        sddm-theme-breeze
    )
    
    # Install the packages
    if ! apt_install "${full_packages[@]}"; then
        log_error "Failed to install full KDE Plasma packages"
        return 1
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_full_installed"
    log_success "Full KDE Plasma desktop installed successfully"
    return 0
}

# Install and configure SDDM display manager
function install_sddm() {
    if [[ "${SKIP_SDDM}" == "true" ]]; then
        log_info "Skipping SDDM installation as requested"
        return 0
    fi
    
    log_step "Installing and configuring SDDM display manager"
    
    if check_state "${SCRIPT_NAME}_sddm_installed"; then
        log_info "SDDM already installed and configured. Skipping..."
        return 0
    fi
    
    # Install SDDM display manager
    if ! apt_install sddm sddm-theme-breeze; then
        log_error "Failed to install SDDM"
        return 1
    fi
    
    # Set SDDM as default display manager
    log_info "Setting SDDM as default display manager"
    
    # Backup existing configuration
    if [[ -f /etc/X11/default-display-manager ]]; then
        cp /etc/X11/default-display-manager /etc/X11/default-display-manager.backup
    fi
    
    # Use debconf to configure SDDM as default display manager
    echo "/usr/bin/sddm" > /etc/X11/default-display-manager
    
    # Configure debconf to set SDDM as default display manager
    echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections
    
    # Reconfigure display manager packages
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure sddm
    
    # Check if any other display managers are installed and reconfigure them
    for dm in gdm3 lightdm xdm; do
        if dpkg -l | grep -q "^ii  ${dm} "; then
            echo "${dm} shared/default-x-display-manager select sddm" | debconf-set-selections
            DEBIAN_FRONTEND=noninteractive dpkg-reconfigure "${dm}"
        fi
    done
    
    # Create SDDM config directory if it doesn't exist
    mkdir -p /etc/sddm.conf.d/
    
    # Configure SDDM with better defaults
    cat > /etc/sddm.conf.d/kde_settings.conf << EOF
[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000

[X11]
ServerArguments=-nolisten tcp

[Wayland]
EnableHiDPI=true

[Autologin]
Relogin=false
Session=plasma
EOF
    
    # Enable SDDM service
    systemctl enable sddm.service
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_sddm_installed"
    log_success "SDDM installed and configured successfully"
    return 0
}

# Configure Plasma defaults
function configure_plasma_defaults() {
    log_step "Configuring KDE Plasma default settings"
    
    if check_state "${SCRIPT_NAME}_defaults_configured"; then
        log_info "KDE Plasma defaults already configured. Skipping..."
        return 0
    fi
    
    # Create default look-and-feel settings
    mkdir -p /etc/skel/.config
    
    # Set default session to Plasma
    if [[ -d /usr/share/xsessions ]]; then
        # Create session defaults file
        cat > /etc/skel/.dmrc << EOF
[Desktop]
Session=plasma
EOF
    fi
    
    # Set default plasma theme
    mkdir -p /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
    cat > /etc/skel/.config/kdeglobals << EOF
[KDE]
LookAndFeelPackage=org.kde.breeze.desktop
SingleClick=false

[General]
ColorScheme=BreezeLight
EOF
    
    # Set default icon theme
    mkdir -p /etc/skel/.config/kdedefaults
    cat > /etc/skel/.config/kdedefaults/kdeglobals << EOF
[Icons]
Theme=breeze
EOF
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_defaults_configured"
    log_success "KDE Plasma default settings configured successfully"
    return 0
}

# Remove unwanted KDE packages
function remove_unwanted_kde_packages() {
    log_step "Removing unwanted KDE packages"
    
    if check_state "${SCRIPT_NAME}_unwanted_removed"; then
        log_info "Unwanted KDE packages already removed. Skipping..."
        return 0
    fi
    
    # List of packages to remove
    local unwanted_packages=(
        kmail
        kontact
        kaddressbook
        korganizer
        akregator
        dragonplayer
        k3b
        kamoso
        kmahjongg
        kmines
        ksudoku
        konversation
        kopete
    )
    
    # Check if packages are installed before trying to remove them
    local packages_to_remove=()
    
    for pkg in "${unwanted_packages[@]}"; do
        if dpkg -l | grep -q "^ii  ${pkg} "; then
            packages_to_remove+=("${pkg}")
        fi
    done
    
    if [[ ${#packages_to_remove[@]} -gt 0 ]]; then
        log_info "Removing ${#packages_to_remove[@]} unwanted KDE packages"
        
        # Remove the packages
        if ! apt-get remove -y "${packages_to_remove[@]}"; then
            log_warning "Failed to remove some unwanted KDE packages"
        else
            # Mark packages as manually removed so they don't get reinstalled
            apt-mark auto "${packages_to_remove[@]}" || true
            
            # Make sure no orphaned dependencies remain
            apt-get autoremove -y
            
            log_success "Unwanted KDE packages removed successfully"
        fi
    else
        log_info "No unwanted KDE packages found to remove"
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_unwanted_removed"
    return 0
}

# Fix KDE network detection issues
function fix_kde_networking() {
    log_step "Fixing KDE network detection issues"
    
    if check_state "${SCRIPT_NAME}_network_fixed"; then
        log_info "KDE network detection issues already fixed. Skipping..."
        return 0
    fi
    
    # 1. Ensure NetworkManager is installed and enabled
    log_info "Ensuring NetworkManager is installed and enabled"
    if ! apt_install network-manager; then
        log_warning "Failed to install NetworkManager"
    fi
    
    # Enable and start NetworkManager
    systemctl enable NetworkManager
    systemctl start NetworkManager
    
    # 2. Ensure KDE Network Management widgets are installed
    log_info "Ensuring KDE Network Management widgets are installed"
    if ! apt_install plasma-nm; then
        log_warning "Failed to install plasma-nm"
    fi
    
    # 3. Configure NetworkManager as primary network manager
    log_info "Configuring NetworkManager as primary network manager"
    mkdir -p /etc/NetworkManager
    
    # Create or update NetworkManager.conf
    cat > /etc/NetworkManager/NetworkManager.conf << EOF
[main]
managed=true
EOF
    
    # Restart NetworkManager to apply changes
    systemctl restart NetworkManager
    
    # 4. Check for competing network services
    log_info "Checking for competing network services"
    
    # Check if systemd-networkd is active
    if systemctl is-active --quiet systemd-networkd; then
        log_info "Disabling systemd-networkd in favor of NetworkManager"
        systemctl stop systemd-networkd
        systemctl disable systemd-networkd
    fi
    
    # 5. Update netplan configuration if it exists
    if [[ -d /etc/netplan ]]; then
        log_info "Updating netplan configuration to use NetworkManager"
        
        # Create a NetworkManager netplan configuration
        cat > /etc/netplan/01-network-manager-all.yaml << EOF
# Let NetworkManager manage all devices
network:
  version: 2
  renderer: NetworkManager
EOF
        
        # Apply netplan configuration
        netplan apply || log_warning "Failed to apply netplan configuration"
    fi
    
    # 6. Ensure packagekit service is enabled for Discover
    log_info "Ensuring packagekit service is enabled for Discover"
    systemctl enable packagekit
    systemctl start packagekit
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_network_fixed"
    log_success "KDE network detection issues fixed successfully"
    return 0
}

# Add KDE Backports PPA for newer packages
function add_kde_backports() {
    log_step "Adding KDE Backports PPA"
    
    if check_state "${SCRIPT_NAME}_backports_added"; then
        log_info "KDE Backports PPA already added. Skipping..."
        return 0
    fi
    
    # Add the KDE Backports PPA if available for this Ubuntu version
    log_info "Adding Kubuntu Backports PPA"
    if ! add_apt_repository -y ppa:kubuntu-ppa/backports; then
        log_warning "Failed to add Kubuntu Backports PPA. This may not be available for your Ubuntu version."
        # Continue anyway as this is optional
    else
        # Update package lists after adding PPA
        apt_update
        log_success "Kubuntu Backports PPA added successfully"
        set_state "${SCRIPT_NAME}_backports_added"
    fi
    
    return 0
}

# ============================================================================
# Main Installation Function
# ============================================================================

function install_kde_plasma() {
    log_section "Installing KDE Plasma Desktop Environment"
    
    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "KDE Plasma desktop environment has already been installed. Skipping..."
        
        # Offer to force reinstallation in interactive mode
        if [[ "${INTERACTIVE}" == "true" ]]; then
            if prompt_yes_no "Force reinstallation of KDE Plasma desktop?"; then
                log_info "Forcing reinstallation of KDE Plasma desktop"
                
                # Clear relevant states to force reinstallation
                for state in "${SCRIPT_NAME}_minimal_installed" "${SCRIPT_NAME}_standard_installed" "${SCRIPT_NAME}_full_installed" "${SCRIPT_NAME}_sddm_installed" "${SCRIPT_NAME}_defaults_configured" "${SCRIPT_NAME}_completed"; do
                    reset_step "${state}"
                done
            else
                return 0
            fi
        else
            return 0
        fi
    fi
    
    # Add KDE Backports PPA
    add_kde_backports
    
    # Ensure system is up to date
    log_step "Updating package lists"
    apt_update
    
    # Install KDE Plasma based on installation type
    case "${KDE_INSTALLATION_TYPE}" in
        minimal)
            log_info "Installing minimal KDE Plasma desktop environment"
            install_kde_plasma_minimal
            ;;
        standard)
            log_info "Installing standard KDE Plasma desktop environment"
            install_kde_plasma_standard
            ;;
        full)
            log_info "Installing full KDE Plasma desktop environment"
            install_kde_plasma_full
            ;;
        *)
            log_error "Unknown installation type: ${KDE_INSTALLATION_TYPE}"
            exit 1
            ;;
    esac
    
    # Install and configure SDDM
    install_sddm
    
    # Configure default session and appearance
    configure_plasma_defaults
    
    # Remove unwanted packages
    remove_unwanted_kde_packages
    
    # Fix KDE network detection issues
    fix_kde_networking
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "KDE Plasma desktop environment installed successfully"
    
    # Set reboot flag since desktop environment needs a restart
    touch "${STATE_DIR}/reboot_required"
    log_warning "A system reboot is required to start using KDE Plasma"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Parse command line arguments
parse_args "$@"

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_kde_plasma

# Return the exit code
exit $?
