#!/bin/bash

# 03-nvidia-rtx-setup.sh
# This script installs NVIDIA drivers optimized for RTX 3090 and LLM inference
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

# Check if we have restored configurations
if [[ -n "${CONFIG_MAPPING_PATH}" ]] && [[ -f "${CONFIG_MAPPING_PATH}" ]]; then
    echo "Found restored configuration mapping at: ${CONFIG_MAPPING_PATH}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_PATH}"
fi

# Determine user home directory
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
else
    USER_HOME="${HOME}"
fi

# Define configuration files for NVIDIA
NVIDIA_CONFIG_FILES=(
    "/etc/nvidia/nvidia-config.conf"
    "/etc/X11/xorg.conf.d/10-nvidia.conf"
    "/etc/cuda/cuda.conf"
    "/etc/profile.d/nvidia-env.sh"
    "/etc/systemd/system/nvidia-persistenced.service"
    "/etc/systemd/system/nvidia-persistence-mode.service"
    "/etc/ld.so.conf.d/cuda-ldconfig.conf"
)

# Display a section header
section "NVIDIA RTX 3090 Setup Script"
echo "This script will install optimized NVIDIA drivers for your RTX 3090 GPU."
echo "It will also configure CUDA and optimize the system for LLM inference workloads."
echo

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Check for restored NVIDIA configurations
RESTORED_NVIDIA_CONFIGS=false
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    echo "Checking for restored NVIDIA configurations..."
    
    # Look for NVIDIA configuration files in various locations in the backup
    POSSIBLE_NVIDIA_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/nvidia"
        "${GENERAL_CONFIGS_PATH}/etc/X11/xorg.conf.d"
        "${GENERAL_CONFIGS_PATH}/etc/cuda"
        "${GENERAL_CONFIGS_PATH}/etc/profile.d"
        "${GENERAL_CONFIGS_PATH}/etc/systemd/system"
    )
    
    for path in "${POSSIBLE_NVIDIA_PATHS[@]}"; do
        if [[ -d "${path}" ]]; then
            echo "Found potential NVIDIA configurations at: ${path}"
            RESTORED_NVIDIA_CONFIGS=true
        fi
    done
    
    if [[ "${RESTORED_NVIDIA_CONFIGS}" = true ]]; then
        echo "Will use restored NVIDIA configurations where possible."
    else
        echo "No restored NVIDIA configurations found."
    fi
fi

# Set up pre-installation configurations for NVIDIA only if we don't have restored configs
if [[ "${RESTORED_NVIDIA_CONFIGS}" = false ]]; then
    handle_pre_installation_config "nvidia" "${NVIDIA_CONFIG_FILES[@]}"
fi

# === STAGE 2: Remove existing NVIDIA drivers if any ===
section "Checking for Existing NVIDIA Drivers"

# Check if NVIDIA drivers are already installed
if dpkg -l | grep -E "nvidia-driver|nvidia-utils" > /dev/null || true; then
    echo "Existing NVIDIA drivers detected. Removing them before installation..."
    apt-get purge -y nvidia-*
    apt-get autoremove -y
    echo "✓ Removed existing NVIDIA drivers"
else
    echo "No existing NVIDIA drivers detected, proceeding with installation."
fi

# === STAGE 3: Add NVIDIA Repository ===
section "Adding NVIDIA Repository"

# Add NVIDIA's official GPU PPA
add-apt-repository -y ppa:graphics-drivers/ppa
apt-get update
echo "✓ Added NVIDIA GPU drivers PPA"

# === STAGE 4: Install NVIDIA Drivers ===
section "Installing NVIDIA Drivers for RTX 3090"

# Install recommended NVIDIA driver for RTX 3090
install_packages "NVIDIA Drivers" \
    nvidia-driver-545 \
    nvidia-utils-545 \
    libnvidia-common-545 \
    nvidia-settings

# Install NVIDIA CUDA toolkit
install_packages "NVIDIA CUDA Toolkit" \
    nvidia-cuda-toolkit \
    nvidia-cuda-dev

echo "✓ Installed NVIDIA drivers and CUDA toolkit"

# === STAGE 5: Configure System for RTX 3090 ===
section "Configuring System for RTX 3090"

# Create NVIDIA configuration directory if it doesn't exist
mkdir -p /etc/nvidia
mkdir -p /etc/X11/xorg.conf.d
mkdir -p /etc/cuda

# Check for restored NVIDIA configuration files
if [[ "${RESTORED_NVIDIA_CONFIGS}" = true ]]; then
    echo "Restoring NVIDIA configurations from backup..."
    
    # Restore NVIDIA configuration file if found in backup
    if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
        # Try to find and restore /etc/nvidia/nvidia-config.conf
        NVIDIA_CONFIG="${GENERAL_CONFIGS_PATH}/etc/nvidia/nvidia-config.conf"
        if [[ -f "${NVIDIA_CONFIG}" ]]; then
            cp "${NVIDIA_CONFIG}" /etc/nvidia/nvidia-config.conf
            echo "✓ Restored NVIDIA configuration from backup"
        fi
        
        # Try to find and restore /etc/X11/xorg.conf.d/10-nvidia.conf
        XORG_NVIDIA="${GENERAL_CONFIGS_PATH}/etc/X11/xorg.conf.d/10-nvidia.conf"
        if [[ -f "${XORG_NVIDIA}" ]]; then
            cp "${XORG_NVIDIA}" /etc/X11/xorg.conf.d/10-nvidia.conf
            echo "✓ Restored X11 NVIDIA configuration from backup"
        fi
        
        # Try to find and restore CUDA configuration
        CUDA_CONF="${GENERAL_CONFIGS_PATH}/etc/cuda/cuda.conf"
        if [[ -f "${CUDA_CONF}" ]]; then
            cp "${CUDA_CONF}" /etc/cuda/cuda.conf
            echo "✓ Restored CUDA configuration from backup"
        fi
        
        # Try to find and restore NVIDIA environment configuration
        NVIDIA_ENV="${GENERAL_CONFIGS_PATH}/etc/profile.d/nvidia-env.sh"
        if [[ -f "${NVIDIA_ENV}" ]]; then
            cp "${NVIDIA_ENV}" /etc/profile.d/nvidia-env.sh
            chmod +x /etc/profile.d/nvidia-env.sh
            echo "✓ Restored NVIDIA environment configuration from backup"
        fi
        
        # Try to find and restore NVIDIA persistence service
        NVIDIA_PERSIST_SVC="${GENERAL_CONFIGS_PATH}/etc/systemd/system/nvidia-persistenced.service"
        if [[ -f "${NVIDIA_PERSIST_SVC}" ]]; then
            cp "${NVIDIA_PERSIST_SVC}" /etc/systemd/system/nvidia-persistenced.service
            echo "✓ Restored NVIDIA persistence service configuration from backup"
        fi
        
        # Try to find and restore NVIDIA persistence mode service
        NVIDIA_PERSIST_MODE="${GENERAL_CONFIGS_PATH}/etc/systemd/system/nvidia-persistence-mode.service"
        if [[ -f "${NVIDIA_PERSIST_MODE}" ]]; then
            cp "${NVIDIA_PERSIST_MODE}" /etc/systemd/system/nvidia-persistence-mode.service
            echo "✓ Restored NVIDIA persistence mode service configuration from backup"
        fi
    fi
fi

# Create a configuration file for NVIDIA GPUs if it doesn't exist
if ! handle_installed_software_config "nvidia" "/etc/nvidia/nvidia-config.conf"; then
    # Create a basic default configuration file
    cat > /etc/nvidia/nvidia-config.conf << EOF
# NVIDIA RTX 3090 Configuration

# Power management settings (for optimal performance)
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp

# Graphics control
options nvidia-drm modeset=1

# CUDA configurations
options nvidia NVreg_EnableGpuFirmware=1
EOF
    
    echo "✓ Created default NVIDIA configuration"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "nvidia" "/etc/nvidia/nvidia-config.conf"
fi

# Add NVIDIA modules to initramfs
{
    echo "nvidia"
    echo "nvidia_drm"
    echo "nvidia_uvm"
    echo "nvidia_modeset"
} >> /etc/modules-load.d/nvidia.conf

# Update initramfs
update-initramfs -u
echo "✓ Configured system for RTX 3090"

# === STAGE 6: Apply Performance Optimizations ===
section "Applying Performance Optimizations for LLM Inference"

# Create a systemd service for NVIDIA persistence mode if it doesn't exist in the repo
if ! handle_installed_software_config "nvidia" "/etc/systemd/system/nvidia-persistenced.service"; then
    # Create a basic default configuration file
    cat > /etc/systemd/system/nvidia-persistenced.service << EOF
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user root --persistence-mode
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced

[Install]
WantedBy=multi-user.target
EOF
    
    echo "✓ Created NVIDIA persistence daemon service"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "nvidia" "/etc/systemd/system/nvidia-persistenced.service"
fi

# Create a configuration file for CUDA-specific settings if it doesn't exist in the repo
if ! handle_installed_software_config "nvidia" "/etc/profile.d/nvidia-env.sh"; then
    # Create a basic default configuration file
    cat > /etc/profile.d/nvidia-env.sh << EOF
# CUDA optimization settings for LLM inference

# Add CUDA to PATH and LD_LIBRARY_PATH
export PATH=\$PATH:/usr/local/c)

# Create CUDA cache directory
mkdir -p /var/cache/cuda
chmod 1777 /var/cache/cuda

# Enable and start NVIDIA persistence service
systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service
echo "✓ Applied performance optimizations for LLM inference"

# === STAGE 7: Restore LLM Optimizations ===
section "Checking for LLM-Specific Optimizations"

# Check for restored LLM optimizations scripts
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    LLM_SCRIPTS_PATH="${GENERAL_CONFIGS_PATH}/bin"
    
    # Check for Ollama optimizer script
    if [[ -f "${LLM_SCRIPTS_PATH}/ollama-optimizer.sh" ]]; then
        echo "Found Ollama optimizer script in backup"
        
        # Create bin directory if it doesn't exist
        mkdir -p "${USER_HOME}/bin"
        
        # Copy script to bin directory
        cp "${LLM_SCRIPTS_PATH}/ollama-optimizer.sh" "${USER_HOME}/bin/"
        chmod +x "${USER_HOME}/bin/ollama-optimizer.sh"
        
        # Set proper ownership
        set_user_ownership "${USER_HOME}/bin/ollama-optimizer.sh"
        
        echo "✓ Restored Ollama optimizer script"
    fi
    
    # Check for RTX 3090 modelfile template
    RTX_MODELFILE="${GENERAL_CONFIGS_PATH}/ollama/rtx3090-modelfile.txt"
    if [[ -f "${RTX_MODELFILE}" ]]; then
        echo "Found RTX 3090 modelfile template in backup"
        
        # Create Ollama directory if it doesn't exist
        mkdir -p "${USER_HOME}/.ollama/modelfiles"
        
mkdir -p "${USER_HOME}/.ollama/modelfiles"
    
    # Create the modelfile with RTX 3090 optimizations
    cat > "${USER_HOME}/.ollama/modelfiles/rtx3090-modelfile.txt" << EOF
# RTX 3090 Optimized Modelfile Template
# Use this as a base for your Ollama models

FROM {{MODEL_NAME}}

# RTX 3090 CUDA optimizations
PARAMETER num_ctx 8192
PARAMETER num_gpu 1
PARAMETER num_thread 8
PARAMETER num_batch 128
PARAMETER use_flash_attn 1
PARAMETER gpu_layers 43

# Memory optimizations for RTX 3090 (24GB VRAM)
PARAMETER f16 true
PARAMETER tensor_split 1
EOF
    
    # Set proper ownership
    set_user_ownership "${USER_HOME}/.ollama"
    
    echo "✓ Created RTX 3090 modelfile template"
fi

       # Copy modelfile template
        cp "${RTX_MODELFILE}" "${USER_HOME}/.ollama/modelfiles/"
        
        # Set proper ownership
        set_user_ownership "${USER_HOME}/.ollama"
        
        echo "✓ Restored RTX 3090 modelfile template"
    fi
fi

# === STAGE 8: Manage NVIDIA Configurations ===
section "Managing NVIDIA Configurations"

# Handle configuration files
handle_installed_software_config "nvidia" "${NVIDIA_CONFIG_FILES[@]}"

# If there's a persistence script in the backup, configure it to run at startup
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    PERSISTENCE_SCRIPT="${GENERAL_CONFIGS_PATH}/bin/nvidia-persistence-mode.sh"
    if [[ -f "${PERSISTENCE_SCRIPT}" ]]; then
        echo "Found NVIDIA persistence script in backup"
        
        # Create script directory if it doesn't exist
        mkdir -p /usr/local/bin
        
        # Copy script
        cp "${PERSISTENCE_SCRIPT}" /usr/local/bin/nvidia-persistence-mode.sh
        chmod +x /usr/local/bin/nvidia-persistence-mode.sh
        
        # Create a systemd service for the script if it doesn't exist
        if [[ ! -f "/etc/systemd/system/nvidia-persistence-mode.service" ]]; then
            cat > "/etc/systemd/system/nvidia-persistence-mode.service" << EOF
[Unit]
Description=NVIDIA Persistence Mode Script
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-persistence-mode.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
            echo "✓ Created NVIDIA persistence mode service"
        fi
        
        systemctl enable nvidia-persistence-mode.service
        echo "✓ Configured persistence mode script to run at startup"
    fi
    
    # Check for LLM optimization script
    LLM_SCRIPT="${GENERAL_CONFIGS_PATH}/nvidia/llm/llm-optimizations.sh"
    if [[ -f "${LLM_SCRIPT}" ]]; then
        echo "Found LLM optimization script in backup"
        
        # Create script directory if it doesn't exist
        mkdir -p /repo/personal/core-configs/nvidia/llm
        
        # Copy script
        cp "${LLM_SCRIPT}" /repo/personal/core-configs/nvidia/llm/llm-optimizations.sh
        chmod +x /repo/personal/core-configs/nvidia/llm/llm-optimizations.sh
        
        # Execute the script
        bash /repo/personal/core-configs/nvidia/llm/llm-optimizations.sh
        echo "✓ Applied LLM-specific optimizations from backup"
    fi
fi

echo "✓ NVIDIA configuration management complete"

# === STAGE 9: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "nvidia" "${NVIDIA_CONFIG_FILES[@]}"

# === STAGE 10: Update System ===
section "Updating System"

# Final update
apt-get update
apt-get upgrade -y

# === STAGE 11: Configure Persistence Mode ===
section "Enabling NVIDIA Persistence Mode"

# Enable GPU persistence mode for improved performance
nvidia-smi -pm 1 || echo "Note: Persistence mode will be enabled after reboot"

section "NVIDIA RTX 3090 Setup Complete!"
echo "NVIDIA drivers and CUDA have been installed and optimized for your RTX 3090."
echo "The system is now configured for optimal LLM inference performance."
echo
echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
echo "  - Any changes to configurations should be made in the repository"
echo
echo "You need to reboot your system to apply all changes."
echo "Command: sudo systemctl reboot"
