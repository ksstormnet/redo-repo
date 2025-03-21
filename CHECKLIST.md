# Kubuntu System Rebuild Checklist

This checklist guides you through the complete system rebuild process from backup to a fully configured KDE Plasma desktop with optimized configurations.

## Initial Preparation

- [X] Connect external backup drive to current system
- [X] Run backup preparation script: `./prep-scripts/backup_critical_data.sh`
- [ ] Verify backup completion and integrity in `/restart/prep/backups`
- [X] Download Ubuntu Server 24.04 ISO
- [X] Create bootable USB installation media
- [ ] Copy scripts directory to a separate USB drive
- [ ] Shutdown current system

## Hardware Setup

- [ ] Connect both USB drives (installation media and scripts)
- [ ] Boot from Ubuntu Server installation USB
- [ ] Select "Try Ubuntu Server" option to access live environment

## LVM Setup During Ubuntu Server Installation

- [ ] Start the Ubuntu Server installation process
- [ ] When you reach the storage configuration step, press Ctrl+Alt+F2 to access a terminal
- [ ] Login with username "ubuntu" (no password required)
- [ ] Mount scripts USB: `sudo mkdir -p /mnt/usb && sudo mount /dev/sdX1 /mnt/usb` (replace sdX1 with your USB device)
- [ ] Navigate to scripts: `cd /mnt/usb/bare-to-lvm`
- [ ] Make scripts executable: `chmod +x *.sh`
- [ ] Run LVM preparation script: `sudo ./00-lvm-prepare.sh`
- [ ] Run LVM volume group setup: `sudo ./01-lvm-setup.sh`
- [ ] Run LVM logical volumes setup: `sudo ./02-lvm-logical-volumes.sh`
- [ ] Return to installer with Ctrl+Alt+F1

## Base System Installation

- [ ] In the installer, select "Manual" partitioning
- [ ] Set up EFI partition on SSD
- [ ] Set up root partition on SSD
- [ ] Complete installation up to reboot prompt
- [ ] Cancel reboot and return to shell (Ctrl+Alt+F2)
- [ ] Mount installed system: `sudo mount /dev/sda2 /mnt` (adjust device if needed)
- [ ] Mount EFI partition: `sudo mount /dev/sda1 /mnt/boot/efi`
- [ ] Bind necessary filesystems: `for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done`
- [ ] Enter chroot environment: `sudo chroot /mnt`
- [ ] Run LVM mount configuration: `bash /path/to/03-lvm-mount-config.sh`
- [ ] Exit chroot: `exit`
- [ ] Unmount filesystems: `for i in /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys /mnt/run; do sudo umount $i; done`
- [ ] Unmount installed system: `sudo umount /mnt/boot/efi && sudo umount /mnt`
- [ ] Reboot: `sudo reboot`

## Configuration Restoration and Base Setup

- [ ] Login to the new Ubuntu Server system
- [ ] Mount backup drive to `/restart`
- [ ] Copy scripts to the local system
- [ ] Ensure scripts are executable: `chmod +x scripts/*.sh`
- [ ] Run restoration script: `sudo scripts/restore-critical-backups.sh`
- [ ] Verify restoration completion in `/restart/critical_backups`
- [ ] Run master installer or follow sequence below: `sudo scripts/master-installer-script.sh`

## Sequential Installation (if not using master installer)

### Core System Setup
- [ ] Run initial setup: `sudo scripts/00-initial-setup.sh`
- [ ] Set up core system: `sudo scripts/01-core-system-setup.sh`
- [ ] Configure audio system: `sudo scripts/02-audio-system-setup.sh`
- [ ] Set up NVIDIA drivers: `sudo scripts/03-nvidia-rtx-setup.sh`
- [ ] Install KDE desktop: `sudo scripts/04-kde-desktop-install.sh`
- [ ] **Reboot system**

### Development Environment Setup
- [ ] Install development tools: `sudo scripts/05-development-tools-setup.sh`
- [ ] Set up global dev packages: `sudo scripts/06-global-dev-packages.sh`
- [ ] Install code editors: `sudo scripts/07-code-editors-setup.sh`
- [ ] Configure ZSH shell: `sudo scripts/08-zsh-shell-setup.sh`

### Application Installation
- [ ] Install specialized software: `sudo scripts/09-specialized-software.sh`
- [ ] Set up browsers: `sudo scripts/10-browsers-setup.sh`
- [ ] Configure Ollama for LLMs: `sudo scripts/11-ollama-llm-setup.sh`
- [ ] Install email client: `sudo scripts/12-email-client-setup.sh`
- [ ] Set up terminal enhancements: `sudo scripts/13-terminal-enhancements.sh`
- [ ] Configure AppImage support: `sudo scripts/14-appimage-setup.sh`

### Final Configuration
- [ ] Apply KDE settings: `sudo scripts/15-kde-settings-configuration.sh`
- [ ] Set up configuration backups: `sudo scripts/16-configuration-backups.sh`
- [ ] Perform final cleanup: `sudo scripts/17-final-cleanup.sh`
- [ ] Apply system tuning tweaks: `sudo scripts/18-system-tuning-tweaks.sh`
- [ ] Configure network enhancements: `sudo scripts/19-networking-tweaks.sh`
- [ ] **Reboot system**

## Post-Installation Configuration

- [ ] Run Audacity configuration: `scripts/post-install/audacity-config.sh`
- [ ] Set up microphone processing: `scripts/post-install/mic-processing.sh`
- [ ] Optimize Ollama for RTX: `sudo scripts/post-install/ollama-optimizer.sh`
- [ ] Configure real-time audio: `sudo scripts/post-install/realtime-audio-setup.sh`
- [ ] Set up VirtualBox audio bridge: `sudo scripts/post-install/virtualbox-audio-bridge.sh`

## Final Verification

- [ ] Verify symlinks to configuration repository: `ls -la ~/.config` (look for symlinks)
- [ ] Check system performance: `htop` and `nvidia-smi`
- [ ] Verify audio setup: `pw-top` and test audio playback
- [ ] Test Ollama: `ollama run llama3`
- [ ] Check KDE configuration and custom settings
- [ ] Verify that all volume mounts are correctly set up: `lsblk`
- [ ] Review installation summary: `~/kde-setup-summary.md`

---

*Back to [README.md](README.md)*
