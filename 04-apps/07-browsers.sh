#!/usr/bin/env bash
# ============================================================================
# 07-browsers.sh
# ----------------------------------------------------------------------------
# Installs multiple web browsers for development and testing purposes
# Includes Brave, Microsoft Edge, Firefox, and Zen browsers
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
SCRIPT_NAME="07-browsers"

# Common browser dependencies
function register_browser_dependencies() {
    # Skip if dependency management is not available
    if ! command -v register_packages &> /dev/null; then
        return 0
    fi

    # Common browser dependencies
    local browser_deps=(
        apt-transport-https
        ca-certificates
        curl
        gnupg
        wget
    )

    # Register these as essential packages
    register_packages "essential" "${browser_deps[@]}"
    log_debug "Registered common browser dependencies"
}

# ============================================================================
# Browser Installation Functions
# ============================================================================

# Install Brave Browser
function install_brave_browser() {
    log_step "Installing Brave Browser"

    if check_state "${SCRIPT_NAME}_brave_installed"; then
        log_info "Brave Browser is already installed. Skipping..."
        return 0
    fi

    # Check if Brave is already installed
    if check_installed brave-browser; then
        log_info "Brave Browser is already installed via package manager"
        set_state "${SCRIPT_NAME}_brave_installed"
        return 0
    fi

    # Register common browser dependencies
    register_browser_dependencies

    # Add the Brave repository
    log_info "Adding Brave Browser repository"
    if ! curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/brave-browser-archive-keyring.gpg; then
        log_error "Failed to add Brave Browser keyring"
        return 1
    fi

    if ! echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null; then
        log_error "Failed to add Brave Browser repository"
        return 1
    fi

    # Update package lists
    log_info "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists after adding Brave repository"
        return 1
    fi

    # Install Brave Browser using smart install if available
    log_info "Installing Brave Browser package"
    if command -v smart_install &> /dev/null; then
        if ! smart_install brave-browser "browsers"; then
            log_error "Failed to install Brave Browser"
            return 1
        fi
    else
        if ! apt_install brave-browser; then
            log_error "Failed to install Brave Browser"
            return 1
        fi
    fi

    # Verify installation
    if ! command -v brave-browser &> /dev/null; then
        log_error "Brave Browser installation verification failed"
        return 1
    fi

    # Get Brave version for logging
    if command -v brave-browser &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local brave_version
        brave_version=$(brave-browser --version 2>/dev/null | head -n1) || true
        log_success "Brave Browser ${brave_version} installed successfully"
    else
        log_success "Brave Browser installed successfully"
    fi

    set_state "${SCRIPT_NAME}_brave_installed"
    return 0
}

# Install Microsoft Edge
function install_microsoft_edge() {
    log_step "Installing Microsoft Edge"

    if check_state "${SCRIPT_NAME}_edge_installed"; then
        log_info "Microsoft Edge is already installed. Skipping..."
        return 0
    fi

    # Check if Edge is already installed
    if check_installed microsoft-edge-stable; then
        log_info "Microsoft Edge is already installed via package manager"
        set_state "${SCRIPT_NAME}_edge_installed"
        return 0
    fi

    # Register common browser dependencies
    register_browser_dependencies

    # Add the Microsoft Edge repository
    log_info "Adding Microsoft Edge repository"
    if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft-edge.gpg; then
        log_error "Failed to add Microsoft Edge keyring"
        return 1
    fi

    if ! echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null; then
        log_error "Failed to add Microsoft Edge repository"
        return 1
    fi

    # Update package lists
    log_info "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists after adding Microsoft Edge repository"
        return 1
    fi

    # Install Microsoft Edge using smart install if available
    log_info "Installing Microsoft Edge package"
    if command -v smart_install &> /dev/null; then
        if ! smart_install microsoft-edge-stable "browsers"; then
            log_error "Failed to install Microsoft Edge"
            return 1
        fi
    else
        if ! apt_install microsoft-edge-stable; then
            log_error "Failed to install Microsoft Edge"
            return 1
        fi
    fi

    # Verify installation
    if ! command -v microsoft-edge &> /dev/null && ! command -v microsoft-edge-stable &> /dev/null; then
        log_error "Microsoft Edge installation verification failed"
        return 1
    fi

    # Get Edge version for logging
    if command -v microsoft-edge-stable &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local edge_version
        edge_version=$(microsoft-edge-stable --version 2>/dev/null | head -n1) || true
        log_success "Microsoft Edge ${edge_version} installed successfully"
    else
        log_success "Microsoft Edge installed successfully"
    fi

    set_state "${SCRIPT_NAME}_edge_installed"
    return 0
}

# Install Firefox
function install_firefox() {
    log_step "Installing Firefox"

    if check_state "${SCRIPT_NAME}_firefox_installed"; then
        log_info "Firefox is already installed. Skipping..."
        return 0
    fi

    # Check if Firefox is already installed
    if command -v firefox &> /dev/null || check_installed firefox; then
        log_info "Firefox is already installed"
        set_state "${SCRIPT_NAME}_firefox_installed"
        return 0
    fi

    # Register common browser dependencies
    register_browser_dependencies

    # Install Firefox using smart install if available
    log_info "Installing Firefox package"
    if command -v smart_install &> /dev/null; then
        if ! smart_install firefox "browsers"; then
            log_error "Failed to install Firefox"
            return 1
        fi
    else
        if ! apt_install firefox; then
            log_error "Failed to install Firefox"
            return 1
        fi
    fi

    # Verify installation
    if ! command -v firefox &> /dev/null; then
        log_error "Firefox installation verification failed"
        return 1
    fi

    # Get Firefox version for logging
    if command -v firefox &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local firefox_version
        firefox_version=$(firefox --version 2>/dev/null | head -n1) || true
        log_success "Firefox ${firefox_version} installed successfully"
    else
        log_success "Firefox installed successfully"
    fi

    set_state "${SCRIPT_NAME}_firefox_installed"
    return 0
}

# Install Zen Browser
function install_zen_browser() {
    log_step "Installing Zen Browser"

    if check_state "${SCRIPT_NAME}_zen_installed"; then
        log_info "Zen Browser is already installed. Skipping..."
        return 0
    fi

    # Check if Zen Browser is already installed
    if [[ -d "/opt/zen" ]] || [[ -d "${HOME}/.local/share/applications/zen-browser" ]]; then
        log_info "Zen Browser is already installed"
        set_state "${SCRIPT_NAME}_zen_installed"
        return 0
    fi

    # Create a temporary file for the installer script
    # Declare first, then assign to avoid masking return values
    local temp_script
    temp_script=$(mktemp) || true

    # Download the official Zen browser installer script
    log_info "Downloading Zen Browser installer script"
    if ! wget -q "https://updates.zen-browser.app/appimage.sh" -O "${temp_script}"; then
        log_error "Failed to download Zen Browser installer script"
        rm -f "${temp_script}"
        return 1
    fi

    # Add execute permissions to the script
    chmod +x "${temp_script}"

    # Execute the installer script
    log_info "Running Zen Browser installer script"

    # If running as root/sudo, run the installer as the actual user
    if [[ -n "${SUDO_USER}" ]]; then
        if ! sudo -u "${SUDO_USER}" "${temp_script}"; then
            log_error "Failed to install Zen Browser"
            rm -f "${temp_script}"
            return 1
        fi
    else
        if ! "${temp_script}"; then
            log_error "Failed to install Zen Browser"
            rm -f "${temp_script}"
            return 1
        fi
    fi

    # Clean up
    rm -f "${temp_script}"

    log_success "Zen Browser installed successfully"
    set_state "${SCRIPT_NAME}_zen_installed"
    return 0
}

# Create browser profiles for testing (optional)
function create_browser_profiles() {
    log_step "Creating browser testing profiles"

    if check_state "${SCRIPT_NAME}_profiles_created"; then
        log_info "Browser testing profiles already created. Skipping..."
        return 0
    fi

    # Check if this is an interactive session and if the user wants to create profiles
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Would you like to create testing profiles for the browsers?" "n"; then
            log_info "Skipping browser profile creation"
            return 0
        fi
    else
        # In non-interactive mode, skip this optional step
        log_info "Skipping browser profile creation in non-interactive mode"
        return 0
    fi

    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_home="${HOME}"
    fi

    # Function to create a browser launcher with specific profile
    function create_launcher() {
        local browser_name="$1"
        local command="$2"
        local profile_name="$3"
        local icon="$4"

        local launcher_dir="${user_home}/.local/share/applications"
        mkdir -p "${launcher_dir}"

        local launcher_file="${launcher_dir}/${browser_name,,}-${profile_name,,}.desktop"

        cat > "${launcher_file}" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${browser_name} - ${profile_name} Profile
Comment=${browser_name} with ${profile_name} testing profile
Exec=${command}
Icon=${icon}
Terminal=false
Categories=Network;WebBrowser;
EOF

        if [[ -n "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}:${SUDO_USER}" "${launcher_file}"
            chmod +x "${launcher_file}"
        else
            chmod +x "${launcher_file}"
        fi

        log_info "Created launcher for ${browser_name} with ${profile_name} profile"
    }

    # Create Firefox testing profiles
    if command -v firefox &> /dev/null; then
        log_info "Creating Firefox testing profiles"

        # Development profile
        create_launcher "Firefox" "firefox -P Development --no-remote" "Development" "firefox"

        # Testing profile
        create_launcher "Firefox" "firefox -P Testing --no-remote" "Testing" "firefox"
    fi

    # Create Brave testing profiles
    if command -v brave-browser &> /dev/null; then
        log_info "Creating Brave testing profiles"

        # Development profile
        create_launcher "Brave" "brave-browser --user-data-dir=${user_home}/.config/brave-development" "Development" "brave-browser"

        # Testing profile
        create_launcher "Brave" "brave-browser --user-data-dir=${user_home}/.config/brave-testing" "Testing" "brave-browser"
    fi

    # Create Edge testing profiles
    if command -v microsoft-edge-stable &> /dev/null; then
        log_info "Creating Microsoft Edge testing profiles"

        # Development profile
        create_launcher "Edge" "microsoft-edge-stable --user-data-dir=${user_home}/.config/edge-development" "Development" "microsoft-edge"

        # Testing profile
        create_launcher "Edge" "microsoft-edge-stable --user-data-dir=${user_home}/.config/edge-testing" "Testing" "microsoft-edge"
    fi

    set_state "${SCRIPT_NAME}_profiles_created"
    log_success "Browser testing profiles created successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

# Set Microsoft Edge as the default browser
function set_edge_as_default() {
    log_step "Setting Microsoft Edge as the default browser"

    if check_state "${SCRIPT_NAME}_edge_default_set"; then
        log_info "Microsoft Edge is already set as the default browser. Skipping..."
        return 0
    fi

    # Check if Edge is installed
    if ! command -v microsoft-edge-stable &> /dev/null && ! check_installed microsoft-edge-stable; then
        log_warning "Microsoft Edge is not installed. Cannot set as default browser."
        return 1
    fi

    log_info "Setting Microsoft Edge as the default browser system-wide"

    # Set as default for xdg-settings
    if command -v xdg-settings &> /dev/null; then
        xdg-settings set default-web-browser microsoft-edge-stable.desktop
    fi

    # Set as default for MIME types
    if command -v xdg-mime &> /dev/null; then
        # Set for common web MIME types
        xdg-mime default microsoft-edge-stable.desktop x-scheme-handler/http
        xdg-mime default microsoft-edge-stable.desktop x-scheme-handler/https
        xdg-mime default microsoft-edge-stable.desktop text/html
        xdg-mime default microsoft-edge-stable.desktop application/xhtml+xml
    fi

    # Set for KDE specifically if running KDE
    if command -v kwriteconfig5 &> /dev/null; then
        # Set default browser in KDE settings
        kwriteconfig5 --file kdeglobals --group General --key BrowserApplication "microsoft-edge-stable.desktop"
    fi

    # Update alternatives system
    update-alternatives --set x-www-browser /usr/bin/microsoft-edge-stable 2>/dev/null || true
    update-alternatives --set gnome-www-browser /usr/bin/microsoft-edge-stable 2>/dev/null || true

    # Set for all users by updating /etc/xdg
    mkdir -p /etc/xdg/xfce4
    if [[ -d "/etc/xdg/xfce4" ]]; then
        echo "WebBrowser=microsoft-edge-stable" > /etc/xdg/xfce4/helpers.rc
    fi

    # Create a default mimeapps.list file
    mkdir -p /etc/skel/.config
    cat > /etc/skel/.config/mimeapps.list << EOF
[Default Applications]
x-scheme-handler/http=microsoft-edge-stable.desktop
x-scheme-handler/https=microsoft-edge-stable.desktop
text/html=microsoft-edge-stable.desktop
application/xhtml+xml=microsoft-edge-stable.desktop
EOF

    # Also update for current user if running as sudo
    if [[ -n "${SUDO_USER}" ]]; then
        local user_home
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true

        mkdir -p "${user_home}/.config"
        cat > "${user_home}/.config/mimeapps.list" << EOF
[Default Applications]
x-scheme-handler/http=microsoft-edge-stable.desktop
x-scheme-handler/https=microsoft-edge-stable.desktop
text/html=microsoft-edge-stable.desktop
application/xhtml+xml=microsoft-edge-stable.desktop
EOF

        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/mimeapps.list"
    fi

    set_state "${SCRIPT_NAME}_edge_default_set"
    log_success "Microsoft Edge set as the default browser"
    return 0
}

# Function to install all browsers
function install_browsers() {
    log_section "Installing Web Browsers"

    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Browsers have already been installed. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install each browser with error handling
    # Even if one browser fails to install, we continue with the others
    # Note: Microsoft Edge is installed last

    if ! install_brave_browser; then
        log_warning "Failed to install Brave Browser"
    fi

    if ! install_firefox; then
        log_warning "Failed to install Firefox"
    fi

    if ! install_zen_browser; then
        log_warning "Failed to install Zen Browser"
    fi

    # Install Microsoft Edge last
    if ! install_microsoft_edge; then
        log_warning "Failed to install Microsoft Edge"
    else
        # Set Microsoft Edge as the default browser
        if ! set_edge_as_default; then
            log_warning "Failed to set Microsoft Edge as the default browser"
        fi
    fi

    # Create browser profiles for testing
    create_browser_profiles

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Web browsers installation completed successfully"

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
install_browsers

# Return the exit code
exit $?
