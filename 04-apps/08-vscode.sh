#!/usr/bin/env bash
# ============================================================================
# 08-vscode.sh
# ----------------------------------------------------------------------------
# Installs Visual Studio Code and configures essential extensions
# for PHP and WordPress development
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${FORCE_MODE:=false}"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="08-vscode"

# ============================================================================
# VS Code Installation
# ============================================================================

# Install Visual Studio Code
function install_vscode() {
    log_step "Installing Visual Studio Code"

    # Check if VS Code is already installed
    if command -v code &> /dev/null && ! is_force_mode; then
        log_info "Visual Studio Code is already installed"

        # Get VS Code version for logging
        # Declare first, then assign to avoid masking return values
        local vscode_version
        vscode_version=$(code --version | head -n 1) || true
        log_info "VS Code version: ${vscode_version}"
        return 0
    fi

    # Install dependencies
    log_info "Installing dependencies for VS Code"
    local dependencies=(
        apt-transport-https
        wget
        gpg
    )

    if ! apt_install "${dependencies[@]}"; then
        log_warning "Failed to install some dependencies. This might affect VS Code installation."
    fi

    # Add Microsoft GPG key
    log_info "Adding Microsoft GPG key"
    if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg; then
        log_error "Failed to download Microsoft GPG key"
        return 1
    fi

    if ! mv /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg; then
        log_error "Failed to move Microsoft GPG key to trusted directory"
        return 1
    fi

    # Add VS Code repository
    log_info "Adding Visual Studio Code repository"
    if ! echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list; then
        log_error "Failed to add VS Code repository"
        return 1
    fi

    # Update package lists
    log_info "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install VS Code
    log_info "Installing Visual Studio Code package"
    if ! apt_install code; then
        log_error "Failed to install Visual Studio Code"
        return 1
    fi

    # Verify installation
    if ! command -v code &> /dev/null; then
        log_error "VS Code installation verification failed"
        return 1
    fi

    # Get VS Code version for logging
    # Declare first, then assign to avoid masking return values
    local vscode_version
    vscode_version=$(code --version | head -n 1) || true
    log_success "Visual Studio Code version ${vscode_version} installed successfully"

    return 0
}

# ============================================================================
# VS Code Extensions Installation
# ============================================================================

# Install Visual Studio Code extensions
function install_vscode_extensions() {
    log_step "Installing Visual Studio Code extensions"

    if check_state "${SCRIPT_NAME}_extensions_installed" && ! is_force_mode; then
        log_info "VS Code extensions already installed. Skipping..."
        return 0
    fi

    # Get the actual user to run commands as
    local actual_user
    if [[ -n "${SUDO_USER}" ]]; then
        actual_user="${SUDO_USER}"
    else
        actual_user="$(whoami)"
    fi

    # Check if VS Code is installed
    if ! command -v code &> /dev/null; then
        log_error "VS Code is not installed. Please install it first."
        return 1
    fi

    # List of essential extensions for PHP and WordPress development
    log_info "Preparing to install VS Code extensions"

    # PHP essentials
    local php_extensions=(
        "bmewburn.vscode-intelephense-client"           # PHP IntelliSense
        "felixfbecker.php-debug"                        # PHP Debug
        "neilbrayfield.php-docblocker"                  # PHP DocBlocker
        "mehedidracula.php-namespace-resolver"          # PHP Namespace Resolver
    )

    # WordPress specific
    local wp_extensions=(
        "wordpresstoolbox.wordpress-toolbox"            # WordPress Snippets
        "tungvn.wordpress-snippet"                      # WordPress Snippet
        "yogensia.searchwp-php-doc"                     # SearchWP PHP Doc
    )

    # General web development
    local web_extensions=(
        "esbenp.prettier-vscode"                        # Prettier - Code formatter
        "dbaeumer.vscode-eslint"                        # ESLint
        "ritwickdey.liveserver"                         # Live Server
        "editorconfig.editorconfig"                     # EditorConfig
    )

    # Git integration
    local git_extensions=(
        "eamodio.gitlens"                               # GitLens
    )

    # Utilities
    local utility_extensions=(
        "mikestead.dotenv"                              # DotENV
        "gruntfuggly.todo-tree"                         # Todo Tree
        "streetsidesoftware.code-spell-checker"         # Code Spell Checker
        "ms-vsliveshare.vsliveshare"                    # Live Share
    )

    # Combine all extensions
    local all_extensions=(
        "${php_extensions[@]}"
        "${wp_extensions[@]}"
        "${web_extensions[@]}"
        "${git_extensions[@]}"
        "${utility_extensions[@]}"
    )

    # Log the total number of extensions to install
    log_info "Installing ${#all_extensions[@]} extensions for VS Code"

    # Install extensions as the actual user
    local installed_count=0
    local failed_count=0

    for extension in "${all_extensions[@]}"; do
        log_info "Installing extension: ${extension}"

        if sudo -u "${actual_user}" code --install-extension "${extension}" --force; then
            ((installed_count++))
        else
            log_warning "Failed to install extension: ${extension}"
            ((failed_count++))
        fi
    done

    # Report installation results
    if [[ ${failed_count} -eq 0 ]]; then
        log_success "All ${installed_count} VS Code extensions installed successfully"
    else
        log_warning "${installed_count} extensions installed, ${failed_count} failed to install"
    fi

    set_state "${SCRIPT_NAME}_extensions_installed"
    return 0
}

# ============================================================================
# VS Code Configuration
# ============================================================================

# Configure VS Code for PHP and WordPress development
function configure_vscode() {
    log_step "Configuring Visual Studio Code for PHP and WordPress development"

    if check_state "${SCRIPT_NAME}_configured" && ! is_force_mode; then
        log_info "VS Code already configured. Skipping..."
        return 0
    fi

    # Get the actual user and home directory
    local actual_user
    local user_home

    if [[ -n "${SUDO_USER}" ]]; then
        actual_user="${SUDO_USER}"
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        actual_user="$(whoami)"
        user_home="${HOME}"
    fi

    # Create VS Code settings directory
    log_info "Creating VS Code settings directory"
    local settings_dir="${user_home}/.config/Code/User"

    if ! sudo -u "${actual_user}" mkdir -p "${settings_dir}"; then
        log_warning "Failed to create VS Code settings directory"
        return 1
    fi

    # Create settings.json with PHP and WordPress development settings
    log_info "Creating PHP/WordPress development settings"
    local settings_file="${settings_dir}/settings.json"

    # Check if settings file already exists
    if [[ -f "${settings_file}" ]]; then
        log_info "VS Code settings file already exists, creating backup"
        # Get date separately to avoid masking return value
        local backup_date
        backup_date=$(date '+%Y%m%d-%H%M%S') || true
        if ! sudo -u "${actual_user}" cp "${settings_file}" "${settings_file}.backup-${backup_date}"; then
            log_warning "Failed to create backup of existing settings file"
        fi
    fi

    # Create settings.json content
    log_info "Writing VS Code settings file"
    local settings_content='{
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.rulers": [120],
    "files.eol": "\n",
    "files.insertFinalNewline": true,
    "files.trimTrailingWhitespace": true,
    "php.suggest.basic": true,
    "php.validate.enable": true,
    "php.validate.run": "onSave",
    "[php]": {
        "editor.defaultFormatter": "bmewburn.vscode-intelephense-client",
        "editor.formatOnSave": true
    },
    "intelephense.format.enable": true,
    "intelephense.completion.fullyQualifyGlobalConstantsAndFunctions": true,
    "intelephense.completion.insertUseDeclaration": true,
    "intelephense.diagnostics.undefinedTypes": false,
    "intelephense.diagnostics.undefinedFunctions": false,
    "intelephense.diagnostics.undefinedConstants": false,
    "intelephense.diagnostics.undefinedClassConstants": false,
    "intelephense.diagnostics.undefinedMethods": false,
    "intelephense.diagnostics.undefinedProperties": false,
    "intelephense.diagnostics.unexpectedTokens": false,
    "intelephense.diagnostics.duplicateSymbols": false,
    "wordpresstoolbox.enable": true,
    "wordpresstoolbox.codeblock": true,
    "php.executablePath": "/usr/bin/php"
}'

    # Write settings to file
    if ! echo "${settings_content}" | sudo -u "${actual_user}" tee "${settings_file}" > /dev/null; then
        log_error "Failed to write VS Code settings file"
        return 1
    fi

    # Create keybindings.json with useful shortcuts
    log_info "Creating helpful keyboard shortcuts"
    local keybindings_file="${settings_dir}/keybindings.json"

    # Check if keybindings file already exists
    if [[ -f "${keybindings_file}" ]]; then
        log_info "VS Code keybindings file already exists, creating backup"
        # Get date separately to avoid masking return value
        local backup_date
        backup_date=$(date '+%Y%m%d-%H%M%S') || true
        if ! sudo -u "${actual_user}" cp "${keybindings_file}" "${keybindings_file}.backup-${backup_date}"; then
            log_warning "Failed to create backup of existing keybindings file"
        fi
    fi

    # Create keybindings.json content
    log_info "Writing VS Code keybindings file"
    local keybindings_content='[
    {
        "key": "ctrl+shift+/",
        "command": "editor.action.blockComment",
        "when": "editorTextFocus && !editorReadonly"
    },
    {
        "key": "ctrl+k ctrl+f",
        "command": "editor.action.formatSelection",
        "when": "editorHasSelection && editorTextFocus && !editorReadonly"
    },
    {
        "key": "ctrl+k ctrl+d",
        "command": "editor.action.formatDocument",
        "when": "editorTextFocus && !editorReadonly"
    }
]'

    # Write keybindings to file
    if ! echo "${keybindings_content}" | sudo -u "${actual_user}" tee "${keybindings_file}" > /dev/null; then
        log_error "Failed to write VS Code keybindings file"
        return 1
    fi

    # Create snippets directory and add useful snippets
    log_info "Creating PHP/WordPress code snippets"
    local snippets_dir="${settings_dir}/snippets"

    if ! sudo -u "${actual_user}" mkdir -p "${snippets_dir}"; then
        log_warning "Failed to create VS Code snippets directory"
    else
        # Create PHP snippets file
        local php_snippets_file="${snippets_dir}/php.json"
        # shellcheck disable=SC2016
        local php_snippets_content='{
    "PHP Class": {
        "prefix": "phpclass",
        "body": [
            "<?php",
            "",
            "namespace ${1:Namespace};",
            "",
            "/**",
            " * Class ${2:ClassName}",
            " */",
            "class ${2:ClassName} {",
            "\\t$0",
            "}"
        ],
        "description": "Create a PHP class"
    },
    "PHP Function": {
        "prefix": "phpfunction",
        "body": [
            "/**",
            " * ${1:Description}",
            " * ",
            " * @param ${2:type} \\$${3:param}",
            " * @return ${4:type}",
            " */",
            "function ${5:name}(\\$${3:param}) {",
            "\\t$0",
            "}"
        ],
        "description": "Create a PHP function with docblock"
    },
    "WP Plugin Header": {
        "prefix": "wpplugin",
        "body": [
            "<?php",
            "/**",
            " * Plugin Name: ${1:Plugin Name}",
            " * Plugin URI: ${2:https://example.com/plugin}",
            " * Description: ${3:Description of the plugin}",
            " * Version: ${4:1.0.0}",
            " * Author: ${5:Your Name}",
            " * Author URI: ${6:https://example.com}",
            " * Text Domain: ${7:text-domain}",
            " * Domain Path: /languages",
            " * License: GPL-2.0+",
            " * License URI: http://www.gnu.org/licenses/gpl-2.0.txt",
            " */",
            "",
            "// If this file is called directly, abort.",
            "if (!defined(\"WPINC\")) {",
            "\\tdie;",
            "}",
            "",
            "$0"
        ],
        "description": "Create a WordPress plugin header"
    }
}'

        # Write PHP snippets to file
        if ! echo "${php_snippets_content}" | sudo -u "${actual_user}" tee "${php_snippets_file}" > /dev/null; then
            log_warning "Failed to create PHP snippets file"
        fi
    fi

    set_state "${SCRIPT_NAME}_configured"
    log_success "Visual Studio Code has been configured for PHP and WordPress development"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

# Main function to install and configure VS Code
function main() {
    log_section "Setting up Visual Studio Code for PHP and WordPress Development"

    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Visual Studio Code setup has already been completed. Skipping..."
        return 0
    fi

    # Install VS Code
    if ! install_vscode; then
        log_error "Failed to install Visual Studio Code"
        return 1
    fi

    # Install extensions
    if ! install_vscode_extensions; then
        log_warning "Some VS Code extensions failed to install"
        # Continue anyway, as the core application is installed
    fi

    # Configure VS Code
    if ! configure_vscode; then
        log_warning "Failed to configure Visual Studio Code"
        # Continue anyway, as the core application and extensions are installed
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Visual Studio Code setup completed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Run the main function
main

# Return the exit code
exit $?
