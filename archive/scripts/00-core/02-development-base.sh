#!/usr/bin/env bash
# ============================================================================
# 02-development-base.sh
# ----------------------------------------------------------------------------
# Installs essential development tools and programming languages
# including build tools, Python, and Node.js
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

# FORCE_MODE may be set in common.sh, but set a default if not
: "${FORCE_MODE:=false}"

# Script name for state management and logging
SCRIPT_NAME="02-development-base"

# ============================================================================
# Installation Functions
# ============================================================================

# Install build essentials and dev tools
function install_build_tools() {
    log_step "Installing build essentials and development tools"
    
    local dev_packages=(
        build-essential
        cmake
        git
        git-lfs
        automake
        autoconf
        libtool
        pkg-config
    )
    
    if ! apt_install "${dev_packages[@]}"; then
        log_error "Failed to install development packages"
        return 1
    fi
    
    log_success "Build tools installed successfully"
    return 0
}

# Install Python development tools
function install_python_tools() {
    log_step "Installing Python development tools"
    
    local python_packages=(
        python3
        python3-pip
        python3-dev
        python3-venv
    )
    
    if ! apt_install "${python_packages[@]}"; then
        log_error "Failed to install Python packages"
        return 1
    fi
    
    # Install Python packages via pip
    log_step "Installing Python packages via pip"
    local pip_packages=(
        virtualenv
        ipython
        pylint
        black
        pytest
    )
    
    # Use Python's pip module directly (more reliable across distributions)
    if ! python3 -m pip install --user "${pip_packages[@]}"; then
        log_warning "Some Python packages failed to install via pip"
        # Continue anyway, as these can be installed later if needed
    else
        log_success "Python pip packages installed successfully"
    fi
    
    log_success "Python development tools installed successfully"
    return 0
}

# Install Node.js LTS
function install_nodejs() {
    log_step "Installing Node.js LTS"
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node --version)
        log_info "Node.js is already installed (Version: ${node_version})"
        return 0
    fi
    
    log_info "Installing Node.js from NodeSource repository"
    
    # Add the NodeSource repository (LTS version)
    if ! curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -; then
        log_error "Failed to add Node.js repository"
        return 1
    fi
    
    # Install Node.js
    if ! apt_install nodejs; then
        log_error "Failed to install Node.js"
        return 1
    fi
    
    # Verify installation
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node --version)
        local npm_version
        npm_version=$(npm --version)
        log_success "Node.js installed successfully (Node: ${node_version}, NPM: ${npm_version})"
    else
        log_error "Node.js installation verification failed"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_dev_base() {
    log_section "Installing Development Base Packages"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Development base packages have already been installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install build tools
    if ! install_build_tools; then
        log_error "Failed to install build tools"
        return 1
    fi
    
    # Install Python development tools
    if ! install_python_tools; then
        log_error "Failed to install Python development tools"
        return 1
    fi
    
    # Install Node.js LTS
    if ! install_nodejs; then
        log_warning "Failed to install Node.js"
        # Continue anyway as Node.js is not critical for all development
    fi
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Development base packages installed successfully"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_dev_base

# Return the exit code
exit $?
