#!/bin/bash

# Global Development Packages Setup Script
# This script installs recommended global packages for PHP and Node.js development
# and manages development environment configurations using the repository
# Assumes PHP 8.4, Composer, and Node.js are already installed

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
    echo "PHP Version: $(php -v | head -n 1)"
    echo "Composer Version: $(composer --version)"
    echo "Node.js Version: $(node -v)"
    echo "npm Version: $(npm -v)"
}

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for development tools
handle_pre_installation_config "node" "${NODE_CONFIG_FILES[@]}"
handle_pre_installation_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
handle_pre_installation_config "git" "${GIT_CONFIG_FILES[@]}"
handle_pre_installation_config "bin" "${BIN_SCRIPT_FILES[@]}"

# Install global Node.js packages
install_node_globals() {
    section "Installing Global Node.js Packages"
    
    # Development workflow tools
    echo "Installing development workflow tools..."
    npm install -g nodemon         # Monitor for changes and restart applications
    npm install -g pm2             # Process manager for Node.js
    npm install -g http-server     # Simple HTTP server
    npm install -g serve           # Static file server
    npm install -g concurrently    # Run multiple commands concurrently
    npm install -g json-server     # Fake REST API server
    
    # Code quality and formatting tools
    echo "Installing code quality and formatting tools..."
    npm install -g eslint          # JavaScript linter
    npm install -g prettier        # Code formatter
    npm install -g typescript      # TypeScript compiler
    npm install -g ts-node         # TypeScript execution environment
    
    # Build tools and task runners
    echo "Installing build tools and task runners..."
    npm install -g gulp-cli        # Gulp command line interface
    npm install -g grunt-cli       # Grunt command line interface
    npm install -g webpack-cli     # Webpack command line interface
    npm install -g vite            # Frontend build tool
    
    # Utility and CLI tools
    echo "Installing utility and CLI tools..."
    npm install -g npm-check-updates # Check for package updates
    npm install -g tldr            # Simplified man pages
    npm install -g trash-cli       # Safer alternative to rm
    npm install -g release-it      # Automate versioning and package publishing
    npm install -g dotenv-cli      # Environment variable management
    
    # Package management tools
    echo "Installing package management tools..."
    npm install -g npm-check       # Check for outdated, incorrect, and unused dependencies
    npm install -g depcheck        # Check for unused dependencies
    npm install -g license-checker # Check licenses of dependencies
    
    # Framework-specific CLI tools
    echo "Installing framework-specific CLI tools..."
    npm install -g @angular/cli    # Angular CLI
    npm install -g create-react-app # React application generator
    npm install -g @vue/cli        # Vue.js CLI
    npm install -g next            # Next.js
    
    echo "✅ Global Node.js packages installed successfully."
}

# Install global Composer packages
install_composer_globals() {
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
    composer global require infection/infection             # Mutation Testing
    
    # Security tools
    echo "Installing security tools..."
    composer global require sensiolabs/security-checker     # Security vulnerability checker
    
    # Utility tools
    echo "Installing utility tools..."
    composer global require laravel/installer               # Laravel installer
    composer global require symfony/symfony-installer       # Symfony installer
    composer global require symfony/var-dumper              # Better var_dump
    composer global require ramsey/composer-install         # Composer install helper
    
    # Documentation tools
    echo "Installing documentation tools..."
    composer global require phpdocumentor/phpdocumentor     # PHP Documentor
    
    echo "✅ Global Composer packages installed successfully."
}

# Configure PATH for Composer global binaries
configure_composer_path() {
    section "Configuring PATH for Composer Global Binaries"
    
    # Determine shell configuration file
    SHELL_CONFIG=""
    if [[ -n "${BASH_VERSION}" ]]; then
        if [[ -f "${USER_HOME}/.bashrc" ]]; then
            SHELL_CONFIG="${USER_HOME}/.bashrc"
        elif [[ -f "${USER_HOME}/.bash_profile" ]]; then
            SHELL_CONFIG="${USER_HOME}/.bash_profile"
        fi
    elif [[ -n "${ZSH_VERSION}" ]]; then
        SHELL_CONFIG="${USER_HOME}/.zshrc"
    else
        echo "⚠️ Could not determine shell configuration file. You'll need to manually add Composer's bin directory to your PATH."
        return
    fi
    
    # Get Composer global bin directory
    COMPOSER_BIN_DIR=$(composer global config bin-dir --absolute 2>/dev/null || echo "${USER_HOME}/.composer/vendor/bin")
    
    # Check if PATH already contains Composer bin directory
    if echo "${PATH}" | grep -q "${COMPOSER_BIN_DIR}"; then
        echo "✅ Composer bin directory is already in PATH."
    else
        # Add Composer bin directory to PATH
        echo "export PATH=\"\$PATH:${COMPOSER_BIN_DIR}\"" >> "${SHELL_CONFIG}"
        echo "✅ Added Composer bin directory to PATH in ${SHELL_CONFIG}."
        echo "   Please run 'source ${SHELL_CONFIG}' to update your current session."
    fi
}

# Create project templates
create_project_templates() {
    section "Creating Project Templates"
    
    # Create templates directory
    TEMPLATES_DIR="${USER_HOME}/Templates/Development"
    mkdir -p "${TEMPLATES_DIR}"
    
    # Create Node.js project template
    NODE_TEMPLATE_DIR="${TEMPLATES_DIR}/node-project"
    mkdir -p "${NODE_TEMPLATE_DIR}"
    
    # Create package.json template if it doesn't exist
    if [[ ! -f "${NODE_TEMPLATE_DIR}/package.json" ]]; then
        cat > "${NODE_TEMPLATE_DIR}/package.json" << EOF
{
  "name": "project-name",
  "version": "1.0.0",
  "description": "Project description",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest",
    "lint": "eslint ."
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "devDependencies": {
    "eslint": "^8.42.0",
    "jest": "^29.5.0",
    "nodemon": "^2.0.22"
  }
}
EOF
    fi
    
    # Create .gitignore template if it doesn't exist
    if [[ ! -f "${NODE_TEMPLATE_DIR}/.gitignore" ]]; then
        cat > "${NODE_TEMPLATE_DIR}/.gitignore" << EOF
# Dependency directories
node_modules/
jspm_packages/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Coverage directory used by tools like istanbul
coverage/

# Build outputs
dist/
build/
out/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    fi
    
    # Create README template if it doesn't exist
    if [[ ! -f "${NODE_TEMPLATE_DIR}/README.md" ]]; then
        cat > "${NODE_TEMPLATE_DIR}/README.md" << EOF
# Project Name

Project description goes here.

## Installation

\`\`\`bash
npm install
\`\`\`

## Usage

\`\`\`bash
npm start
\`\`\`

## Development

\`\`\`bash
npm run dev
\`\`\`

## Testing

\`\`\`bash
npm test
\`\`\`
EOF
    fi
    
    # Create PHP project template
    PHP_TEMPLATE_DIR="${TEMPLATES_DIR}/php-project"
    mkdir -p "${PHP_TEMPLATE_DIR}/src"
    mkdir -p "${PHP_TEMPLATE_DIR}/tests"
    
    # Create composer.json template if it doesn't exist
    if [[ ! -f "${PHP_TEMPLATE_DIR}/composer.json" ]]; then
        cat > "${PHP_TEMPLATE_DIR}/composer.json" << EOF
{
    "name": "vendor/project",
    "description": "Project description",
    "type": "project",
    "require": {
        "php": "^8.4"
    },
    "require-dev": {
        "phpunit/phpunit": "^10.0",
        "squizlabs/php_codesniffer": "^3.7",
        "phpstan/phpstan": "^1.10"
    },
    "autoload": {
        "psr-4": {
            "App\\\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "App\\\\Tests\\\\": "tests/"
        }
    },
    "scripts": {
        "test": "phpunit",
        "phpcs": "phpcs --standard=PSR12 src tests",
        "phpstan": "phpstan analyse src tests"
    }
}
EOF
    fi
    
    # Create PHP .gitignore template if it doesn't exist
    if [[ ! -f "${PHP_TEMPLATE_DIR}/.gitignore" ]]; then
        cat > "${PHP_TEMPLATE_DIR}/.gitignore" << EOF
# Composer files
/vendor/
composer.phar
composer.lock

# PHPUnit
/phpunit.xml
.phpunit.result.cache

# Environment files
.env
.env.local

# IDE files
.idea/
.vscode/
*.sublime-project
*.sublime-workspace

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    fi
    
    # Create PHP README template if it doesn't exist
    if [[ ! -f "${PHP_TEMPLATE_DIR}/README.md" ]]; then
        cat > "${PHP_TEMPLATE_DIR}/README.md" << EOF
# PHP Project

PHP project description goes here.

## Requirements

- PHP 8.4 or higher
- Composer

## Installation

\`\`\`bash
composer install
\`\`\`

## Testing

\`\`\`bash
composer test
\`\`\`

## Code Quality

\`\`\`bash
composer phpcs    # Code style check
composer phpstan  # Static analysis
\`\`\`
EOF
    fi
    
    # Set proper ownership
    if [[ "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}":"${SUDO_USER}" "${TEMPLATES_DIR}"
    fi
    
    echo "✅ Project templates created in ${TEMPLATES_DIR}"
    echo "   - Node.js project template: ${TEMPLATES_DIR}/node-project"
    echo "   - PHP project template: ${TEMPLATES_DIR}/php-project"
}

# Create bin directory and helper scripts
setup_bin_directory() {
    section "Setting Up Bin Directory"
    
    # Create bin directory
    BIN_DIR="${USER_HOME}/bin"
    mkdir -p "${BIN_DIR}"
    
    # Create script to generate new Node.js project if it doesn't exist
    if ! handle_installed_software_config "bin" "${BIN_DIR}/new-node-project"; then
        cat > "${BIN_DIR}/new-node-project" << 'EOF'
#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: new-node-project <project-name> [directory]"
    exit 1
fi

PROJECT_NAME=$1
DIRECTORY=${2:-$PROJECT_NAME}

# Create project directory
mkdir -p "$DIRECTORY"
cd "$DIRECTORY" || exit

# Check if Templates directory exists
TEMPLATE_DIR="$HOME/Templates/Development/node-project"
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: Template directory not found at $TEMPLATE_DIR"
    echo "Please run the global-dev-packages setup script first"
    exit 1
fi

# Copy template files
cp -r "$TEMPLATE_DIR/"* .
cp -r "$TEMPLATE_DIR/".* . 2>/dev/null || true

# Update package.json with project name
sed -i "s/project-name/$PROJECT_NAME/g" package.json

# Initialize git repository
git init
git add .
git commit -m "Initial commit"

# Install dependencies
npm install

echo "✅ Node.js project '$PROJECT_NAME' created successfully in '$DIRECTORY'"
echo "   cd '$DIRECTORY' to get started"
EOF
        chmod +x "${BIN_DIR}/new-node-project"
        
        # Now move it to the repo and create a symlink
        handle_installed_software_config "bin" "${BIN_DIR}/new-node-project"
    fi
    
    # Create script to generate new PHP project if it doesn't exist
    if ! handle_installed_software_config "bin" "${BIN_DIR}/new-php-project"; then
        cat > "${BIN_DIR}/new-php-project" << 'EOF'
#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: new-php-project <project-name> [directory]"
    exit 1
fi

PROJECT_NAME=$1
DIRECTORY=${2:-$PROJECT_NAME}

# Create project directory
mkdir -p "$DIRECTORY"
cd "$DIRECTORY" || exit

# Check if Templates directory exists
TEMPLATE_DIR="$HOME/Templates/Development/php-project"
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: Template directory not found at $TEMPLATE_DIR"
    echo "Please run the global-dev-packages setup script first"
    exit 1
fi

# Copy template files
cp -r "$TEMPLATE_DIR/"* .
cp -r "$TEMPLATE_DIR/".* . 2>/dev/null || true

# Update composer.json with project name
SANITIZED_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
sed -i "s/vendor\/project/$SANITIZED_NAME/g" composer.json

# Initialize git repository
git init
git add .
git commit -m "Initial commit"

# Install dependencies
composer install

echo "✅ PHP project '$PROJECT_NAME' created successfully in '$DIRECTORY'"
echo "   cd '$DIRECTORY' to get started"
EOF
        chmod +x "${BIN_DIR}/new-php-project"
        
        # Now move it to the repo and create a symlink
        handle_installed_software_config "bin" "${BIN_DIR}/new-php-project"
    fi
    
    # Add bin directory to PATH if needed
    if ! echo "${PATH}" | grep -q "${BIN_DIR}"; then
        if [[ -n "${SHELL_CONFIG}" ]]; then
            echo "export PATH=\"\$PATH:${BIN_DIR}\"" >> "${SHELL_CONFIG}"
            echo "✅ Added bin directory to PATH in ${SHELL_CONFIG}."
        else
            echo "⚠️ Could not determine shell configuration file. You'll need to manually add ${BIN_DIR} to your PATH."
        fi
    fi
    
    echo "✅ Bin directory setup at ${BIN_DIR}"
    echo "   Project helper scripts will be installed to this location."
}

# === STAGE 2: Install Global Packages ===
section "Installing Global Packages"

# Check requirements
check_requirements

# Install global Node.js packages
install_node_globals

# Install global Composer packages
install_composer_globals

# Configure Composer PATH
configure_composer_path

# Create project templates
create_project_templates

# Setup bin directory and helper scripts
setup_bin_directory

# === STAGE 3: Manage Development Tool Configurations ===
section "Managing Development Tool Configurations"

# Create required directories
mkdir -p "${USER_HOME}/.config/typescript"
mkdir -p "${USER_HOME}/.config/phpcs"
mkdir -p "${USER_HOME}/.composer"

# Handle configuration files
handle_installed_software_config "node" "${NODE_CONFIG_FILES[@]}"
handle_installed_software_config "composer" "${COMPOSER_CONFIG_FILES[@]}"
handle_installed_software_config "git" "${GIT_CONFIG_FILES[@]}"
handle_installed_software_config "bin" "${BIN_SCRIPT_FILES[@]}"

# Configure Git global gitignore if needed
if [[ -f "${USER_HOME}/.gitignore_global" ]]; then
    git config --global core.excludesfile "${USER_HOME}/.gitignore_global"
fi

# Configure Git credential helper if needed
if [[ -f "${USER_HOME}/.git-credentials" ]]; then
    git config --global credential.helper store
fi

# Set proper ownership
if [[ "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.composer"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.gitconfig"
    chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.gitignore_global"
    [[ -f "${USER_HOME}/.git-credentials" ]] && chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.git-credentials"
fi

# === STAGE 4: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "node" "${NODE_CONFIG_FILES[@]}"
check_post_installation_configs "composer" "${COMPOSER_CONFIG_FILES[@]}"
check_post_installation_configs "git" "${GIT_CONFIG_FILES[@]}"
check_post_installation_configs "bin" "${BIN_SCRIPT_FILES[@]}"

section "Setup Complete!"
echo "✅ Global development packages have been installed and configurations managed."
echo 
echo "To use the helper scripts:"
echo "  new-node-project myproject     # Create a new Node.js project"
echo "  new-php-project myproject      # Create a new PHP project"
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "To apply PATH changes to your current session:"
if [[ -n "${SHELL_CONFIG}" ]]; then
    echo "  source ${SHELL_CONFIG}"
else
    echo "  Please restart your terminal or source your shell configuration file."
fi
