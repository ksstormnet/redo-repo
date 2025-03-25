#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================================
# 02-productivity.sh
# ----------------------------------------------------------------------------
# Installs office and productivity applications including document viewers,
# image viewers, text editors, and other productivity tools
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
SCRIPT_NAME="02-productivity"

# ============================================================================
# Office & Productivity Applications
# ============================================================================

# Install document viewers (PDF, e-books, etc.)
function install_document_viewers() {
    log_step "Installing document viewers"

    if check_state "${SCRIPT_NAME}_document_viewers_installed"; then
        log_info "Document viewers already installed. Skipping..."
        return 0
    fi

    # Document viewers packages
    local document_viewers=(
        okular                   # KDE document viewer (PDF, EPUB, etc.)
        poppler-utils            # PDF utilities
        djview4                  # DjVu viewer
        calibre                  # E-book manager
        evince                   # GNOME document viewer
    )

    if ! apt_install "${document_viewers[@]}"; then
        log_error "Failed to install document viewers"
        return 1
    fi

    set_state "${SCRIPT_NAME}_document_viewers_installed"
    log_success "Document viewers installed successfully"
    return 0
}

# Install image viewers and editors
function install_image_viewers() {
    log_step "Installing image viewers"

    if check_state "${SCRIPT_NAME}_image_viewers_installed"; then
        log_info "Image viewers already installed. Skipping..."
        return 0
    fi

    # Image viewer packages
    local image_viewers=(
        gwenview                 # KDE image viewer
        kimageformats            # Additional image format plugins
        eog                      # Eye of GNOME image viewer
        gthumb                   # Image viewer and browser
    )

    if ! apt_install "${image_viewers[@]}"; then
        log_error "Failed to install image viewers"
        return 1
    fi

    set_state "${SCRIPT_NAME}_image_viewers_installed"
    log_success "Image viewers installed successfully"
    return 0
}

# Install text editors
function install_text_editors() {
    log_step "Installing text editors"

    if check_state "${SCRIPT_NAME}_text_editors_installed"; then
        log_info "Text editors already installed. Skipping..."
        return 0
    fi

    # Text editor packages
    local text_editors=(
        ghostwriter              # Markdown editor
        kate                     # KDE advanced text editor
        nano                     # Simple terminal text editor
        vim                      # Vi IMproved text editor
        gedit                    # GNOME text editor
    )

    if ! apt_install "${text_editors[@]}"; then
        log_error "Failed to install text editors"
        return 1
    fi

    set_state "${SCRIPT_NAME}_text_editors_installed"
    log_success "Text editors installed successfully"
    return 0
}

# Install LibreOffice suite
function install_office_suite() {
    log_step "Installing LibreOffice suite"

    if check_state "${SCRIPT_NAME}_office_suite_installed"; then
        log_info "Office suite already installed. Skipping..."
        return 0
    fi

    # Check if installing full LibreOffice suite is desired
    local install_libreoffice=true

    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Install LibreOffice suite?" "y"; then
            log_info "Skipping LibreOffice installation by user choice"
            install_libreoffice=false
        fi
    fi

    if [[ "${install_libreoffice}" == "true" ]]; then
        # LibreOffice packages
        local office_packages=(
            libreoffice                  # Full LibreOffice suite
            libreoffice-style-breeze     # KDE Breeze style for LibreOffice
            libreoffice-gtk3             # GTK3 integration
            libreoffice-help-en-us       # English help files
            hunspell-en-us               # English dictionary
        )

        if ! apt_install "${office_packages[@]}"; then
            log_error "Failed to install LibreOffice suite"
            return 1
        fi

        log_success "LibreOffice suite installed successfully"
    else
        # Install only essential office applications if full suite is not desired
        local minimal_office_packages=(
            libreoffice-writer           # Word processor
            libreoffice-calc             # Spreadsheet
            libreoffice-impress          # Presentation
        )

        if ! apt_install "${minimal_office_packages[@]}"; then
            log_error "Failed to install minimal office applications"
            return 1
        fi

        log_success "Minimal office applications installed successfully"
    fi

    set_state "${SCRIPT_NAME}_office_suite_installed"
    return 0
}

# Install note-taking applications
function install_note_taking() {
    log_step "Installing note-taking applications"

    if check_state "${SCRIPT_NAME}_note_taking_installed"; then
        log_info "Note-taking applications already installed. Skipping..."
        return 0
    fi

    # Note-taking packages
    local note_taking_packages=(
        zim                      # Desktop wiki
        cherrytree               # Hierarchical note-taking application
        gnote                    # Desktop note-taking application
    )

    if ! apt_install "${note_taking_packages[@]}"; then
        log_error "Failed to install note-taking applications"
        return 1
    fi

    set_state "${SCRIPT_NAME}_note_taking_installed"
    log_success "Note-taking applications installed successfully"
    return 0
}

# Install additional productivity tools
function install_productivity_tools() {
    log_step "Installing additional productivity tools"

    if check_state "${SCRIPT_NAME}_productivity_tools_installed"; then
        log_info "Productivity tools already installed. Skipping..."
        return 0
    fi

    # Productivity tool packages
    local productivity_tools=(
        korganizer                # KDE calendar and scheduling application
        kaddressbook              # KDE contact manager
        krita                     # KDE painting program
        kmag                      # KDE screen magnifier
        kcalc                     # KDE calculator
        planner                   # Project management tool
        kcharselect               # Character selector
        krename                   # Batch file renamer
    )

    if ! apt_install "${productivity_tools[@]}"; then
        log_error "Failed to install productivity tools"
        return 1
    fi

    set_state "${SCRIPT_NAME}_productivity_tools_installed"
    log_success "Productivity tools installed successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_office_productivity() {
    log_section "Installing Office & Productivity Applications"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Office & Productivity applications have already been installed. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install packages by category
    install_document_viewers || log_warning "Failed to install some document viewers"
    install_image_viewers || log_warning "Failed to install some image viewers"
    install_text_editors || log_warning "Failed to install some text editors"
    install_office_suite || log_warning "Failed to install office suite"
    install_note_taking || log_warning "Failed to install note-taking applications"
    install_productivity_tools || log_warning "Failed to install some productivity tools"

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Office & Productivity applications installation completed successfully"

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
install_office_productivity

# Return the exit code
exit $?
