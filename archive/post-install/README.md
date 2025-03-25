# Post-Installation Utilities

This directory contains scripts and utilities that are designed to be run after the main installation process is complete. These scripts provide additional configuration and optimization for specific software and hardware components.

## Scripts

### [audacity-config.sh](audacity-config.sh)

- **Purpose**: Configures Audacity for professional audio production
- **Functions**:
  - Sets up optimal audio settings
  - Configures plugins and effects
  - Customizes interface for efficient workflow
- **Usage**: Run after Audacity is installed via the main installation scripts

### [mic-processing.sh](mic-processing.sh)

- **Purpose**: Sets up microphone processing for the Vocaster 1 USB microphone
- **Functions**:
  - Configures PipeWire filters for level boosting
  - Sets up noise reduction and EQ
  - Creates persistent configuration
- **Usage**: Run after audio system is configured

### [ollama-optimizer.sh](ollama-optimizer.sh)

- **Purpose**: Optimizes Ollama for RTX 3090 GPU
- **Functions**:
  - Configures CUDA settings for optimal performance
  - Sets up memory allocation for large models
  - Optimizes inference parameters
- **Usage**: Run after Ollama is installed and basic models are downloaded

### [realtime-audio-setup.sh](realtime-audio-setup.sh)

- **Purpose**: Configures system for real-time audio processing
- **Functions**:
  - Sets up real-time kernel parameters
  - Configures CPU governor for audio workloads
  - Optimizes IRQ priorities
  - Sets up JACK/PipeWire integration
- **Usage**: Run after audio system is installed and tested

### [virtualbox-audio-bridge.sh](virtualbox-audio-bridge.sh)

- **Purpose**: Sets up audio routing between host and VirtualBox VMs
- **Functions**:
  - Configures virtual audio devices
  - Sets up PipeWire loopback modules
  - Creates persistent configuration
- **Usage**: Run after VirtualBox is installed and configured

### [rtx3090-modelfile.txt](rtx3090-modelfile.txt)

- **Purpose**: Configuration file for RTX 3090 GPU optimization
- **Content**: Contains parameters and settings for CUDA optimization
- **Usage**: Referenced by the ollama-optimizer.sh script

## Usage Notes

- These scripts should be run after the main installation process is complete
- Some scripts require root privileges and should be run with `sudo`
- Scripts can be run individually as needed, or sequentially for a complete setup
- Each script creates appropriate log files in `/var/log/kde-installer/post-install/`

## Customization

These post-installation scripts can be customized by editing:

- Configuration parameters at the beginning of each script
- Specific paths and settings to match your hardware
- Processing parameters for audio and GPU optimization

## Dependencies

These scripts depend on the successful completion of the main installation scripts, particularly:

- Audio system setup (02-audio-system-setup.sh)
- NVIDIA RTX setup (03-nvidia-rtx-setup.sh)
- Specialized software installation (09-specialized-software.sh)
- Ollama LLM setup (11-ollama-llm-setup.sh)

---

*Back to [Main README](../../README.md) | Previous: [Scripts](../README.md)*
