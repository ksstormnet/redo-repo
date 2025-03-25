#!/bin/bash
# ============================================================================
# package_utils.sh
# ----------------------------------------------------------------------------
# Package management utilities for system installer scripts
# Provides wrappers for apt, ppa, and other package operations
# ============================================================================

# Update package lists
function apt_update() {
    log_step "Updating package lists"
    
    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    log_debug "Package lists updated successfully"
    return 0
}

# Install packages with error handling
function apt_install() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for installation"
        return 1
    fi
    
    log_step "Installing packages: ${packages[*]}"
    
    # Use a noninteractive frontend to avoid prompts
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
        log_error "Failed to install packages: ${packages[*]}"
        return 1
    fi
    
    log_debug "Packages installed successfully: ${packages[*]}"
    return 0
}

# Install a single package
function install_package() {
    apt_install "$1"
}

# Install multiple packages
function install_packages() {
    apt_install "$@"
}

# Remove packages
function apt_remove() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for removal"
        return 1
    fi
    
    log_step "Removing packages: ${packages[*]}"
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get remove -y "${packages[@]}"; then
        log_error "Failed to remove packages: ${packages[*]}"
        return 1
    fi
    
    log_debug "Packages removed successfully: ${packages[*]}"
    return 0
}

# Remove packages with configuration files
function apt_purge() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for purge"
        return 1
    fi
    
    log_step "Purging packages: ${packages[*]}"
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get purge -y "${packages[@]}"; then
        log_error "Failed to purge packages: ${packages[*]}"
        return 1
    fi
    
    log_debug "Packages purged successfully: ${packages[*]}"
    return 0
}

# Auto-remove unused packages
function apt_autoremove() {
    log_step "Removing unused packages"
    
    if ! apt-get autoremove -y; then
        log_warning "Failed to autoremove packages"
        return 1
    fi
    
    log_debug "Unused packages removed successfully"
    return 0
}

# Clean apt cache
function apt_clean() {
    log_step "Cleaning package cache"
    
    if ! apt-get clean; then
        log_warning "Failed to clean package cache"
        return 1
    fi
    
    if ! apt-get autoclean; then
        log_warning "Failed to autoclean package cache"
        return 1
    fi
    
    log_debug "Package cache cleaned successfully"
    return 0
}

# Fix broken packages
function apt_fix_broken() {
    log_step "Fixing broken packages"
    
    if ! apt-get install -f -y; then
        log_error "Failed to fix broken packages"
        return 1
    fi
    
    log_debug "Broken packages fixed successfully"
    return 0
}

# Add PPA repository
function add_ppa() {
    local ppa_name="$1"
    
    log_step "Adding PPA: ${ppa_name}"
    
    # Check if add-apt-repository command is available
    if ! command -v add-apt-repository &> /dev/null; then
        log_info "Installing software-properties-common for PPA support"
        apt_install software-properties-common
    fi
    
    # Add the PPA
    if ! add-apt-repository -y "ppa:${ppa_name}"; then
        log_error "Failed to add PPA: ${ppa_name}"
        return 1
    fi
    
    # Update package lists
    apt_update
    
    log_debug "PPA added successfully: ${ppa_name}"
    return 0
}

# Add a repository with keyring
function add_repository_with_key() {
    local name="$1"
    local key_url="$2"
    local repo_url="$3"
    local components="${4:-main}"
    local keyring_dir="/etc/apt/trusted.gpg.d"
    local keyring_file="${keyring_dir}/${name}.gpg"
    
    log_step "Adding repository: ${name}"
    
    # Ensure keyring directory exists
    mkdir -p "${keyring_dir}"
    
    # Download and add the GPG key
    log_info "Downloading GPG key for ${name}"
    
    # Download key and save to a temporary file to avoid masking return value
    local temp_key
    if ! temp_key=$(curl -fsSL "${key_url}"); then
        log_error "Failed to download GPG key for ${name}"
        return 1
    fi
    
    # Dearmor the key
    if ! echo "${temp_key}" | gpg --dearmor -o "${keyring_file}"; then
        log_error "Failed to dearmor GPG key for ${name}"
        return 1
    fi
    
    # Add the repository
    log_info "Adding repository for ${name}"
    
    # Get release codename
    local codename
    codename=$(lsb_release -cs) || true
    
    echo "deb [arch=amd64 signed-by=${keyring_file}] ${repo_url} ${codename} ${components}" > "/etc/apt/sources.list.d/${name}.list"
    
    # Update package lists
    apt_update
    
    log_debug "Repository added successfully: ${name}"
    return 0
}

# Check if a package is installed
function check_installed() {
    local package="$1"
    
    # Check if package is installed, avoiding masking return value
    local dpkg_output
    dpkg_output=$(dpkg -l "${package}" 2>/dev/null) || true
    
    if echo "${dpkg_output}" | grep -q "^ii"; then
        log_debug "Package ${package} is installed"
        return 0
    else
        log_debug "Package ${package} is not installed"
        return 1
    fi
}

# Get the version of an installed package
function get_package_version() {
    local package="$1"
    
    if check_installed "${package}"; then
        local version
        version=$(dpkg-query -W -f='${Version}' "${package}") || true
        echo "${version}"
        return 0
    else
        log_debug "Cannot get version, package ${package} is not installed"
        echo ""
        return 1
    fi
}

# Check if package is available in repositories
function apt_cache_policy() {
    local package="$1"
    
    if apt-cache policy "${package}" &> /dev/null; then
        apt-cache policy "${package}"
        return 0
    else
        log_debug "Package ${package} not found in repositories"
        return 1
    fi
}

# Update a single package
function apt_upgrade_package() {
    local package="$1"
    
    log_step "Upgrading package: ${package}"
    
    if ! apt-get install --only-upgrade -y "${package}"; then
        log_error "Failed to upgrade package: ${package}"
        return 1
    fi
    
    log_debug "Package upgraded successfully: ${package}"
    return 0
}

# Install packages from a list file
function install_packages_from_file() {
    local package_file="$1"
    
    if [[ ! -f "${package_file}" ]]; then
        log_error "Package list file not found: ${package_file}"
        return 1
    fi
    
    log_step "Installing packages from file: ${package_file}"
    
    # Read packages from file, ignoring comments and empty lines
    local packages=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Add package to the list
        packages+=("${line}")
    done < "${package_file}"
    
    # Check if any packages were found
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages found in file: ${package_file}"
        return 0
    fi
    
    # Install the packages
    log_info "Installing ${#packages[@]} packages from file: ${package_file}"
    if ! apt_install "${packages[@]}"; then
        log_error "Failed to install packages from file: ${package_file}"
        return 1
    fi
    
    log_success "Successfully installed ${#packages[@]} packages from file"
    return 0
}
