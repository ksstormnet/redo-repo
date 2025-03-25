# Configuration Management System

This document explains the configuration management system used in the installation scripts. The system provides a consistent way to handle configuration files across different software installations.

## Overview

The configuration management system follows these principles:

1. **Repository-Based**: All configuration files are stored in a central Git repository at `/repo/personal/core-configs`.
2. **Symlink-Based**: Configuration files are symlinked from their original locations to the repository.
3. **Automatic Handling**: The system automatically detects and manages configuration files.
4. **Version Control**: Changes to configuration files are committed to the repository.

## Configuration Management Functions

The configuration management functions are defined in `config-management-functions.sh` and provide three main functions:

### 1. `handle_installed_software_config`

This function handles configuration files when software is already installed:

- If a configuration file exists in the repository, it creates a symlink from the original location to the repository.
- If a configuration file exists in the system but not in the repository, it moves the file to the repository and creates a symlink.
- It commits any new configuration files to the repository.

Usage:
```bash
handle_installed_software_config "software_name" "config_file_path1" "config_file_path2" ...
```

### 2. `handle_pre_installation_config`

This function handles configuration files before software is installed:

- If a configuration file exists in the repository, it creates a symlink from the repository to the original location.
- This allows pre-configuring software before it's installed.

Usage:
```bash
handle_pre_installation_config "software_name" "config_file_path1" "config_file_path2" ...
```

### 3. `check_post_installation_configs`

This function checks for new configuration files after software installation:

- It looks for configuration files that exist in the system but not in the repository.
- If found, it moves the file to the repository, creates a symlink, and commits the changes.

Usage:
```bash
check_post_installation_configs "software_name" "config_file_path1" "config_file_path2" ...
```

## Workflow Examples

### Example 1: Installing Software with Existing Configurations

```bash
# Define configuration files to manage
CONFIG_FILES=(
    "$USER_HOME/.config/software/settings.conf"
    "$USER_HOME/.config/software/keybindings.conf"
)

# Set up pre-installation configurations
handle_pre_installation_config "software" "${CONFIG_FILES[@]}"

# Install the software
install_packages "Software" software

# Handle configuration files after installation
handle_installed_software_config "software" "${CONFIG_FILES[@]}"

# Check for any new configuration files created during installation
check_post_installation_configs "software" "${CONFIG_FILES[@]}"
```

### Example 2: Adding New Software to the System

When adding new software to the system, follow these steps:

1. Define the configuration files that need to be managed.
2. Use `handle_pre_installation_config` before installing the software.
3. Install the software.
4. Use `handle_installed_software_config` after installing the software.
5. Use `check_post_installation_configs` to check for any new configuration files.

## Repository Structure

The repository at `/repo/personal/core-configs` is organized by software:

```
/repo/personal/core-configs/
├── zsh/
│   ├── .zshrc
│   └── .zsh/
├── vscode/
│   ├── settings.json
│   └── keybindings.json
├── kde/
│   ├── kwinrc
│   └── ...
└── ...
```

Each software has its own directory containing its configuration files.

## Benefits

This configuration management system provides several benefits:

1. **Consistency**: All configuration files are managed in a consistent way.
2. **Portability**: Configuration files can be easily transferred to a new system.
3. **Version Control**: Changes to configuration files are tracked in Git.
4. **Automation**: The system automatically handles configuration files.
5. **Flexibility**: The system can handle both pre-installation and post-installation configurations.

## Implementation Details

The configuration management functions handle the following scenarios:

1. **Software is installed and now we're handling configs**:
   - If a file exists in the repo, it overrides the default config by deleting the default and symlinking the repo version in its place.
   - If the repo does not have a config file for the software, the system locates the correct config file(s), moves them to the repo, and then symlinks them from the original location to the repo. At the conclusion, it commits the repo, describing which configs were added.

2. **Configs are placed before the software is installed**:
   - The system symlinks from the repo to the correct location.
   - After the software is installed, it reviews to see if it created new config files, and if so, follows the process to add them to the repo, symlink them, and commit the repo.
