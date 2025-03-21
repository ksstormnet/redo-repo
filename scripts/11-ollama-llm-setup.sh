#!/bin/bash

# 11-ollama-llm-setup.sh
# This script installs Ollama for local LLM inference optimized for RTX 3090
# Part of the sequential Ubuntu Server to KDE conversion process

# Exit on any error
set -e

# Source the configuration management functions
# shellcheck disable=SC1090
if [[ -n "${CONFIG_FUNCTIONS_PATH}" ]] && [[ -f "${CONFIG_FUNCTIONS_PATH}" ]]; then
    source "${CONFIG_FUNCTIONS_PATH}"
else
    echo "ERROR: Configuration management functions not found."
    echo "Please ensure the CONFIG_FUNCTIONS_PATH environment variable is set correctly."
    exit 1
fi

# Source the backup configuration mapping if available
if [[ -n "${CONFIG_MAPPING_FILE}" ]] && [[ -f "${CONFIG_MAPPING_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING_FILE}"
    echo "✓ Loaded configuration mapping from ${CONFIG_MAPPING_FILE}"
else
    echo "Note: Configuration mapping file not found or not specified."
    echo "Will continue with default configuration locations."
fi

# Display a section header
section() {
    echo
    echo "========================================================"
    echo "  ${1}"
    echo "========================================================"
    echo
}

# Function to install packages with progress indication
install_packages() {
    local description="${1}"
    shift
    
    echo "Installing: ${description}..."
    apt-get install -y "$@"
    echo "✓ Completed: ${description}"
}

# Determine user home directory
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    # shellcheck disable=SC2034
    USER_HOME="${HOME}" # Used for configuration paths
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Define configuration files for Ollama
OLLAMA_CONFIG_FILES=(
    "/root/.ollama/ollama.json"
    "/etc/systemd/system/ollama.service.d/override.conf"
)

# Define modelfiles directory
OLLAMA_MODELFILES_DIR="/root/.ollama/modelfiles"
MODELS_REGISTRY="/repo/personal/core-configs/ollama/models.txt"

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Define backup paths based on the configuration mapping
OLLAMA_BACKUP_DIR=""
# This variable is defined for consistency but not currently used
# shellcheck disable=SC2034
OLLAMA_MODEL_BACKUP_DIR=""
RTX_MODELFILE=""

# Check if we have backup configs from general configs path
if [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    if [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.ollama" ]]; then
        OLLAMA_BACKUP_DIR="${GENERAL_CONFIGS_PATH}/config_files/.ollama"
    elif [[ -d "${GENERAL_CONFIGS_PATH}/config_files/.config/ollama" ]]; then
        OLLAMA_BACKUP_DIR="${GENERAL_CONFIGS_PATH}/config_files/.config/ollama"
    fi
fi

# If no general configs path, try other locations
if [[ -z "${OLLAMA_BACKUP_DIR}" ]] && [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for Ollama config in various potential locations
    for potential_dir in \
        "${BACKUP_CONFIGS_PATH}/configs/ollama" \
        "${BACKUP_CONFIGS_PATH}/ollama" \
        "${BACKUP_CONFIGS_PATH}/configs/config_files/.ollama"; do
        if [[ -d "${potential_dir}" ]]; then
            OLLAMA_BACKUP_DIR="${potential_dir}"
            break
        fi
    done
fi

# Look for RTX model file in backup
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for model file in various potential locations
    for potential_file in \
        "${BACKUP_CONFIGS_PATH}/rtx3090-modelfile.txt" \
        "${BACKUP_CONFIGS_PATH}/ollama/rtx3090-modelfile.txt" \
        "${BACKUP_CONFIGS_PATH}/configs/ollama/rtx3090-modelfile.txt"; do
        if [[ -f "${potential_file}" ]]; then
            RTX_MODELFILE="${potential_file}"
            break
        fi
    done
fi

# Look for Ollama optimizer script in backup
OLLAMA_OPTIMIZER=""
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    # Look for optimizer script in various potential locations
    for potential_file in \
        "${BACKUP_CONFIGS_PATH}/ollama-optimizer.sh" \
        "${BACKUP_CONFIGS_PATH}/ollama/ollama-optimizer.sh" \
        "${BACKUP_CONFIGS_PATH}/configs/ollama/ollama-optimizer.sh"; do
        if [[ -f "${potential_file}" ]]; then
            OLLAMA_OPTIMIZER="${potential_file}"
            break
        fi
    done
fi

# Set up pre-installation configurations for Ollama
handle_pre_installation_config "ollama" "${OLLAMA_CONFIG_FILES[@]}"

# === STAGE 2: Check NVIDIA Drivers ===
section "Checking NVIDIA Drivers for LLM Compatibility"

# Check if NVIDIA drivers are installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA drivers are not installed or not properly configured."
    echo "Please install NVIDIA drivers first using the 03-nvidia-rtx-setup.sh script."
    exit 1
fi

# Check NVIDIA driver version
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
echo "Detected NVIDIA driver version: ${DRIVER_VERSION}"

# Verify CUDA is available
if ! command -v nvcc &> /dev/null; then
    echo "Installing CUDA development tools..."
    install_packages "CUDA Development Tools" nvidia-cuda-toolkit
fi

CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | sed 's/,//') || true
echo "Detected CUDA version: ${CUDA_VERSION}"

# === STAGE 3: Install Ollama ===
section "Installing Ollama for Local LLM Inference"

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh || true
echo "✓ Installed Ollama"

# === STAGE 4: Manage Ollama Configurations ===
section "Managing Ollama Configurations"

# Create the configs directory if it doesn't exist
mkdir -p "/root/.ollama"
mkdir -p "/etc/systemd/system/ollama.service.d"

# Restore Ollama config from backup if available
if [[ -n "${OLLAMA_BACKUP_DIR}" ]] && [[ -f "${OLLAMA_BACKUP_DIR}/ollama.json" ]]; then
    echo "Restoring Ollama configuration from backup..."
    cp "${OLLAMA_BACKUP_DIR}/ollama.json" "/root/.ollama/"
    echo "✓ Restored Ollama configuration from backup"
fi

# Handle configuration files
handle_installed_software_config "ollama" "${OLLAMA_CONFIG_FILES[@]}"

# Create a default override.conf if it doesn't exist in the repo and backup
if [[ ! -f "/repo/personal/core-configs/ollama/override.conf" ]] && [[ ! -f "/etc/systemd/system/ollama.service.d/override.conf" ]]; then
    # Create Ollama GPU optimization override
    cat > "/etc/systemd/system/ollama.service.d/override.conf" << EOF
[Service]
Environment="OLLAMA_CUDA_MALLOC=arena"
Environment="OLLAMA_CUDA_MEMORY_FRACTION=0.9"
Environment="OLLAMA_MODEL_PATH=/opt/models"
EOF
    echo "✓ Created default optimization configuration"
    
    # Now move it to the repo and create a symlink
    handle_installed_software_config "ollama" "/etc/systemd/system/ollama.service.d/override.conf"
fi

# Create models directory if it doesn't exist
mkdir -p /opt/models

# Set proper ownership
if [[ -n "${SUDO_USER}" ]]; then
    chown -R "${SUDO_USER}":"${SUDO_USER}" /opt/models
    # If running as sudo, also set ownership for config files
    if [[ -d "/root/.ollama" ]]; then
        chown -R "${SUDO_USER}":"${SUDO_USER}" "/root/.ollama"
    fi
fi

echo "✓ Created models directory at /opt/models"

# Reload systemd configuration
systemctl daemon-reload

# Restart Ollama service
systemctl restart ollama
echo "✓ Restarted Ollama with optimized configuration"

# === STAGE 5: Manage Modelfiles ===
section "Managing Ollama Modelfiles"

# Create modelfiles directory if it doesn't exist
mkdir -p "${OLLAMA_MODELFILES_DIR}"

# Copy RTX model file if available
if [[ -n "${RTX_MODELFILE}" ]]; then
    echo "Found RTX 3090 modelfile, copying to Ollama modelfiles directory..."
    cp "${RTX_MODELFILE}" "${OLLAMA_MODELFILES_DIR}/rtx3090.txt"
    echo "✓ Copied RTX 3090 modelfile"
fi

# Check for and copy any Modelfiles from local to repo
if [[ -d "${OLLAMA_MODELFILES_DIR}" ]] && [[ -n "$(ls -A "${OLLAMA_MODELFILES_DIR}" 2>/dev/null || true)" ]]; then
    echo "Checking for local modelfiles to back up to repository..."
    for modelfile in "${OLLAMA_MODELFILES_DIR}"/*; do
        if [[ -f "${modelfile}" ]]; then
            # Variable used for logging or future expansion
            # shellcheck disable=SC2034
            modelname=$(basename "${modelfile}")
            handle_installed_software_config "ollama/modelfiles" "${modelfile}"
        fi
    done
fi

# Create a default model registry if it doesn't exist
if [[ ! -f "${MODELS_REGISTRY}" ]]; then
    echo "Creating default model registry..."
    mkdir -p "$(dirname "${MODELS_REGISTRY}")"
    cat > "${MODELS_REGISTRY}" << EOF
# Ollama Model Registry
# List the models you want to automatically pull during setup, one per line
# Lines starting with # are comments and will be ignored

# Example models:
# llama3
# mistral
# mixtral
# gemma
EOF
    echo "✓ Created default model registry template"
    
    # Commit the model registry to the repository
    (cd "/repo/personal/core-configs" && git add "ollama/models.txt" && git commit -m "Add Ollama model registry")
else
    echo "Found existing model registry in repository"
    cat "${MODELS_REGISTRY}"
fi

# === STAGE 6: Test Ollama ===
section "Testing Ollama Installation"

# Check if Ollama service is running
if systemctl is-active --quiet ollama; then
    echo "✓ Ollama service is running"
else
    echo "Ollama service is not running. Starting now..."
    systemctl start ollama
    
    # Check again
    if systemctl is-active --quiet ollama; then
        echo "✓ Ollama service is now running"
    else
        echo "Failed to start Ollama service. Please check the logs: journalctl -u ollama"
    fi
fi

# === STAGE 7: Pull Models (if specified) ===
section "Processing Model Registry"

# Check if we have a model registry list
if [[ -f "${MODELS_REGISTRY}" ]]; then
    echo "Processing model registry list..."
    
    # Count the number of models
    MODEL_COUNT=$(grep -v "^#" "${MODELS_REGISTRY}" | grep -cv "^$") || true
    echo "Found ${MODEL_COUNT} models to pull"
    
    # Pull each model in the list
    COUNT=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comments and empty lines
        if [[ "${line}" =~ ^# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        COUNT=$((COUNT + 1))
        echo "[${COUNT}/${MODEL_COUNT}] Pulling model: ${line}"
        
        # If running with sudo, run the ollama command as the actual user
        if [[ -n "${SUDO_USER}" ]]; then
            su - "${SUDO_USER}" -c "ollama pull \"${line}\""
        else
            ollama pull "${line}"
        fi
        
        echo "✓ Pulled model: ${line}"
    done < "${MODELS_REGISTRY}"
    
    echo "✓ Completed pulling ${COUNT} models"
else
    echo "No model registry list found. Skipping model pull."
    echo "You can manually pull models using: ollama pull <model_name>"
fi

# === STAGE 8: Apply Optimizer Script if available ===
section "Applying RTX 3090 Optimizations"

if [[ -n "${OLLAMA_OPTIMIZER}" ]]; then
    echo "Found Ollama optimizer script for RTX 3090..."
    echo "Executing optimizer script..."
    chmod +x "${OLLAMA_OPTIMIZER}"
    bash "${OLLAMA_OPTIMIZER}"
    echo "✓ Applied RTX 3090 optimizations from script"
    
    # Copy script to /usr/local/bin for future use
    cp "${OLLAMA_OPTIMIZER}" /usr/local/bin/ollama-optimizer.sh
    chmod +x /usr/local/bin/ollama-optimizer.sh
    echo "✓ Installed optimizer script to /usr/local/bin/ollama-optimizer.sh"
else
    echo "No optimizer script found, applying default optimizations..."
    
    # Apply some basic optimizations for RTX 3090
    echo "Setting NVIDIA GPU to persistence mode..."
    nvidia-smi -pm 1
    
    echo "Setting optimal clocks for LLM inference..."
    nvidia-smi -ac 1395,1695
    
    echo "Setting CPU governor to performance mode..."
    # Check if cpufreq is available
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" > "${cpu}"
        done
        echo "✓ CPU governor set to performance"
    else
        echo "CPU governor settings not available"
    fi
    
    echo "✓ Applied basic RTX 3090 optimizations"
fi

# === STAGE 9: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "ollama" "${OLLAMA_CONFIG_FILES[@]}"

section "Ollama Installation Complete!"
echo "Ollama has been installed and optimized for your RTX 3090."
echo "Configuration has been saved to your repository."
echo
echo "Model Registry:"
if [[ -f "${MODELS_REGISTRY}" ]]; then
    grep -v "^#" "${MODELS_REGISTRY}" | grep -v "^$" || echo "No models in registry" || true
else
    echo "No model registry found."
fi
echo
echo "To pull a model manually, use: ollama pull <model_name>"
echo "Example models to try:"
echo "  - mistral (ollama pull mistral)"
echo "  - llama3 (ollama pull llama3)"
echo "  - mixtral (ollama pull mixtral)"
echo "  - gemma (ollama pull gemma)"
echo
echo "Models are stored in /opt/models"
echo 
echo "To run a model, use: ollama run <model_name>"
echo
if [[ -n "${RTX_MODELFILE}" ]]; then
    echo "Your RTX 3090 modelfile is available. To create an optimized model:"
    echo "ollama create rtx-llama3 -f /root/.ollama/modelfiles/rtx3090.txt"
    echo
fi
echo "For more information, visit: https://ollama.com/library"
echo
if [[ -n "${BACKUP_CONFIGS_PATH}" ]]; then
    echo "Configurations were restored from your backups at: ${BACKUP_CONFIGS_PATH}"
fi
