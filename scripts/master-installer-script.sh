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
