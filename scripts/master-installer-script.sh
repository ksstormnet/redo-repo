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
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    mkdir -p "${user_home}/.config/kde-installer"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${user_home}/.config/kde-installer"
}

# Mark a script as completed
mark_completed() {
    local script_name="${1}"
    local user_home
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    touch "${user_home}/.config/kde-installer/${script_name}.completed"
    chown "${SUDO_USER}":"${SUDO_USER}" "${user_home}/.config/kde-installer/${script_name}.completed"
    echo -e "${GREEN}✓ Marked ${script_name} as completed${NC}"
}

# Check if a script has been completed
is_completed() {
    local script_name="${1}"
    local user_home
    user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    if [[ -f "${user_home}/.config/kde-installer/${script_name}.completed" ]]; then
        return 0  # True, script is completed
    else
        return 1  # False, script is not completed
    fi
}

# Get script basename without extension
get_script_basename() {
    local full_name="${1}"
    basename "${full_name}" .sh
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

# Function to run script with confirmation
run_script() {
    local script="${1}"
    local basename
    basename=$(get_script_basename "${script}")
    
    # Check if script has already been completed
    if is_completed "${basename}"; then
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
        
        # Run the script
        if bash "${script}"; then
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
    
    # Find all scripts with numeric prefixes and sort them
    find "${script_dir}" -maxdepth 1 -name "[0-9][0-9]-*.sh" | sort
}

# Main function
main() {
    display_header
    check_sudo
    create_flag_directory
    source_config_functions
    
    # Get list of scripts
    mapfile -t SCRIPTS < <(find_scripts)
    
    section "Installation Sequence"
    echo "The following scripts will be executed in sequence:"
    echo
    
    for script in "${SCRIPTS[@]}"; do
        local basename
        basename=$(get_script_basename "${script}")
        if is_completed "${basename}"; then
            echo -e "${GREEN}✓ ${script}${NC} (completed)"
        else
            echo -e "${YELLOW}• ${script}${NC} (pending)"
        fi
    done
    
    echo
    read -p "Press Enter to begin the installation sequence..." -r
    
    # Execute scripts in sequence
    for script in "${SCRIPTS[@]}"; do
        run_script "${script}"
        
        # Check if script execution failed
        if ! run_script "${script}"; then
            echo -e "${RED}Installation sequence interrupted.${NC}"
            echo "Fix the issues and run this script again to continue."
            exit 1
        fi
        
        # Check if a reboot is needed based on script name
        local basename
        basename=$(get_script_basename "${script}")
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
