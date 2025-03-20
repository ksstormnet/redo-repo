#!/bin/bash

# 10-ollama-llm-setup.sh
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
if [[ "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
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

CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | sed 's/,//')
echo "Detected CUDA version: ${CUDA_VERSION}"

# === STAGE 3: Install Ollama ===
section "Installing Ollama for Local LLM Inference"

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
echo "✓ Installed Ollama"

# === STAGE 4: Manage Ollama Configurations ===
section "Managing Ollama Configurations"

# Create the configs directory if it doesn't exist
mkdir -p "/root/.ollama"
mkdir -p "/etc/systemd/system/ollama.service.d"

# Handle configuration files
handle_installed_software_config "ollama" "${OLLAMA_CONFIG_FILES[@]}"

# Create a default override.conf if it doesn't exist in the repo
if [[ ! -f "/repo/personal/core-configs/ollama/override.conf" ]]; then
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
if [[ "${SUDO_USER}" ]]; then
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

# Check for and copy any Modelfiles from local to repo
if [[ -d "${OLLAMA_MODELFILES_DIR}" ]] && [[ -n "$(ls -A "${OLLAMA_MODELFILES_DIR}" 2>/dev/null)" ]]; then
    echo "Checking for local modelfiles to back up to repository..."
    for modelfile in "${OLLAMA_MODELFILES_DIR}"/*; do
        if [[ -f "${modelfile}" ]]; then
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
    MODEL_COUNT=$(grep -v "^#" "${MODELS_REGISTRY}" | grep -cv "^$")
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
        if [[ "${SUDO_USER}" ]]; then
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

# === STAGE 8: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Check for any new configuration files created during installation
check_post_installation_configs "ollama" "${OLLAMA_CONFIG_FILES[@]}"

section "Ollama Installation Complete!"
echo "Ollama has been installed and optimized for your RTX 3090."
echo "Configuration has been saved to your repository."
echo
echo "Model Registry:"
if [[ -f "${MODELS_REGISTRY}" ]]; then
    grep -v "^#" "${MODELS_REGISTRY}" | grep -v "^$" || echo "No models in registry"
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
echo "For more information, visit: https://ollama.com/library"
