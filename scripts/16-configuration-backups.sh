#!/bin/bash

# 15-configuration-backups.sh
# This script sets up an integrated configuration management strategy
# that works alongside a Git repository for dotfiles/configs
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source the configuration management functions
# shellcheck disable=SC1090
if [[ -n "${CONFIG_FUNCTIONS_PATH}" ]] && [[ -f "${CONFIG_FUNCTIONS_PATH}" ]]; then
    source "${CONFIG_FUNCTIONS_PATH}"
else
    echo "ERROR: Configuration management functions not found."
    echo "Please ensure the CONFIG_FUNCTIONS_PATH environment variable is set correctly."
    exit 1
fi

# Display a section header
section() {
    echo
    echo "========================================================"
    echo "  ${1}"
    echo "========================================================"
    echo
}

# Function to check if a file is a symlink and get its target
get_symlink_target() {
    if [[ -L "${1}" ]]; then
        readlink -f "${1}"
    else
        echo ""
    fi
}

# Determine user home directory
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define configuration files for backup tools
BACKUP_TOOL_FILES=(
    "${USER_HOME}/config-backups/check_symlinks.sh"
    "${USER_HOME}/config-backups/find_configs.sh"
)

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for backup tools
handle_pre_installation_config "backup-tools" "${BACKUP_TOOL_FILES[@]}"

# === STAGE 2: Check Repository Existence ===
section "Checking Configuration Repository"

REPO_DIR="/repo/personal/core-configs"
if [[ ! -d "${REPO_DIR}" ]]; then
    echo "Repository directory ${REPO_DIR} does not exist."
    echo "Creating repository directory structure..."
    
    # Create the repository directory
    mkdir -p "${REPO_DIR}"
    
    echo "✓ Created repository directory at ${REPO_DIR}"
    echo "NOTE: You should initialize this as a Git repository manually:"
    echo "  cd ${REPO_DIR} && git init"
else
    echo "Found existing configuration repository at ${REPO_DIR}"
    
    # Check if it's a git repository
    if [[ -d "${REPO_DIR}/.git" ]]; then
        echo "✓ Repository is a valid Git repository"
    else
        echo "WARNING: Directory exists but is not a Git repository."
        echo "Consider initializing it with: cd ${REPO_DIR} && git init"
    fi
fi

# === STAGE 3: Create Complementary Backup Directories ===
section "Setting Up Complementary Backup Structure"

# Create a directory for configuration backups that aren't in the repo
BACKUP_DIR="${USER_HOME}/config-backups"
mkdir -p "${BACKUP_DIR}"/{browsers,git,code-editors,email,application-state,temp}

# Create a directory for quick temporary backups (not tracked in Git)
mkdir -p "${BACKUP_DIR}/temp"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${BACKUP_DIR}"
fi

echo "✓ Created complementary backup directories at ${BACKUP_DIR}"

# === STAGE 4: Create Configuration Categories Map ===
section "Creating Configuration Category Documentation"

# Create a README file explaining the integrated approach
cat > "${BACKUP_DIR}/README.md" << EOF
# Integrated Configuration Management

This directory complements the Git-managed configurations at \`${REPO_DIR}\`.

## Directory Structure

- **${REPO_DIR}/**: Core configuration files managed with Git
  - Dotfiles (.bashrc, .zshrc, .gitconfig, etc.)
  - Editor configurations (VS Code, Vim, etc.)
  - Window manager and desktop environment settings
  - Terminal and shell configurations

- **${BACKUP_DIR}/**: Complementary backups not suitable for Git
  - **browsers/**: Browser profiles, bookmarks, and extensions
  - **git/**: Git credentials and sensitive information
  - **code-editors/**: Editor state and workspace files
  - **email/**: Email client accounts and settings
  - **application-state/**: Application state and cache
  - **temp/**: Quick temporary backups before major changes

## Workflow

### For Core Configurations (Git-Managed)

1. Store original configs in \`${REPO_DIR}\`
2. Use symlinks from your home directory to the repo
3. Commit and push changes to back up

Example:
\`\`\`bash
# Adding a new dotfile to the repository
cp ~/.zshrc ${REPO_DIR}/zsh/zshrc
rm ~/.zshrc
ln -s ${REPO_DIR}/zsh/zshrc ~/.zshrc
cd ${REPO_DIR} && git add zsh/zshrc && git commit -m "Add zshrc"
\`\`\`

### For Large or Private Configurations (Non-Git)

1. Export configurations from applications
2. Save them to the appropriate directory in \`${BACKUP_DIR}\`
3. Document export/import procedures in README files

## Symlink Management

When you run \`check_symlinks.sh\`, it will:
1. Identify which configs are already symlinked to the repository
2. Suggest configs that could be moved to the repository
3. Help create new symlinks for existing repository files

## Restoration Process

In case of system reinstallation:
1. Clone your config repository: \`git clone <url> ${REPO_DIR}\`
2. Run the symlink creation script: \`${REPO_DIR}/create_symlinks.sh\`
3. Manually restore non-Git backups from \`${BACKUP_DIR}\`
EOF

# === STAGE 5: Create Symlink Management Tools ===
section "Creating Symlink Management Scripts"

# Create a script to check existing configuration files
cat > "${BACKUP_DIR}/check_symlinks.sh" << 'EOF'
#!/bin/bash

# check_symlinks.sh
# Analyzes home directory dotfiles and their relationship to the config repository

REPO_DIR="/repo/personal/core-configs"
USER_HOME="${HOME}"

echo "Analyzing configuration files in ${USER_HOME}..."

# Common dotfiles to check
DOTFILES=(.bashrc .zshrc .gitconfig .vimrc .tmux.conf .config/Code/User/settings.json .config/nvim/init.vim .config/starship.toml)

# First check files already managed by symlinks
echo -e "\n=== Configurations Already Managed by Repository ==="
for file in "${DOTFILES[@]}"; do
    full_path="${USER_HOME}/${file}"
    if [[ -L "${full_path}" ]]; then
        target=$(readlink -f "${full_path}")
        if [[ ${target} == ${REPO_DIR}* ]]; then
            echo "✓ ${file} → ${target}"
        else
            echo "⚠ ${file} → ${target} (links outside the repository)"
        fi
    fi
done

# Then check files that exist but are not symlinks
echo -e "\n=== Configurations That Could Be Added to Repository ==="
for file in "${DOTFILES[@]}"; do
    full_path="${USER_HOME}/${file}"
    if [[ -f "${full_path}" ]] && [[ ! -L "${full_path}" ]]; then
        echo "• ${file} (regular file, not symlinked)"
    fi
done

# Finally, check repository files that aren't symlinked
echo -e "\n=== Repository Files Not Currently Symlinked ==="
find "${REPO_DIR}" -type f -not -path "*/\.*" | while read -r repo_file; do
    relative_path=${repo_file#${REPO_DIR}/}
    if [[ "${relative_path}" != README* ]] && [[ "${relative_path}" != *.sh ]]; then
        potential_link="${USER_HOME}/.${relative_path}"
        if [[ ! -e "${potential_link}" ]]; then
            echo "• ${relative_path} (in repo but not symlinked to ~/${relative_path})"
        fi
    fi
done

echo -e "\nTo add a configuration file to the repository:"
echo "1. Copy it to the repository: cp ~/.config/file ${REPO_DIR}/config/file"
echo "2. Remove the original: rm ~/.config/file"
echo "3. Create a symlink: ln -s ${REPO_DIR}/config/file ~/.config/file"
echo "4. Commit the change: cd ${REPO_DIR} && git add config/file && git commit"
EOF

# Create a script to find configs that could be added to repo
cat > "${BACKUP_DIR}/find_configs.sh" << 'EOF'
#!/bin/bash

# find_configs.sh
# Discovers potential configuration files in the home directory

USER_HOME="${HOME}"

echo "Discovering configuration files in ${USER_HOME}..."

# Find all dotfiles in the home directory (excluding common directories to avoid noise)
echo -e "\n=== Dotfiles in Home Directory ==="
find "${USER_HOME}" -maxdepth 1 -name ".*" -type f | sort | while read -r file; do
    echo "• $(basename "${file}")"
done

# Find configuration directories
echo -e "\n=== Configuration Directories ==="
find "${USER_HOME}/.config" -maxdepth 2 -type d | sort | while read -r dir; do
    if [[ "${dir}" != "${USER_HOME}/.config" ]]; then
        echo "• ${dir#${USER_HOME}/}"
    fi
done

# Find VSCode settings
if [[ -d "${USER_HOME}/.config/Code/User" ]]; then
    echo -e "\n=== VS Code Configuration Files ==="
    find "${USER_HOME}/.config/Code/User" -type f -name "*.json" | sort | while read -r file; do
        echo "• ${file#${USER_HOME}/}"
    done
fi

echo -e "\nTo decide which configs to include in your repository:"
echo "1. Focus on text-based configuration files (avoid binaries, caches, etc.)"
echo "2. Exclude files with sensitive information or tokens"
echo "3. Exclude large files or directories with frequently changing state"
echo "4. Prioritize configs that you want to be consistent across machines"
EOF

# Make the scripts executable
chmod +x "${BACKUP_DIR}/check_symlinks.sh"
chmod +x "${BACKUP_DIR}/find_configs.sh"

# Set proper ownership if running as sudo
if [[ "${SUDO_USER}" ]]; then
    chown "${SUDO_USER}":"${SUDO_USER}" "${BACKUP_DIR}/check_symlinks.sh"
    chown "${SUDO_USER}":"${SUDO_USER}" "${BACKUP_DIR}/find_configs.sh"
fi

echo "✓ Created symlink management scripts"

# Handle configuration files
handle_installed_software_config "backup-tools" "${BACKUP_TOOL_FILES[@]}"

# === STAGE 6: Create Repository Template Structure ===
section "Setting Up Repository Directory Structure"

# Only create template if it doesn't exist or is empty
if [[ ! -d "${REPO_DIR}/.git" ]] && [[ $(find "${REPO_DIR}" -maxdepth 0 -empty -type d | wc -l) -eq 1 ]]; then
    # Create a basic structure for the repository
    mkdir -p "${REPO_DIR}"/{shell,git,editors,kde,terminal}
    
    # Create a README file for the repository
    cat > "${REPO_DIR}/README.md" << EOF
# Core Configuration Files

This repository contains core configuration files that are symlinked from the home directory.

## Directory Structure

- **shell/**: Shell configurations (.bashrc, .zshrc, etc.)
- **git/**: Git configurations (.gitconfig, git templates, etc.)
- **editors/**: Text editor configurations (VS Code, Vim, etc.)
- **kde/**: KDE Plasma settings
- **terminal/**: Terminal configurations (Alacritty, Kitty, etc.)

## Setup

Run the \`create_symlinks.sh\` script to create symlinks from your home directory to this repository:

\`\`\`bash
./create_symlinks.sh
\`\`\`

## Manual Symlink Creation

To manually create a symlink for a configuration file:

\`\`\`bash
# Remove existing file (back it up first if needed)
rm ~/.zshrc

# Create symlink from home directory to repository
ln -s ${REPO_DIR}/shell/zshrc ~/.zshrc
\`\`\`

## Non-Repository Backups

Some configurations aren't suitable for this repository (sensitive data, binary files, large databases).
These are backed up to \`~/config-backups/\` instead.
EOF

    # Create a basic symlink creation script
    cat > "${REPO_DIR}/create_symlinks.sh" << 'EOF'
#!/bin/bash

# Exit on error
set -e

# Current directory (repository root)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"

# Create symlinks
create_link() {
    local source="${REPO_DIR}/${1}"
    local target="${USER_HOME}/${2}"
    
    # Check if target already exists
    if [[ -e "${target}" ]] && [[ ! -L "${target}" ]]; then
        echo "Backing up existing ${target} to ${target}.bak"
        mv "${target}" "${target}.bak"
    elif [[ -L "${target}" ]]; then
        echo "Removing existing symlink ${target}"
        rm "${target}"
    fi
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "${target}")"
    
    # Create the symlink
    echo "Creating symlink: ${target} -> ${source}"
    ln -s "${source}" "${target}"
}

# Shell configurations
if [[ -f "${REPO_DIR}/shell/zshrc" ]]; then
    create_link "shell/zshrc" ".zshrc"
fi

if [[ -f "${REPO_DIR}/shell/bashrc" ]]; then
    create_link "shell/bashrc" ".bashrc"
fi

# Git configurations
if [[ -f "${REPO_DIR}/git/gitconfig" ]]; then
    create_link "git/gitconfig" ".gitconfig"
fi

# Vim configuration
if [[ -f "${REPO_DIR}/editors/vimrc" ]]; then
    create_link "editors/vimrc" ".vimrc"
fi

# VS Code settings
if [[ -f "${REPO_DIR}/editors/vscode-settings.json" ]]; then
    create_link "editors/vscode-settings.json" ".config/Code/User/settings.json"
fi

# Add more symlinks for other configuration files as needed

echo "Symlinks created successfully!"
EOF

    # Make the symlink script executable
    chmod +x "${REPO_DIR}/create_symlinks.sh"
    
    # Set proper ownership if running as sudo
    if [[ "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}":"${SUDO_USER}" "${REPO_DIR}"
    fi
    
    echo "✓ Created repository template structure at ${REPO_DIR}"
else
    echo "Repository already initialized, skipping template creation"
fi

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "backup-tools" "${BACKUP_TOOL_FILES[@]}"

section "Configuration Management Setup Complete!"
echo "Your integrated configuration management system is now set up:"
echo "  1. Git repository for core configs: ${REPO_DIR}"
echo "  2. Complementary backup directory: ${BACKUP_DIR}"
echo "  3. Management scripts in backup directory"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "Next steps:"
echo "  • Run ${BACKUP_DIR}/find_configs.sh to discover configurations"
echo "  • Run ${BACKUP_DIR}/check_symlinks.sh to manage repository symlinks"
echo "  • If repo is new: cd ${REPO_DIR} && git init"
echo "  • Consider backing up browser and application state to ${BACKUP_DIR}"
