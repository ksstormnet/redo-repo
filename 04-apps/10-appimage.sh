#!/usr/bin/env bash
# ============================================================================
# 10-appimage.sh
# ----------------------------------------------------------------------------
# Sets up AppImage support and installs various AppImage applications
# Includes proper directories, integration, and environment configuration
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
SCRIPT_NAME="10-appimage"

# ============================================================================
# Helper Functions
# ============================================================================

# Set up the AppImage directory structure
function setup_appimage_directories() {
    log_step "Setting up AppImage directories"

    if check_state "${SCRIPT_NAME}_directories_setup"; then
        log_info "AppImage directories already set up. Skipping..."
        return 0
    fi

    local user_home

    # Determine the actual user's home directory when running with sudo
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi

    # Create AppImage directories
    local appimage_dirs=(
        "${user_home}/Applications"
        "${user_home}/.local/bin"
        "${user_home}/.local/share/applications"
    )

    for dir in "${appimage_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_info "Creating directory: ${dir}"
            mkdir -p "${dir}"
        fi
    done

    # Set correct permissions
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/Applications"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.local/bin"
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.local/share/applications"
    fi

    # Add AppImage executable permissions to all files in Applications directory
    find "${user_home}/Applications" -type f -name "*.AppImage" -exec chmod +x {} \;

    set_state "${SCRIPT_NAME}_directories_setup"
    log_success "AppImage directories set up successfully"
    return 0
}

# Install AppImage utilities for better integration
function install_appimage_utils() {
    log_step "Installing AppImage utilities"

    if check_state "${SCRIPT_NAME}_utils_installed"; then
        log_info "AppImage utilities already installed. Skipping..."
        return 0
    fi

    # Install FUSE which is required for AppImages
    log_info "Installing FUSE library for AppImage support"
    if ! apt_install libfuse2; then
        log_error "Failed to install FUSE library"
        return 1
    fi

    # Check if appimaged is available in repositories
    if apt_cache_policy appimaged &>/dev/null; then
        log_info "Installing appimaged for AppImage integration"
        if ! apt_install appimaged; then
            log_warning "Failed to install appimaged"
        fi
    fi

    set_state "${SCRIPT_NAME}_utils_installed"
    log_success "AppImage utilities installed successfully"
    return 0
}

# Download and install an AppImage
function download_appimage() {
    local app_name="$1"
    local app_url="$2"
    local desktop_file="$3"
    local create_symlink="${4:-false}"

    log_info "Processing AppImage for ${app_name}"

    # Check if already installed
    if check_state "${SCRIPT_NAME}_${app_name}_installed"; then
        log_info "${app_name} is already installed. Skipping..."
        return 0
    fi

    local user_home

    # Determine the actual user's home directory when running with sudo
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi

    local app_dir="${user_home}/Applications"
    local app_path="${app_dir}/${app_name}.AppImage"

    if [[ -f "${app_path}" ]]; then
        log_info "${app_name} AppImage already exists at ${app_path}"
        # Make sure it's executable
        chmod +x "${app_path}"
        set_state "${SCRIPT_NAME}_${app_name}_installed"
        return 0
    fi

    log_info "Downloading ${app_name} AppImage from ${app_url}"

    # Download the AppImage
    if [[ -n "${SUDO_USER}" ]]; then
        # Download as the actual user to avoid permission issues
        if ! sudo -u "${SUDO_USER}" wget "${app_url}" -O "${app_path}"; then
            log_error "Failed to download ${app_name} AppImage"
            return 1
        fi
    else
        if ! wget "${app_url}" -O "${app_path}"; then
            log_error "Failed to download ${app_name} AppImage"
            return 1
        fi
    fi

    # Make it executable
    chmod +x "${app_path}"

    # Create a symlink in ~/.local/bin if requested
    if [[ "${create_symlink}" == "true" ]]; then
        local bin_dir="${user_home}/.local/bin"
        local bin_path="${bin_dir}/${app_name}"

        if [[ ! -f "${bin_path}" ]]; then
            log_info "Creating symlink at ${bin_path}"
            if [[ -n "${SUDO_USER}" ]]; then
                sudo -u "${SUDO_USER}" ln -sf "${app_path}" "${bin_path}"
            else
                ln -sf "${app_path}" "${bin_path}"
            fi
        fi
    fi

    # Create desktop file if provided
    if [[ -n "${desktop_file}" ]]; then
        local desktop_dir="${user_home}/.local/share/applications"
        local desktop_path="${desktop_dir}/${app_name}.desktop"

        log_info "Creating desktop file at ${desktop_path}"

        if [[ -n "${SUDO_USER}" ]]; then
            echo "${desktop_file}" | sudo -u "${SUDO_USER}" tee "${desktop_path}" >/dev/null
        else
            echo "${desktop_file}" > "${desktop_path}"
        fi
    fi

    set_state "${SCRIPT_NAME}_${app_name}_installed"
    log_success "${app_name} AppImage installed successfully"
    return 0
}

# ============================================================================
# Application Installation Functions
# ============================================================================

# Install Obsidian AppImage
function install_obsidian() {
    log_step "Installing Obsidian AppImage"

    if check_state "${SCRIPT_NAME}_obsidian_installed"; then
        log_info "Obsidian AppImage is already installed. Skipping..."
        return 0
    fi

    local obsidian_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.5.3/Obsidian-1.5.3.AppImage"
    local obsidian_desktop="[Desktop Entry]
Name=Obsidian
Comment=Obsidian Knowledge Base
Exec=/home/${SUDO_USER}/Applications/Obsidian.AppImage
Icon=obsidian
Terminal=false
Type=Application
Categories=Office;
MimeType=text/markdown;
Keywords=markdown;knowledge;notes;
StartupWMClass=obsidian"

    # Download and install Obsidian
    if download_appimage "Obsidian" "${obsidian_url}" "${obsidian_desktop}" "true"; then
        log_success "Obsidian AppImage installed successfully"
        return 0
    else
        log_error "Failed to install Obsidian AppImage"
        return 1
    fi
}

# Install Joplin AppImage
function install_joplin() {
    log_step "Installing Joplin AppImage"

    if check_state "${SCRIPT_NAME}_joplin_installed"; then
        log_info "Joplin AppImage is already installed. Skipping..."
        return 0
    fi

    local joplin_url="https://github.com/laurent22/joplin/releases/download/v2.12.19/Joplin-2.12.19.AppImage"
    local joplin_desktop="[Desktop Entry]
Name=Joplin
Comment=Joplin Note Taking App
Exec=/home/${SUDO_USER}/Applications/Joplin.AppImage
Icon=joplin
Terminal=false
Type=Application
Categories=Office;
MimeType=text/markdown;
Keywords=markdown;notes;
StartupWMClass=joplin"

    # Download and install Joplin
    if download_appimage "Joplin" "${joplin_url}" "${joplin_desktop}" "true"; then
        log_success "Joplin AppImage installed successfully"
        return 0
    else
        log_error "Failed to install Joplin AppImage"
        return 1
    fi
}

# Install Etcher AppImage
function install_etcher() {
    log_step "Installing Etcher AppImage"

    if check_state "${SCRIPT_NAME}_etcher_installed"; then
        log_info "Etcher AppImage is already installed. Skipping..."
        return 0
    fi

    local etcher_url="https://github.com/balena-io/etcher/releases/download/v1.18.11/balenaEtcher-1.18.11-x64.AppImage"
    local etcher_desktop="[Desktop Entry]
Name=balenaEtcher
Comment=Flash OS images to SD cards & USB drives, safely and easily
Exec=/home/${SUDO_USER}/Applications/balenaEtcher.AppImage
Icon=balena-etcher-electron
Terminal=false
Type=Application
Categories=Utility;
Keywords=flash;usb;sd;image;
StartupWMClass=balenaEtcher"

    # Download and install Etcher
    if download_appimage "balenaEtcher" "${etcher_url}" "${etcher_desktop}" "true"; then
        log_success "Etcher AppImage installed successfully"
        return 0
    else
        log_error "Failed to install Etcher AppImage"
        return 1
    fi
}

# Install Insomnia API Client AppImage
function install_insomnia() {
    log_step "Installing Insomnia API Client AppImage"

    if check_state "${SCRIPT_NAME}_insomnia_installed"; then
        log_info "Insomnia AppImage is already installed. Skipping..."
        return 0
    fi

    local insomnia_url="https://github.com/Kong/insomnia/releases/download/core%402023.5.8/Insomnia.Core-2023.5.8.AppImage"
    local insomnia_desktop="[Desktop Entry]
Name=Insomnia
Comment=API Development Environment
Exec=/home/${SUDO_USER}/Applications/Insomnia.AppImage
Icon=insomnia
Terminal=false
Type=Application
Categories=Development;WebDevelopment;
Keywords=api;rest;graphql;development;
StartupWMClass=insomnia"

    # Download and install Insomnia
    if download_appimage "Insomnia" "${insomnia_url}" "${insomnia_desktop}" "true"; then
        log_success "Insomnia AppImage installed successfully"
        return 0
    else
        log_error "Failed to install Insomnia AppImage"
        return 1
    fi
}

# Install ClickUp AppImage
function install_clickup() {
    log_step "Installing ClickUp AppImage"

    if check_state "${SCRIPT_NAME}_clickup_installed"; then
        log_info "ClickUp AppImage is already installed. Skipping..."
        return 0
    fi

    local clickup_url="https://desktop.clickup.com/linux/ClickUp-2.0.22-x86_64.AppImage"
    local clickup_desktop="[Desktop Entry]
Name=ClickUp
Comment=All-in-one productivity platform
Exec=/home/${SUDO_USER}/Applications/ClickUp.AppImage
Icon=clickup
Terminal=false
Type=Application
Categories=Office;ProjectManagement;
Keywords=productivity;project;task;management;
StartupWMClass=clickup"

    # Download and install ClickUp
    if download_appimage "ClickUp" "${clickup_url}" "${clickup_desktop}" "true"; then
        log_success "ClickUp AppImage installed successfully"
        return 0
    else
        log_error "Failed to install ClickUp AppImage"
        return 1
    fi
}

# Install Kdenlive AppImage
function install_kdenlive() {
    log_step "Installing Kdenlive AppImage"

    if check_state "${SCRIPT_NAME}_kdenlive_installed"; then
        log_info "Kdenlive AppImage is already installed. Skipping..."
        return 0
    fi

    local kdenlive_url="https://download.kde.org/stable/kdenlive/23.08/linux/kdenlive-23.08.5-x86_64.AppImage"
    local kdenlive_desktop="[Desktop Entry]
Name=Kdenlive
Comment=KDE Non-Linear Video Editor
Exec=/home/${SUDO_USER}/Applications/Kdenlive.AppImage
Icon=kdenlive
Terminal=false
Type=Application
Categories=AudioVideo;AudioVideoEditing;Video;VideoEditing;
MimeType=application/x-kdenlive;
Keywords=video;editor;kde;multimedia;
StartupWMClass=kdenlive"

    # Download and install Kdenlive
    if download_appimage "Kdenlive" "${kdenlive_url}" "${kdenlive_desktop}" "true"; then
        log_success "Kdenlive AppImage installed successfully"
        return 0
    else
        log_error "Failed to install Kdenlive AppImage"
        return 1
    fi
}

# Install OpenShot AppImage
function install_openshot() {
    log_step "Installing OpenShot AppImage"

    if check_state "${SCRIPT_NAME}_openshot_installed"; then
        log_info "OpenShot AppImage is already installed. Skipping..."
        return 0
    fi

    local openshot_url="https://github.com/OpenShot/openshot-qt/releases/download/v3.1.1/OpenShot-v3.1.1-x86_64.AppImage"
    local openshot_desktop="[Desktop Entry]
Name=OpenShot Video Editor
Comment=Free and open-source video editor
Exec=/home/${SUDO_USER}/Applications/OpenShot.AppImage
Icon=openshot-qt
Terminal=false
Type=Application
Categories=AudioVideo;AudioVideoEditing;Video;VideoEditing;
MimeType=application/vnd.openshot-project;
Keywords=video;editor;non-linear;
StartupWMClass=openshot-qt"

    # Download and install OpenShot
    if download_appimage "OpenShot" "${openshot_url}" "${openshot_desktop}" "true"; then
        log_success "OpenShot AppImage installed successfully"
        return 0
    else
        log_error "Failed to install OpenShot AppImage"
        return 1
    fi
}

# Install StandardNotes AppImage
function install_standard_notes() {
    log_step "Installing StandardNotes AppImage"

    if check_state "${SCRIPT_NAME}_standard_notes_installed"; then
        log_info "StandardNotes AppImage is already installed. Skipping..."
        return 0
    fi

    local standard_notes_url="https://github.com/standardnotes/app/releases/download/3.183.6/standard-notes-3.183.6-linux-x86_64.AppImage"
    local standard_notes_desktop="[Desktop Entry]
Name=Standard Notes
Comment=A simple and private notes app
Exec=/home/${SUDO_USER}/Applications/StandardNotes.AppImage
Icon=standard-notes
Terminal=false
Type=Application
Categories=Office;Utility;
Keywords=notes;encrypted;secure;
StartupWMClass=standard-notes"

    # Download and install StandardNotes
    if download_appimage "StandardNotes" "${standard_notes_url}" "${standard_notes_desktop}" "true"; then
        log_success "StandardNotes AppImage installed successfully"
        return 0
    else
        log_error "Failed to install StandardNotes AppImage"
        return 1
    fi
}

# ============================================================================
# Main Function
# ============================================================================
function setup_appimages() {
    log_section "Setting up AppImage Support and Applications"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "AppImage setup has already been completed. Skipping..."
        return 0
    fi

    # Set up AppImage directories
    if ! setup_appimage_directories; then
        log_error "Failed to set up AppImage directories"
        return 1
    fi

    # Install AppImage utilities
    if ! install_appimage_utils; then
        log_error "Failed to install AppImage utilities"
        return 1
    fi

    # Install various AppImages
    install_obsidian || log_warning "Failed to install Obsidian AppImage"
    install_joplin || log_warning "Failed to install Joplin AppImage"
    install_etcher || log_warning "Failed to install Etcher AppImage"
    install_insomnia || log_warning "Failed to install Insomnia AppImage"
    install_clickup || log_warning "Failed to install ClickUp AppImage"
    install_kdenlive || log_warning "Failed to install Kdenlive AppImage"
    install_openshot || log_warning "Failed to install OpenShot AppImage"
    install_standard_notes || log_warning "Failed to install StandardNotes AppImage"

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "AppImage setup completed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Call the main function
setup_appimages

# Return the exit code
exit $?
