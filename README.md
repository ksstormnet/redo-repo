# Kubuntu System Rebuild Project

## Overview

This project provides a complete end-to-end solution for rebuilding a system from Ubuntu Server to a fully configured KDE Plasma desktop environment. It's designed for development work, professional audio production, and local LLM inference, using a modular approach that breaks down the installation process into discrete steps.

The system rebuilds from bare metal to a fully configured KDE Plasma desktop environment with:

- LVM-based storage architecture with mirrored and striped volumes (configured during Ubuntu Server installation)
- Comprehensive backup and restoration of critical configuration files
- Automated installation of development tools, audio software, and specialized applications
- System tuning for real-time audio performance and ML/LLM inference
- Configuration management through a centralized Git repository

## Repository Structure

The repository is organized into several directories:

```
.
├── bare-to-lvm/          # LVM setup scripts for Ubuntu Server installation
├── plans/                # Detailed implementation plans and architecture
├── prep-scripts/         # Preparation and backup scripts
└── scripts/              # Core installation scripts and utilities
    └── post-install/     # Post-installation utilities and configurations
```

## Installation Process

The installation process follows these high-level steps:

1. **Preparation**: Back up critical data and configurations using the prep-scripts
2. **LVM Setup**: Configure disk layout with LVM during Ubuntu Server installation using bare-to-lvm scripts
3. **Core Installation**: Install KDE and core system components using the numbered scripts
4. **Application Setup**: Install development tools, audio software, and specialized applications
5. **System Tuning**: Apply performance optimizations for various workloads

For a complete step-by-step guide to follow during installation, see the [Installation Checklist](CHECKLIST.md).

## Key Components

### LVM Configuration

The system uses Logical Volume Management (LVM) to create a flexible storage architecture with optimized volumes for different workloads:

- Mirrored volumes (RAID1) for critical user data
- Striped volumes (RAID0) for performance-sensitive applications
- Separate volumes for different workloads (development, VMs, LLM models, etc.)

### Configuration Management

All configuration files are managed through a central Git repository at `/repo/personal/core-configs`, which provides:

- Version-controlled configuration files
- Automatic symlink management
- Backup and restore capabilities
- Documentation of configuration changes

### Specialized Configurations

The system includes specialized configurations for:

- Professional audio with PipeWire and real-time kernel optimizations
- NVIDIA RTX optimization for ML/LLM inference
- Development environments for various languages and frameworks
- Browser configurations and workspaces for different tasks

## Using the Master Installer

For most installation scenarios, the master installer script provides the easiest way to execute all required steps:

```bash
sudo ./scripts/master-installer-script.sh
```

This provides a menu-driven interface to run scripts sequentially or selectively, with proper dependency handling and confirmation prompts.

## Directory-Specific Documentation

- [bare-to-lvm/README.md](bare-to-lvm/README.md): Details on LVM setup scripts
- [plans/README.md](plans/README.md): Overview of implementation plans
- [prep-scripts/README.md](prep-scripts/README.md): Guide to preparation scripts
- [scripts/README.md](scripts/README.md): Documentation for installation scripts

## Customization

The modular design makes it easy to customize the installation process:

- Skip certain components by not running specific scripts
- Modify individual scripts to add or remove packages
- Update configuration files in the central repository
- Add new post-installation utilities as needed

---

*For a complete checklist to follow during the installation process, see [CHECKLIST.md](CHECKLIST.md).*
