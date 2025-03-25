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
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Check if we have restored configurations
if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
    echo "Found restored configuration mapping at: ${CONFIG_MAPPING_PATH}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_PATH}"
fi

# Define shell configs path if not already defined
if [[ -z "${SHELL_CONFIGS_PATH}" ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    SHELL_CONFIGS_PATH="${GENERAL_CONFIGS_PATH}/home"
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

# Check for restored development configurations
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    echo "Checking for restored development tool configurations..."
    
    # Check for various development tool configurations
    RESTORED_DEV_CONFIGS=false
    
    # Check Java configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/java" ]] || [[ -f "${SHELL_CONFIGS_PATH}/.java" ]]; then
        echo "Found restored Java configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check Python configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/pip" ]]; then
        echo "Found restored Python/pip configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check Node.js configs
    if [[ -f "${SHELL_CONFIGS_PATH}/.npmrc" ]] || [[ -d "${GENERAL_CONFIGS_PATH}/config/configstore" ]]; then
        echo "Found restored Node.js configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check PHP configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/etc/php" ]]; then
        echo "Found restored PHP configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check Composer configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/composer" ]] || [[ -d "${GENERAL_CONFIGS_PATH}/composer" ]]; then
        echo "Found restored Composer configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check WP-CLI configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/wp-cli" ]]; then
        echo "Found restored WP-CLI configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    # Check Docker configs
    if [[ -d "${GENERAL_CONFIGS_PATH}/docker" ]] || [[ -f "${GENERAL_CONFIGS_PATH}/etc/docker/daemon.json" ]]; then
        echo "Found restored Docker configurations"
        RESTORED_DEV_CONFIGS=true
    fi
    
    if [[ "${RESTORED_DEV_CONFIGS}" = true ]]; then
        echo "Will use restored development tool configurations where possible."
    else
        echo "No restored development tool configurations found."
    fi
else
    echo "No restored configuration mapping found. Using default configurations."
    RESTORED_DEV_CONFIGS=false
fi

# Set up pre-installation configurations only if no restored configs
if [[ "${RESTORED_DEV_CONFIGS}" = false ]]; then
    handle_pre_installation_config "java" "${JAVA_CONFIG_FILES[@]}"
    handle_pre_installation_config "python" "${PYTHON_CONFIG_FILES[@]}"
    handle_pre_installation_config "node" "${NODE_CONFIG_FILES[@]}"
    handle_pre_installation_config "php" "${PHP_CONFIG_FILES[@]}"
    handle_pre_installation_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
    handle_pre_installation_config "wp-cli" "${WPCLI_CONFIG_FILES[@]}"
    handle_pre_installation_config "docker" "${DOCKER_CONFIG_FILES[@]}"
    handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
    handle_pre_installation_config "wrangler" "${WRANGLER_CONFIG_FILES[@]}"
fi

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
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || true
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
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || true
ARCH=$(dpkg --print-architecture) || true
RELEASE=$(lsb_release -cs) || true
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${RELEASE} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install Docker (minimal set)
install_packages "Docker" \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add current user to Docker group if running as sudo
if [[ -n "${SUDO_USER}" ]]; then
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

# === STAGE 6: Restore Development Tool Configurations ===
section "Restoring Development Tool Configurations"

# Check for restored development tools configurations
if [[ -n "${GENERAL_CONFIGS_PATH}" ]] && [[ "${RESTORED_DEV_CONFIGS}" = true ]]; then
    echo "Restoring development tool configurations from backup..."
    
    # Restore Java configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/java" ]]; then
        echo "Restoring Java configurations from backup..."
        mkdir -p "${USER_HOME}/.java"
        cp -r "${GENERAL_CONFIGS_PATH}/java"/* "${USER_HOME}/.java/"
        echo "✓ Restored Java configurations"
    elif [[ -d "${SHELL_CONFIGS_PATH}/.java" ]]; then
        echo "Restoring Java configurations from shell configs backup..."
        mkdir -p "${USER_HOME}/.java"
        cp -r "${SHELL_CONFIGS_PATH}/.java"/* "${USER_HOME}/.java/"
        echo "✓ Restored Java configurations"
    fi
    
    # Restore Python/pip configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/pip" ]]; then
        echo "Restoring Python/pip configurations from backup..."
        mkdir -p "${USER_HOME}/.config/pip"
        cp -r "${GENERAL_CONFIGS_PATH}/config/pip"/* "${USER_HOME}/.config/pip/"
        echo "✓ Restored Python/pip configurations"
    fi
    
    # Restore Node.js configurations if found
    if [[ -f "${SHELL_CONFIGS_PATH}/.npmrc" ]]; then
        echo "Restoring .npmrc from backup..."
        cp "${SHELL_CONFIGS_PATH}/.npmrc" "${USER_HOME}/"
        echo "✓ Restored .npmrc"
    fi
    
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/configstore" ]]; then
        echo "Restoring npm configstore from backup..."
        mkdir -p "${USER_HOME}/.config/configstore"
        cp -r "${GENERAL_CONFIGS_PATH}/config/configstore"/* "${USER_HOME}/.config/configstore/"
        echo "✓ Restored npm configstore"
    fi
    
    # Restore PHP configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/etc/php" ]]; then
        echo "Restoring PHP configurations from backup..."
        # This is a system path, so we need to be careful
        if [[ -d "${GENERAL_CONFIGS_PATH}/etc/php/8.4/cli/conf.d" ]]; then
            mkdir -p /etc/php/8.4/cli/conf.d
            # Copy only the custom configuration files
            for config_file in 99-custom.ini 99-development.ini; do
                if [[ -f "${GENERAL_CONFIGS_PATH}/etc/php/8.4/cli/conf.d/${config_file}" ]]; then
                    cp "${GENERAL_CONFIGS_PATH}/etc/php/8.4/cli/conf.d/${config_file}" "/etc/php/8.4/cli/conf.d/"
                    echo "✓ Restored PHP configuration: ${config_file}"
                fi
            done
        fi
    fi
    
    # Restore Composer configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/config/composer" ]]; then
        echo "Restoring Composer configurations from backup..."
        mkdir -p "${USER_HOME}/.config/composer"
        cp -r "${GENERAL_CONFIGS_PATH}/config/composer"/* "${USER_HOME}/.config/composer/"
        echo "✓ Restored Composer configurations"
    elif [[ -d "${GENERAL_CONFIGS_PATH}/composer" ]]; then
        echo "Restoring Composer configurations from alternative backup path..."
        mkdir -p "${USER_HOME}/.config/composer"
        cp -r "${GENERAL_CONFIGS_PATH}/composer"/* "${USER_HOME}/.config/composer/"
        echo "✓ Restored Composer configurations"
    fi
    
    # Restore WP-CLI configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/wp-cli" ]]; then
        echo "Restoring WP-CLI configurations from backup..."
        mkdir -p "${USER_HOME}/.wp-cli"
        cp -r "${GENERAL_CONFIGS_PATH}/wp-cli"/* "${USER_HOME}/.wp-cli/"
        echo "✓ Restored WP-CLI configurations"
    fi
    
    # Restore Docker configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/docker" ]]; then
        echo "Restoring Docker configurations from backup..."
        mkdir -p "${USER_HOME}/.docker"
        cp -r "${GENERAL_CONFIGS_PATH}/docker"/* "${USER_HOME}/.docker/"
        echo "✓ Restored Docker user configurations"
    fi
    
    if [[ -f "${GENERAL_CONFIGS_PATH}/etc/docker/daemon.json" ]]; then
        echo "Restoring Docker daemon configuration from backup..."
        mkdir -p /etc/docker
        cp "${GENERAL_CONFIGS_PATH}/etc/docker/daemon.json" "/etc/docker/"
        echo "✓ Restored Docker daemon configuration"
        
        # Restart Docker service to apply new configuration
        systemctl restart docker
    fi
    
    # Restore Wrangler configurations if found
    if [[ -d "${GENERAL_CONFIGS_PATH}/wrangler" ]]; then
        echo "Restoring Wrangler configurations from backup..."
        mkdir -p "${USER_HOME}/.wrangler"
        cp -r "${GENERAL_CONFIGS_PATH}/wrangler"/* "${USER_HOME}/.wrangler/"
        echo "✓ Restored Wrangler configurations"
    fi
    
    echo "✓ Restored development tool configurations from backup"
else
    echo "No restored development tool configurations found or configuration path not set."
    echo "Using repository-based configuration management."
    
    # Handle configuration files from repository
    handle_installed_software_config "java" "${JAVA_CONFIG_FILES[@]}"
    handle_installed_software_config "python" "${PYTHON_CONFIG_FILES[@]}"
    handle_installed_software_config "node" "${NODE_CONFIG_FILES[@]}"
    handle_installed_software_config "php" "${PHP_CONFIG_FILES[@]}"
    handle_installed_software_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
    handle_installed_software_config "wp-cli" "${WPCLI_CONFIG_FILES[@]}"
    handle_installed_software_config "docker" "${DOCKER_CONFIG_FILES[@]}"
    handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
    handle_installed_software_config "wrangler" "${WRANGLER_CONFIG_FILES[@]}"
fi

# === STAGE 7: Restore Development Projects if Available ===
section "Checking for Development Projects"

# Check for restored Development projects
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    PROJECTS_PATH="${GENERAL_CONFIGS_PATH}/Development/Projects"
    if [[ -d "${PROJECTS_PATH}" ]]; then
        echo "Found Development Projects in backup at: ${PROJECTS_PATH}"
        
        # Create Projects directory if it doesn't exist
        mkdir -p "/data/Development/Projects"
        
        # Ask user if they want to restore projects
        read -p "Would you like to restore Development Projects from backup? (y/n): " -n 1 -r
        echo
        if [[ ${REPLY} =~ ^[Yy]$ ]]; then
            echo "Restoring Development Projects from backup..."
            cp -r "${PROJECTS_PATH}"/* "/data/Development/Projects/"
            
            # Set proper ownership
            chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "/data/Development/Projects"
            
            echo "✓ Restored Development Projects from backup"
        else
            echo "Skipping restoration of Development Projects."
        fi
    fi
fi

# === STAGE 8: Restore Development Templates and Scripts ===
section "Checking for Development Templates"

# Check for restored Development templates
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    TEMPLATES_PATH="${GENERAL_CONFIGS_PATH}/Templates/Development"
    if [[ -d "${TEMPLATES_PATH}" ]]; then
        echo "Found Development Templates in backup at: ${TEMPLATES_PATH}"
        
        # Create Templates directory if it doesn't exist
        mkdir -p "${USER_HOME}/Templates/Development"
        
        # Copy templates
        cp -r "${TEMPLATES_PATH}"/* "${USER_HOME}/Templates/Development/"
        
        # Set proper ownership
        chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/Templates/Development"
        
        echo "✓ Restored Development Templates from backup"
    fi
    
    # Check for development scripts
    SCRIPTS_PATH="${GENERAL_CONFIGS_PATH}/bin"
    if [[ -d "${SCRIPTS_PATH}" ]]; then
        echo "Checking for development scripts in backup..."
        
        # Create bin directory if it doesn't exist
        mkdir -p "${USER_HOME}/bin"
        
        # Look for common development scripts
        for script in "new-node-project" "new-php-project" "new-monorepo-project"; do
            if [[ -f "${SCRIPTS_PATH}/${script}" ]]; then
                echo "Found ${script} script in backup"
                cp "${SCRIPTS_PATH}/${script}" "${USER_HOME}/bin/"
                chmod +x "${USER_HOME}/bin/${script}"
                echo "✓ Restored ${script} script"
            fi
        done
        
        # Set proper ownership
        chown -R "${ACTUAL_USER}":"${ACTUAL_USER}" "${USER_HOME}/bin"
    fi
fi

# === STAGE 9: Check for New Configuration Files ===
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
if [[ "${RESTORED_DEV_CONFIGS}" = true ]]; then
    echo "Your restored development configurations have been applied from the backup."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
    echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
    echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
    echo "  - Any changes to configurations should be made in the repository"
fi
echo
echo "You may need to log out and back in for group membership changes to take effect."
