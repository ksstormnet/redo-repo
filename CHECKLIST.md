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
- [ ] (Optional) Run LVM wipe script if you need to clean previous configurations: `sudo ./00-lvm-wipe.sh`
- [ ] Run LVM enhanced setup script: `sudo ./01-lvm-setup-enhanced.sh`
- [ ] Run enhanced logical volumes setup script: `sudo ./02-lvm-logical-volumes-enhanced.sh`
- [ ] (Optional) Monitor LVM space usage: `sudo ./lvm-monitor.sh`
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
- [ ] Run enhanced LVM mount configuration: `bash /path/to/03-lvm-mount-config-enhanced.sh`
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

### Phase 1: Core System (00-core)
- [ ] Run `sudo scripts/00-core/01-initial-setup.sh`
- [ ] Run `sudo scripts/00-core/02-repositories.sh`
- [ ] Run `sudo scripts/00-core/03-base-packages.sh`
- [ ] Run `sudo scripts/00-core/04-system-config.sh`
- [ ] Run `sudo scripts/00-core/05-audio-system.sh`
- [ ] Run `sudo scripts/00-core/06-nvidia-drivers.sh`
- [ ] **Reboot system**

### Phase 2: Desktop Environment (10-desktop)
- [ ] Run `sudo scripts/10-desktop/01-kde-plasma.sh`
- [ ] Run `sudo scripts/10-desktop/02-fonts.sh`
- [ ] Run `sudo scripts/10-desktop/03-themes.sh`
- [ ] Run `sudo scripts/10-desktop/04-kde-config.sh`
- [ ] Run `sudo scripts/10-desktop/05-display-manager.sh`
- [ ] **Reboot system**

### Phase 3: Development Environment (20-development)
- [ ] Run `sudo scripts/20-development/01-base-dev-tools.sh`
- [ ] Run `sudo scripts/20-development/02-programming-languages.sh`
- [ ] Run `sudo scripts/20-development/03-vscode.sh`
- [ ] Run `sudo scripts/20-development/04-git-config.sh`
- [ ] Run `sudo scripts/20-development/05-containers.sh`
- [ ] Run `sudo scripts/20-development/06-zsh-setup.sh`

### Phase 4: Application Installation (30-applications)
- [ ] Run `sudo scripts/30-applications/01-browsers.sh`
- [ ] Run `sudo scripts/30-applications/02-productivity.sh`
- [ ] Run `sudo scripts/30-applications/03-media.sh`
- [ ] Run `sudo scripts/30-applications/04-utilities.sh`
- [ ] Run `sudo scripts/30-applications/05-communication.sh`
- [ ] Run `sudo scripts/30-applications/06-ollama-llm.sh`
- [ ] Run `sudo scripts/30-applications/07-appimage-support.sh`

### Phase 5: Optimization (40-optimization)
- [ ] Run `sudo scripts/40-optimization/01-system-tuning.sh`
- [ ] Run `sudo scripts/40-optimization/02-networking.sh`
- [ ] Run `sudo scripts/40-optimization/03-config-backups.sh`
- [ ] Run `sudo scripts/40-optimization/04-final-cleanup.sh`
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
- [ ] Run enhanced LVM monitoring script: `sudo ./lvm-monitor.sh`
- [ ] Run enhanced post-installation script: `sudo ./04-lvm-post-install-enhanced.sh`
- [ ] Review installation summary: `~/kde-setup-summary.md`

---

*Back to [README.md](README.md)*
