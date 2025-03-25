#!/usr/bin/env bash
# ============================================================================
# 11-nodejs-packages.sh
# ----------------------------------------------------------------------------
# Installs global Node.js packages useful for web development
# Includes essential tools, web frameworks, bundlers, and testing utilities
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
SCRIPT_NAME="11-nodejs-packages"

# ============================================================================
# Dependency Verification
# ============================================================================

# Verify Node.js installation
function verify_nodejs() {
    log_step "Verifying Node.js installation"

    # Check if Node.js and npm are installed
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Please install Node.js first."
        log_info "You can install Node.js using the 03-web-development.sh script"
        return 1
    fi

    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed. Please install npm first."
        log_info "npm should be included with the Node.js installation"
        return 1
    fi

    # Get versions for logging
    # Declare first, then assign to avoid masking return values
    local node_version
    node_version=$(node --version) || true

    local npm_version
    npm_version=$(npm --version) || true

    log_info "Node.js ${node_version} is installed"
    log_info "npm ${npm_version} is installed"

    return 0
}

# ============================================================================
# Package Management
# ============================================================================

# Install Yarn package manager
function install_yarn() {
    log_step "Installing Yarn package manager"

    if check_state "${SCRIPT_NAME}_yarn_installed"; then
        log_info "Yarn is already installed. Skipping..."
        return 0
    fi

    # Check if Yarn is already installed
    if command -v yarn &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local yarn_version
        yarn_version=$(yarn --version) || true
        log_info "Yarn is already installed: v${yarn_version}"
        set_state "${SCRIPT_NAME}_yarn_installed"
        return 0
    fi

    # Install Yarn globally
    log_info "Installing Yarn via npm"
    if ! npm install -g yarn; then
        log_error "Failed to install Yarn package manager"
        return 1
    fi

    # Verify installation
    if command -v yarn &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local yarn_version
        yarn_version=$(yarn --version) || true
        log_success "Yarn v${yarn_version} installed successfully"
        set_state "${SCRIPT_NAME}_yarn_installed"
        return 0
    else
        log_error "Yarn installation verification failed"
        return 1
    fi
}

# Install pnpm package manager
function install_pnpm() {
    log_step "Installing pnpm package manager"

    if check_state "${SCRIPT_NAME}_pnpm_installed"; then
        log_info "pnpm is already installed. Skipping..."
        return 0
    fi

    # Check if pnpm is already installed
    if command -v pnpm &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local pnpm_version
        pnpm_version=$(pnpm --version) || true
        log_info "pnpm is already installed: v${pnpm_version}"
        set_state "${SCRIPT_NAME}_pnpm_installed"
        return 0
    fi

    # Install pnpm globally
    log_info "Installing pnpm via npm"
    if ! npm install -g pnpm; then
        log_error "Failed to install pnpm package manager"
        return 1
    fi

    # Verify installation
    if command -v pnpm &> /dev/null; then
        # Declare first, then assign to avoid masking return values
        local pnpm_version
        pnpm_version=$(pnpm --version) || true
        log_success "pnpm v${pnpm_version} installed successfully"
        set_state "${SCRIPT_NAME}_pnpm_installed"
        return 0
    else
        log_error "pnpm installation verification failed"
        return 1
    fi
}

# Install essential global npm packages
function install_essential_packages() {
    log_step "Installing essential global npm packages"

    if check_state "${SCRIPT_NAME}_essential_packages_installed"; then
        log_info "Essential npm packages already installed. Skipping..."
        return 0
    fi

    # Define essential packages
    local essential_packages=(
        "npm-check-updates"     # Upgrade package.json dependencies
        "eslint"                # JavaScript linter
        "prettier"              # Code formatter
        "typescript"            # TypeScript compiler
        "ts-node"               # TypeScript execution environment
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${essential_packages[@]}"; do
        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} essential npm packages installed successfully"
        set_state "${SCRIPT_NAME}_essential_packages_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        return 1
    fi
}

# Install web development tools
function install_web_dev_tools() {
    log_step "Installing web development tools"

    if check_state "${SCRIPT_NAME}_web_dev_tools_installed"; then
        log_info "Web development tools already installed. Skipping..."
        return 0
    fi

    # Define web development tools
    local web_dev_packages=(
        "serve"                 # Static file server
        "http-server"           # Lightweight HTTP server
        "json-server"           # Full fake REST API
        "live-server"           # Development server with live reload
        "nodemon"               # Monitor for changes and restart server
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${web_dev_packages[@]}"; do
        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} web development tools installed successfully"
        set_state "${SCRIPT_NAME}_web_dev_tools_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        # Continue anyway as these are helpful but not critical
        set_state "${SCRIPT_NAME}_web_dev_tools_installed"
        return 0
    fi
}

# Install build and bundler tools
function install_build_tools() {
    log_step "Installing build and bundler tools"

    if check_state "${SCRIPT_NAME}_build_tools_installed"; then
        log_info "Build tools already installed. Skipping..."
        return 0
    fi

    # Define build/bundler tools
    local build_packages=(
        "webpack-cli"           # Webpack command line interface
        "parcel-bundler"        # Zero configuration bundler
        "gulp-cli"              # Gulp command line interface
        "rollup"                # ES module bundler
        "vite"                  # Next generation frontend tooling
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${build_packages[@]}"; do
        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} build tools installed successfully"
        set_state "${SCRIPT_NAME}_build_tools_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        # Continue anyway as these are helpful but not critical
        set_state "${SCRIPT_NAME}_build_tools_installed"
        return 0
    fi
}

# Install testing tools
function install_testing_tools() {
    log_step "Installing testing tools"

    if check_state "${SCRIPT_NAME}_testing_tools_installed"; then
        log_info "Testing tools already installed. Skipping..."
        return 0
    fi

    # Define testing tools
    local testing_packages=(
        "jest"                  # JavaScript testing framework
        "mocha"                 # JavaScript test framework
        "cypress"               # End-to-end testing framework
        "lighthouse"            # Performance auditing tool
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${testing_packages[@]}"; do
        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} testing tools installed successfully"
        set_state "${SCRIPT_NAME}_testing_tools_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        # Continue anyway as these are helpful but not critical
        set_state "${SCRIPT_NAME}_testing_tools_installed"
        return 0
    fi
}

# Install utility tools
function install_utility_tools() {
    log_step "Installing utility tools"

    if check_state "${SCRIPT_NAME}_utility_tools_installed"; then
        log_info "Utility tools already installed. Skipping..."
        return 0
    fi

    # Define utility tools
    local utility_packages=(
        "tldr"                  # Simplified man pages
        "npm-check"             # Check for outdated, incorrect, and unused dependencies
        "doctoc"                # Generate table of contents for markdown files
        "svgo"                  # SVG optimizer
        "jshint"                # JavaScript syntax checker
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${utility_packages[@]}"; do
        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} utility tools installed successfully"
        set_state "${SCRIPT_NAME}_utility_tools_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        # Continue anyway as these are helpful but not critical
        set_state "${SCRIPT_NAME}_utility_tools_installed"
        return 0
    fi
}

# Install framework-specific tools
function install_framework_tools() {
    log_step "Installing framework-specific tools"

    if check_state "${SCRIPT_NAME}_framework_tools_installed"; then
        log_info "Framework tools already installed. Skipping..."
        return 0
    fi

    # Define framework-specific tools with their commands
    declare -A framework_packages=(
        ["@angular/cli"]="ng"                        # Angular CLI
        ["create-react-app"]="create-react-app"      # Create React applications
        ["@vue/cli"]="vue"                           # Vue.js development tool
        ["create-next-app"]="create-next-app"        # Create Next.js applications
        ["@nestjs/cli"]="nest"                       # Nest.js CLI
        ["astro"]="astro"                            # Astro.js SSG framework
    )

    local installed_count=0
    local failed_count=0

    # Install each package
    for package in "${!framework_packages[@]}"; do
        local cmd_name="${framework_packages[${package}]}"

        # Check if already installed
        if command -v "${cmd_name}" &> /dev/null; then
            log_info "${package} is already installed"
            ((installed_count++))
            continue
        fi

        log_info "Installing ${package}..."

        if npm install -g "${package}"; then
            ((installed_count++))
        else
            log_warning "Failed to install ${package}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} framework tools installed successfully"
        set_state "${SCRIPT_NAME}_framework_tools_installed"
        return 0
    else
        log_warning "${installed_count} packages installed, ${failed_count} failed"
        # Continue anyway as these are helpful but not critical
        set_state "${SCRIPT_NAME}_framework_tools_installed"
        return 0
    fi
}

# ============================================================================
# Main Function
# ============================================================================

function install_nodejs_packages() {
    log_section "Installing Global Node.js Packages"

    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Node.js global packages have already been installed. Skipping..."
        return 0
    fi

    # Verify Node.js installation first
    if ! verify_nodejs; then
        log_error "Node.js verification failed. Cannot continue."
        return 1
    fi

    # Create array to track installations
    local installation_steps=(
        "install_yarn"
        "install_pnpm"
        "install_essential_packages"
        "install_web_dev_tools"
        "install_build_tools"
        "install_testing_tools"
        "install_utility_tools"
        "install_framework_tools"
    )

    local installed_count=0
    local failed_count=0

    # Run installation steps
    for step in "${installation_steps[@]}"; do
        if ! ${step}; then
            log_warning "Step ${step} had some failures"
            ((failed_count++))
        else
            ((installed_count++))
        fi
    done

    # Clean up npm cache
    log_step "Cleaning npm cache"
    npm cache clean --force

    # List installed global packages
    log_step "Listing installed global packages"
    npm list -g --depth=0

    # Report final status
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All Node.js global packages installed successfully"
    else
        log_warning "Some package installations had warnings or failures"
        log_info "You may want to try installing failed packages manually"
    fi

    # Mark as completed regardless of individual failures
    # as these are non-critical development tools
    set_state "${SCRIPT_NAME}_completed"
    log_success "Node.js global packages installation completed"

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
install_nodejs_packages

# Return the exit code
exit $?
