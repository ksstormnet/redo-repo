#!/bin/bash
#
# Revised Master Installer Script
# ------------------------------
#
# This script provides a unified approach to system configuration by:
# - Using a modular, phase-based approach
# - Processing scripts in correct order based on directory structure
# - Handling reboots at appropriate points
# - Supporting both interactive and non-interactive modes
# - Providing extensive command-line options
# - Offering comprehensive logging and error handling
#
# Usage:
#   ./revised-master-installer.sh [options]
#
# Options:
#   --help              Show this help message
#   --phase PHASE       Run only the specified phase(s)
#   --skip-phases PHASE Skip the specified phase(s)
#   --force             Force execution of already completed scripts
#   --interactive       Run in interactive mode with prompts
#   --auto-reboot       Automatically reboot when necessary
#   --dry-run           Show what would be executed without actually executing
#   --verbose           Enable verbose output
#   --no-color          Disable colored output
#   --log-mode MODE     Set log display mode (full, minimal, quiet)
#   --log-level LEVEL   Set log level (DEBUG, INFO, WARNING, ERROR)
#
# Examples:
#   ./revised-master-installer.sh                      # Run all phases in non-interactive mode
#   ./revised-master-installer.sh --interactive        # Run all phases with interactive prompts
#   ./revised-master-installer.sh --phase 00-core      # Run only the core phase
#   ./revised-master-installer.sh --skip-phases 30-applications,40-optimization  # Skip specified phases
#   ./revised-master-installer.sh --force --phase 10-desktop  # Re-run the desktop phase

# shellcheck disable=SC2311

# Set script to exit on error
set -e

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions and utilities
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: lib/common.sh not found. Script cannot continue."
    exit 1
fi

# Define script variables
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME=""
SCRIPT_NAME=$(basename "$0")
STATE_DIR="/var/cache/system-installer"
LOG_DIR="/var/log/system-installer"
REBOOT_MARKER="${STATE_DIR}/reboot_required"
CURRENT_PHASE_MARKER="${STATE_DIR}/current_phase"
# SCRIPT_START_TIME is used for calculating elapsed time
SCRIPT_START_TIME=""
SCRIPT_START_TIME=$(date +%s) || true

# Function to print elapsed time (referenced by SCRIPT_START_TIME)
function print_elapsed_time() {
    local end_time
    end_time=$(date +%s) || true
    local elapsed=$((end_time - SCRIPT_START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(( (elapsed % 3600) / 60 ))
    local seconds=$((elapsed % 60))
    
    log_info "Total installation time: ${hours}h ${minutes}m ${seconds}s"
}

# Default configuration
INTERACTIVE=false
AUTO_REBOOT=false
DRY_RUN=false
FORCE_MODE=false
VERBOSE=false
PHASES_TO_RUN=()
PHASES_TO_SKIP=()
LOG_MODE="normal"  # Options: full, minimal, quiet
LOG_LEVEL="INFO"   # Options: DEBUG, INFO, WARNING, ERROR

# Print usage information
function print_usage() {
    echo "Usage: ${SCRIPT_NAME} [options]"
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --phase PHASE       Run only the specified phase(s) (comma-separated)"
    echo "  --skip-phases PHASE Skip the specified phase(s) (comma-separated)"
    echo "  --force             Force execution of already completed scripts"
    echo "  --interactive       Run in interactive mode with prompts"
    echo "  --auto-reboot       Automatically reboot when necessary"
    echo "  --dry-run           Show what would be executed without actually executing"
    echo "  --verbose           Enable verbose output"
    echo "  --no-color          Disable colored output"
    echo "  --log-mode MODE     Set log display mode (full, minimal, quiet)"
    echo "  --log-level LEVEL   Set log level (DEBUG, INFO, WARNING, ERROR)"
    echo ""
    echo "Examples:"
    echo "  ${SCRIPT_NAME}                      # Run all phases in non-interactive mode"
    echo "  ${SCRIPT_NAME} --interactive        # Run all phases with interactive prompts"
    echo "  ${SCRIPT_NAME} --phase 00-core      # Run only the core phase"
    echo "  ${SCRIPT_NAME} --phase '00-core,10-desktop'  # Run only core and desktop phases"
    echo "  ${SCRIPT_NAME} --skip-phases 30-applications,40-optimization  # Skip specified phases"
}

# Parse command-line arguments
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                print_usage
                exit 0
                ;;
            --phase)
                if [[ -z "$2" || "$2" == --* ]]; then
                    log_error "Missing argument for --phase"
                    exit 1
                fi
                IFS=',' read -ra PHASES <<< "$2"
                for phase in "${PHASES[@]}"; do
                    PHASES_TO_RUN+=("${phase}")
                done
                shift 2
                ;;
            --skip-phases)
                if [[ -z "$2" || "$2" == --* ]]; then
                    log_error "Missing argument for --skip-phases"
                    exit 1
                fi
                IFS=',' read -ra PHASES <<< "$2"
                for phase in "${PHASES[@]}"; do
                    PHASES_TO_SKIP+=("${phase}")
                done
                shift 2
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --auto-reboot)
                AUTO_REBOOT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                shift
                ;;
            --no-color)
                export NO_COLOR=true
                shift
                ;;
            --log-mode)
                if [[ -z "$2" || "$2" == --* ]]; then
                    log_error "Missing argument for --log-mode"
                    exit 1
                fi
                LOG_MODE="$2"
                export LOG_MODE="${LOG_MODE}"
                shift 2
                ;;
            --log-level)
                if [[ -z "$2" || "$2" == --* ]]; then
                    log_error "Missing argument for --log-level"
                    exit 1
                fi
                LOG_LEVEL="$2"
                export LOG_LEVEL="${LOG_LEVEL}"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

# Find all phases in correct order
function find_phases() {
    local all_phases=()
    
    # Find all phase directories - avoid masking return value
    local find_result
    # Use set +e to temporarily disable exit on error
    set +e
    find_result=$(find . -maxdepth 1 -type d -name "[0-9][0-9]-*" | sort) || true
    local find_status=$?
    # Re-enable exit on error
    set -e
    
    if [[ ${find_status} -ne 0 ]]; then
        log_warning "Error finding phase directories"
        return "${find_status}"
    fi
    
    for dir in ${find_result}; do
        dir=${dir#./}
        all_phases+=("${dir}")
    done
    
    if [[ ${#all_phases[@]} -eq 0 ]]; then
        log_error "No phase directories found"
        exit 1
    fi
    
    # Log found phases
    log_info "Found ${#all_phases[@]} phases: ${all_phases[*]}"
    
    if [[ ${#PHASES_TO_RUN[@]} -gt 0 ]]; then
        # Filter to include only requested phases
        local matching_phases=()
        for phase in "${all_phases[@]}"; do
            for requested in "${PHASES_TO_RUN[@]}"; do
                if [[ "${phase}" == "${requested}" || "${phase}" == *"${requested}"* ]]; then
                    matching_phases+=("${phase}")
                    break
                fi
            done
        done
        all_phases=("${matching_phases[@]}")
        log_info "Filtered to ${#all_phases[@]} phases based on --phase option: ${all_phases[*]}"
    fi
    
    if [[ ${#PHASES_TO_SKIP[@]} -gt 0 ]]; then
        # Filter to exclude skipped phases
        local remaining_phases=()
        for phase in "${all_phases[@]}"; do
            local skip=false
            for skipped in "${PHASES_TO_SKIP[@]}"; do
                if [[ "${phase}" == "${skipped}" || "${phase}" == *"${skipped}"* ]]; then
                    skip=true
                    break
                fi
            done
            if [[ "${skip}" == "false" ]]; then
                remaining_phases+=("${phase}")
            fi
        done
        all_phases=("${remaining_phases[@]}")
        log_info "Filtered to ${#all_phases[@]} phases after skipping: ${all_phases[*]}"
    fi
    
    # Return the phases as output, separated by newlines
    printf "%s\n" "${all_phases[@]}"
}

# Find all scripts in a phase in the correct order
function find_scripts() {
    local phase="$1"
    
    if [[ ! -d "${phase}" ]]; then
        log_error "Phase directory ${phase} does not exist"
        return 1
    fi
    
    # Store result in a variable to avoid masking return value
    local find_result
    # Use set +e to temporarily disable exit on error
    set +e
    find_result=$(find "${phase}" -maxdepth 1 -type f -name "*.sh" | sort) || true
    local find_status=$?
    # Re-enable exit on error
    set -e
    
    if [[ ${find_status} -ne 0 ]]; then
        log_warning "Error finding scripts in ${phase}"
        return "${find_status}"
    fi
    
    echo "${find_result}"
    return 0
}

# Check if a reboot is required after running a script
function check_reboot_required() {
    local script_path="$1"
    local script_name=""
    script_name=$(basename "${script_path}")
    
    # Check for explicit reboot files
    if [[ -f "${REBOOT_MARKER}" ]]; then
        log_info "Reboot marker file found"
        return 0
    fi
    
    # Check for standard system reboot indicators
    if [[ -f /var/run/reboot-required ]]; then
        log_info "System reboot required file found"
        return 0
    fi
    
    # Check if script contains a reboot trigger phrase
    if grep -q "# REBOOT_REQUIRED" "${script_path}"; then
        log_info "Script ${script_name} has REBOOT_REQUIRED marker"
        return 0
    fi
    
    return 1
}

# Run a script and handle its output properly
function run_script() {
    local script_path="$1"
    local script_name=""
    script_name=$(basename "${script_path}")
    local phase_name=""
    phase_name=$(dirname "${script_path}")
    phase_name=${phase_name#./}

    # Check if script has already been completed
    if is_step_completed "${phase_name}/${script_name}" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Skipping ${script_name} (already completed)"
        return 0
    fi

    # Visual separator before running script
    log_section "Running: ${script_name} (Phase: ${phase_name})"

    # In interactive mode, prompt before running each script
    if [[ "${INTERACTIVE}" == "true" ]]; then
        # Display script description if it exists (first comment block in the script)
        local description=""
        # Break down the command to avoid masking return values
        local grep_result
        grep_result=$(grep "^#" "${script_path}") || true
        
        local filtered_result
        filtered_result=$(echo "${grep_result}" | grep -v "^#!/") || true
        
        local head_result
        head_result=$(echo "${filtered_result}" | head -5) || true
        
        local description
        # Use parameter expansion instead of sed
        description="${head_result//#\ /}" || true
        if [[ -n "${description}" ]]; then
            echo "Description:"
            echo "${description}"
            echo ""
        fi
        
        if ! prompt_yes_no "Run this script?" "y"; then
            log_info "Skipping ${script_name} (user request)"
            return 0
        fi
    fi

    # Execute the script
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: bash ${script_path}"
    else
        log_info "Executing: ${script_path}"
        
        # Create script-specific log file - will be used by log_script_execution
        
        # Execute the script and capture its exit code
        if log_script_execution "${script_path}"; then
            mark_step_completed "${phase_name}/${script_name}"
            log_success "Script ${script_name} completed successfully"
        else
            local exit_code=$?
            log_error "Script ${script_name} failed with exit code ${exit_code}"
            
            if [[ "${INTERACTIVE}" == "true" ]]; then
                if ! prompt_yes_no "Continue despite error?" "n"; then
                    log_error "Aborting installation at user request"
                    exit 1
                fi
            else
                log_error "Aborting installation due to script failure"
                exit 1
            fi
        fi
    fi

    # Check if a reboot is required
    # Check reboot required separately to avoid masking return value
    local reboot_required
    check_reboot_required "${script_path}"
    reboot_required=$?
    
    if [[ ${reboot_required} -eq 0 ]]; then
        # Get next script for continuation after reboot
        local all_scripts=()
        local scripts_result
        
        # Call find_scripts separately to avoid masking return value
        set +e  # Temporarily disable exit on error
        find_scripts "${phase_name}"
        local find_status=$?
        set -e  # Re-enable exit on error
        
        # Now get the result, but don't use || true to avoid SC2310
        if [[ ${find_status} -eq 0 ]]; then
            scripts_result=$(find_scripts "${phase_name}")
        else
            log_warning "Error finding scripts in ${phase_name} for reboot handling"
            # Continue anyway, just won't have a next script
            scripts_result=""
        fi
        
        # Use readarray to read the output into an array
        readarray -t all_scripts <<< "${scripts_result}"
        local next_script=""
        local found=false
        
        for s in "${all_scripts[@]}"; do
            if [[ "${found}" == "true" ]]; then
                next_script="${s}"
                break
            fi
            
            if [[ "${s}" == "${script_path}" ]]; then
                found=true
            fi
        done
        
        handle_reboot "Reboot required after running ${script_name}" "${next_script}"
    fi
    
    return 0
}

# Main installer function
function run_installer() {
    # Check if script is running as root
    if [[ ${EUID} -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Initialize state directory
    initialize_state
    
    # Get all phases - call find_phases separately to avoid masking return value
    local phases_result
    
    # Call find_phases separately to avoid masking return value
    set +e  # Temporarily disable exit on error
    find_phases
    local find_status=$?
    set -e  # Re-enable exit on error
    
    # Now get the result, but don't use || true to avoid SC2310
    if [[ ${find_status} -eq 0 ]]; then
        phases_result=$(find_phases)
    else
        log_error "Error finding installation phases"
        exit 1
    fi
    
    readarray -t all_phases <<< "${phases_result}"
    
    # Get total number of scripts for progress calculation
    local total_scripts=0
    local completed_scripts=0
    
    for phase in "${all_phases[@]}"; do
        local scripts=()
        # Store result to avoid masking return value
        local scripts_result
        
        # Call find_scripts separately to avoid masking return value
        set +e  # Temporarily disable exit on error
        find_scripts "${phase}"
        local find_status=$?
        set -e  # Re-enable exit on error
        
        # Now get the result, but don't use || true to avoid SC2310
        if [[ ${find_status} -eq 0 ]]; then
            scripts_result=$(find_scripts "${phase}")
        else
            log_warning "Error finding scripts in ${phase}"
            scripts_result=""
        fi
        
        readarray -t scripts <<< "${scripts_result}"
        total_scripts=$((total_scripts + ${#scripts[@]}))
    done
    
    log_info "Found ${total_scripts} scripts in ${#all_phases[@]} phases"
    
    # Check if resuming after reboot
    if is_resuming_after_reboot; then
        local execution_state
        execution_state=$(get_saved_execution_state)
        
        local resume_phase
        # Break down the command to avoid masking return values
        local grep_phase_result
        grep_phase_result=$(echo "${execution_state}" | grep -o "phase=.*,") || true
        
        local cut_phase_result
        cut_phase_result=$(echo "${grep_phase_result}" | cut -d'=' -f2) || true
        
        local resume_phase
        resume_phase=$(echo "${cut_phase_result}" | cut -d',' -f1) || true
        
        local grep_script_result
        grep_script_result=$(echo "${execution_state}" | grep -o "script=.*") || true
        
        local resume_script
        resume_script=$(echo "${grep_script_result}" | cut -d'=' -f2) || true
        
        if [[ -f "${resume_script}" ]]; then
            log_info "Resuming installation after reboot"
            log_info "Continuing with phase ${resume_phase}, script $(basename "${resume_script}")"
            
            # Remove reboot markers
            clear_execution_state
            
            # Find the phase that contains the resume script
            # Declare first, then assign to avoid masking return values
            local phases_result
            
            # Call find_phases separately to avoid masking return value
            set +e  # Temporarily disable exit on error
            find_phases
            local find_status=$?
            set -e  # Re-enable exit on error
            
            # Now get the result, but don't use || true to avoid SC2310
            if [[ ${find_status} -eq 0 ]]; then
                phases_result=$(find_phases)
            else
                log_warning "Error finding phases for resume"
                phases_result=""
            fi
            
            local phases="${phases_result}"
            local resumed=false
            
            for phase in ${phases}; do
                if [[ "${phase}" == "${resume_phase}" ]] || [[ "${resumed}" == "true" ]]; then
                    resumed=true
                    log_section "Processing phase: ${phase}"
                    
                    # Use mapfile instead of command substitution with array
                    local scripts_result
                    
                    # Call find_scripts separately to avoid masking return value
                    set +e  # Temporarily disable exit on error
                    find_scripts "${phase}"
                    local find_status=$?
                    set -e  # Re-enable exit on error
                    
                    # Now get the result, but don't use || true to avoid SC2310
                    if [[ ${find_status} -eq 0 ]]; then
                        scripts_result=$(find_scripts "${phase}")
                    else
                        log_warning "Error finding scripts in ${phase} for resume"
                        scripts_result=""
                    fi
                    
                    local scripts=()
                    readarray -t scripts <<< "${scripts_result}"
                    local skip_until_resume=true
                    
                    for script in "${scripts[@]}"; do
                        if [[ "${skip_until_resume}" == "true" && "${script}" == "${resume_script}" ]]; then
                            skip_until_resume=false
                        fi
                        
                        if [[ "${skip_until_resume}" == "false" ]]; then
                            completed_scripts=$((completed_scripts + 1))
                            # Calculate progress percentage (for potential future use)
                            # local progress=$((completed_scripts * 100 / total_scripts))
                            
                            # Show progress
                            show_progress "${completed_scripts}" "${total_scripts}" "Processing script"
                            
                            run_script "${script}"
                        else
                            # Count skipped scripts for progress tracking
                            completed_scripts=$((completed_scripts + 1))
                        fi
                    done
                fi
            done
        else
            log_warning "Resume script not found: ${resume_script}"
        fi
    fi
    
    # Regular execution (not resuming or resuming but finished the resumed phase)
    for phase in "${all_phases[@]}"; do
        if [[ -f "${CURRENT_PHASE_MARKER}" ]]; then
            # Declare first, then assign to avoid masking return values
            local current_phase
            current_phase=$(cat "${CURRENT_PHASE_MARKER}") || true
            if [[ "${phase}" == "${current_phase}" ]]; then
                # Skip this phase as it's being handled by the resume logic
                continue
            fi
        fi
        
        log_section "Processing phase: ${phase}"
        echo "${phase}" > "${CURRENT_PHASE_MARKER}"
        
        local scripts=()
        # Store result to avoid masking return value
        local scripts_result
        
        # Call find_scripts separately to avoid masking return value
        set +e  # Temporarily disable exit on error
        find_scripts "${phase}"
        local find_status=$?
        set -e  # Re-enable exit on error
        
        # Now get the result, but don't use || true to avoid SC2310
        if [[ ${find_status} -eq 0 ]]; then
            scripts_result=$(find_scripts "${phase}")
        else
            log_warning "Error finding scripts in ${phase}"
            scripts_result=""
        fi
        
        readarray -t scripts <<< "${scripts_result}"
        log_debug "Found ${#scripts[@]} scripts in phase ${phase}"
        
        for script in "${scripts[@]}"; do
            completed_scripts=$((completed_scripts + 1))
            
            # Show progress
            show_progress "${completed_scripts}" "${total_scripts}" "Processing script"
            
            run_script "${script}"
        done
    done
    
    # Clean up phase marker when done
    rm -f "${CURRENT_PHASE_MARKER}"
    
    # Installation completed successfully
    print_elapsed_time
    
    log_success "Installation completed successfully!"
    
    return 0
}

# Script entry point
function main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Display banner
    log_section "Revised System Installer (v${SCRIPT_VERSION})"
    
    # Log script start
    log_info "Starting installation with options:"
    log_info "  Interactive: ${INTERACTIVE}"
    log_info "  Auto-reboot: ${AUTO_REBOOT}"
    log_info "  Dry-run: ${DRY_RUN}"
    log_info "  Force: ${FORCE_MODE}"
    log_info "  Verbose: ${VERBOSE}"
    log_info "  Log mode: ${LOG_MODE}"
    log_info "  Log level: ${LOG_LEVEL}"
    
    if [[ ${#PHASES_TO_RUN[@]} -gt 0 ]]; then
        log_info "  Phases to run: ${PHASES_TO_RUN[*]}"
    fi
    
    if [[ ${#PHASES_TO_SKIP[@]} -gt 0 ]]; then
        log_info "  Phases to skip: ${PHASES_TO_SKIP[*]}"
    fi
    
    # Setup error traps
    setup_error_traps
    
    # Run the installer
    run_installer
    
    exit 0
}

# Initialize the script
initialize()
{
    # Set up required directories and initial state
    mkdir -p "${STATE_DIR}" "${LOG_DIR}"
}

initialize

# Execute main with all arguments
main "$@"
