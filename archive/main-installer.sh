#!/usr/bin/env bash
# =============================================================================
# main-installer.sh - Main installation script for the system setup
# =============================================================================
# This script serves as the entry point for the entire installation process.
# It calls the scripts in the various phase directories in the correct order.
# 
# Usage: ./main-installer.sh [options]
# Options:
#   -h, --help          Show this help message and exit
#   -l, --list          List all available installation phases
#   -p, --phase PHASE   Install only the specified phase
#   -f, --force         Force installation (ignore previous state)
#   -v, --verbose       Enable verbose output
#   -q, --quiet         Minimize output (only show errors)
#   --skip-phases PHASES Skip specified phases (comma-separated)
#
# Example:
#   ./main-installer.sh --phase core --force   # Run only the core phase with force mode
#   ./main-installer.sh --skip-phases desktop  # Run all phases except desktop
# =============================================================================

# Set strict mode
set -eo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "Error: Cannot source common library. Exiting."
    exit 1
}

# Define installation phases in the correct order
PHASES=(
    "00-core"
    "10-desktop"
    "20-config"
    "30-optimization"
)

# Default options
FORCE_MODE=false
VERBOSE_MODE=false
QUIET_MODE=false
SELECTED_PHASE=""
SKIP_PHASES=""

# ============================================================================
# Function Definitions
# ============================================================================

function print_header() {
    local title="$1"
    local width=80
    local line=$(printf "%${width}s" | tr ' ' '=')
    
    echo -e "\n${COLOR_BOLD}${COLOR_BLUE}${line}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}$(printf "%*s" $(( (width - ${#title}) / 2 )) "")${title}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}${line}${COLOR_RESET}\n"
}

function print_help() {
    cat <<EOF
${COLOR_BOLD}Ubuntu System Setup - Installation Script${COLOR_RESET}

This script installs and configures a complete Ubuntu system based on a
set of predefined phases.

${COLOR_BOLD}Usage:${COLOR_RESET}
  ./main-installer.sh [options]

${COLOR_BOLD}Options:${COLOR_RESET}
  -h, --help                Show this help message and exit
  -l, --list                List all available installation phases
  -p, --phase PHASE         Install only the specified phase
  -f, --force               Force installation (ignore previous state)
  -v, --verbose             Enable verbose output
  -q, --quiet               Minimize output (only show errors)
  --skip-phases PHASES      Skip specified phases (comma-separated)
  
${COLOR_BOLD}Examples:${COLOR_RESET}
  ./main-installer.sh                         # Run all phases in order
  ./main-installer.sh --phase core            # Run only the core phase
  ./main-installer.sh --skip-phases desktop   # Run all phases except desktop
  ./main-installer.sh --force                 # Run all phases, ignoring previous state

${COLOR_BOLD}Available Phases:${COLOR_RESET}
EOF
    list_phases
}

function list_phases() {
    local phase
    local phase_name
    local description
    
    for phase in "${PHASES[@]}"; do
        phase_name=${phase#*-}
        
        # Extract description from the README or first script in phase directory
        if [[ -f "${SCRIPT_DIR}/${phase}/README.md" ]]; then
            description=$(grep -m 1 -A 1 "# " "${SCRIPT_DIR}/${phase}/README.md" | tail -n 1)
        else
            description=$(find "${SCRIPT_DIR}/${phase}" -name "*.sh" | sort | head -n 1 | xargs grep -m 1 "# " | cut -d '#' -f 2-)
            if [[ -z "$description" ]]; then
                description="No description available"
            fi
        fi
        
        echo -e "  ${COLOR_BOLD}${COLOR_GREEN}${phase_name}${COLOR_RESET} - ${description}"
    done
}

function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -l|--list)
                print_header "Available Installation Phases"
                list_phases
                exit 0
                ;;
            -p|--phase)
                if [[ -n "$2" && "$2" != -* ]]; then
                    SELECTED_PHASE="$2"
                    shift
                else
                    log_error "Option $1 requires an argument."
                    exit 1
                fi
                ;;
            -f|--force)
                FORCE_MODE=true
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                set_log_level "DEBUG"
                ;;
            -q|--quiet)
                QUIET_MODE=true
                set_log_level "ERROR"
                ;;
            --skip-phases)
                if [[ -n "$2" && "$2" != -* ]]; then
                    SKIP_PHASES="$2"
                    shift
                else
                    log_error "Option $1 requires an argument."
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
        shift
    done
}

function validate_phase() {
    local phase="$1"
    local phase_name=${phase#*-}
    
    # Check if the selected phase exists
    for p in "${PHASES[@]}"; do
        if [[ "${p#*-}" == "$phase_name" ]]; then
            return 0
        fi
    done
    
    log_error "Invalid phase: $phase_name"
    echo -e "\nAvailable phases:"
    list_phases
    exit 1
}

function should_skip_phase() {
    local phase="$1"
    local phase_name=${phase#*-}
    
    # Check if this phase should be skipped
    if [[ -n "$SKIP_PHASES" ]]; then
        IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_PHASES"
        for skip in "${SKIP_ARRAY[@]}"; do
            if [[ "$phase_name" == "$skip" ]]; then
                return 0  # Should skip
            fi
        done
    fi
    
    return 1  # Should not skip
}

function run_phase() {
    local phase="$1"
    local phase_name=${phase#*-}
    
    if should_skip_phase "$phase"; then
        log_info "Skipping phase: $phase_name"
        return 0
    fi
    
    print_header "Running Phase: $phase_name"
    
    # Check if phase directory exists
    if [[ ! -d "${SCRIPT_DIR}/${phase}" ]]; then
        log_error "Phase directory not found: ${SCRIPT_DIR}/${phase}"
        return 1
    fi
    
    # Find all scripts in the phase directory and run them in order
    local scripts=( $(find "${SCRIPT_DIR}/${phase}" -name "*.sh" | sort) )
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        log_warning "No scripts found in phase: $phase_name"
        return 0
    fi
    
    local start_time=$(date +%s)
    local script_count=${#scripts[@]}
    local success_count=0
    local failed_scripts=()
    
    log_info "Found $script_count scripts in phase: $phase_name"
    
    # Execute each script in the phase
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        log_info "Running script: $script_name"
        
        if [[ "$FORCE_MODE" == "true" ]]; then
            export FORCE_MODE=true
        fi
        
        if [[ "$VERBOSE_MODE" == "true" ]]; then
            export VERBOSE_MODE=true
        fi
        
        if [[ "$QUIET_MODE" == "true" ]]; then
            export QUIET_MODE=true
        fi
        
        # Execute the script
        if bash "$script"; then
            log_success "Script completed successfully: $script_name"
            ((success_count++))
        else
            log_error "Script failed: $script_name"
            failed_scripts+=("$script_name")
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print phase summary
    print_header "Phase Summary: $phase_name"
    echo -e "Total scripts: ${COLOR_BOLD}$script_count${COLOR_RESET}"
    echo -e "Successful scripts: ${COLOR_BOLD}${COLOR_GREEN}$success_count${COLOR_RESET}"
    echo -e "Failed scripts: ${COLOR_BOLD}${COLOR_RED}${#failed_scripts[@]}${COLOR_RESET}"
    echo -e "Duration: ${COLOR_BOLD}$(format_duration $duration)${COLOR_RESET}"
    
    if [[ ${#failed_scripts[@]} -gt 0 ]]; then
        echo -e "\n${COLOR_BOLD}${COLOR_RED}Failed scripts:${COLOR_RESET}"
        for script in "${failed_scripts[@]}"; do
            echo -e "  - $script"
        done
        return 1
    fi
    
    return 0
}

function format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    minutes=$((minutes % 60))
    seconds=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

function main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Initialize with script name for logging
    initialize_script "main-installer"
    
    # Print welcome message
    print_header "Ubuntu System Setup - Installation Script"
    
    log_info "Installation started at: $(date)"
    
    # Set force mode if specified
    if [[ "$FORCE_MODE" == "true" ]]; then
        log_warning "Force mode enabled. Previous state will be ignored."
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    local start_time=$(date +%s)
    local phase_count=${#PHASES[@]}
    local success_count=0
    local failed_phases=()
    
    # Run specific phase if selected
    if [[ -n "$SELECTED_PHASE" ]]; then
        # Find the matching phase directory
        local found=false
        local full_phase_name=""
        
        for phase in "${PHASES[@]}"; do
            if [[ "${phase#*-}" == "$SELECTED_PHASE" ]]; then
                found=true
                full_phase_name=$phase
                break
            fi
        done
        
        if [[ "$found" == "false" ]]; then
            log_error "Phase not found: $SELECTED_PHASE"
            echo -e "\nAvailable phases:"
            list_phases
            exit 1
        fi
        
        log_info "Running only phase: $SELECTED_PHASE"
        
        if run_phase "$full_phase_name"; then
            log_success "Phase completed successfully: $SELECTED_PHASE"
            success_count=1
        else
            log_error "Phase failed: $SELECTED_PHASE"
            failed_phases+=("$SELECTED_PHASE")
        fi
    else
        # Run all phases in order
        log_info "Running all installation phases"
        
        for phase in "${PHASES[@]}"; do
            if run_phase "$phase"; then
                log_success "Phase completed successfully: ${phase#*-}"
                ((success_count++))
            else
                log_error "Phase failed: ${phase#*-}"
                failed_phases+=("${phase#*-}")
            fi
        done
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print installation summary
    print_header "Installation Summary"
    
    if [[ -n "$SELECTED_PHASE" ]]; then
        echo -e "Selected phase: ${COLOR_BOLD}$SELECTED_PHASE${COLOR_RESET}"
    else
        echo -e "Total phases: ${COLOR_BOLD}$phase_count${COLOR_RESET}"
        echo -e "Successful phases: ${COLOR_BOLD}${COLOR_GREEN}$success_count${COLOR_RESET}"
        echo -e "Failed phases: ${COLOR_BOLD}${COLOR_RED}${#failed_phases[@]}${COLOR_RESET}"
    fi
    
    echo -e "Total duration: ${COLOR_BOLD}$(format_duration $duration)${COLOR_RESET}"
    echo -e "Installation completed at: ${COLOR_BOLD}$(date)${COLOR_RESET}"
    
    if [[ ${#failed_phases[@]} -gt 0 ]]; then
        echo -e "\n${COLOR_BOLD}${COLOR_RED}Failed phases:${COLOR_RESET}"
        for phase in "${failed_phases[@]}"; do
            echo -e "  - $phase"
        done
        echo -e "\n${COLOR_BOLD}${COLOR_YELLOW}To retry failed phases, run:${COLOR_RESET}"
        echo -e "  $0 --phase PHASE_NAME --force"
        
        return 1
    else
        echo -e "\n${COLOR_BOLD}${COLOR_GREEN}Installation completed successfully!${COLOR_RESET}"
        
        # Suggest a reboot if substantial changes were made
        if [[ -n "$SELECTED_PHASE" ]]; then
            if [[ "$SELECTED_PHASE" == "core" || "$SELECTED_PHASE" == "desktop" ]]; then
                echo -e "\n${COLOR_BOLD}${COLOR_YELLOW}It is recommended to reboot your system.${COLOR_RESET}"
                echo -e "Run: ${COLOR_BOLD}sudo reboot${COLOR_RESET}"
            fi
        else
            echo -e "\n${COLOR_BOLD}${COLOR_YELLOW}It is recommended to reboot your system.${COLOR_RESET}"
            echo -e "Run: ${COLOR_BOLD}sudo reboot${COLOR_RESET}"
        fi
        
        return 0
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi

#!/bin/bash

# master-installer.sh
# Master script to run Ubuntu Server to KDE conversion scripts in sequence
# with configuration restoration functionality

# Exit on error
set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Display styled header
display_header() {
    clear
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${CYAN}  Ubuntu Server to KDE Plasma Desktop Installer${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo
}

# Display section header
section() {
    echo
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${CYAN}  ${1}${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo
}

# Check if running as root with sudo
check_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}Please run this script with sudo.${NC}"
        exit 1
    fi
    
    # Get the actual user (if running with sudo)
    if [[ -z "${SUDO_USER}" ]]; then
        echo -e "${RED}This script must be run with sudo.${NC}"
        exit 1
    fi
}

# Create flag directory if it doesn't exist
create_flag_directory() {
    local user_home
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    mkdir -p "${user_home}/.config/kde-installer"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${user_home}/.config/kde-installer"
}

# Mark a script as completed
mark_completed() {
    local script_name="${1}"
    local user_home
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    touch "${user_home}/.config/kde-installer/${script_name}.completed"
    chown "${SUDO_USER}":"${SUDO_USER}" "${user_home}/.config/kde-installer/${script_name}.completed"
    echo -e "${GREEN}✓ Marked ${script_name} as completed${NC}"
}

# Check if a script has been completed
is_completed() {
    local script_name="${1}"
    local user_home
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    if [[ -f "${user_home}/.config/kde-installer/${script_name}.completed" ]]; then
        return 0  # True, script is completed
    else
        return 1  # False, script is not completed
    fi
}

# Get script basename without extension
get_script_basename() {
    local full_name="${1}"
    local result
    result=$(basename "${full_name}" .sh) || true
    echo "${result}"
}

# Source the configuration management functions
# shellcheck disable=SC1090
source_config_functions() {
    local script_dir
    script_dir=$(dirname "${0}")
    local config_functions_script="${script_dir}/config-management-functions.sh"

    if [[ -f "${config_functions_script}" ]]; then
        echo -e "${GREEN}Sourcing configuration management functions...${NC}"
        source "${config_functions_script}"
        echo -e "${GREEN}✓ Configuration management functions loaded${NC}"
    else
        echo -e "${RED}Configuration management functions script not found at:${NC}"
        echo -e "${RED}${config_functions_script}${NC}"
        echo -e "${YELLOW}Some scripts may not function correctly without these functions.${NC}"
    fi
}

# Function to restore critical backups before installation
restore_critical_backups() {
return # commented out for now, the backups don't need restored every time this runs
    local script_dir
    script_dir=$(dirname "${0}")
    local restore_script="${script_dir}/restore-critical-backups.sh"
    
    section "Restoring Critical Backups"
    
    if [[ -f "${restore_script}" ]]; then
        echo -e "${GREEN}Restoring critical configuration backups...${NC}"
        chmod +x "${restore_script}"
        
        if bash "${restore_script}"; then
            echo -e "${GREEN}✓ Critical backups restored successfully${NC}"
            
            # Create CONFIG_MAPPING_PATH environment variable for use by install scripts
            if [[ -f "/restart/critical_backups/config_mapping.txt" ]]; then
                export CONFIG_MAPPING_PATH="/restart/critical_backups/config_mapping.txt"
                echo -e "${GREEN}✓ Config mapping path set to: ${CONFIG_MAPPING_PATH}${NC}"
            else
                echo -e "${YELLOW}Warning: Config mapping file not found at /restart/critical_backups/config_mapping.txt${NC}"
                echo -e "${YELLOW}Some installation scripts may not be able to find restored configurations.${NC}"
            fi
            
            return 0
        else
            echo -e "${YELLOW}Warning: Restore script returned non-zero exit code${NC}"
            echo -e "${YELLOW}Will continue with installation, but some configurations may not be available.${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Restore script not found at: ${restore_script}${NC}"
        echo -e "${YELLOW}Will continue with installation without restoring backups.${NC}"
        return 1
    fi
}

# Function to run script with confirmation
run_script() {
    local script="${1}"
    local basename
    
    # Get the basename separately to preserve set -e behavior
    set +e
    basename=$(get_script_basename "${script}")
    set -e
    
    # Check if script has already been completed
    # Run is_completed separately to preserve set -e behavior
    local is_already_completed
    set +e
    is_completed "${basename}"
    is_already_completed=$?
    set -e
    
    if [[ ${is_already_completed} -eq 0 ]]; then
        echo -e "${GREEN}Script ${script} has already been completed. Skipping.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}About to run: ${NC}${CYAN}${script}${NC}"
    echo
    read -p "Do you want to run this script? (y/n): " -n 1 -r
    echo
    
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
        section "Running ${script}"
        chmod +x "${script}"
        
        # Export the path to the configuration management functions
        export CONFIG_FUNCTIONS_PATH
        CONFIG_FUNCTIONS_PATH="$(dirname "${0}")/config-management-functions.sh"
        
        # Export the CONFIG_MAPPING_PATH if it exists
        if [[ -n "${CONFIG_MAPPING_PATH}" ]]; then
            export CONFIG_MAPPING_PATH
        fi
        
        # Run the script
        local script_result
        set +e
        bash "${script}"
        script_result=$?
        set -e
        
        if [[ ${script_result} -eq 0 ]]; then
            echo
            echo -e "${GREEN}✓ Completed: ${script}${NC}"
            
            # Mark script as completed
            mark_completed "${basename}"
            
            echo
            read -p "Press Enter to continue to the next script..." -r
            return 0
        else
            echo
            echo -e "${RED}✗ Failed: ${script}${NC}"
            echo "Please resolve any issues before continuing."
            return 1
        fi
    else
        echo -e "${YELLOW}Skipped: ${script}${NC}"
        return 0
    fi
}

# Find all installation scripts
find_scripts() {
    local script_dir
    script_dir=$(dirname "${0}")
    
    # Find all scripts with numeric prefixes except LVM scripts and sort them
    find "${script_dir}" -maxdepth 1 -name "[0-9][0-9]-*.sh" | grep -v "lvm" | sort || true
}

# Main function
main() {
    display_header
    check_sudo
    create_flag_directory
    source_config_functions
    
    # Restore critical backups first
    restore_critical_backups
    
    # Get list of scripts
    local script_list
    script_list=$(find_scripts) || true
    mapfile -t SCRIPTS <<< "${script_list}"
    
    section "Installation Sequence"
    echo "The following scripts will be executed in sequence:"
    echo
    
    for script in "${SCRIPTS[@]}"; do
        local basename
        # Get the basename separately to preserve set -e behavior
        set +e
        basename=$(get_script_basename "${script}")
        set -e
        
        # Run is_completed separately to preserve set -e behavior
        local is_already_completed
        set +e
        is_completed "${basename}"
        is_already_completed=$?
        set -e
        
        if [[ ${is_already_completed} -eq 0 ]]; then
            echo -e "${GREEN}✓ ${script}${NC} (completed)"
        else
            echo -e "${YELLOW}• ${script}${NC} (pending)"
        fi
    done
    
    echo
    read -p "Press Enter to begin the installation sequence..." -r
    
    # Execute scripts in sequence
    for script in "${SCRIPTS[@]}"; do
        # Run the script separately to preserve set -e behavior
        local run_result
        set +e
        run_script "${script}"
        run_result=$?
        set -e
        
        if [[ ${run_result} -ne 0 ]]; then
            echo -e "${RED}Installation sequence interrupted.${NC}"
            echo "Fix the issues and run this script again to continue."
            exit 1
        fi
        
        # Check if a reboot is needed based on script name
        local basename
        basename=$(get_script_basename "${script}") || true
        if [[ "${basename}" == *"kde-desktop"* ]] || [[ "${basename}" == *"nvidia"* ]]; then
            echo -e "${YELLOW}A reboot is recommended at this point.${NC}"
            echo "This ensures all components are properly initialized."
            echo
            read -p "Do you want to reboot now? (y/n): " -n 1 -r
            echo
            
            if [[ ${REPLY} =~ ^[Yy]$ ]]; then
                echo "Rebooting system..."
                echo "After reboot, run this script again to continue the installation."
                sleep 3
                reboot
                exit 0
            else
                echo "Continuing without reboot..."
            fi
        fi
    done
    
    section "Installation Complete!"
    echo -e "${GREEN}All installation scripts have been executed successfully.${NC}"
    echo "Your system is now set up with:"
    echo "  • KDE Plasma desktop environment"
    echo "  • Development tools and environments"
    echo "  • Properly symlinked configurations from your config repository"
    echo "  • Audio system optimizations"
    echo "  • Network and system performance tweaks"
    echo
    echo "You may want to reboot your system to ensure all changes take effect."
    echo
    read -p "Do you want to reboot now? (y/n): " -n 1 -r
    echo
    
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Rebooting system..."
        sleep 3
        reboot
    fi
}

# Run the main function
main
