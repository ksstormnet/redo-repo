#!/bin/bash

# 03-nvidia-rtx-setup.sh
# This script installs NVIDIA drivers optimized for RTX 3090 and LLM inference
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

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

# Set up pre-installation configurations for NVIDIA
handle_pre_installation_config "nvidia" "${NVIDIA_CONFIG_FILES[@]}"

# === STAGE 2: Remove existing NVIDIA drivers if any ===
section "Checking for Existing NVIDIA Drivers"

# Check if NVIDIA drivers are already installed
if dpkg -l | grep -E "nvidia-driver|nvidia-utils" > /dev/null; then
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

# Create a configuration file for NVIDIA GPUs if it doesn't exist in the repo
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
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "nvidia" "/etc/profile.d/nvidia-env.sh"
fi

# Create CUDA cache directory
mkdir -p /var/cache/cuda
chmod 1777 /var/cache/cuda

# Enable and start NVIDIA persistence service
systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service
echo "✓ Applied performance optimizations for LLM inference"

# === STAGE 7: Manage NVIDIA Configurations ===
section "Managing NVIDIA Configurations"

# Handle configuration files
handle_installed_software_config "nvidia" "${NVIDIA_CONFIG_FILES[@]}"

# If there's a persistence script, configure it to run at startup
if [[ -f "/repo/personal/core-configs/nvidia/scripts/persistence-mode.sh" ]]; then
    echo "Setting up NVIDIA persistence script..."
    ln -sf "/repo/personal/core-configs/nvidia/scripts/persistence-mode.sh" /usr/local/bin/nvidia-persistence-mode.sh
    chmod +x /usr/local/bin/nvidia-persistence-mode.sh
    
    # Create a systemd service for the script if it doesn't exist in the repo
    if ! handle_installed_software_config "nvidia" "/etc/systemd/system/nvidia-persistence-mode.service"; then
        # Create a basic default configuration file
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
        
        # Now move it to the repo and create a symlink
        handle_installed_software_config "nvidia" "/etc/systemd/system/nvidia-persistence-mode.service"
    fi
    
    systemctl enable nvidia-persistence-mode.service
    echo "✓ Configured persistence mode script to run at startup"
fi

# Apply any custom tweaks for optimal LLM performance
if [[ -f "/repo/personal/core-configs/nvidia/llm/llm-optimizations.sh" ]]; then
    echo "Applying LLM-specific optimizations..."
    bash "/repo/personal/core-configs/nvidia/llm/llm-optimizations.sh"
    echo "✓ Applied LLM-specific optimizations"
fi

echo "✓ NVIDIA configuration management complete"

# === STAGE 8: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "nvidia" "${NVIDIA_CONFIG_FILES[@]}"

# === STAGE 9: Update System ===
section "Updating System"

# Final update
apt-get update
apt-get upgrade -y

# === STAGE 10: Configure Persistence Mode ===
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
