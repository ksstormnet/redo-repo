# Installation Scripts

This directory contains the core scripts for installing and configuring the Kubuntu system. These scripts follow a modular design, with each script handling a specific aspect of the system setup.

## Master Installer

### [master-installer-script.sh](master-installer-script.sh)

- **Purpose**: Manages the execution of all installation scripts in the correct sequence
- **Features**:
  - Menu-driven interface for selecting which scripts to run
  - Progress tracking with completion flags
  - Automatic restoration of critical backups
  - Managed reboots at appropriate points
  - Error handling and recovery options
- **Usage**: `sudo ./master-installer-script.sh`

## Configuration Management

### [config-management-functions.sh](config-management-functions.sh)

- **Purpose**: Provides centralized functions for managing configuration files
- **Features**:
  - Handles symlinks between original locations and Git repository
  - Manages pre-installation and post-installation configurations
  - Automatically commits changes to the configuration repository
  - Provides consistent interface for all scripts
- **Documentation**: [README-config-management.md](README-config-management.md)

### [restore-critical-backups.sh](restore-critical-backups.sh)

- **Purpose**: Extracts and prepares backup files for use by installation scripts
- **Features**:
  - Extracts archives from `/restart/prep/backups`
  - Creates a configuration mapping file for other scripts
  - Sets up directories and symlinks for easy access to configurations
  - Provides validation of extracted configurations
- **Usage**: Run before other installation scripts or via master installer

## Sequential Installation Scripts

### Core System Setup

#### [00-initial-setup.sh](00-initial-setup.sh)

- **Purpose**: Prepares the system for installation and sets up core directories
- **Key Actions**: Updates package lists, installs dependencies, creates function libraries, restores Git configuration

#### [01-core-system-setup.sh](01-core-system-setup.sh)

- **Purpose**: Installs essential system components and base utilities
- **Key Actions**: Installs system utilities, configures LVM tools, sets up user profile

#### [02-audio-system-setup.sh](02-audio-system-setup.sh)

- **Purpose**: Configures PipeWire audio system with optimizations for professional audio
- **Key Actions**: Installs PipeWire, sets up real-time privileges, configures RTIRQ

#### [03-nvidia-rtx-setup.sh](03-nvidia-rtx-setup.sh)

- **Purpose**: Installs NVIDIA drivers optimized for RTX 3090 and ML/LLM inference
- **Key Actions**: Sets up CUDA, configures persistence mode, applies optimizations for LLM inference

#### [04-kde-desktop-install.sh](04-kde-desktop-install.sh)

- **Purpose**: Installs KDE Plasma desktop environment with optimized settings
- **Key Actions**: Installs Kubuntu desktop, removes unwanted applications, restores KDE configurations

### Development Environment

#### [05-development-tools-setup.sh](05-development-tools-setup.sh)

- **Purpose**: Sets up development tools for various programming languages
- **Key Actions**: Installs PHP, Node.js, Docker, and development utilities

#### [06-global-dev-packages.sh](06-global-dev-packages.sh)

- **Purpose**: Installs global development packages for Node.js and PHP
- **Key Actions**: Sets up global packages, linters, formatters, and development utilities

#### [07-code-editors-setup.sh](07-code-editors-setup.sh)

- **Purpose**: Installs and configures code editors
- **Key Actions**: Sets up VS Code, Zed, Kate, and terminal editors

#### [08-zsh-shell-setup.sh](08-zsh-shell-setup.sh)

- **Purpose**: Configures ZSH shell with plugins and enhancements
- **Key Actions**: Installs ZSH, sets up Starship prompt, configures shell utilities

### Application Installation

#### [09-specialized-software.sh](09-specialized-software.sh)

- **Purpose**: Installs specialized software for various tasks
- **Key Actions**: Sets up audio production, graphics, design, and productivity software

#### [10-browsers-setup.sh](10-browsers-setup.sh)

- **Purpose**: Installs and configures web browsers
- **Key Actions**: Sets up Brave, Edge, Firefox, and profile management

#### [11-ollama-llm-setup.sh](11-ollama-llm-setup.sh)

- **Purpose**: Installs Ollama for local LLM inference with RTX 3090 optimizations
- **Key Actions**: Configures models directory, optimizes for GPU, pulls models

#### [12-email-client-setup.sh](12-email-client-setup.sh)

- **Purpose**: Sets up Mailspring email client
- **Key Actions**: Installs Mailspring and restores configurations

#### [13-terminal-enhancements.sh](13-terminal-enhancements.sh)

- **Purpose**: Installs additional terminal utilities and enhancements
- **Key Actions**: Sets up monitoring tools, file managers, and system utilities

#### [14-appimage-setup.sh](14-appimage-setup.sh)

- **Purpose**: Configures AppImage support and management
- **Key Actions**: Creates directories and helper scripts, downloads common AppImages

### Final Configuration

#### [15-kde-settings-configuration.sh](15-kde-settings-configuration.sh)

- **Purpose**: Applies additional KDE settings and customizations
- **Key Actions**: Configures keyboard, power management, and file manager settings

#### [16-configuration-backups.sh](16-configuration-backups.sh)

- **Purpose**: Sets up an integrated configuration management strategy
- **Key Actions**: Creates backup directories, syncs with Git repository, documents configurations

#### [17-final-cleanup.sh](17-final-cleanup.sh)

- **Purpose**: Performs system cleanup and generates installation summary
- **Key Actions**: Removes unnecessary packages, cleans caches, creates summary document

#### [18-system-tuning-tweaks.sh](18-system-tuning-tweaks.sh)

- **Purpose**: Applies advanced system tuning for optimal performance
- **Key Actions**: Configures kernel parameters, I/O schedulers, and system optimizations

#### [19-networking-tweaks.sh](19-networking-tweaks.sh)

- **Purpose**: Sets up networking enhancements and configurations
- **Key Actions**: Configures SMB/CIFS, DNS, browser settings, and network optimizations

## Post-Installation Utilities

See [post-install/README.md](post-install/README.md) for details on post-installation utilities and configurations.

## Usage Notes

- Scripts should be run in the numbered sequence, as many have dependencies on earlier scripts
- Most scripts require root privileges and should be run with `sudo`
- The master installer is the recommended way to run these scripts
- Scripts can be customized by editing variables at the beginning of each file
- Each script creates appropriate log files in `/var/log/kde-installer/`

---

*Back to [Main README](../README.md) | Previous: [LVM Setup](../bare-to-lvm/README.md) | Next: [Post-Install Utilities](post-install/README.md)*
