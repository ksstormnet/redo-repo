#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2034,SC2016
# ============================================================================
# 03-web-development.sh
# ----------------------------------------------------------------------------
# Installs PHP 8.3 and related tools for WordPress development
# Configures PHP extensions, Composer, WP-CLI and code quality tools
# Skips MariaDB and Nginx as they'll be handled by Docker
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck source=../lib/common.sh
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="03-web-development"

# ============================================================================
# PHP Installation Functions
# ============================================================================

# Add the PHP repository and update package lists
function add_php_repository() {
    log_step "Adding PHP repository"

    if check_state "${SCRIPT_NAME}_repository_added"; then
        log_info "PHP repository already added. Skipping..."
        return 0
    fi

    # Add the Ondrej PHP PPA
    if ! add_ppa "ondrej/php"; then
        log_error "Failed to add PHP repository"
        return 1
    fi

    # Update package lists
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    set_state "${SCRIPT_NAME}_repository_added"
    log_success "PHP repository added successfully"
    return 0
}

# Install PHP core and extensions
function install_php() {
    local php_version="$1"

    log_step "Installing PHP ${php_version} core"

    if check_state "${SCRIPT_NAME}_php_installed"; then
        log_info "PHP ${php_version} already installed. Skipping..."
        return 0
    fi

    # Install PHP core - only CLI and FPM, nothing that requires Apache
    if ! apt_install "php${php_version}-cli" "php${php_version}-fpm"; then
        log_error "Failed to install PHP ${php_version}"
        return 1
    fi

    set_state "${SCRIPT_NAME}_php_installed"
    log_success "PHP ${php_version} installed successfully"
    return 0
}

# Install PHP extensions for WordPress development
function install_php_extensions() {
    local php_version="$1"

    log_step "Installing PHP ${php_version} extensions for WordPress"

    if check_state "${SCRIPT_NAME}_php_extensions_installed"; then
        log_info "PHP extensions already installed. Skipping..."
        return 0
    fi

    # Define required PHP extensions for WordPress - excluding any that might pull in Apache
    local php_extensions=(
        "common"
        "curl"
        "gd"
        "imagick"
        "intl"
        "mbstring"
        "mysql"
        "opcache"
        "xml"
        "zip"
        "bcmath"
        "soap"
        "xdebug"
    )

    # Build the list of packages to install
    local extension_packages=()
    for ext in "${php_extensions[@]}"; do
        extension_packages+=("php${php_version}-${ext}")
    done

    # Add additional PHP tools
    extension_packages+=(
        "php-pear"
        "php-dev"
    )

    # Install all PHP extensions
    if ! apt_install "${extension_packages[@]}"; then
        log_error "Failed to install PHP extensions"
        return 1
    fi

    set_state "${SCRIPT_NAME}_php_extensions_installed"
    log_success "PHP extensions installed successfully"
    return 0
}

# ============================================================================
# Development Tools Installation
# ============================================================================

# Install and configure PHP Composer
function install_composer() {
    log_step "Installing PHP Composer"

    if check_state "${SCRIPT_NAME}_composer_installed"; then
        log_info "Composer already installed. Skipping..."
        return 0
    fi

    # Download the Composer installer
    local composer_setup="/tmp/composer-setup.php"
    if ! curl -sS https://getcomposer.org/installer -o "${composer_setup}"; then
        log_error "Failed to download Composer installer"
        return 1
    fi

    # Verify the installer
    log_info "Verifying Composer installer"
    EXPECTED_CHECKSUM="$(curl -sS https://composer.github.io/installer.sig)"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '${composer_setup}');")"

    if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
        log_error "Composer installer checksum verification failed"
        rm "${composer_setup}"
        return 1
    fi

    # Get the user who will use composer
    local user_name
    local user_home

    if [[ -n "${SUDO_USER}" ]]; then
        user_name="${SUDO_USER}"
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_name=$(whoami)
        user_home="${HOME}"
    fi

    # Create directory for Composer in user's home
    log_info "Creating Composer directory for user ${user_name}"
    local composer_dir="${user_home}/.local/bin"

    if [[ ! -d "${composer_dir}" ]]; then
        mkdir -p "${composer_dir}"
        chown -R "${user_name}:${user_name}" "$(dirname "${composer_dir}")"
    fi

    # Install Composer for user
    log_info "Installing Composer for user ${user_name}"
    if [[ "${user_name}" != "$(whoami)" ]]; then
        if ! sudo -u "${user_name}" php "${composer_setup}" --quiet --install-dir="${composer_dir}" --filename=composer; then
            log_error "Failed to install Composer for user ${user_name}"
            rm "${composer_setup}"
            return 1
        fi
    else
        if ! php "${composer_setup}" --quiet --install-dir="${composer_dir}" --filename=composer; then
            log_error "Failed to install Composer"
            rm "${composer_setup}"
            return 1
        fi
    fi

    # Clean up
    rm "${composer_setup}"

    # Set correct ownership
    chown -R "${user_name}:${user_name}" "${composer_dir}"

    # Add Composer to user's PATH if not already there
    log_info "Adding Composer to ${user_name}'s PATH"
    local profile_file="${user_home}/.profile"

    if [[ -f "${profile_file}" ]]; then
        if ! grep -q "${composer_dir}" "${profile_file}"; then
            # Add to PATH
            if [[ "${user_name}" != "$(whoami)" ]]; then
                sudo -u "${user_name}" bash -c "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> \"${profile_file}\""
            else
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "${profile_file}"
            fi
            log_info "Added Composer directory to PATH in ${profile_file}"
        else
            log_info "Composer directory already in PATH"
        fi
    fi

    # Create a system-wide symlink for convenience
    log_info "Creating system-wide symlink to composer"
    if [[ -f "${composer_dir}/composer" ]]; then
        ln -sf "${composer_dir}/composer" /usr/local/bin/composer
    fi

    # Verify the installation
    if [[ ! -f "${composer_dir}/composer" ]]; then
        log_error "Composer installation verification failed"
        return 1
    fi

    # Display Composer version - avoid masking return value
    local composer_version
    if [[ "${user_name}" != "$(whoami)" ]]; then
        composer_version=$(sudo -u "${user_name}" "${composer_dir}/composer" --version) || true
    else
        composer_version=$("${composer_dir}/composer" --version) || true
    fi
    log_info "Composer ${composer_version} installed successfully for user ${user_name}"

    set_state "${SCRIPT_NAME}_composer_installed"
    log_success "Composer installed successfully"
    return 0
}

# Install WordPress CLI
function install_wp_cli() {
    log_step "Installing WordPress CLI"

    if check_state "${SCRIPT_NAME}_wp_cli_installed"; then
        log_info "WP-CLI already installed. Skipping..."
        return 0
    fi

    # Download WP-CLI
    if ! curl -sS https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /tmp/wp-cli.phar; then
        log_error "Failed to download WP-CLI"
        return 1
    fi

    # Verify the download
    log_info "Verifying WP-CLI"
    if ! php /tmp/wp-cli.phar --info &>/dev/null; then
        log_error "Downloaded WP-CLI is not valid"
        rm /tmp/wp-cli.phar
        return 1
    fi

    # Make executable and move to path
    log_info "Installing WP-CLI to /usr/local/bin"
    if ! chmod +x /tmp/wp-cli.phar; then
        log_error "Failed to make WP-CLI executable"
        rm /tmp/wp-cli.phar
        return 1
    fi

    if ! mv /tmp/wp-cli.phar /usr/local/bin/wp; then
        log_error "Failed to move WP-CLI to /usr/local/bin"
        rm /tmp/wp-cli.phar
        return 1
    fi

    # Create bash completion for WP command
    log_info "Installing WP-CLI bash completion"
    if ! curl -sS https://raw.githubusercontent.com/wp-cli/wp-cli/main/utils/wp-completion.bash -o /etc/bash_completion.d/wp-completion.bash; then
        log_warning "Failed to download WP-CLI bash completion, but WP-CLI is installed"
    fi

    # Verify the installation
    if ! command -v wp &>/dev/null; then
        log_error "WP-CLI installation verification failed"
        return 1
    fi

    # Display WP-CLI version - avoid masking return value
    local wp_version
    wp_version=$(wp --version) || true
    log_info "${wp_version} installed successfully"

    set_state "${SCRIPT_NAME}_wp_cli_installed"
    log_success "WordPress CLI installed successfully"
    return 0
}

# Install PHP code quality tools
function install_php_tools() {
    log_step "Installing PHP code quality tools"

    if check_state "${SCRIPT_NAME}_php_tools_installed"; then
        log_info "PHP code quality tools already installed. Skipping..."
        return 0
    fi

    # Make sure composer is installed
    if ! command -v composer &>/dev/null; then
        log_error "Composer is not installed. Cannot install PHP tools."
        return 1
    fi

    # List of global composer packages for PHP development
    local composer_packages=(
        "phpstan/phpstan"
        "squizlabs/php_codesniffer"
        "friendsofphp/php-cs-fixer"
        "phpmd/phpmd"
        "phan/phan"
    )

    # Determine the user to run commands as
    local user_name
    local user_home

    if [[ -n "${SUDO_USER}" ]]; then
        user_name="${SUDO_USER}"
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    else
        user_name=$(whoami)
        user_home="${HOME}"
    fi

    # Create composer global directory
    log_info "Setting up Composer global directory"
    local composer_config_dir="${user_home}/.config/composer"

    if [[ ! -d "${composer_config_dir}" ]]; then
        mkdir -p "${composer_config_dir}"
        if [[ "${user_name}" != "$(whoami)" ]]; then
            chown -R "${user_name}:${user_name}" "${composer_config_dir}"
        fi
    fi

    # Install global composer packages
    log_info "Installing global Composer packages"
    for package in "${composer_packages[@]}"; do
        log_info "Installing ${package}"

        if [[ "${user_name}" != "$(whoami)" ]]; then
            # Install as the actual user
            if ! sudo -u "${user_name}" composer global require --no-interaction "${package}"; then
                log_warning "Failed to install ${package}"
            fi
        else
            # Install as current user
            if ! composer global require --no-interaction "${package}"; then
                log_warning "Failed to install ${package}"
            fi
        fi
    done

    # Add composer bin directory to PATH for the user
    log_info "Adding Composer bin to user PATH"
    local profile_file="${user_home}/.profile"

    if [[ -f "${profile_file}" ]]; then
        if ! grep -q "composer/vendor/bin" "${profile_file}"; then
            if [[ "${user_name}" != "$(whoami)" ]]; then
                # Append as the actual user
                sudo -u "${user_name}" bash -c "echo 'export PATH=\"\$HOME/.config/composer/vendor/bin:\$PATH\"' >> \"${profile_file}\""
            else
                # Append as current user
                # shellcheck disable=SC2016
                echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> "${profile_file}"
            fi

            log_info "Added composer bin directory to PATH in ${profile_file}"
        else
            log_info "Composer bin directory already in PATH"
        fi
    fi

    set_state "${SCRIPT_NAME}_php_tools_installed"
    log_success "PHP code quality tools installed successfully"
    return 0
}

# ============================================================================
# PHP Configuration
# ============================================================================

# Configure PHP for development
function configure_php() {
    local php_version="$1"

    log_step "Configuring PHP ${php_version} for development"

    if check_state "${SCRIPT_NAME}_php_configured"; then
        log_info "PHP already configured. Skipping..."
        return 0
    fi

    # PHP CLI configuration
    local php_cli_conf="/etc/php/${php_version}/cli/php.ini"

    if [[ -f "${php_cli_conf}" ]]; then
        log_info "Configuring PHP CLI"

        # Backup the original file if no backup exists
        if [[ ! -f "${php_cli_conf}.original" ]]; then
            cp "${php_cli_conf}" "${php_cli_conf}.original"
            log_info "Created backup of original CLI configuration"
        fi

        # Update PHP CLI settings for development
        log_info "Updating PHP CLI settings"
        sed -i 's/memory_limit = .*/memory_limit = 512M/' "${php_cli_conf}"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' "${php_cli_conf}"
        sed -i 's/error_reporting = .*/error_reporting = E_ALL/' "${php_cli_conf}"
        sed -i 's/display_errors = .*/display_errors = On/' "${php_cli_conf}"
        sed -i 's/display_startup_errors = .*/display_startup_errors = On/' "${php_cli_conf}"
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "${php_cli_conf}"
        sed -i 's/post_max_size = .*/post_max_size = 64M/' "${php_cli_conf}"

        log_success "PHP CLI configured for development"
    else
        log_warning "PHP CLI configuration file not found at ${php_cli_conf}"
    fi

    # PHP-FPM configuration
    local php_fpm_conf="/etc/php/${php_version}/fpm/php.ini"

    if [[ -f "${php_fpm_conf}" ]]; then
        log_info "Configuring PHP-FPM"

        # Backup the original file if no backup exists
        if [[ ! -f "${php_fpm_conf}.original" ]]; then
            cp "${php_fpm_conf}" "${php_fpm_conf}.original"
            log_info "Created backup of original FPM configuration"
        fi

        # Update PHP-FPM settings for development
        log_info "Updating PHP-FPM settings"
        sed -i 's/memory_limit = .*/memory_limit = 256M/' "${php_fpm_conf}"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' "${php_fpm_conf}"
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "${php_fpm_conf}"
        sed -i 's/post_max_size = .*/post_max_size = 64M/' "${php_fpm_conf}"

        log_success "PHP-FPM configured for development"
    else
        log_warning "PHP-FPM configuration file not found at ${php_fpm_conf}"
    fi

    # Configure Xdebug if installed
    local xdebug_conf="/etc/php/${php_version}/mods-available/xdebug.ini"

    if [[ -f "${xdebug_conf}" ]]; then
        log_info "Configuring Xdebug"

        # Backup the original file if no backup exists
        if [[ ! -f "${xdebug_conf}.original" ]]; then
            cp "${xdebug_conf}" "${xdebug_conf}.original"
            log_info "Created backup of original Xdebug configuration"
        fi

        # Update Xdebug settings
        log_info "Creating Xdebug configuration for VS Code"
        cat > "${xdebug_conf}" << EOF
; Xdebug configuration for PHP ${php_version}
zend_extension=xdebug.so
xdebug.mode=develop,debug
xdebug.start_with_request=trigger
xdebug.client_port=9003
xdebug.client_host=127.0.0.1
xdebug.idekey=VSCODE
xdebug.log=/var/log/xdebug.log
xdebug.discover_client_host=true
EOF

        # Create log file with proper permissions
        touch /var/log/xdebug.log
        chmod 666 /var/log/xdebug.log

        log_success "Xdebug configured for development"
    else
        log_warning "Xdebug configuration file not found at ${xdebug_conf}"
    fi

    # Restart PHP-FPM service to apply changes
    log_info "Restarting PHP-FPM service"
    if systemctl is-active --quiet "php${php_version}-fpm"; then
        if ! systemctl restart "php${php_version}-fpm"; then
            log_warning "Failed to restart PHP-FPM service"
        fi
    fi

    set_state "${SCRIPT_NAME}_php_configured"
    log_success "PHP configured successfully for development"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_web_development() {
    log_section "Installing PHP 8.3 and Web Development Tools"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Web development setup has already been completed. Skipping..."
        return 0
    fi

    # PHP version to install
    local php_version="8.3"

    # Add PHP repository
    if ! add_php_repository; then
        log_error "Failed to add PHP repository"
        return 1
    fi

    # Install PHP
    if ! install_php "${php_version}"; then
        log_error "Failed to install PHP ${php_version}"
        return 1
    fi

    # Install PHP extensions
    if ! install_php_extensions "${php_version}"; then
        log_error "Failed to install PHP extensions"
        return 1
    fi

    # Install Composer
    if ! install_composer; then
        log_error "Failed to install Composer"
        return 1
    fi

    # Install WordPress CLI
    if ! install_wp_cli; then
        log_error "Failed to install WordPress CLI"
        return 1
    fi

    # Install PHP code quality tools
    if ! install_php_tools; then
        log_warning "Failed to install some PHP code quality tools"
        # Continue anyway, as these are not critical
    fi

    # Configure PHP for development
    if ! configure_php "${php_version}"; then
        log_warning "Failed to configure some PHP settings"
        # Continue anyway, as these are configurable later
    fi

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "PHP ${php_version} and web development tools installed successfully"

    log_info "Note: MariaDB and Nginx are NOT installed as they will be handled by Docker"

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

# Call the main function
install_web_development

# Return the exit code
exit $?
