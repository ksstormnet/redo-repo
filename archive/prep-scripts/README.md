# Preparation Scripts

This directory contains scripts used to prepare the system for the rebuild process. These scripts focus on backing up critical data and configurations before beginning the installation process.

## Scripts

### [backup_critical_data.sh](backup_critical_data.sh)

This script performs a comprehensive backup of all critical user and system data before rebuilding:

- **Purpose**: Creates a complete backup of configurations, documents, and system settings
- **Usage**: Run on the source system before beginning rebuild process
- **Output**: Creates timestamped backup archives in `/restart/prep/backups`
- **Features**:
  - Backs up home directory configuration files
  - Encrypts and backs up SSH keys and credentials
  - Preserves git configurations
  - Archives shell configurations
  - Backs up database dumps
  - Creates package lists of installed software
  - Backs up GPG keys and crontabs
  - Organizes backups with timestamps and metadata files

The script creates several archives:
- Main configuration backup (`main_backup_*.tar.gz`)
- SSH keys backup (`ssh_encrypted_*.tar.gz.gpg`) - encrypted with a passphrase
- Database dumps (`*-db.tar.gz`)
- Desktop files (`desktop_*.tar.gz`)

All these are combined into a comprehensive archive (`complete_backup_*.tar`) with metadata for easy restoration.

## Backup Location

Backups are stored in `/restart/prep/backups/` by default. This location should be on an external drive or separate partition that will remain accessible during the system rebuild process.

## Using Backups During Installation

These backups are used by the `scripts/restore-critical-backups.sh` script during installation to:

1. Extract critical configurations to `/restart/critical_backups`
2. Create a configuration mapping file that other scripts use to locate settings
3. Provide a seamless transition from the old system to the new one

## Customization

The backup script can be customized by editing:

- The backup destination (`BACKUP_DIR` variable)
- The encryption password for SSH keys (`ENCRYPTION_PASSWORD` variable)
- The list of directories and files to back up

## Important Notes

- The script should be run with sudo privileges to access system-wide configuration files
- The backup process can take considerable time for large home directories
- Make sure you have sufficient space on the backup device 
- The encryption password for SSH keys is set within the script and should be changed for security

---

*Back to [Main README](../README.md) | Next: [LVM Setup](../bare-to-lvm/README.md)*
