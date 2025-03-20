 Server to KDE Modular Installation Scripts

## Overview
This set of scripts provides a modular approach to installing KDE Plasma over Ubuntu Server with a focus on development work, local LLM inference with an RTX 3090, and professional audio capabilities. Each script handles a specific aspect of the system configuration, allowing for easier maintenance, troubleshooting, and customization.

## Script Sequence

### 0. Master Installer (`00-master-installer.sh`)
- Provides a menu-driven interface to run all scripts
- Allows for selective installation of components
- Offers preset installation profiles (full, core, developer)
- Handles script sequencing and reboot prompts

### 1. Core System Setup (`01-core-system-setup.sh`)
- Installs essential system utilities and tools
- Sets up base system components and performance tools
- Configures LVM tools and low-latency kernel

### 2. Audio System Setup (`02-audio-system-setup.sh`)
- Installs PipeWire audio system (modern replacement for PulseAudio)
- Configures audio utilities and real-time privileges
- Sets up IRQ priorities for optimal audio performance

### 3. NVIDIA RTX Setup (`03-nvidia-rtx-setup.sh`)
- Installs optimized NVIDIA drivers for RTX 3090
- Sets up CUDA and ML support
- Configures persistence mode and optimizations for LLM inference

### 4. KDE Desktop Installation (`04-kde-desktop-install.sh`)
- Installs KDE Plasma desktop environment
- Configures desktop settings and removes unwanted applications
- Sets up additional KDE applications and customizations

### 5. Development Tools Setup (`05-development-tools-setup.sh`)
- Installs a lightweight set of development tools for WordPress plugin development
- Sets up PHP 8.4 with necessary extensions
- Configures Node.js, Docker, and other essential development components

### 6. Code Editors Setup (`06-code-editors-setup.sh`)
- Installs VS Code and Zed Editor
- Sets up additional text editors (Vim, Kate)
- Configures editor settings

### 7. ZSH Shell Setup (`07-zsh-shell-setup.sh`)
- Installs ZSH with plugins and Starship prompt
- Configures ZSH as the default shell
- Sets up essential terminal utilities

### 8. Specialized Software (`08-specialized-software.sh`)
- Installs audio production software
- Sets up virtualization with VirtualBox
- Configures graphics, design, office, and productivity tools

### 9. Browsers Setup (`09-browsers-setup.sh`)
- Installs Brave Browser, Microsoft Edge, and Firefox
- Provides information about Zen Browser (manual installation)

### 10. Ollama LLM Setup (`10-ollama-llm-setup.sh`)
- Installs Ollama for local LLM inference
- Optimizes configuration for RTX 3090
- Sets up model directory and tests the installation

### 11. Email Client Setup (`11-email-client-setup.sh`)
- Installs Mailspring email client
- Configures KDE integration

### 12. Terminal Enhancements (`12-terminal-enhancements.sh`)
- Installs additional terminal utilities
- Sets up monitoring and system management tools
- Configures Tmux with sensible defaults

### 13. AppImage Setup (`13-appimage-setup.sh`)
- Sets up AppImage support
- Creates directory structure and helper scripts
- Downloads and configures various AppImage applications

### 14. KDE Settings Configuration (`14-kde-settings-configuration.sh`)
- Configures additional KDE settings
- Sets up Meta key shortcuts
- Optimizes KDE rendering performance with OpenGL

### 15. Configuration Backups (`15-configuration-backups.sh`)
- Creates directory structure for configuration backups
- Sets up documentation for backup/restore processes
- Prepares the system for user configuration management

### 16. Final Cleanup (`16-final-cleanup.sh`)
- Removes unnecessary packages and dependencies
- Cleans package and system caches
- Creates an installation summary document
- Performs final system optimizations

## Usage

You have two options for running these scripts:

### Option 1: Menu-Driven Installation

Run the master script for a guided, interactive installation:

```bash
sudo bash 00-master-installer.sh
```

This provides a menu with several options:
- Install individual components
- Install all components sequentially
- Install just the core components (1-4)
- Install the developer toolkit (1-7)

### Option 2: Manual Installation

Each script can be run independently:

```bash
sudo bash 01-core-system-setup.sh
sudo bash 02-audio-system-setup.sh
# ... and so on
```

A reboot is recommended after scripts 1-4 and again after all scripts are completed.

## Customization

These scripts are designed to be modular, making it easy to:
- Skip certain components by not running specific scripts
- Modify individual scripts to add or remove packages as needed
- Change configuration settings within each domain

## Requirements

- A clean Ubuntu Server installation
- Internet connection for package downloads
- RTX 3090 GPU (for optimal LLM performance)
- Sufficient disk space (at least 50GB recommended)

## Post-Installation

After running all scripts, you'll have a fully configured KDE desktop environment with:
- Development tools ready for WordPress plugin development
- Docker set up for containerized services
- Optimized GPU drivers for AI/ML workloads
- Professional audio capabilities with low-latency performance
- A comprehensive set of applications for productivity and creativity
- Configuration backup directories for storing your settings
- A detailed installation summary for future reference
