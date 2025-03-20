# Preparation Scripts

This directory contains scripts for preparing the system for installation and migration.

## Scripts

### backup_critical_data.sh

This script performs a comprehensive backup of critical data before system installation or migration. It backs up:

- Home directory configuration files
- SSH keys
- Git configuration
- Shell configuration files
- Important config directories
- Database dumps
- Installed packages list
- GPG keys
- Crontabs

### Usage

```bash
# Make sure the script is executable
chmod +x backup_critical_data.sh

# Run the script
./backup_critical_data.sh
```

The script will create a timestamped backup in the `/restart/prep/backups` directory. It will also create a compressed archive of the backup.

## Integration with Installation Process

This script should be run before beginning the system installation process to ensure all critical data is safely backed up.

It is referenced in the migration plan and is an essential part of the pre-installation preparation process.
