#!/bin/bash
# shellcheck disable=SC1091

# config-management-functions.sh
# This script provides functions for managing configuration files
# to be included in other installation scripts

# Function to handle configuration files when software is installed
# Usage: handle_installed_software_config <software_name> <config_file_path> [<additional_config_files>...]
handle_installed_software_config() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    local commit_needed=false
    local added_configs=()
    
    echo "Managing configuration for $software_name..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    mkdir -p "$software_dir"
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the target path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the repo
        if [ -e "$repo_config" ]; then
            echo "Config file exists in repo: $repo_config"
            
            # If the original config exists and is not a symlink, back it up and remove it
            if [ -e "$config_file" ] && [ ! -L "$config_file" ]; then
                echo "Backing up existing config: $config_file → ${config_file}.orig.$(date +%Y%m%d-%H%M%S)"
                mv "$config_file" "${config_file}.orig.$(date +%Y%m%d-%H%M%S)"
            elif [ -L "$config_file" ]; then
                # If it's already a symlink, remove it
                echo "Removing existing symlink: $config_file"
                rm "$config_file"
            fi
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "$config_file")"
            
            # Create symlink from original location to repo
            echo "Creating symlink: $config_file → $repo_config"
            ln -sf "$repo_config" "$config_file"
        else
            # Config doesn't exist in repo, but exists in the system
            if [ -e "$config_file" ] && [ ! -L "$config_file" ]; then
                echo "Moving config to repo: $config_file → $repo_config"
                
                # Create parent directory in repo if needed
                mkdir -p "$(dirname "$repo_config")"
                
                # Move the config file to the repo
                cp -a "$config_file" "$repo_config"
                
                # Remove the original and create a symlink
                rm "$config_file"
                ln -sf "$repo_config" "$config_file"
                
                # Mark for commit
                commit_needed=true
                added_configs+=("$filename")
            else
                echo "Config file not found: $config_file"
            fi
        fi
    done
    
    # Commit changes if needed
    if [[ "${commit_needed}" = true ]] && [[ ${#added_configs[@]} -gt 0 ]]; then
        echo "Committing new configurations to repository..."
        
        # Format the list of added configs for the commit message
        local commit_message="Add ${software_name} configurations: ${added_configs[*]}"
        
        # Commit the changes
        (cd "${repo_dir}" && git add "${software_name}" && git commit -m "${commit_message}")
        echo "✓ Committed changes to repository"
    fi
    
    echo "✓ Configuration management for ${software_name} completed"
}

# Function to handle configuration files before software is installed
# Usage: handle_pre_installation_config <software_name> <config_file_path> [<additional_config_files>...]
handle_pre_installation_config() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    
    echo "Setting up pre-installation configuration for ${software_name}..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    
    # Check if the software directory exists in the repo
    if [[ ! -d "${software_dir}" ]]; then
        echo "No pre-installation configs found for ${software_name} in the repository."
        return 0
    fi
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the source path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the repo
        if [ -e "$repo_config" ]; then
            echo "Config file exists in repo: $repo_config"
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "$config_file")"
            
            # Create symlink from repo to original location
            echo "Creating symlink: $config_file → $repo_config"
            ln -sf "$repo_config" "$config_file"
        fi
    done
    
    echo "✓ Pre-installation configuration for ${software_name} completed"
}

# Function to check for new config files after software installation
# Usage: check_post_installation_configs <software_name> <config_file_path> [<additional_config_files>...]
check_post_installation_configs() {
    local software_name="${1}"
    shift
    local config_files=("$@")
    local repo_dir="/repo/personal/core-configs"
    local commit_needed=false
    local added_configs=()
    
    echo "Checking for new configuration files after ${software_name} installation..."
    
    # Ensure the repository directory exists
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Configuration repository not found at $repo_dir"
        echo "Please ensure the repository is mounted or cloned at this location."
        return 1
    fi
    
    # Create software-specific directory in the repo if it doesn't exist
    local software_dir="${repo_dir}/${software_name}"
    mkdir -p "$software_dir"
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
        # Skip if the path is empty
        if [ -z "$config_file" ]; then
            continue
        fi
        
        # Get the filename and create the target path in the repo
        local filename
        filename=$(basename "$config_file")
        local repo_config="${software_dir}/${filename}"
        
        # Check if the config exists in the system but not in the repo
        if [ -e "$config_file" ] && [ ! -L "$config_file" ] && [ ! -e "$repo_config" ]; then
            echo "New config file found: $config_file"
            
            # Create parent directory in repo if needed
            mkdir -p "$(dirname "$repo_config")"
            
            # Move the config file to the repo
            cp -a "$config_file" "$repo_config"
            
            # Remove the original and create a symlink
            rm "$config_file"
            ln -sf "$repo_config" "$config_file"
            
            # Mark for commit
            commit_needed=true
            added_configs+=("$filename")
        fi
    done
    
    # Commit changes if needed
    if [[ "${commit_needed}" = true ]] && [[ ${#added_configs[@]} -gt 0 ]]; then
        echo "Committing new configurations to repository..."
        
        # Format the list of added configs for the commit message
        local commit_message="Add new ${software_name} configurations after installation: ${added_configs[*]}"
        
        # Commit the changes
        (cd "${repo_dir}" && git add "${software_name}" && git commit -m "${commit_message}")
        echo "✓ Committed changes to repository"
    else
        echo "No new configuration files found for ${software_name}"
    fi
    
    echo "✓ Post-installation configuration check for ${software_name} completed"
}
