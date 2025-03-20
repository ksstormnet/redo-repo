#!/bin/bash

# 05-development-tools-setup.sh
# This script installs a lightweight set of development tools focused on WordPress plugin development
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

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

# Define configuration files for development tools
JAVA_CONFIG_FILES=(
    "${USER_HOME}/.java/deployment/deployment.properties"
    "${USER_HOME}/.java/deployment/security/exception.sites"
)

PYTHON_CONFIG_FILES=(
    "${USER_HOME}/.config/pip/pip.conf"
    "${USER_HOME}/.config/pycodestyle"
)

NODE_CONFIG_FILES=(
    "${USER_HOME}/.npmrc"
    "${USER_HOME}/.config/configstore/update-notifier-npm.json"
)

PHP_CONFIG_FILES=(
    "/etc/php/8.4/cli/conf.d/99-custom.ini"
    "/etc/php/8.4/cli/conf.d/99-development.ini"
)

COMPOSER_CONFIG_FILES=(
    "${USER_HOME}/.config/composer/composer.json"
    "${USER_HOME}/.config/composer/auth.json"
)

WPCLI_CONFIG_FILES=(
    "${USER_HOME}/.wp-cli/config.yml"
)

DOCKER_CONFIG_FILES=(
    "${USER_HOME}/.docker/config.json"
    "/etc/docker/daemon.json"
)

GIT_CONFIG_FILES=(
    "${USER_HOME}/.gitconfig"
    "${USER_HOME}/.gitignore_global"
)

WRANGLER_CONFIG_FILES=(
    "${USER_HOME}/.wrangler/config.toml"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for development tools
handle_pre_installation_config "java" "${JAVA_CONFIG_FILES[@]}"
handle_pre_installation_config "python" "${PYTHON_CONFIG_FILES[@]}"
handle_pre_installation_config "node" "${NODE_CONFIG_FILES[@]}"
handle_pre_installation_config "php" "${PHP_CONFIG_FILES[@]}"
handle_pre_installation_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
handle_pre_installation_config "wp-cli" "${WPCLI_CONFIG_FILES[@]}"
handle_pre_installation_config "docker" "${DOCKER_CONFIG_FILES[@]}"
handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
handle_pre_installation_config "wrangler" "${WRANGLER_CONFIG_FILES[@]}"

# === STAGE 2: Basic Development Tools ===
section "Installing Basic Development Tools"

# Essential build tools
install_packages "Essential Build Tools" \
    gcc \
    g++ \
    make \
    pkg-config

# Minimal Java for compatibility (IPMI panels, etc.)
install_packages "Minimal Java Runtime" \
    openjdk-8-jre \
    icedtea-netx

# Create Java configuration directories
mkdir -p "${USER_HOME}/.java/deployment/security"

# Python basics
install_packages "Python Tools" \
    python3-full \
    python3-pip \
    python3-dev

# Create Python configuration directories
mkdir -p "${USER_HOME}/.config/pip"

# Node.js setup
section "Setting Up Node.js"

# Add NodeSource repository for latest LTS Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get update

install_packages "Node.js" \
    nodejs

# Update npm to latest version
npm install -g npm@latest
echo "✓ Updated npm to latest version"

# Create Node.js configuration directories
mkdir -p "${USER_HOME}/.config/configstore"

# === STAGE 3: PHP Development for WordPress Plugins ===
section "Setting Up PHP for WordPress Plugin Development"

# Add PHP Repository (Ondrej)
add-apt-repository -y ppa:ondrej/php
apt-get update

# PHP 8.4 focused on WordPress plugin development
install_packages "PHP 8.4 for WordPress" \
    php8.4 \
    php8.4-cli \
    php8.4-common \
    php8.4-curl \
    php8.4-gd \
    php8.4-intl \
    php8.4-mbstring \
    php8.4-mysql \
    php8.4-opcache \
    php8.4-xml \
    php8.4-zip \
    php8.4-bcmath \
    php8.4-imagick

# Ensure PHP 8.4 is the default
update-alternatives --set php /usr/bin/php8.4
echo "✓ Set PHP 8.4 as default"

# Create PHP configuration directories
mkdir -p /etc/php/8.4/cli/conf.d

# Install Composer
section "Installing Composer"
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
    echo "ERROR: Invalid composer installer checksum"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
echo "✓ Installed Composer"

# Create Composer configuration directories
mkdir -p "${USER_HOME}/.config/composer"

# Install WP-CLI
section "Installing WP-CLI"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
echo "✓ Installed WP-CLI"

# Create WP-CLI configuration directories
mkdir -p "${USER_HOME}/.wp-cli"

# === STAGE 4: Docker for Development Environments ===
section "Setting Up Docker for Development Environments"

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install Docker (minimal set)
install_packages "Docker" \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add current user to Docker group if running as sudo
if [[ "${SUDO_USER}" ]]; then
    usermod -aG docker "${SUDO_USER}"
    echo "✓ Added user ${SUDO_USER} to docker group"
fi

# Enable and start Docker service
systemctl enable docker
systemctl start docker
echo "✓ Enabled and started Docker service"

# Create Docker configuration directories
mkdir -p "${USER_HOME}/.docker"
mkdir -p /etc/docker

# === STAGE 5: Development Utilities ===
section "Installing Essential Development Utilities"

# Install git extensions
install_packages "Git Extensions" \
    git-lfs

# Setup Git LFS
git lfs install
echo "✓ Initialized Git LFS"

# Install Cloudflare Wrangler
npm install -g wrangler
echo "✓ Installed Cloudflare Wrangler"

# Create Wrangler configuration directories
mkdir -p "${USER_HOME}/.wrangler"

# === STAGE 6: Manage Development Tool Configurations ===
section "Managing Development Tool Configurations"

# Handle configuration files
handle_installed_software_config "java" "${JAVA_CONFIG_FILES[@]}"
handle_installed_software_config "python" "${PYTHON_CONFIG_FILES[@]}"
handle_installed_software_config "node" "${NODE_CONFIG_FILES[@]}"
handle_installed_software_config "php" "${PHP_CONFIG_FILES[@]}"
handle_installed_software_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
handle_installed_software_config "wp-cli" "${WPCLI_CONFIG_FILES[@]}"
handle_installed_software_config "docker" "${DOCKER_CONFIG_FILES[@]}"
handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
handle_installed_software_config "wrangler" "${WRANGLER_CONFIG_FILES[@]}"

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.java"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.wp-cli"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.docker"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.wrangler"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.gitconfig"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.gitignore_global"
fi

# === STAGE 7: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "java" "${JAVA_CONFIG_FILES[@]}"
check_post_installation_configs "python" "${PYTHON_CONFIG_FILES[@]}"
check_post_installation_configs "node" "${NODE_CONFIG_FILES[@]}"
check_post_installation_configs "php" "${PHP_CONFIG_FILES[@]}"
check_post_installation_configs "composer" "${COMPOSER_CONFIG_FILES[@]}"
check_post_installation_configs "wp-cli" "${WPCLI_CONFIG_FILES[@]}"
check_post_installation_configs "docker" "${DOCKER_CONFIG_FILES[@]}"
check_post_installation_configs "git" "${GIT_CONFIG_FILES[@]}"
check_post_installation_configs "wrangler" "${WRANGLER_CONFIG_FILES[@]}"

# Final update
apt-get update
apt-get upgrade -y

section "Development Tools Setup Complete!"
echo "You now have a lightweight development environment installed with managed configurations."
echo "Notable tools include:"
echo "  - PHP 8.4 with WordPress plugin development packages"
echo "  - Node.js with npm"
echo "  - Docker for containerized services"
echo "  - WP-CLI and Composer for PHP development"
echo "  - Minimal Java runtime for compatibility"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "You may need to log out and back in for group membership changes to take effect."
