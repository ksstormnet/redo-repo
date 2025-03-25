# Revised Comprehensive File Cleanup and Migration Plan

## Overview
This plan outlines the revised approach for migrating to a new system with optimized storage, organization, and software configuration. It incorporates LVM setup, configuration backup/restoration, and a modified file deduplication strategy.

## Phase 1: Pre-Migration Analysis and Preparation (Before Hardware Update)

### 1.1 Analysis and Inventory
- Create working environment in `/restart/prep/`
- Analyze current system state (installed packages, hidden directories)
- Scan for large files and identify duplicates
- Review and categorize results by importance (keep, archive, delete)

### 1.2 Configuration Backup
- Back up critical configuration files to `/restart/prep/configs/config-backup/`
- Export application settings from browsers, code editors, development tools
- Create an inventory of configurations for later restoration
- *Refer to Configuration Backup README for detailed process*

### 1.3 Initial File Organization
- Begin organizing files by type and importance
- Perform initial deduplication of non-recovery directories
- Prepare file sets for migration
- *Refer to File Migration System README for detailed process*

## Phase 2: LVM Setup and Base System Installation (During Hardware Update)

### 2.1 Hardware Preparation
- Install new hardware components
- Boot from Ubuntu Server installation media
- Mount flash drive with installation scripts at `/mnt/scott/Restart-Critical`

### 2.2 LVM Configuration 
- Run LVM preparation scripts from flash drive:
  - Clear existing drive signatures (00-lvm-prepare.sh)
  - Create physical volumes and volume group (01-lvm-setup.sh)
  - Create logical volumes with appropriate RAID levels (02-lvm-logical-volumes.sh)
- *Refer to LVM Setup README for detailed process*

### 2.3 Ubuntu Server Installation
- Install Ubuntu Server 24.04 with minimal configuration
- Configure the system to use the LVM volumes
- Set up mount points according to plan (03-lvm-mount-config.sh)

### 2.4 Post-Installation LVM Setup
- After first boot, finalize LVM configuration (04-lvm-post-install.sh)
- Mount the data backup drive at `/restart` 
- Verify all logical volumes are properly mounted and accessible

## Phase A: Sequential System Installation with Configuration Restoration

### A.1 Initial Setup
- Run 00-initial-setup.sh to prepare system environment
- Restore system-level configurations 
- Create common function libraries

### A.2 Core System Setup
- Install core system components (01-core-system-setup.sh)
- Restore user profile basics and git configurations
- Configure LVM tools and system performance settings

### A.3 Audio System Setup
- Configure professional audio system with PipeWire (02-audio-system-setup.sh)
- Restore audio configurations and settings
- Set up real-time audio privileges

### A.4 KDE Desktop Installation
- Install KDE Plasma desktop environment (04-kde-desktop-install.sh)
- Restore KDE themes, panel layouts, and desktop settings
- Configure additional KDE applications

### A.5 Development Tools Setup
- Install development tools for various programming languages (05-development-tools-setup.sh)
- Restore development environment configurations
- Set up Docker, PHP, Node.js, and other development components

### A.6 Additional Software Installation
- Install code editors with configuration restoration (06-code-editors-setup.sh)
- Set up ZSH shell and terminal enhancements (07-zsh-shell-setup.sh, 12-terminal-enhancements.sh)
- Install browsers and restore profiles (09-browsers-setup.sh)
- Configure email client with restored settings (11-email-client-setup.sh)
- Set up specialized software and AppImage support (08-specialized-software.sh, 13-appimage-setup.sh)

### A.7 Final Configuration
- Apply additional KDE settings and customizations (14-kde-settings-configuration.sh)
- Create configuration backup structure for future use (15-configuration-backups.sh)
- Perform final system cleanup and optimization (16-final-cleanup.sh)

## Phase 4: Data Migration and Organization

### 4.1 File Migration Execution
- Execute the file migration plan using the prepared scripts
- Move files to their designated locations in the new directory structure
- *Refer to File Migration System README for detailed process*

### 4.2 Post-Migration Deduplication
- Perform deduplication on known duplicate-heavy directories
- Process recovery folders to identify and integrate unique files
- Verify migration integrity with checksums

### 4.3 Final Organization and Classification
- Implement the new flat directory structure
- Organize files according to content type and use case
- Create documentation for the new organization system

## Phase 5: Verification and Documentation

### 5.1 System Verification
- Verify all software is installed and configured correctly
- Check that all configurations have been properly restored
- Test critical system functions (audio, development, virtualization)

### 5.2 Data Verification
- Generate file manifests for all major directories
- Verify critical files exist in the new structure
- Perform final size and integrity checks

### 5.3 Final Documentation
- Document the new system configuration
- Create a directory structure map
- List all installed software with versions
- Document any manual steps required for specific tools

### 5.4 Future Maintenance Plan
- Establish backup routines for the new system
- Create maintenance schedule for package updates
- Document procedures for future system changes

## Conclusion
This revised plan integrates hardware updates, LVM setup, software installation, configuration restoration, and file migration into a comprehensive process. The sequential approach ensures each component is properly configured before moving to the next, with configuration restoration integrated at the appropriate points.

---

**Note:** Throughout this document, references to READMEs indicate separate, detailed documentation for specific processes. These should be linked in the final documentation structure.
