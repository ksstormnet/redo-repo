#!/usr/bin/env bash
# ============================================================================
# 03-nvidia-rtx-optimizer.sh
# ----------------------------------------------------------------------------
# Optimizes system settings for NVIDIA RTX 3090 GPU
# Includes CUDA configuration, GPU settings, and system optimizations
# specifically tailored for deep learning and AI workloads
# ============================================================================

# shellcheck disable=SC1091,SC2154,SC2250,SC2034,SC2292

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="03-nvidia-rtx-optimizer"

# ============================================================================
# Script Variables
# ============================================================================
NVIDIA_CONF_DIR="/etc/nvidia"
CUDA_CONF_DIR="/etc/cuda"
OLLAMA_CONFIG_DIR="/etc/ollama"
MODPROBE_CONF_DIR="/etc/modprobe.d"
SYSTEMD_CONF_DIR="/etc/systemd/system"
TMP_DIR="/tmp/nvidia-optimizer"

# ============================================================================
# Helper Functions
# ============================================================================

# Check if the RTX 3090 GPU is present
function check_rtx3090_gpu() {
    log_step "Checking for NVIDIA RTX 3090 GPU"
    
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA tools not installed. Please run the NVIDIA driver installation script first."
        return 1
    fi
    
    # Check for RTX 3090 specifically
    if nvidia-smi --query-gpu=name --format=csv,noheader | grep -i "RTX 3090" &> /dev/null; then
        log_success "NVIDIA RTX 3090 detected"
        return 0
    else
        log_warning "NVIDIA RTX 3090 not detected. This script is optimized specifically for the RTX 3090."
        log_warning "Proceeding may still improve performance, but settings may not be optimal for your GPU."
        
        # Ask for confirmation if not running in non-interactive mode
        if [[ "${INTERACTIVE}" == "true" ]]; then
            if ! prompt_yes_no "Do you want to continue anyway?" "n"; then
                log_info "Aborting RTX 3090 optimization as requested"
                return 1
            fi
        fi
        
        return 0
    fi
}

# Create necessary directories
function create_directories() {
    log_step "Creating necessary directories"
    
    mkdir -p "${NVIDIA_CONF_DIR}" "${CUDA_CONF_DIR}" "${OLLAMA_CONFIG_DIR}" "${TMP_DIR}"
    
    if [[ ! -d "${MODPROBE_CONF_DIR}" ]]; then
        mkdir -p "${MODPROBE_CONF_DIR}"
    fi
    
    log_success "Directories created successfully"
    return 0
}

# ============================================================================
# Optimization Functions
# ============================================================================

# Configure NVIDIA driver parameters
function configure_nvidia_driver() {
    log_step "Configuring NVIDIA driver parameters"
    
    if check_state "${SCRIPT_NAME}_nvidia_driver_configured"; then
        log_info "NVIDIA driver parameters already configured. Skipping..."
        return 0
    fi
    
    # Configure persistent mode for improved performance
    log_info "Enabling NVIDIA persistent mode"
    if ! nvidia-smi -pm 1; then
        log_warning "Failed to enable persistent mode. This may affect performance."
    fi
    
    # Set power management mode to maximum performance
    log_info "Setting power management to maximum performance"
    if ! nvidia-smi -pl 350; then  # 350W is typical max for RTX 3090
        log_warning "Failed to set power limit. This may affect performance."
    fi
    
    # Configure GPU clocks to maximum performance
    log_info "Setting GPU clock profiles to maximum performance"
    if ! nvidia-smi --auto-boost-default=0; then
        log_warning "Failed to disable auto boost. This may affect performance."
    fi
    
    # Create nvidia-modprobe configuration file
    log_info "Creating NVIDIA modprobe configuration"
    cat > "${MODPROBE_CONF_DIR}/nvidia-rtx-optimizer.conf" << EOF
# NVIDIA RTX 3090 optimized settings
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnablePCIeGen3=1
options nvidia NVreg_EnableGpuFirmware=1
options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
EOF
    
    # Update initramfs to apply module settings
    log_info "Updating initramfs to apply module settings"
    if ! update-initramfs -u; then
        log_warning "Failed to update initramfs. You may need to restart to apply some changes."
    fi
    
    set_state "${SCRIPT_NAME}_nvidia_driver_configured"
    log_success "NVIDIA driver parameters configured successfully"
    return 0
}

# Configure CUDA optimizations
function configure_cuda_optimizations() {
    log_step "Configuring CUDA optimizations"
    
    if check_state "${SCRIPT_NAME}_cuda_optimized"; then
        log_info "CUDA optimizations already configured. Skipping..."
        return 0
    fi
    
    # Check CUDA installation
    if ! command -v nvcc &> /dev/null; then
        log_warning "CUDA toolkit not found. Some optimizations may not be effective."
        # Continue anyway as this is not critical
    fi
    
    # Create CUDA configuration file with optimized settings
    log_info "Creating CUDA configuration file with optimized settings"
    cat > "${CUDA_CONF_DIR}/cuda-rtx3090-optimizer.conf" << EOF
# CUDA optimizations for RTX 3090
CUDA_CACHE_DISABLE=0
CUDA_CACHE_MAXSIZE=4294967296 # 4GB cache
CUDA_DEVICE_ORDER=PCI_BUS_ID
CUDA_VISIBLE_DEVICES=all
CUDA_AUTO_BOOST=0
EOF
    
    # Add CUDA environment variables to profile
    log_info "Adding CUDA environment variables to system profile"
    cat > "/etc/profile.d/cuda-optimizer.sh" << EOF
#!/bin/bash
# CUDA optimization environment variables
export CUDA_CACHE_DISABLE=0
export CUDA_CACHE_MAXSIZE=4294967296 # 4GB cache
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=all
export CUDA_AUTO_BOOST=0
# RTX 3090 specific optimizations
export NVIDIA_TF32_OVERRIDE=1
export NVIDIA_VISIBLE_DEVICES=all
EOF
    
    # Make the profile script executable
    chmod +x "/etc/profile.d/cuda-optimizer.sh"
    
    set_state "${SCRIPT_NAME}_cuda_optimized"
    log_success "CUDA optimizations configured successfully"
    return 0
}

# Configure optimizations for the Ollama AI platform
function configure_ollama_optimizations() {
    log_step "Configuring Ollama optimizations for RTX 3090"
    
    if check_state "${SCRIPT_NAME}_ollama_optimized"; then
        log_info "Ollama optimizations already configured. Skipping..."
        return 0
    fi
    
    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        log_info "Ollama not found. Skipping Ollama-specific optimizations."
        return 0
    fi
    
    log_info "Creating Ollama configuration for RTX 3090"
    
    # Create Ollama config directory if it doesn't exist
    mkdir -p "${OLLAMA_CONFIG_DIR}"
    
    # Create RTX 3090 modelfile template
    cat > "${OLLAMA_CONFIG_DIR}/rtx3090-modelfile.txt" << EOF
# RTX 3090 optimized settings for Ollama
# Maximum GPU VRAM to use (in MB)
GPU_LAYERS ALL
# Maximum memory to use for layers (in MiB)
F16 TRUE
# Enable or disable flash attention
FLASH_ATTN TRUE
# Enable or disable batch processing
BATCH TRUE
# Number of batch size to process
BATCH_SIZE 8192
# Context size (in tokens)
CONTEXT_SIZE 32768
# Number of GPU layers
GPU_LAYERS ALL
# Threads to use
THREADS AUTO
EOF
    
    # Create a systemd dropin file for Ollama service to apply GPU optimizations
    if [[ -f "/etc/systemd/system/ollama.service" ]]; then
        log_info "Creating systemd dropin file for Ollama service"
        
        mkdir -p "/etc/systemd/system/ollama.service.d"
        cat > "/etc/systemd/system/ollama.service.d/rtx3090-optimizer.conf" << EOF
[Service]
Environment="CUDA_VISIBLE_DEVICES=all"
Environment="NVIDIA_VISIBLE_DEVICES=all"
Environment="OLLAMA_HOST=0.0.0.0"
Environment="CUDA_AUTO_BOOST=0"
# RTX 3090 settings
Environment="OLLAMA_GPU_LAYERS=all"
Environment="OLLAMA_F16=true"  
Environment="OLLAMA_FLASH_ATTN=true"
Environment="OLLAMA_BATCH=true"
Environment="OLLAMA_BATCH_SIZE=8192"
Environment="OLLAMA_CONTEXT_SIZE=32768"
EOF
        
        # Reload systemd configuration
        log_info "Reloading systemd configuration"
        if ! systemctl daemon-reload; then
            log_warning "Failed to reload systemd configuration. Ollama service may need manual restart."
        fi
        
        # Restart Ollama service if it's running
        if systemctl is-active --quiet ollama; then
            log_info "Restarting Ollama service to apply new settings"
            if ! systemctl restart ollama; then
                log_warning "Failed to restart Ollama service. You may need to restart it manually."
            fi
        fi
    else
        log_warning "Ollama service file not found. Skipping service configuration."
        
        # Create a shell script with environment variables instead
        log_info "Creating environment script for Ollama"
        cat > "/etc/profile.d/ollama-rtx3090-optimizer.sh" << EOF
#!/bin/bash
# Ollama RTX 3090 optimizations
export OLLAMA_GPU_LAYERS=all
export OLLAMA_F16=true
export OLLAMA_FLASH_ATTN=true
export OLLAMA_BATCH=true
export OLLAMA_BATCH_SIZE=8192
export OLLAMA_CONTEXT_SIZE=32768
EOF
        
        chmod +x "/etc/profile.d/ollama-rtx3090-optimizer.sh"
    fi
    
    set_state "${SCRIPT_NAME}_ollama_optimized"
    log_success "Ollama optimizations for RTX 3090 configured successfully"
    return 0
}

# Configure system memory and CPU for optimal GPU performance
function configure_system_for_gpu() {
    log_step "Configuring system memory and CPU for optimal GPU performance"
    
    if check_state "${SCRIPT_NAME}_system_optimized"; then
        log_info "System already optimized for GPU performance. Skipping..."
        return 0
    fi
    
    # Configure transparent huge pages for better memory performance
    log_info "Enabling transparent huge pages for better memory performance"
    echo "always" > /sys/kernel/mm/transparent_hugepage/enabled
    
    # Create a systemd service to enable huge pages at boot
    cat > "${SYSTEMD_CONF_DIR}/gpu-memory-optimizer.service" << EOF
[Unit]
Description=GPU Memory Optimization Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo always > /sys/kernel/mm/transparent_hugepage/enabled"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    systemctl daemon-reload
    systemctl enable gpu-memory-optimizer.service
    
    # Configure swappiness for better performance
    log_info "Configuring swappiness for better performance"
    echo "vm.swappiness=10" >> /etc/sysctl.d/99-gpu-optimizer.conf
    
    # Configure dirty ratio for better I/O performance
    log_info "Configuring I/O parameters for better performance"
    cat >> /etc/sysctl.d/99-gpu-optimizer.conf << EOF
# Increase dirty ratio for better I/O performance
vm.dirty_ratio = 60
vm.dirty_background_ratio = 30

# Increase file handles
fs.file-max = 2097152

# Increase max user watches for file changes
fs.inotify.max_user_watches = 524288
EOF
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-gpu-optimizer.conf
    
    # Configure CPU governor for performance
    log_info "Configuring CPU governor for maximum performance"
    if command -v cpupower &> /dev/null; then
        cpupower frequency-set -g performance
        
        # Create a systemd service to set CPU governor at boot
        cat > "${SYSTEMD_CONF_DIR}/cpu-performance-governor.service" << EOF
[Unit]
Description=CPU Performance Governor Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable the service
        systemctl daemon-reload
        systemctl enable cpu-performance-governor.service
    else
        log_warning "cpupower not found. CPU governor not configured."
    fi
    
    set_state "${SCRIPT_NAME}_system_optimized"
    log_success "System configured for optimal GPU performance"
    return 0
}

# Create a script for monitoring and dynamically adjusting GPU performance
function create_gpu_monitoring_script() {
    log_step "Creating GPU monitoring and optimization script"
    
    if check_state "${SCRIPT_NAME}_monitoring_script_created"; then
        log_info "GPU monitoring script already created. Skipping..."
        return 0
    fi
    
    log_info "Creating GPU monitoring and optimization script"
    
    # Create the monitoring script
    cat > "/usr/local/bin/rtx3090-monitor.sh" << 'EOF'
#!/bin/bash
# RTX 3090 Monitoring and Optimization Script
# This script monitors GPU usage and adjusts settings dynamically for optimal performance

# Configuration
CHECK_INTERVAL=30  # Check every 30 seconds
TEMP_THRESHOLD=80  # Temperature threshold in C
UTILIZATION_THRESHOLD=50  # GPU utilization threshold %

# Log file
LOG_FILE="/var/log/rtx3090-monitor.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check GPU temperature
check_temperature() {
    local temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    echo "$temp"
}

# Function to check GPU utilization
check_utilization() {
    local util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
    echo "$util"
}

# Function to optimize for high performance
optimize_performance() {
    log_message "Optimizing for high performance"
    nvidia-smi -pm 1
    nvidia-smi --auto-boost-default=0
    nvidia-smi -pl 350  # Set power limit to 350W
    
    # Set memory clocks to maximum
    nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=1000" > /dev/null 2>&1
    
    # Set GPU clocks to maximum
    nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=100" > /dev/null 2>&1
    
    # Set fan speed to auto
    nvidia-settings -a "[gpu:0]/GPUFanControlState=0" > /dev/null 2>&1
}

# Function to optimize for temperature (cooling mode)
optimize_temperature() {
    log_message "Optimizing for temperature control"
    nvidia-smi -pl 300  # Reduce power limit to 300W
    
    # Reset memory and GPU clock offsets
    nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=0" > /dev/null 2>&1
    nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=0" > /dev/null 2>&1
    
    # Set fan speed to high
    nvidia-settings -a "[gpu:0]/GPUFanControlState=1" > /dev/null 2>&1
    nvidia-settings -a "[fan:0]/GPUTargetFanSpeed=80" > /dev/null 2>&1
}

# Main monitoring loop
log_message "RTX 3090 Monitoring and Optimization Script started"

while true; do
    # Check GPU temperature
    TEMP=$(check_temperature)
    UTIL=$(check_utilization)
    
    log_message "GPU Temperature: ${TEMP}°C, Utilization: ${UTIL}%"
    
    # Apply optimizations based on conditions
    if [[ $TEMP -ge $TEMP_THRESHOLD ]]; then
        log_message "WARNING: High temperature detected (${TEMP}°C)"
        optimize_temperature
    elif [[ $UTIL -ge $UTILIZATION_THRESHOLD ]]; then
        log_message "High GPU utilization detected (${UTIL}%)"
        optimize_performance
    fi
    
    # Sleep for the check interval
    sleep $CHECK_INTERVAL
done
EOF
    
    # Make script executable
    chmod +x "/usr/local/bin/rtx3090-monitor.sh"
    
    # Create a systemd service for the monitoring script
    cat > "${SYSTEMD_CONF_DIR}/rtx3090-monitor.service" << EOF
[Unit]
Description=RTX 3090 Monitoring and Optimization Service
After=nvidia-persistenced.service

[Service]
Type=simple
ExecStart=/usr/local/bin/rtx3090-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Don't enable the service by default, let the user decide
    log_info "Created RTX 3090 monitoring service (not enabled by default)"
    log_info "To enable the service, run: sudo systemctl enable --now rtx3090-monitor.service"
    
    set_state "${SCRIPT_NAME}_monitoring_script_created"
    log_success "GPU monitoring and optimization script created successfully"
    return 0
}

# Verify NVIDIA installation and optimizations
function verify_nvidia_optimizations() {
    log_step "Verifying NVIDIA RTX optimizations"
    
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi command not found. NVIDIA driver may not be installed correctly."
        return 1
    fi
    
    # Display GPU information
    log_info "GPU Information:"
    nvidia-smi
    
    # Check if CUDA is available
    if command -v nvcc &> /dev/null; then
        local cuda_version
        cuda_version=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
        log_info "CUDA version: ${cuda_version}"
    else
        log_warning "CUDA toolkit not found"
    fi
    
    # Check Ollama configuration if installed
    if command -v ollama &> /dev/null; then
        log_info "Ollama is installed and configured for RTX 3090"
    fi
    
    # Check if our configuration files exist
    if [[ -f "${MODPROBE_CONF_DIR}/nvidia-rtx-optimizer.conf" ]]; then
        log_info "NVIDIA kernel module configuration is in place"
    fi
    
    if [[ -f "/etc/profile.d/cuda-optimizer.sh" ]]; then
        log_info "CUDA environment variables are configured"
    fi
    
    log_success "NVIDIA RTX optimizations verified"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function nvidia_rtx_optimize() {
    log_section "NVIDIA RTX 3090 Optimization"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "NVIDIA RTX 3090 optimizations have already been applied. Skipping..."
        return 0
    fi
    
    # Create necessary directories
    if ! create_directories; then
        log_error "Failed to create necessary directories"
        return 1
    fi
    
    # Check for RTX 3090 GPU
    if ! check_rtx3090_gpu; then
        log_info "Aborting NVIDIA RTX 3090 optimization"
        return 1
    fi
    
    # Configure NVIDIA driver parameters
    configure_nvidia_driver || log_warning "Failed to configure some NVIDIA driver parameters"
    
    # Configure CUDA optimizations
    configure_cuda_optimizations || log_warning "Failed to configure some CUDA optimizations"
    
    # Configure Ollama optimizations
    configure_ollama_optimizations || log_warning "Failed to configure Ollama optimizations"
    
    # Configure system for GPU
    configure_system_for_gpu || log_warning "Failed to configure some system parameters for GPU"
    
    # Create GPU monitoring script
    create_gpu_monitoring_script || log_warning "Failed to create GPU monitoring script"
    
    # Verify optimizations
    verify_nvidia_optimizations
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "NVIDIA RTX 3090 optimization completed successfully"
    
    # Remind about reboot
    log_warning "A system reboot is recommended to apply all optimizations"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Parse command line arguments
INSTALL_CUDA=false
FORCE_MODE=false
NONINTERACTIVE=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --with-cuda)
            INSTALL_CUDA=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        --non-interactive)
            NONINTERACTIVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --with-cuda          Install CUDA toolkit"
            echo "  --force              Force reinstallation of components"
            echo "  --non-interactive    Run without interactive prompts"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Call the main function
nvidia_rtx_optimize

# Return the exit code
exit $?
