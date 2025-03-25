#!/usr/bin/env bash
# ============================================================================
# 04-container-tools.sh
# ----------------------------------------------------------------------------
# Installs container management tools including Docker and related utilities
# Configures Docker permissions and sets up essential Docker components
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="04-container-tools"

# ============================================================================
# Installation Functions
# ============================================================================

# Install Docker and Docker Compose
function install_docker() {
    log_step "Installing Docker and related tools"

    # Check if Docker is already installed
    if command -v docker &> /dev/null && check_state "${SCRIPT_NAME}_docker_installed"; then
        log_info "Docker is already installed. Skipping..."
        return 0
    fi

    log_info "Installing Docker from Docker's official repository"

    # Add Docker's official GPG key
    log_info "Adding Docker's GPG key"
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        log_error "Failed to add Docker GPG key"
        return 1
    fi

    # Set up the stable repository
    log_info "Setting up Docker repository"

    # Get architecture separately to avoid masking return value
    local arch
    arch=$(dpkg --print-architecture) || true

    # Get release codename separately to avoid masking return value
    local release_cs
    release_cs=$(lsb_release -cs) || true

    if ! echo \
        "deb [arch=${arch} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu \
        ${release_cs} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        log_error "Failed to add Docker repository"
        return 1
    fi

    # Update package lists to include Docker repository
    log_info "Updating package lists with Docker repository"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install Docker Engine and related packages
    log_info "Installing Docker packages"
    local docker_packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-compose-plugin
    )

    if ! apt_install "${docker_packages[@]}"; then
        log_error "Failed to install Docker packages"
        return 1
    fi

    # Set Docker to start on boot
    log_info "Enabling Docker service"
    if ! systemctl enable docker.service; then
        log_warning "Failed to enable Docker service on boot"
    fi

    # Start Docker service
    log_info "Starting Docker service"
    if ! systemctl start docker.service; then
        log_warning "Failed to start Docker service"
    fi

    # Check Docker installation
    if ! docker --version; then
        log_error "Docker installation verification failed"
        return 1
    fi

    # Check Docker Compose installation
    if ! docker compose version; then
        log_warning "Docker Compose installation verification failed"
    fi

    set_state "${SCRIPT_NAME}_docker_installed"
    log_success "Docker installed successfully"
    return 0
}

# Configure user permissions for Docker
function configure_docker_permissions() {
    log_step "Configuring Docker permissions"

    # Check if permissions are already configured
    if check_state "${SCRIPT_NAME}_permissions_configured"; then
        log_info "Docker permissions already configured. Skipping..."
        return 0
    fi

    # Add current user to docker group if not running as root directly
    if [[ -n "${SUDO_USER}" ]]; then
        log_info "Adding user ${SUDO_USER} to the docker group"
        if ! usermod -aG docker "${SUDO_USER}"; then
            log_error "Failed to add user ${SUDO_USER} to the docker group"
            return 1
        fi

        log_warning "You will need to log out and back in for the docker group changes to take effect"
    else
        log_info "Running as root directly, skipping user permissions setup"
    fi

    set_state "${SCRIPT_NAME}_permissions_configured"
    log_success "Docker permissions configured successfully"
    return 0
}

# Install additional container tools (optional)
function install_additional_tools() {
    log_step "Installing additional container management tools"

    # Check if additional tools are already installed
    if check_state "${SCRIPT_NAME}_additional_tools_installed"; then
        log_info "Additional container tools already installed. Skipping..."
        return 0
    fi

    # List of additional container tools
    local additional_tools=(
        podman
        buildah
        skopeo
    )

    # Default value for INTERACTIVE if not set
    : "${INTERACTIVE:=false}"

    # Check if the user wants to install these tools
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Install additional container tools (Podman, Buildah, Skopeo)?" "n"; then
            log_info "Skipping installation of additional container tools"
            return 0
        fi
    fi

    # Install additional tools
    log_info "Installing additional container tools"
    if ! apt_install "${additional_tools[@]}"; then
        log_warning "Failed to install some additional container tools"
        # Continue anyway as these are optional
    fi

    set_state "${SCRIPT_NAME}_additional_tools_installed"
    log_success "Additional container tools installed successfully"
    return 0
}

# Pull common Docker images for convenience
function pull_common_docker_images() {
    log_step "Pulling common Docker images"

    # Check if this step is already completed
    if check_state "${SCRIPT_NAME}_images_pulled"; then
        log_info "Common Docker images already pulled. Skipping..."
        return 0
    fi

    # Check if the user wants to pull common images
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Pull common Docker images (alpine, ubuntu, nginx, postgres)?" "n"; then
            log_info "Skipping pulling common Docker images"
            return 0
        fi
    else
        # In non-interactive mode, skip this step by default
        log_info "Skipping pulling common Docker images in non-interactive mode"
        return 0
    fi

    # List of common images to pull
    local common_images=(
        "alpine:latest"
        "ubuntu:latest"
        "nginx:latest"
        "postgres:latest"
    )

    # Pull each image
    for image in "${common_images[@]}"; do
        log_info "Pulling Docker image: ${image}"
        if ! docker pull "${image}"; then
            log_warning "Failed to pull Docker image: ${image}"
            # Continue with other images
        fi
    done

    set_state "${SCRIPT_NAME}_images_pulled"
    log_success "Common Docker images pulled successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_container_tools() {
    log_section "Installing Container Management Tools"

    # Default value for FORCE_MODE if not set
    : "${FORCE_MODE:=false}"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Container tools have already been installed. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install Docker
    if ! install_docker; then
        log_error "Failed to install Docker"
        return 1
    fi

    # Configure Docker permissions
    if ! configure_docker_permissions; then
        log_warning "Failed to configure Docker permissions"
        # Continue anyway as this is not critical
    fi

    # Install additional container tools
    install_additional_tools

    # Pull common Docker images
    pull_common_docker_images

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Container tools installation completed successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_container_tools

# Return the exit code
exit $?
