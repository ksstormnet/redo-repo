#!/usr/bin/env bash
# ============================================================================
# 05-virtualization.sh
# ----------------------------------------------------------------------------
# Installs virtualization tools including VirtualBox, QEMU/KVM and related
# packages for virtual machine management
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${INTERACTIVE:=false}"
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
SCRIPT_NAME="05-virtualization"

# ============================================================================
# Installation Functions
# ============================================================================

# Verify system readiness for virtualization
function verify_system_readiness() {
    log_step "Verifying system readiness for virtualization"

    # Check if virtualization is supported by the CPU
    if ! grep -Eq "(vmx|svm)" /proc/cpuinfo; then
        log_warning "CPU virtualization extensions (VMX/SVM) not found. Virtualization may not be supported or enabled in BIOS/UEFI."
    else
        log_info "CPU virtualization extensions detected"
    fi

    # Check if running in a VM
    if is_running_in_vm; then
        log_warning "Running in a virtual machine. Nested virtualization might not be supported or performant."
    fi

    return 0
}

# Install VirtualBox and related packages
function install_virtualbox() {
    log_step "Installing VirtualBox"

    if check_state "${SCRIPT_NAME}_virtualbox_installed"; then
        log_info "VirtualBox is already installed. Skipping..."
        return 0
    fi

    # Check if user wants to install VirtualBox
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Install VirtualBox?" "y"; then
            log_info "Skipping VirtualBox installation by user choice"
            return 0
        fi
    fi

    # Add VirtualBox repository
    log_info "Adding VirtualBox repository"

    # Add the Oracle VirtualBox public key
    if ! curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/oracle-virtualbox-2016.gpg; then
        log_error "Failed to add VirtualBox repository key"
        return 1
    fi

    # Get the release codename separately to avoid masking return value
    local release_codename
    release_codename=$(lsb_release -cs) || true

    # Add the repository
    if ! echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian ${release_codename} contrib" > /etc/apt/sources.list.d/virtualbox.list; then
        log_error "Failed to add VirtualBox repository"
        return 1
    fi

    # Update package lists
    log_info "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists after adding VirtualBox repository"
        return 1
    fi

    # Install VirtualBox and required dependencies
    log_info "Installing VirtualBox packages"
    local virtualbox_packages=(
        "virtualbox-7.0"
        "dkms"
        "linux-headers-$(uname -r)"
    )

    if ! apt_install "${virtualbox_packages[@]}"; then
        log_error "Failed to install VirtualBox"
        return 1
    fi

    # Install VirtualBox Extension Pack
    log_info "Installing VirtualBox Extension Pack"

    # Get the exact VirtualBox version installed
    # Declare first, then assign to avoid masking return values
    local vbox_version
    vbox_version=$(vboxmanage -v | cut -d 'r' -f 1) || true
    if [[ -z "${vbox_version}" ]]; then
        log_error "Failed to determine VirtualBox version"
        return 1
    fi

    # Download and install the Extension Pack
    # Declare first, then assign to avoid masking return values
    local temp_dir
    temp_dir=$(mktemp -d) || true
    local ext_pack_file="${temp_dir}/Oracle_VM_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"

    if ! curl -L "https://download.virtualbox.org/virtualbox/${vbox_version}/Oracle_VM_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack" -o "${ext_pack_file}"; then
        log_error "Failed to download VirtualBox Extension Pack"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Accept the license and install extension pack
    log_info "Installing VirtualBox Extension Pack (accepting license)"
    if ! echo "y" | VBoxManage extpack install --replace "${ext_pack_file}"; then
        log_error "Failed to install VirtualBox Extension Pack"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Clean up
    rm -rf "${temp_dir}"

    # Add current user to the vboxusers group
    if [[ -n "${SUDO_USER}" ]]; then
        log_info "Adding user ${SUDO_USER} to vboxusers group"
        if ! usermod -aG vboxusers "${SUDO_USER}"; then
            log_warning "Failed to add user ${SUDO_USER} to vboxusers group"
        fi
    fi

    # Set up VirtualBox storage location in /data/virtualbox
    log_info "Setting up VirtualBox storage location in /data/virtualbox"

    # Create the directory if it doesn't exist
    if [[ ! -d "/data/virtualbox" ]]; then
        log_info "Creating /data/virtualbox directory"
        mkdir -p "/data/virtualbox"

        # Set appropriate permissions
        if [[ -n "${SUDO_USER}" ]]; then
            chown "${SUDO_USER}:${SUDO_USER}" "/data/virtualbox"
        fi

        chmod 755 "/data/virtualbox"
    fi

    # Configure VirtualBox to use the new location
    if [[ -n "${SUDO_USER}" ]]; then
        local user_home
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)

        # Create VirtualBox configuration directory if it doesn't exist
        mkdir -p "${user_home}/.config/VirtualBox"

        # Create or update VirtualBox.xml configuration file
        log_info "Configuring VirtualBox to use /data/virtualbox as default machine folder"

        # Check if the file exists and contains the SystemProperties element
        if [[ -f "${user_home}/.config/VirtualBox/VirtualBox.xml" ]] && grep -q "<SystemProperties" "${user_home}/.config/VirtualBox/VirtualBox.xml"; then
            # Update the existing defaultMachineFolder attribute
            sed -i 's|defaultMachineFolder="[^"]*"|defaultMachineFolder="/data/virtualbox"|g' "${user_home}/.config/VirtualBox/VirtualBox.xml"
        else
            # Create a new configuration file
            cat > "${user_home}/.config/VirtualBox/VirtualBox.xml" << EOF
<?xml version="1.0"?>
<VirtualBox xmlns="http://www.virtualbox.org/" version="1.12-linux">
  <Global>
    <SystemProperties defaultMachineFolder="/data/virtualbox"/>
  </Global>
</VirtualBox>
EOF
        fi

        # Set correct ownership
        chown -R "${SUDO_USER}:${SUDO_USER}" "${user_home}/.config/VirtualBox"
    fi

    set_state "${SCRIPT_NAME}_virtualbox_installed"
    log_success "VirtualBox installation completed successfully"
    return 0
}

# Install QEMU/KVM virtualization
function install_qemu_kvm() {
    log_step "Installing QEMU/KVM virtualization"

    if check_state "${SCRIPT_NAME}_qemu_kvm_installed"; then
        log_info "QEMU/KVM is already installed. Skipping..."
        return 0
    fi

    # Check if user wants to install QEMU/KVM
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Install QEMU/KVM virtualization?" "y"; then
            log_info "Skipping QEMU/KVM installation by user choice"
            return 0
        fi
    fi

    # Install QEMU/KVM packages
    log_info "Installing QEMU/KVM packages"
    local qemu_packages=(
        qemu-kvm
        libvirt-daemon-system
        libvirt-clients
        bridge-utils
        virt-manager
    )

    if ! apt_install "${qemu_packages[@]}"; then
        log_error "Failed to install QEMU/KVM packages"
        return 1
    fi

    # Add current user to libvirt groups
    if [[ -n "${SUDO_USER}" ]]; then
        log_info "Adding user ${SUDO_USER} to libvirt groups"
        if ! usermod -aG libvirt "${SUDO_USER}"; then
            log_warning "Failed to add user ${SUDO_USER} to libvirt group"
        fi

        if ! usermod -aG libvirt-qemu "${SUDO_USER}"; then
            log_warning "Failed to add user ${SUDO_USER} to libvirt-qemu group"
        fi
    fi

    # Enable and start libvirtd service
    log_info "Enabling and starting libvirtd service"
    if ! systemctl enable libvirtd; then
        log_warning "Failed to enable libvirtd service"
    fi

    if ! systemctl start libvirtd; then
        log_warning "Failed to start libvirtd service"
    fi

    set_state "${SCRIPT_NAME}_qemu_kvm_installed"
    log_success "QEMU/KVM installation completed successfully"
    return 0
}

# Install additional virtualization tools
function install_virtualization_tools() {
    log_step "Installing additional virtualization tools"

    if check_state "${SCRIPT_NAME}_tools_installed"; then
        log_info "Additional virtualization tools already installed. Skipping..."
        return 0
    fi

    # Install additional virtualization tools
    log_info "Installing additional virtualization tools"
    local tools_packages=(
        "bridge-utils"         # For network bridges
        "virt-viewer"          # For VM console viewing
        "virtinst"             # For virt-install tools
        "spice-client-gtk"     # For SPICE protocol support
        "virt-top"             # VM monitoring tool
        "libguestfs-tools"     # Guest filesystem tools
        "libosinfo-bin"        # OS information database tools
    )

    if ! apt_install "${tools_packages[@]}"; then
        log_error "Failed to install additional virtualization tools"
        return 1
    fi

    set_state "${SCRIPT_NAME}_tools_installed"
    log_success "Additional virtualization tools installed successfully"
    return 0
}

# Install Vagrant for virtual machine management
function install_vagrant() {
    log_step "Installing Vagrant"

    if check_state "${SCRIPT_NAME}_vagrant_installed"; then
        log_info "Vagrant is already installed. Skipping..."
        return 0
    fi

    # Check if user wants to install Vagrant
    if [[ "${INTERACTIVE}" == "true" ]]; then
        if ! prompt_yes_no "Install Vagrant for VM management?" "n"; then
            log_info "Skipping Vagrant installation by user choice"
            return 0
        fi
    else
        # In non-interactive mode, skip installation by default
        log_info "Skipping Vagrant installation in non-interactive mode"
        return 0
    fi

    # Download Vagrant .deb package
    log_info "Downloading Vagrant .deb package"
    local vagrant_version="2.3.4"
    local vagrant_deb="vagrant_${vagrant_version}_x86_64.deb"
    local vagrant_url="https://releases.hashicorp.com/vagrant/${vagrant_version}/${vagrant_deb}"

    # Declare first, then assign to avoid masking return values
    local temp_dir
    temp_dir=$(mktemp -d) || true

    if ! wget -q "${vagrant_url}" -O "${temp_dir}/${vagrant_deb}"; then
        log_error "Failed to download Vagrant package"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Install Vagrant package
    log_info "Installing Vagrant package"
    if ! dpkg -i "${temp_dir}/${vagrant_deb}"; then
        log_warning "Initial Vagrant installation failed, resolving dependencies..."

        # Fix dependencies and retry
        if ! apt_fix_broken; then
            log_error "Failed to fix dependencies for Vagrant"
            rm -rf "${temp_dir}"
            return 1
        fi

        # Try again after fixing dependencies
        if ! dpkg -i "${temp_dir}/${vagrant_deb}"; then
            log_error "Failed to install Vagrant package after fixing dependencies"
            rm -rf "${temp_dir}"
            return 1
        fi
    fi

    # Clean up
    rm -rf "${temp_dir}"

    # Verify Vagrant installation
    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant installation verification failed"
        return 1
    fi

    # Get Vagrant version for logging
    # Declare first, then assign to avoid masking return values
    local installed_vagrant_version
    installed_vagrant_version=$(vagrant --version) || true
    log_success "Vagrant (${installed_vagrant_version}) installed successfully"

    set_state "${SCRIPT_NAME}_vagrant_installed"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function install_virtualization() {
    log_section "Installing Virtualization Tools"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Virtualization tools have already been installed. Skipping..."
        return 0
    fi

    # Verify system readiness
    verify_system_readiness

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install virtualization tools
    install_virtualbox || log_warning "VirtualBox installation encountered issues"
    install_qemu_kvm || log_warning "QEMU/KVM installation encountered issues"
    install_virtualization_tools || log_warning "Failed to install some virtualization tools"
    install_vagrant || log_warning "Vagrant installation encountered issues"

    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Virtualization tools installation completed successfully"

    # User needs to log out and back in for group changes to take effect
    if [[ -n "${SUDO_USER}" ]]; then
        log_warning "You need to log out and back in for group changes to take effect"
    fi

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Call the main function
install_virtualization

# Return the exit code
exit $?
