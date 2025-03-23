#!/bin/bash

# 03-nvidia-rtx-setup.sh
# This script installs NVIDIA drivers optimized for RTX 3090 and LLM inference
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

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
    nvidia-driver-535 \
    nvidia-utils-535 \
    libnvidia-common-535 \
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

# Create a configuration file for NVIDIA GPUs if it doesn't exist
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

# Create a configuration file for CUDA-specific settings if it doesn't exist in the repo
cat > /etc/profile.d/nvidia-env.sh << EOF
# CUDA optimization settings for LLM inference

# Add CUDA to PATH and LD_LIBRARY_PATH
export PATH=\$PATH:/usr/local/cuda/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64

# Optimize memory allocation for LLMs
export CUDA_MALLOC_CONFIG=arena
export CUDA_VISIBLE_DEVICES=0

# Optimize JIT compilation
export CUDA_CACHE_DISABLE=0
export CUDA_CACHE_MAXSIZE=2147483648  # 2GB cache
export CUDA_CACHE_PATH=/var/cache/cuda
EOF

echo "✓ Created CUDA optimization settings"

export PATH=\$PATH:/usr/local/c)

# Create CUDA cache directory
mkdir -p /var/cache/cuda
chmod 1777 /var/cache/cuda

# Enable and start NVIDIA persistence service
systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service
echo "✓ Applied performance optimizations for LLM inference"

# Create Ollama directory if it doesn't exist
mkdir -p "${USER_HOME}/.ollama/modelfiles"

# Copy modelfile template
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


# Set proper ownership
set_user_ownership "${USER_HOME}/.ollama"

echo "✓ Restored RTX 3090 modelfile template"
=======
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
>>>>>>> 870c0312fa26cdc411d21469eca956a0e824e7f6

# === STAGE 8: Manage NVIDIA Configurations ===
section "Managing NVIDIA Configurations"

cat > /etc/systemd/system/nvidia-persistence-mode.service << EOF
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

systemctl enable nvidia-persistence-mode.service
echo "✓ Configured persistence mode script to run at startup"



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
