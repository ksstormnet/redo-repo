#!/usr/bin/env bash
# ============================================================================
# 01-nvidia-setup.sh
# ----------------------------------------------------------------------------
# Detects NVIDIA graphics hardware, installs appropriate drivers,
# and configures system for optimal performance
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${STATE_DIR:=/var/cache/system-installer}"
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
SCRIPT_NAME="01-nvidia-setup"

# Available NVIDIA driver versions/types
DRIVER_OPTIONS=(
    "nvidia-driver-535" # Recommended for most recent GPUs
    "nvidia-driver-525" # Good for slightly older hardware
    "nvidia-driver-470" # Legacy driver for older GPUs
    "nvidia-driver-390" # Very old GPUs
    "nvidia-driver-open" # Open source version
)

# ============================================================================
# Hardware Detection Functions
# ============================================================================

# Detect NVIDIA graphics hardware
function detect_nvidia_hardware() {
    log_step "Detecting NVIDIA graphics hardware"
    
    # Check if detection has already been completed
    if check_state "${SCRIPT_NAME}_hardware_detected"; then
        log_info "NVIDIA hardware detection previously completed, using cached results"
        return 0
    fi
    
    # Install pciutils if not already installed
    if ! command -v lspci &>/dev/null; then
        log_info "Installing pciutils for hardware detection"
        if ! apt_install pciutils; then
            log_error "Failed to install pciutils"
            return 1
        fi
    fi
    
    # Use lspci to detect NVIDIA hardware
    NVIDIA_DEVICES=$(lspci | grep -i nvidia)
    if [[ -z "${NVIDIA_DEVICES}" ]]; then
        log_warning "No NVIDIA hardware detected. Script will exit."
        set_state "${SCRIPT_NAME}_no_nvidia_hardware"
        return 1
    fi
    
    log_success "NVIDIA hardware detected:"
    echo "${NVIDIA_DEVICES}" | while read -r line; do
        log_info "  ${line}"
    done
    
    # Extract GPU model information for driver recommendations
    # Declare first, then assign to avoid masking return values
    local GPU_MODEL
    GPU_MODEL=$(echo "${NVIDIA_DEVICES}" | grep -i "vga\|3d\|display" | head -n 1 | awk -F: '{print $3}' | sed 's/^[ \t]*//') || true
    
    if [[ -n "${GPU_MODEL}" ]]; then
        log_info "Primary GPU model: ${GPU_MODEL}"
        state_set_value "nvidia_gpu_model" "${GPU_MODEL}"
    fi
    
    # Set state as completed
    set_state "${SCRIPT_NAME}_hardware_detected"
    return 0
}

# Determine best driver version for detected hardware
function determine_best_driver() {
    log_step "Determining optimal NVIDIA driver version"
    
    # Check if driver selection has already been completed
    if check_state "${SCRIPT_NAME}_driver_selected"; then
        # Declare first, then assign to avoid masking return values
        local RECOMMENDED_DRIVER
        RECOMMENDED_DRIVER=$(state_get_value "nvidia_recommended_driver") || true
        
        log_info "Previously selected driver: ${RECOMMENDED_DRIVER}"
        return 0
    fi
    
    # Get GPU model from state if available
    # Declare first, then assign to avoid masking return values
    local GPU_MODEL
    GPU_MODEL=$(state_get_value "nvidia_gpu_model") || true
    
    # Default to the newest driver
    RECOMMENDED_DRIVER="${DRIVER_OPTIONS[0]}"
    
    # Select driver based on GPU model
    if [[ -n "${GPU_MODEL}" ]]; then
        if echo "${GPU_MODEL}" | grep -i -q "GeForce [78]"; then
            RECOMMENDED_DRIVER="${DRIVER_OPTIONS[2]}" # 470 series for older GPUs
            log_info "Selected legacy driver for GeForce 7/8 series GPU"
        elif echo "${GPU_MODEL}" | grep -i -q "GeForce [456]"; then
            RECOMMENDED_DRIVER="${DRIVER_OPTIONS[3]}" # 390 series for very old GPUs
            log_info "Selected legacy driver for GeForce 4/5/6 series GPU"
        else
            log_info "Selected latest driver for modern GPU"
        fi
    else
        log_warning "No GPU model information available, defaulting to latest driver"
    fi
    
    log_info "Recommended driver: ${RECOMMENDED_DRIVER}"
    
    # Save selected driver to state
    state_set_value "nvidia_recommended_driver" "${RECOMMENDED_DRIVER}"
    set_state "${SCRIPT_NAME}_driver_selected"
    
    return 0
}

# ============================================================================
# Driver Installation Functions
# ============================================================================

# Install NVIDIA drivers based on selected driver version
function install_nvidia_drivers() {
    # Get the driver version to install, or use recommended one from state
    local driver_version=${1:-$(state_get_value "nvidia_recommended_driver")}
    
    # Verify we have a driver version to install
    if [[ -z "${driver_version}" ]]; then
        log_error "No driver version specified or recommended"
        return 1
    fi
    
    log_step "Installing NVIDIA drivers: ${driver_version}"
    
    # Check if driver is already installed
    if check_state "${SCRIPT_NAME}_driver_installed_${driver_version}"; then
        log_info "NVIDIA driver ${driver_version} already installed"
        return 0
    fi
    
    # Add the graphics drivers PPA for latest versions
    log_info "Adding graphics-drivers PPA"
    if ! add_apt_repository ppa:graphics-drivers/ppa; then
        log_warning "Failed to add graphics-drivers PPA. Continuing with default repository."
    fi
    
    # Update package lists
    log_info "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install required packages
    log_info "Installing NVIDIA dependencies"
    local dependencies=(
        dkms
        build-essential
        "linux-headers-$(uname -r)"
    )
    
    if ! apt_install "${dependencies[@]}"; then
        log_warning "Failed to install some dependencies. This might affect driver installation."
    fi
    
    # Check if running in a VM
    if systemd-detect-virt -q; then
        log_warning "Running in a virtual environment. NVIDIA driver installation might not work correctly."
    fi
    
    # Install the selected driver
    log_info "Installing driver package: ${driver_version}"
    if ! apt_install "${driver_version}" nvidia-settings nvidia-prime; then
        log_error "Failed to install NVIDIA drivers"
        return 1
    fi
    
    # Install Vulkan support
    log_info "Installing Vulkan support for NVIDIA"
    if ! apt_install vulkan-tools nvidia-vulkan-common nvidia-vulkan-icd; then
        log_warning "Failed to install Vulkan support. This is not critical for basic functionality."
    fi
    
    # Update initramfs to ensure driver is loaded at boot
    log_info "Updating initramfs"
    if ! update-initramfs -u; then
        log_warning "Failed to update initramfs. You may need to run this manually."
    fi
    
    # Mark driver installation as completed
    set_state "${SCRIPT_NAME}_driver_installed_${driver_version}"
    log_success "NVIDIA drivers installed successfully"
    
    # Set flag for reboot requirement
    touch "${STATE_DIR}/reboot_required"
    log_warning "A system reboot is required to complete NVIDIA driver setup"
    
    return 0
}

# ============================================================================
# System Configuration Functions
# ============================================================================

# Configure system for optimal NVIDIA performance
function configure_nvidia_system() {
    log_step "Configuring system for optimal NVIDIA performance"
    
    # Check if system is already configured
    if check_state "${SCRIPT_NAME}_system_configured"; then
        log_info "NVIDIA system already configured"
        return 0
    fi
    
    # Create Xorg configuration directory if it doesn't exist
    if [[ ! -d /etc/X11/xorg.conf.d ]]; then
        log_info "Creating Xorg configuration directory"
        mkdir -p /etc/X11/xorg.conf.d
    fi
    
    # Create a basic NVIDIA configuration file
    log_info "Creating basic NVIDIA configuration file"
    cat > /etc/X11/xorg.conf.d/20-nvidia.conf << EOF
Section "Device"
    Identifier     "NVIDIA Graphics"
    Driver         "nvidia"
    Option         "NoLogo" "1"
    Option         "RegistryDwords" "EnableBrightnessControl=1"
EndSection
EOF
    
    # Configure for hybrid graphics if Intel is also present
    if lspci | grep -i vga | grep -q -i intel; then
        log_info "Intel+NVIDIA hybrid graphics detected, setting up PRIME synchronization"
        cat > /etc/X11/xorg.conf.d/21-prime-sync.conf << EOF
Section "Device"
    Identifier "NVIDIA Card"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration" "Yes"
    Option "PrimaryGPU" "Yes"
EndSection
EOF
    fi
    
    # Configure kernel modules for NVIDIA
    log_info "Configuring kernel modules"
    if [[ ! -f /etc/modules-load.d/nvidia.conf ]]; then
        cat > /etc/modules-load.d/nvidia.conf << EOF
# Automatically load NVIDIA modules at boot
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF
    fi
    
    # Enable DRM KMS for better Wayland support
    log_info "Enabling DRM KMS for improved Wayland support"
    if [[ ! -f /etc/modprobe.d/nvidia-kms.conf ]]; then
        echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia-kms.conf
    fi
    
    # Create udev rules for NVIDIA devices
    log_info "Creating udev rules for NVIDIA devices"
    cat > /etc/udev/rules.d/70-nvidia.rules << EOF
# Remove NVIDIA USB xHCI Host Controller devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

# Remove NVIDIA USB Type-C UCSI devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

# Remove NVIDIA Audio devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"

# Enable runtime PM for NVIDIA VGA/3D controller devices
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

# Disable runtime PM for NVIDIA VGA/3D controller devices
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
EOF
    
    # Reload udev rules
    log_info "Reloading udev rules"
    if ! udevadm control --reload-rules && udevadm trigger; then
        log_warning "Failed to reload udev rules. This will be applied after reboot."
    fi
    
    # Mark system configuration as completed
    set_state "${SCRIPT_NAME}_system_configured"
    log_success "NVIDIA system configuration completed"
    
    return 0
}

# Install CUDA toolkit (optional feature)
function install_cuda_toolkit() {
    # Only install if explicitly requested
    if [[ "${INSTALL_CUDA}" != "true" ]]; then
        log_info "CUDA toolkit installation skipped (use --with-cuda to enable)"
        return 0
    fi
    
    log_step "Installing CUDA toolkit"
    
    # Check if CUDA is already installed
    if check_state "${SCRIPT_NAME}_cuda_installed"; then
        log_info "CUDA toolkit already installed"
        return 0
    fi
    
    # Add CUDA repository
    log_info "Adding CUDA repository"
    if [[ ! -f /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list ]]; then
        # Get the Ubuntu version - this example assumes Ubuntu 22.04
        # Declare first, then assign to avoid masking return values
        local ubuntu_version
        ubuntu_version=$(lsb_release -sc) || true
        
        log_info "Detected Ubuntu version: ${ubuntu_version}"
        
        # Get Ubuntu version separately to avoid masking return value
        local ubuntu_version_num
        ubuntu_version_num=$(lsb_release -sr | sed 's/\.//') || true
        
        # Download and install the CUDA keyring package
        wget -O /tmp/cuda-keyring.deb "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${ubuntu_version_num}/x86_64/cuda-keyring_1.1-1_all.deb"
        dpkg -i /tmp/cuda-keyring.deb
        apt_update
    fi
    
    # Install CUDA toolkit
    log_info "Installing CUDA toolkit packages"
    if ! apt_install cuda-toolkit; then
        log_error "Failed to install CUDA toolkit"
        return 1
    fi
    
    # Set up environment variables
    log_info "Setting up CUDA environment variables"
    if ! grep -q "CUDA_HOME" /etc/environment; then
        echo "CUDA_HOME=/usr/local/cuda" >> /etc/environment
        echo "PATH=\$PATH:/usr/local/cuda/bin" >> /etc/environment
    fi
    
    # Create a script for users' .bashrc to set up CUDA paths
    cat > /etc/profile.d/cuda.sh << 'EOF'
#!/bin/sh
export PATH=$PATH:/usr/local/cuda/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64
EOF
    
    chmod +x /etc/profile.d/cuda.sh
    
    # Mark CUDA installation as completed
    set_state "${SCRIPT_NAME}_cuda_installed"
    log_success "CUDA toolkit installed successfully"
    
    return 0
}

# Verify NVIDIA installation
function verify_nvidia_installation() {
    log_step "Verifying NVIDIA driver installation"
    
    # Check for nvidia-smi command
    if ! command -v nvidia-smi &>/dev/null; then
        log_warning "nvidia-smi not found. Driver installation may have failed."
        return 1
    fi
    
    # Run nvidia-smi to check driver status
    log_info "Running nvidia-smi to verify driver"
    if ! nvidia-smi; then
        log_error "nvidia-smi failed to run. Driver installation may be incomplete."
        return 1
    fi
    
    # Check if the X server can use the NVIDIA driver
    if command -v nvidia-xconfig &>/dev/null; then
        log_info "Testing NVIDIA X configuration"
        # This is a simple test that doesn't modify the config
        if ! nvidia-xconfig --query-gpu-info &>/dev/null; then
            log_warning "Unable to query GPU info. X configuration may need manual adjustment."
        fi
    fi
    
    log_success "NVIDIA driver verification successful"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function nvidia_setup_main() {
    log_section "NVIDIA Graphics Setup"
    
    # Parse command line arguments
    local INSTALL_CUDA=false
    local FORCE_DRIVER=""
    
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --with-cuda)
                INSTALL_CUDA=true
                shift
                ;;
            --force-driver=*)
                FORCE_DRIVER="${1#*=}"
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --with-cuda          Install CUDA toolkit"
                echo "  --force-driver=NAME  Force specific driver (e.g., nvidia-driver-525)"
                echo "  --help               Show this help message"
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Exit if already completed and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "NVIDIA setup has already been completed. Skipping..."
        return 0
    fi
    
    # Detect NVIDIA hardware
    if ! detect_nvidia_hardware; then
        log_info "No NVIDIA hardware detected. Exiting gracefully."
        exit 0
    fi
    
    # Determine best driver version
    determine_best_driver
    
    # Use forced driver if specified
    if [[ -n "${FORCE_DRIVER}" ]]; then
        log_info "Driver force-selected: ${FORCE_DRIVER}"
        state_set_value "nvidia_recommended_driver" "${FORCE_DRIVER}"
    fi
    
    # Get the selected driver
    # Declare first, then assign to avoid masking return values
    local RECOMMENDED_DRIVER
    RECOMMENDED_DRIVER=$(state_get_value "nvidia_recommended_driver") || true
    
    # Install drivers
    if ! install_nvidia_drivers "${RECOMMENDED_DRIVER}"; then
        log_error "Driver installation failed"
        exit 1
    fi
    
    # Configure system
    if ! configure_nvidia_system; then
        log_warning "System configuration for NVIDIA incomplete"
        # Continue anyway since this is not critical
    fi
    
    # Install CUDA if requested
    if [[ "${INSTALL_CUDA}" == "true" ]]; then
        if ! install_cuda_toolkit; then
            log_warning "CUDA toolkit installation failed"
            # Continue anyway since CUDA is optional
        fi
    fi
    
    # Verify installation
    verify_nvidia_installation
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "NVIDIA setup completed successfully"
    
    # Remind about reboot if needed
    if [[ -f "${STATE_DIR}/reboot_required" ]]; then
        log_warning "A system reboot is required to complete NVIDIA driver setup"
        echo ""
        echo "Please reboot your system with: sudo reboot"
    fi
    
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

# Call the main function with all arguments
nvidia_setup_main "$@"

# Return the exit code
exit $?
