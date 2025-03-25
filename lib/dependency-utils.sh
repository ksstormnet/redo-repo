#!/usr/bin/env bash
# ============================================================================
# dependency-utils.sh
# ----------------------------------------------------------------------------
# Provides dependency management utilities for tracking installed packages
# and preventing duplicate package installations across multiple scripts
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common library functions if not already loaded
if [[ -z "${LOG_DEBUG+x}" ]]; then
    if [[ -f "${UTILS_DIR}/log-utils.sh" ]]; then
        # shellcheck disable=SC1091
        source "${UTILS_DIR}/log-utils.sh"
    else
        echo "WARNING: log-utils.sh library not found at ${UTILS_DIR}"
        # Define basic logging functions as fallbacks
        function log_debug() { echo "DEBUG: $*"; }
        function log_info() { echo "INFO: $*"; }
        function log_warning() { echo "WARNING: $*"; }
        function log_error() { echo "ERROR: $*"; }
        function log_success() { echo "SUCCESS: $*"; }
    fi
fi

# Define the dependency state directory
# Stored in a global variable so it's accessible to all functions
DEPENDENCY_DIR="${STATE_DIR:-/var/lib/system-setup/state}/dependencies"

# Package category definitions
declare -A PACKAGE_CATEGORIES

# ============================================================================
# Dependency Initialization
# ============================================================================

# Initialize the dependency tracking system
function init_dependency_tracking() {
    if [[ -z "${DEPENDENCY_DIR}" ]]; then
        log_error "DEPENDENCY_DIR is not defined"
        return 1
    fi

    # Create dependency tracking directory if it doesn't exist
    if [[ ! -d "${DEPENDENCY_DIR}" ]]; then
        mkdir -p "${DEPENDENCY_DIR}"
        log_debug "Created dependency tracking directory: ${DEPENDENCY_DIR}"
    fi

    # Initialize package categories
    define_all_package_categories

    log_debug "Dependency tracking initialized"
    return 0
}

# Define all package categories with default priority values
function define_all_package_categories() {
    # Clear existing categories
    PACKAGE_CATEGORIES=()

    # Define categories with priorities (lower numbers = higher priority)
    # These categories help group packages for reporting and management
    PACKAGE_CATEGORIES["core"]=10           # Core system components
    PACKAGE_CATEGORIES["essential"]=20      # Essential system utilities
    PACKAGE_CATEGORIES["development"]=30    # Development tools and libraries
    PACKAGE_CATEGORIES["utilities"]=40      # General utilities
    PACKAGE_CATEGORIES["network"]=50        # Network-related packages
    PACKAGE_CATEGORIES["desktop"]=60        # Desktop environment packages
    PACKAGE_CATEGORIES["multimedia"]=70     # Multimedia packages
    PACKAGE_CATEGORIES["browsers"]=80       # Web browsers
    PACKAGE_CATEGORIES["productivity"]=90   # Office and productivity applications
    PACKAGE_CATEGORIES["other"]=100         # Miscellaneous packages

    log_debug "Defined ${#PACKAGE_CATEGORIES[@]} package categories"
    return 0
}

# ============================================================================
# Package Registration Functions
# ============================================================================

# Register a single package as installed
function register_package() {
    local package_name="$1"
    local category="${2:-other}"

    # Validate package name
    if [[ -z "${package_name}" ]]; then
        log_error "Package name is required"
        return 1
    fi

    # Validate category
    if [[ -z "${PACKAGE_CATEGORIES[${category}]+x}" ]]; then
        log_warning "Unknown package category: ${category}, defaulting to 'other'"
        category="other"
    fi

    # Create category directory if it doesn't exist
    local category_dir="${DEPENDENCY_DIR}/${category}"
    if [[ ! -d "${category_dir}" ]]; then
        mkdir -p "${category_dir}"
    fi

    # Register the package
    local package_file="${category_dir}/${package_name}"
    if [[ ! -f "${package_file}" ]]; then
        touch "${package_file}"
        log_debug "Registered package '${package_name}' in category '${category}'"
    else
        log_debug "Package '${package_name}' already registered in category '${category}'"
    fi

    return 0
}

# Register multiple packages at once
function register_packages() {
    local category="$1"
    shift

    # Validate category
    if [[ -z "${PACKAGE_CATEGORIES[${category}]+x}" ]]; then
        log_warning "Unknown package category: ${category}, defaulting to 'other'"
        category="other"
    fi

    # Register each package
    for package in "$@"; do
        register_package "${package}" "${category}"
    done

    return 0
}

# Check if a package is already registered
function is_package_registered() {
    local package_name="$1"

    # Validate package name
    if [[ -z "${package_name}" ]]; then
        log_error "Package name is required"
        return 1
    fi

    # Check if the package exists in any category
    for category in "${!PACKAGE_CATEGORIES[@]}"; do
        if [[ -f "${DEPENDENCY_DIR}/${category}/${package_name}" ]]; then
            log_debug "Package '${package_name}' is registered in category '${category}'"
            return 0
        fi
    done

    log_debug "Package '${package_name}' is not registered"
    return 1
}

# ============================================================================
# Smart Installation Functions
# ============================================================================

# Smart install a single package if not already registered
function smart_install() {
    local package_name="$1"
    local category="${2:-other}"

    # Validate package name
    if [[ -z "${package_name}" ]]; then
        log_error "Package name is required"
        return 1
    fi

    # Skip installation if already registered
    if is_package_registered "${package_name}"; then
        log_info "Package '${package_name}' is already installed. Skipping..."
        return 0
    fi

    # Install the package
    log_info "Installing package: ${package_name}"
    if ! apt_install "${package_name}"; then
        log_error "Failed to install package '${package_name}'"
        return 1
    fi

    # Register the package
    register_package "${package_name}" "${category}"

    return 0
}

# Smart install multiple packages at once
function smart_install_packages() {
    local category="$1"
    shift

    local to_install=()

    # Identify packages that need to be installed
    for package in "$@"; do
        if ! is_package_registered "${package}"; then
            to_install+=("${package}")
        else
            log_info "Package '${package}' is already installed. Skipping..."
        fi
    done

    # Install packages if any need installing
    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing ${#to_install[@]} packages in category '${category}'"
        if ! apt_install "${to_install[@]}"; then
            log_error "Failed to install some packages in category '${category}'"
            return 1
        fi

        # Register all packages as installed
        for package in "${to_install[@]}"; do
            register_package "${package}" "${category}"
        done
    else
        log_info "No packages need to be installed in category '${category}'"
    fi

    return 0
}

# ============================================================================
# Reporting Functions
# ============================================================================

# List all registered packages by category
function list_registered_packages() {
    # Ensure dependency tracking is initialized
    if [[ ! -d "${DEPENDENCY_DIR}" ]]; then
        log_info "No registered packages found"
        return 0
    fi

    local total_count=0

    # Sort categories by priority
    local sorted_categories=()
    for category in "${!PACKAGE_CATEGORIES[@]}"; do
        sorted_categories+=("${category}")
    done

    # Sort by priority value
    IFS=$'\n' sorted_categories=($(sort -n -k2,2 < <(for cat in "${sorted_categories[@]}"; do echo "$cat ${PACKAGE_CATEGORIES[$cat]}"; done)))
    unset IFS

    # Extract just the category names
    for i in "${!sorted_categories[@]}"; do
        sorted_categories[$i]=$(echo "${sorted_categories[$i]}" | cut -d' ' -f1)
    done

    # Print packages by category
    echo "Registered Packages by Category:"
    echo "================================"

    for category in "${sorted_categories[@]}"; do
        local category_dir="${DEPENDENCY_DIR}/${category}"

        if [[ -d "${category_dir}" ]]; then
            local packages=()
            while IFS= read -r package; do
                packages+=("$(basename "${package}")")
            done < <(find "${category_dir}" -type f -not -path "*/\.*" | sort)

            local count=${#packages[@]}
            total_count=$((total_count + count))

            if [[ ${count} -gt 0 ]]; then
                echo ""
                echo "${category} (${count} packages):"
                echo "------------------------"

                # Display packages in columns
                local cols=3
                local rows=$(( (count + cols - 1) / cols ))
                local width=25

                for ((row=0; row<rows; row++)); do
                    local line=""
                    for ((col=0; col<cols; col++)); do
                        local idx=$((row + col * rows))
                        if [[ ${idx} -lt ${count} ]]; then
                            printf "%-${width}s" "${packages[$idx]}"
                        fi
                    done
                    echo ""
                done
            fi
        fi
    done

    echo ""
    echo "Total registered packages: ${total_count}"

    return 0
}

# Count the number of registered packages
function count_registered_packages() {
    # Ensure dependency tracking is initialized
    if [[ ! -d "${DEPENDENCY_DIR}" ]]; then
        echo "0"
        return 0
    fi

    local count=0

    # Count packages in all categories
    while IFS= read -r package; do
        count=$((count + 1))
    done < <(find "${DEPENDENCY_DIR}" -type f -not -path "*/\.*")

    echo "${count}"
    return 0
}

# Export functions
export -f init_dependency_tracking
export -f define_all_package_categories
export -f register_package
export -f register_packages
export -f is_package_registered
export -f smart_install
export -f smart_install_packages
export -f list_registered_packages
export -f count_registered_packages
