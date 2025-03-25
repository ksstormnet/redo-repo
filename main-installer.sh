#!/bin/bash
# shellcheck disable=SC2310,SC2312
# ============================================================================
# main-installer.sh
# ----------------------------------------------------------------------------
# Main installer script to orchestrate the installation of all components
# Execute this script after completing the LVM setup (00-lvm)
# Uses dependency tracking to prevent duplicate package installations
# ============================================================================

# Set strict error handling
set -o errexit
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

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
else
    echo "WARNING: dependency-utils.sh library not found at ${LIB_DIR}"
    echo "Dependency tracking will be disabled"
fi

# ============================================================================
# Configuration Variables
# ============================================================================

# Set default values for installation options
: "${INTERACTIVE:=true}"         # Interactive mode by default
: "${FORCE_MODE:=false}"         # Don't force reinstallation by default
: "${INSTALL_STUDIO:=true}"      # Install audio studio components by default
: "${INSTALL_PLASMA:=true}"      # Install KDE Plasma by default
: "${INSTALL_APPS:=true}"        # Install applications by default
: "${INSTALL_TWEAKS:=true}"      # Install system tweaks by default

# Log level: DEBUG, INFO, WARNING, ERROR
: "${LOG_LEVEL:=INFO}"

# Installation phase tracking file
PHASE_FILE="${STATE_DIR:-/var/lib/system-setup/state}/installation_phase"

# ============================================================================
# Installation Phase Functions
# ============================================================================

# Get the current installation phase
function get_current_phase() {
    if [[ -f "${PHASE_FILE}" ]]; then
        cat "${PHASE_FILE}"
    else
        echo "init"  # Default phase if not set
    fi
}

# Set the current installation phase
function set_current_phase() {
    local phase="$1"
    mkdir -p "$(dirname "${PHASE_FILE}")"
    echo "${phase}" > "${PHASE_FILE}"
    log_info "Installation phase set to: ${phase}"
}

# ============================================================================
# Script Execution Functions
# ============================================================================

# Execute a script and return its exit code
function execute_script() {
    local script="$1"
    local description="${2:-Executing script}"

    log_section "${description}: ${script}"

    if [[ ! -f "${script}" ]]; then
        log_error "Script not found: ${script}"
        return 1
    fi

    # Make script executable if it's not already
    if [[ ! -x "${script}" ]]; then
        chmod +x "${script}"
        log_debug "Made script executable: ${script}"
    fi

    # Execute the script
    if ! "${script}"; then
        log_error "Script execution failed: ${script}"
        return 1
    fi

    log_success "Script executed successfully: ${script}"
    return 0
}

# Execute all scripts in a directory
function execute_scripts_in_dir() {
    local dir="$1"
    local description="${2:-Executing scripts in}"

    log_section "${description}: ${dir}"

    if [[ ! -d "${dir}" ]]; then
        log_error "Directory not found: ${dir}"
        return 1
    fi

    # Find all .sh files and sort them
    local scripts=()
    local find_result
    find_result=$(find "${dir}" -name "*.sh" -type f 2>/dev/null | sort || true)
    while IFS= read -r script; do
        [[ -n "${script}" ]] && scripts+=("${script}")
    done < <(echo "${find_result}")

    if [[ ${#scripts[@]} -eq 0 ]]; then
        log_warning "No scripts found in: ${dir}"
        return 0
    fi

    # Execute each script
    for script in "${scripts[@]}"; do
        if ! execute_script "${script}" "Executing $(basename "${script}")"; then
            log_error "Failed to execute script: ${script}"
            if [[ "${INTERACTIVE}" == "true" ]]; then
                if ! prompt_yes_no "Continue with installation despite errors?" "n"; then
                    log_error "Installation aborted by user"
                    return 1
                fi
            else
                # In non-interactive mode, fail on any script error
                return 1
            fi
        fi
    done

    log_success "All scripts in ${dir} executed successfully"
    return 0
}

# ============================================================================
# Installation Phases
# ============================================================================

# Phase 1: System initialization
function phase_init() {
    log_section "Phase 1: System Initialization"

    # Initialize dependency tracking
    if command -v init_dependency_tracking &> /dev/null; then
        init_dependency_tracking
        define_all_package_categories
    fi

    # Execute scripts in 01-init directory
    if ! execute_scripts_in_dir "${SCRIPT_DIR}/01-init" "Initializing system with"; then
        log_error "System initialization failed"
        return 1
    fi

    set_current_phase "studio"
    log_success "System initialization completed successfully"
    return 0
}

# Phase 2: Studio setup
function phase_studio() {
    log_section "Phase 2: Studio Setup"

    if [[ "${INSTALL_STUDIO}" != "true" ]]; then
        log_info "Skipping studio setup (INSTALL_STUDIO=${INSTALL_STUDIO})"
        set_current_phase "plasma"
        return 0
    fi

    # Execute scripts in 02-studio directory
    if ! execute_scripts_in_dir "${SCRIPT_DIR}/02-studio" "Setting up studio with"; then
        log_error "Studio setup failed"
        return 1
    fi

    set_current_phase "plasma"
    log_success "Studio setup completed successfully"
    return 0
}

# Phase 3: KDE Plasma installation
function phase_plasma() {
    log_section "Phase 3: KDE Plasma Installation"

    if [[ "${INSTALL_PLASMA}" != "true" ]]; then
        log_info "Skipping KDE Plasma installation (INSTALL_PLASMA=${INSTALL_PLASMA})"
        set_current_phase "apps"
        return 0
    fi

    # Execute scripts in 03-plasma directory
    if ! execute_scripts_in_dir "${SCRIPT_DIR}/03-plasma" "Installing KDE Plasma with"; then
        log_error "KDE Plasma installation failed"
        return 1
    fi

    set_current_phase "apps"
    log_success "KDE Plasma installation completed successfully"
    return 0
}

# Phase 4: Applications installation
function phase_apps() {
    log_section "Phase 4: Applications Installation"

    if [[ "${INSTALL_APPS}" != "true" ]]; then
        log_info "Skipping applications installation (INSTALL_APPS=${INSTALL_APPS})"
        set_current_phase "tweaks"
        return 0
    fi

    # Execute scripts in 04-apps directory
    if ! execute_scripts_in_dir "${SCRIPT_DIR}/04-apps" "Installing applications with"; then
        log_error "Applications installation failed"
        return 1
    fi

    set_current_phase "tweaks"
    log_success "Applications installation completed successfully"
    return 0
}

# Phase 5: System tweaks
function phase_tweaks() {
    log_section "Phase 5: System Tweaks"

    if [[ "${INSTALL_TWEAKS}" != "true" ]]; then
        log_info "Skipping system tweaks (INSTALL_TWEAKS=${INSTALL_TWEAKS})"
        set_current_phase "complete"
        return 0
    fi

    # Execute scripts in 05-tweaks directory
    if ! execute_scripts_in_dir "${SCRIPT_DIR}/05-tweaks" "Applying system tweaks with"; then
        log_error "System tweaks application failed"
        return 1
    fi

    set_current_phase "complete"
    log_success "System tweaks applied successfully"
    return 0
}

# Phase complete: Final steps and summary
function phase_complete() {
    log_section "Installation Complete"

    log_success "All installation phases completed successfully!"

    # Print summary of installed packages if dependency tracking is enabled
    if command -v list_registered_packages &> /dev/null; then
        log_info "Installed package summary:"
        list_registered_packages
    fi

    # Print final message
    cat << 'EOF'
=======================================================================
                INSTALLATION COMPLETE!
=======================================================================
The system has been successfully installed and configured.
Please reboot to ensure all changes take effect.

To reboot, run:
    sudo reboot

Thank you for using the installer.
=======================================================================
EOF

    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function main() {
    # Parse command line arguments
    for arg in "$@"; do
        case ${arg} in
            --non-interactive)
                INTERACTIVE=false
                ;;
            --force)
                FORCE_MODE=true
                ;;
            --no-studio)
                INSTALL_STUDIO=false
                ;;
            --no-plasma)
                INSTALL_PLASMA=false
                ;;
            --no-apps)
                INSTALL_APPS=false
                ;;
            --no-tweaks)
                INSTALL_TWEAKS=false
                ;;
            --from=*)
                set_current_phase "${arg#*=}"
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --non-interactive    Non-interactive mode (no prompts)"
                echo "  --force              Force reinstallation of all components"
                echo "  --no-studio          Skip audio studio installation"
                echo "  --no-plasma          Skip KDE Plasma installation"
                echo "  --no-apps            Skip applications installation"
                echo "  --no-tweaks          Skip system tweaks"
                echo "  --from=PHASE         Start from a specific phase (init, studio, plasma, apps, tweaks)"
                echo "  --help               Show this help message"
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: ${arg}"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done

    # Check for root privileges
    if [[ ${EUID} -ne 0 ]]; then
        echo "ERROR: This script must be run as root"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi

    # Display the installation configuration
    log_section "Installation Configuration"
    log_info "Interactive Mode: ${INTERACTIVE}"
    log_info "Force Mode: ${FORCE_MODE}"
    log_info "Install Studio: ${INSTALL_STUDIO}"
    log_info "Install Plasma: ${INSTALL_PLASMA}"
    log_info "Install Apps: ${INSTALL_APPS}"
    log_info "Install Tweaks: ${INSTALL_TWEAKS}"

    # Get current phase and execute it
    local current_phase
    current_phase=$(get_current_phase)
    log_info "Starting installation from phase: ${current_phase}"

    case ${current_phase} in
        init)
            if ! phase_init; then
                log_error "Installation failed at init phase"
                exit 1
            fi
            # Continue to next phase
            phase_studio
            ;&
        studio)
            if ! phase_studio; then
                log_error "Installation failed at studio phase"
                exit 1
            fi
            # Continue to next phase
            ;&
        plasma)
            if ! phase_plasma; then
                log_error "Installation failed at plasma phase"
                exit 1
            fi
            # Continue to next phase
            ;&
        apps)
            if ! phase_apps; then
                log_error "Installation failed at apps phase"
                exit 1
            fi
            # Continue to next phase
            ;&
        tweaks)
            if ! phase_tweaks; then
                log_error "Installation failed at tweaks phase"
                exit 1
            fi
            # Continue to next phase
            ;&
        complete)
            phase_complete
            ;;
        *)
            log_error "Unknown installation phase: ${current_phase}"
            log_info "Setting phase to 'init' and restarting"
            set_current_phase "init"
            main "$@"
            ;;
    esac

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function with all arguments
main "$@"

# Return the exit code
exit $?
