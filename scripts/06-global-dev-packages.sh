#!/bin/bash

# Global Development Packages Setup Script
# This script installs recommended global packages for PHP and Node.js development
# and manages development environment configurations using the repository
# Assumes PHP 8.4, Composer, and Node.js are already installed
# Modified to use restored configurations from /restart/critical_backups

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

# Determine user home directory
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Check for restored configurations
CONFIG_MAPPING="/restart/critical_backups/config_mapping.txt"
RESTORED_CONFIGS_AVAILABLE=false

if [[ -f "${CONFIG_MAPPING}" ]]; then
    echo "Found restored configuration mapping at ${CONFIG_MAPPING}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING}"
    RESTORED_CONFIGS_AVAILABLE=true
else
    echo "No restored configuration mapping found at ${CONFIG_MAPPING}"
    echo "Will proceed with default configurations."
fi

# Define configuration files for development tools
NODE_CONFIG_FILES=(
    "${USER_HOME}/.npmrc"
    "${USER_HOME}/.eslintrc.json"
    "${USER_HOME}/.prettierrc"
    "${USER_HOME}/.config/typescript/tsconfig.json"
)

COMPOSER_CONFIG_FILES=(
    "${USER_HOME}/.composer/composer.json"
    "${USER_HOME}/.composer/auth.json"
    "${USER_HOME}/.config/phpcs/phpcs.xml"
)

GIT_CONFIG_FILES=(
    "${USER_HOME}/.gitconfig"
    "${USER_HOME}/.gitignore_global"
    "${USER_HOME}/.git-credentials"
)

BIN_SCRIPT_FILES=(
    "${USER_HOME}/bin/new-node-project"
    "${USER_HOME}/bin/new-php-project"
)

# Display section header function
section() {
    echo
    echo "========================================================"
    echo "  ${1}"
    echo "========================================================"
    echo
}

# Function to handle errors and provide helpful messages
handle_error() {
    local error_message="${1}"
    echo "ERROR: ${error_message}"
    echo "Continuing with script execution..."
    # Return non-zero to indicate error occurred but don't exit
    return 1
}

# Check if required tools are installed
check_requirements() {
    section "Checking Requirements"
    
    if ! command -v php >/dev/null 2>&1; then
        echo "❌ PHP is not installed. Please install PHP 8.4 first."
        exit 1
    fi
    
    if ! command -v composer >/dev/null 2>&1; then
        echo "❌ Composer is not installed. Please install Composer first."
        exit 1
    fi
    
    if ! command -v node >/dev/null 2>&1; then
        echo "❌ Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        echo "❌ npm is not installed. Please install npm first."
        exit 1
    fi
    
    echo "✅ All required tools are installed."
    echo "PHP Version: $(php -v | head -n 1 || true)"
    echo "Composer Version: $(composer --version || true)"
    echo "Node.js Version: $(node -v || true)"
    echo "npm Version: $(npm -v || true)"
}

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for development tools
handle_pre_installation_config "node" "${NODE_CONFIG_FILES[@]}"
handle_pre_installation_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
handle_pre_installation_config "bin" "${BIN_SCRIPT_FILES[@]}"

# Check if requirements are met
check_requirements

# === STAGE 2: Check for Restored Global Packages Lists ===
section "Checking for Restored Global Packages Lists"

# Initialize tracking variables for restoration status
RESTORED_NPM_PACKAGES=false
RESTORED_COMPOSER_PACKAGES=false
# shellcheck disable=SC2034
RESTORED_PROJECT_TEMPLATES=false
# shellcheck disable=SC2034
RESTORED_BIN_SCRIPTS=false

# Check for restored npm global packages list
RESTORED_NPM_LIST=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    NPM_LIST_PATHS=(
        "${GENERAL_CONFIGS_PATH}/node/npm-global-packages.txt"
        "${GENERAL_CONFIGS_PATH}/npm-global-packages.txt"
        "${HOME_CONFIGS_PATH}/npm-global-packages.txt"
    )
    
    for path in "${NPM_LIST_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored npm global packages list at ${path}"
            RESTORED_NPM_LIST="${path}"
            RESTORED_NPM_PACKAGES=true
            break
        fi
    done
fi

# Check for restored composer global packages list
RESTORED_COMPOSER_LIST=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    COMPOSER_LIST_PATHS=(
        "${GENERAL_CONFIGS_PATH}/composer/composer-global-packages.txt"
        "${GENERAL_CONFIGS_PATH}/composer-global-packages.txt"
        "${HOME_CONFIGS_PATH}/composer-global-packages.txt"
    )
    
    for path in "${COMPOSER_LIST_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored composer global packages list at ${path}"
            # shellcheck disable=SC2034
            RESTORED_COMPOSER_LIST="${path}"
            # shellcheck disable=SC2034
            RESTORED_COMPOSER_PACKAGES=true
            break
        fi
    done
fi

# Check for restored project templates
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    TEMPLATE_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/Templates/Development"
        "${HOME_CONFIGS_PATH}/Templates/Development"
    )
    
    for path in "${TEMPLATE_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found restored project templates at ${path}"
            # shellcheck disable=SC2034
            RESTORED_PROJECT_TEMPLATES=true
            break
        fi
    done
fi

# Check for restored bin scripts
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    BIN_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/bin"
        "${HOME_CONFIGS_PATH}/bin"
    )
    
    for path in "${BIN_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found restored bin scripts at ${path}"
            # shellcheck disable=SC2034
            RESTORED_BIN_SCRIPTS=true
            break
        fi
    done
fi

# === STAGE 3: Install Global Node.js Packages ===
if [[ "${RESTORED_NPM_PACKAGES}" = true ]] && [[ -f "${RESTORED_NPM_LIST}" ]]; then
    section "Installing Restored Global Node.js Packages"
    
    echo "Installing global Node.js packages from restored list..."
    while IFS= read -r package || [[ -n "${package}" ]]; do
        # Skip empty lines and comments
        if [[ -z "${package}" || "${package}" == \#* ]]; then
            continue
        fi
        echo "Installing package: ${package}"
        npm install -g "${package}"
    done < "${RESTORED_NPM_LIST}"
    
    echo "✅ Restored global Node.js packages installed successfully."
else
    section "Installing Global Node.js Packages"
    
    # Development workflow tools
    echo "Installing development workflow tools..."
    sudo npm install -g nodemon         # Monitor for changes and restart applications
    sudo npm install -g http-server     # Simple HTTP server
    sudo npm install -g serve           # Static file server
    sudo npm install -g concurrently    # Run multiple commands concurrently
    sudo npm install -g json-server     # Fake REST API server
    
    # Code quality and formatting tools
    echo "Installing code quality and formatting tools..."
    sudo npm install -g eslint          # JavaScript linter
    sudo npm install -g prettier        # Code formatter
    sudo npm install -g typescript      # TypeScript compiler
    sudo npm install -g ts-node         # TypeScript execution environment
    
    # Build tools and task runners
    echo "Installing build tools and task runners..."
    sudo npm install -g gulp-cli        # Gulp command line interface
    sudo npm install -g grunt-cli       # Grunt command line interface
    sudo npm install -g webpack-cli     # Webpack command line interface
    
    # Utility and CLI tools
    echo "Installing utility and CLI tools..."
    sudo npm install -g npm-check-updates # Check for package updates
    sudo npm install -g tldr            # Simplified man pages
    sudo npm install -g trash-cli       # Safer alternative to rm
    sudo npm install -g release-it      # Automate versioning and package publishing
    sudo npm install -g dotenv-cli      # Environment variable management
    
    # Package management tools
    echo "Installing package management tools..."
    sudo npm install -g npm-check       # Check for outdated, incorrect, and unused dependencies
    sudo npm install -g depcheck        # Check for unused dependencies
    sudo npm install -g license-checker # Check licenses of dependencies
    
    echo "✅ Global Node.js packages installed successfully."
    
    # Create a record of installed packages for future restoration
    
    sudo chown -R scott:scott /home/scott
    npm list -g --depth=0 > "${USER_HOME}/npm-global-packages.txt"
    if [[ -d "/repo/personal/core-configs/node" ]]; then
        cp "${USER_HOME}/npm-global-packages.txt" "/repo/personal/core-configs/node/"
        echo "✓ Saved list of global npm packages to repository"
    fi
fi

# === STAGE 4: Install Global Composer Packages ===
if [[ "${RESTORED_COMPOSER_PACKAGES}" = true ]] && [[ -f "${RESTORED_COMPOSER_LIST}" ]]; then
    section "Installing Restored Global Composer Packages"
    
    echo "Installing global Composer packages from restored list..."
    while IFS= read -r package || [[ -n "${package}" ]]; do
        # Skip empty lines and comments
        if [[ -z "${package}" || "${package}" == \#* ]]; then
            continue
        fi
        echo "Installing package: ${package}"
        composer global require "${package}"
    done < "${RESTORED_COMPOSER_LIST}"
    
    echo "✅ Restored global Composer packages installed successfully."
else
    section "Installing Global Composer Packages"
    
    # Code quality and analysis tools
    echo "Installing code quality and analysis tools..."
    composer global require squizlabs/php_codesniffer       # PHP_CodeSniffer for coding standards
    composer global require phpmd/phpmd                     # PHP Mess Detector
    composer global require phpstan/phpstan                 # PHP Static Analysis Tool
    composer global require friendsofphp/php-cs-fixer       # PHP Coding Standards Fixer
    composer global require phan/phan                       # PHP Analyzer
    
    # Testing tools
    echo "Installing testing tools..."
    composer global require phpunit/phpunit                 # PHP Unit Testing
    
    # Utility tools
    echo "Installing utility tools..."
    composer global require symfony/var-dumper              # Better var_dump
    
    echo "✅ Global Composer packages installed successfully."
    
    # Create a record of installed packages for future restoration
    composer global show > "${USER_HOME}/composer-global-packages.txt"
    if [[ -d "/repo/personal/core-configs/composer" ]]; then
        sudo cp "${USER_HOME}/composer-global-packages.txt" "/repo/personal/core-configs/composer/"
	sudo chown -R scott:scott /repo/*
        echo "✓ Saved list of global Composer packages to repository"
    fi
fi

# === STAGE 5: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "node" "${NODE_CONFIG_FILES[@]}"
check_post_installation_configs "composer" "${COMPOSER_CONFIG_FILES[@]}"
check_post_installation_configs "git" "${GIT_CONFIG_FILES[@]}"
check_post_installation_configs "bin" "${BIN_SCRIPT_FILES[@]}"

section "Global Development Packages Setup Complete!"
echo "You now have a comprehensive set of global development packages installed."
echo "Notable packages include:"
echo "  - Node.js: nodemon, eslint, prettier, typescript, etc."
echo "  - PHP: PHP_CodeSniffer, PHPStan, PHP-CS-Fixer, etc."
echo
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    echo "Your restored development configurations have been applied from the backup."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
    echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
    echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
    echo "  - Any changes to configurations should be made in the repository"
fi
