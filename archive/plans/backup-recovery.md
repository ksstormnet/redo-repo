# Kubuntu LVM System Rebuild - Backup and Recovery Plan

## Overview

This document outlines a comprehensive backup and recovery strategy for your newly configured Kubuntu system with LVM. The plan includes both automated and manual backup procedures, as well as recovery instructions.

## 1. Backup Strategy

### Types of Backups

The backup strategy includes several types of backups:

1. **System Configuration Backups**: Essential system configuration files
2. **Home Directory Backups**: User profiles and settings
3. **Data Backups**: Documents, projects, and other user data
4. **LVM Snapshots**: Point-in-time copies of logical volumes
5. **Database Backups**: For development databases

### Backup Schedule

| Data Type | Frequency | Retention | Location |
|-----------|-----------|-----------|----------|
| System Configuration | Weekly | 4 weeks | External Drive |
| Home Directory | Daily | 2 weeks | External Drive |
| User Data | Daily | 4 weeks | External Drive + Cloud |
| LVM Snapshots | Before major changes | Until next snapshot | Local |
| Databases | Daily | 1 week | Local + Cloud |

## 2. Backup Tools and Scripts

### Timeshift for System Snapshots

```bash
# Install Timeshift
sudo apt install -y timeshift

# Configure Timeshift (CLI method)
sudo timeshift --create --comments "Initial system backup" --tags D

# Create a script to automate weekly backups
cat > ~/bin/weekly_timeshift.sh << 'EOF'
#!/bin/bash

# Create a new Timeshift snapshot
sudo timeshift --create --comments "Weekly backup $(date +%Y-%m-%d)" --tags W

# Delete snapshots older than 4 weeks (28 days)
sudo timeshift --delete --snapshot-device /dev/sda2 --older-than 28D

echo "Weekly Timeshift backup completed at $(date)"
EOF

chmod +x ~/bin/weekly_timeshift.sh

# Add to crontab for weekly execution (Sunday at 1 AM)
(crontab -l 2>/dev/null; echo "0 1 * * 0 $HOME/bin/weekly_timeshift.sh") | crontab -
```

### Rsync for Data Backups

```bash
# Create a comprehensive backup script using rsync
cat > ~/bin/backup_data.sh << 'EOF'
#!/bin/bash

# Define backup destinations
BACKUP_DIR="/media/$USER/ExternalDrive/Backups"  # Update with your external drive path
TIMESTAMP=$(date +%Y-%m-%d)
LOG_FILE="$HOME/backup_logs/backup_$TIMESTAMP.log"

# Make sure the log directory exists
mkdir -p "$HOME/backup_logs"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting backup at $(date)"

# Check if backup drive is mounted
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup destination not found at $BACKUP_DIR"
    echo "Please connect your external backup drive and try again."
    exit 1
fi

# Create timestamp directory
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$BACKUP_PATH"

# Backup home directory (excluding large caches)
echo "Backing up home directory..."
rsync -avz --progress --exclude=".cache" --exclude="node_modules" \
  --exclude=".npm" --exclude=".vscode-server" --exclude=".local/share/Trash" \
  --exclude="snap" --exclude=".mozilla/firefox/*.default/cache*" \
  "$HOME/" "$BACKUP_PATH/home/"

# Backup data directory
echo "Backing up data directory..."
rsync -avz --progress --exclude="*/node_modules" --exclude="*/.git" \
  --exclude="*/cache" --exclude="*.tmp" \
  "/data/" "$BACKUP_PATH/data/"

# Backup Docker compose files (but not volumes)
echo "Backing up Docker compose files..."
rsync -avz --progress "/data/Docker/compose/" "$BACKUP_PATH/docker_compose/"

# Backup VirtualBox VM definitions (not disk images)
echo "Backing up VirtualBox VM definitions..."
rsync -avz --progress --include="*/" --include="*.vbox" --include="*.xml" \
  --exclude="*.vdi" --exclude="*.vhd" --exclude="*.vmdk" \
  "/VirtualBox/VMs/" "$BACKUP_PATH/vm_definitions/"

# Backup important configuration files
echo "Backing up system configuration files..."
sudo rsync -avz /etc/ "$BACKUP_PATH/system_config/etc/"

# Record package list
echo "Recording package list..."
dpkg --get-selections > "$BACKUP_PATH/package_list.txt"
apt-mark showmanual > "$BACKUP_PATH/manually_installed.txt"

# Backup LVM configuration
echo "Backing up LVM configuration..."
sudo vgcfgbackup -f "$BACKUP_PATH/vg_data_backup" vg_data

# Clean up old backups (keep 4 weeks of backups)
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +28 -exec rm -rf {} \;

echo "Backup completed at $(date)"
EOF

chmod +x ~/bin/backup_data.sh

# Add to crontab for daily execution (at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * $HOME/bin/backup_data.sh") | crontab -
```

### LVM Snapshot Management

```bash
# Create a script for pre-update LVM snapshots
cat > ~/bin/pre_update_snapshot.sh << 'EOF'
#!/bin/bash

# Create LVM snapshots before system updates
# Must be run as root

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Timestamp for snapshot names
TIMESTAMP=$(date +%Y%m%d)

# Create snapshots of critical volumes
echo "Creating LVM snapshots before system update..."

# Snapshot of /home
lvcreate -s -n lv_home_snap_$TIMESTAMP -L 10G /dev/vg_data/lv_home
echo "Created snapshot of /home: lv_home_snap_$TIMESTAMP"

# Snapshot of /data
lvcreate -s -n lv_data_snap_$TIMESTAMP -L 20G /dev/vg_data/lv_data
echo "Created snapshot of /data: lv_data_snap_$TIMESTAMP"

# Snapshot of root if it's on LVM
if lvs | grep -q "lv_root"; then
    lvcreate -s -n lv_root_snap_$TIMESTAMP -L 5G /dev/vg_data/lv_root
    echo "Created snapshot of /: lv_root_snap_$TIMESTAMP"
fi

echo "Snapshots created successfully at $(date)"
echo "To remove these snapshots after a successful update, run:"
echo "sudo lvremove /dev/vg_data/lv_home_snap_$TIMESTAMP /dev/vg_data/lv_data_snap_$TIMESTAMP"
if lvs | grep -q "lv_root"; then
    echo "sudo lvremove /dev/vg_data/lv_root_snap_$TIMESTAMP"
fi
EOF

chmod +x ~/bin/pre_update_snapshot.sh
```

### Database Backups

```bash
# Create a script for database backups
cat > ~/bin/backup_databases.sh << 'EOF'
#!/bin/bash

# Define variables
BACKUP_DIR="/data/Backups/Databases"
TIMESTAMP=$(date +%Y-%m-%d)
DB_BACKUP_DIR="$BACKUP_DIR/$TIMESTAMP"
LOG_FILE="$HOME/backup_logs/db_backup_$TIMESTAMP.log"

# Make sure directories exist
mkdir -p "$DB_BACKUP_DIR"
mkdir -p "$HOME/backup_logs"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting database backup at $(date)"

# MySQL/MariaDB backup
if command -v mysql &> /dev/null; then
    echo "Backing up MySQL/MariaDB databases..."
    
    # Check for credentials
    if [ -f ~/.my.cnf ]; then
        # Get list of databases
        DATABASES=$(mysql -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys")
        
        # Backup each database
        for DB in $DATABASES; do
            echo "Backing up database: $DB"
            mysqldump --single-transaction --quick --lock-tables=false "$DB" > "$DB_BACKUP_DIR/$DB.sql"
        done
    else
        echo "WARNING: MySQL credentials not found in ~/.my.cnf"
        echo "Create a ~/.my.cnf file or enter credentials manually:"
        echo "Username:"
        read DB_USER
        echo "Password:"
        read -s DB_PASS
        
        if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
            # Get list of databases
            DATABASES=$(mysql -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys")
            
            # Backup each database
            for DB in $DATABASES; do
                echo "Backing up database: $DB"
                mysqldump --single-transaction --quick --lock-tables=false -u"$DB_USER" -p"$DB_PASS" "$DB" > "$DB_BACKUP_DIR/$DB.sql"
            done
        else
            echo "No credentials provided. Skipping MySQL backups."
        fi
    fi
fi

# PostgreSQL backup
if command -v psql &> /dev/null; then
    echo "Backing up PostgreSQL databases..."
    
    # Check if user has PostgreSQL access
    if sudo -u postgres psql -c '\l' &> /dev/null; then
        # Get list of databases
        DATABASES=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';")
        
        # Backup each database
        for DB in $DATABASES; do
            DB=$(echo $DB | tr -d '[:space:]')
            echo "Backing up PostgreSQL database: $DB"
            sudo -u postgres pg_dump -Fc "$DB" > "$DB_BACKUP_DIR/$DB.pg_dump"
        done
    else
        echo "WARNING: Cannot access PostgreSQL as postgres user."
        echo "Skipping PostgreSQL backups."
    fi
fi

# SQLite databases
echo "Looking for SQLite databases..."
find /data -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" | while read DB_FILE; do
    echo "Backing up SQLite database: $DB_FILE"
    DB_NAME=$(basename "$DB_FILE")
    
    # Create a copy of the database
    cp "$DB_FILE" "$DB_BACKUP_DIR/$DB_NAME"
    
    # Also create an SQL dump if sqlite3 command is available
    if command -v sqlite3 &> /dev/null; then
        sqlite3 "$DB_FILE" .dump > "$DB_BACKUP_DIR/${DB_NAME%.db}.sql"
    fi
done

# Compress all backups
echo "Compressing database backups..."
tar -czf "$BACKUP_DIR/db_backup_$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "$TIMESTAMP"

# Clean up old backups (keep 1 week)
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +7 -exec rm -rf {} \;
find "$BACKUP_DIR" -maxdepth 1 -type f -name "db_backup_*.tar.gz" -mtime +7 -exec rm {} \;

echo "Database backup completed at $(date)"
EOF

chmod +x ~/bin/backup_databases.sh

# Add to crontab for daily execution (at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * $HOME/bin/backup_databases.sh") | crontab -
```

### Cloud Backup

```bash
# Install rclone for cloud backups
sudo apt install -y rclone

# Configure rclone (run this command and follow the prompts)
# rclone config

# Create a script for cloud backups
cat > ~/bin/cloud_backup.sh << 'EOF'
#!/bin/bash

# Define variables
CLOUD_NAME="YourCloudName"  # Update with your configured rclone remote name
LOCAL_BACKUP_DIR="/data/Backups"
CLOUD_BACKUP_DIR="KubuntuBackup"
LOG_FILE="$HOME/backup_logs/cloud_backup_$(date +%Y-%m-%d).log"

# Make sure the log directory exists
mkdir -p "$HOME/backup_logs"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting cloud backup at $(date)"

# Check if rclone is configured
if ! rclone listremotes | grep -q "$CLOUD_NAME:"; then
    echo "ERROR: rclone remote '$CLOUD_NAME' not found"
    echo "Please configure rclone first by running 'rclone config'"
    exit 1
fi

# Sync Documents to cloud
echo "Syncing Documents to cloud..."
rclone sync /data/Documents "$CLOUD_NAME:$CLOUD_BACKUP_DIR/Documents" \
    --exclude "**/.git/**" --exclude "**/node_modules/**" --exclude "**/.DS_Store" \
    --exclude "**/.vscode/**" --progress

# Sync Pictures to cloud
echo "Syncing Pictures to cloud..."
rclone sync /data/Pictures "$CLOUD_NAME:$CLOUD_BACKUP_DIR/Pictures" \
    --exclude "**/.DS_Store" --progress

# Sync Projects to cloud (excluding large files and sensitive data)
echo "Syncing Projects to cloud..."
rclone sync /data/Projects "$CLOUD_NAME:$CLOUD_BACKUP_DIR/Projects" \
    --exclude "**/.git/**" --exclude "**/node_modules/**" --exclude "**/.DS_Store" \
    --exclude "**/vendor/**" --exclude "**/.env" --exclude "**/.env.*" \
    --exclude "**/*.log" --max-size 100M --progress

# Sync database backups
echo "Syncing database backups to cloud..."
rclone sync "$LOCAL_BACKUP_DIR/Databases" "$CLOUD_NAME:$CLOUD_BACKUP_DIR/Databases" \
    --max-age 7d --progress

echo "Cloud backup completed at $(date)"
EOF

chmod +x ~/bin/cloud_backup.sh

# Add to crontab for daily execution (at 4 AM)
(crontab -l 2>/dev/null; echo "0 4 * * * $HOME/bin/cloud_backup.sh") | crontab -
```

## 3. System Recovery Procedures

### Restore from Timeshift Snapshot

```bash
# Boot into a live USB environment
# Open terminal and run:
sudo apt install timeshift
sudo timeshift --restore
```

### Recover from LVM Snapshots

```bash
# To view available snapshots
sudo lvs -a | grep snap

# To restore from a snapshot (replace with actual snapshot name)
sudo lvconvert --merge /dev/vg_data/lv_home_snap_20230101

# Note: System may need to be rebooted for the merge to complete
```

### Restore from Rsync Backups

```bash
# Create a recovery script
cat > ~/bin/restore_from_backup.sh << 'EOF'
#!/bin/bash

# Define variables
BACKUP_DIR="/media/$USER/ExternalDrive/Backups"  # Update with your external drive path
LOG_FILE="$HOME/restore_log.txt"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting recovery at $(date)"

# Check if backup drive is mounted
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup source not found at $BACKUP_DIR"
    echo "Please connect your external backup drive and try again."
    exit 1
fi

# List available backups
echo "Available backups:"
ls -l "$BACKUP_DIR" | grep ^d

echo "Enter the backup date to restore from (e.g., 2023-01-01):"
read BACKUP_DATE

if [ ! -d "$BACKUP_DIR/$BACKUP_DATE" ]; then
    echo "ERROR: Backup for $BACKUP_DATE not found"
    exit 1
fi

BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"

echo "Select what to restore:"
echo "1. Home directory"
echo "2. Data directory"
echo "3. Docker compose files"
echo "4. System configurations"
echo "5. All of the above"
read -p "Enter your choice (1-5): " CHOICE

case $CHOICE in
    1|5)
        echo "Restoring home directory..."
        rsync -avz --progress "$BACKUP_PATH/home/" "$HOME/"
        ;;
    2|5)
        echo "Restoring data directory..."
        sudo rsync -avz --progress "$BACKUP_PATH/data/" "/data/"
        ;;
    3|5)
        echo "Restoring Docker compose files..."
        rsync -avz --progress "$BACKUP_PATH/docker_compose/" "/data/Docker/compose/"
        ;;
    4|5)
        echo "Restoring system configurations..."
        sudo rsync -avz --progress "$BACKUP_PATH/system_config/etc/" "/etc/"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "Restoration completed at $(date)"
EOF

chmod +x ~/bin/restore_from_backup.sh
```

### Recover from Complete System Failure

#### Prepare a Recovery USB

```bash
# Create a recovery USB that includes:
# 1. Kubuntu installation media
# 2. Installation scripts
# 3. Backup of LVM configuration
```

#### Recovery Steps

1. **Boot from Recovery USB**
   - Select "Try Kubuntu without installing"

2. **Reinstall System**
   - Follow the LVM Installation Guide to reinstall the base system

3. **Restore LVM Configuration**
   ```bash
   sudo vgcfgrestore -f /path/to/vg_data_backup vg_data
   ```

4. **Restore Data from Backups**
   ```bash
   # Mount external backup drive
   sudo mount /dev/sdX1 /mnt/backup
   
   # Use the restore script or manual rsync commands
   sudo rsync -avz /mnt/backup/latest/home/ /home/
   sudo rsync -avz /mnt/backup/latest/data/ /data/
   ```

5. **Restore Configurations**
   ```bash
   sudo rsync -avz /mnt/backup/latest/system_config/etc/ /etc/
   ```

## 4. Disaster Recovery Documentation

### Critical Information Checklist

Create a physical document containing:

- [ ] Disk layout and LVM configuration
- [ ] Network configuration
- [ ] Encryption passwords (if used)
- [ ] Backup locations and access methods
- [ ] Cloud service credentials

Store this document securely in a physical location.

### Recovery Testing Schedule

Set up a regular schedule to test the recovery procedures:

1. **Monthly**: Test restoring individual files from backups
2. **Quarterly**: Test restoring from LVM snapshots
3. **Bi-annually**: Full disaster recovery simulation

## 5. Maintenance Tasks

### Regular Backup Verification

```bash
# Create a script to verify backups
cat > ~/bin/verify_backups.sh << 'EOF'
#!/bin/bash

# Define variables
BACKUP_DIR="/media/$USER/ExternalDrive/Backups"  # Update with your external drive path
LOG_FILE="$HOME/backup_logs/verification_$(date +%Y-%m-%d).log"

# Make sure the log directory exists
mkdir -p "$HOME/backup_logs"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting backup verification at $(date)"

# Check if backup drive is mounted
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup destination not found at $BACKUP_DIR"
    echo "Please connect your external backup drive and try again."
    exit 1
fi

# Get most recent backup
LATEST_BACKUP=$(ls -1d "$BACKUP_DIR"/20* | sort | tail -1)
echo "Verifying most recent backup: $LATEST_BACKUP"

# Check for critical directories
for DIR in home data system_config docker_compose; do
    if [ ! -d "$LATEST_BACKUP/$DIR" ]; then
        echo "ERROR: Missing critical directory: $DIR"
    else
        echo "✓ Directory $DIR exists"
        # Check size
        SIZE=$(du -sh "$LATEST_BACKUP/$DIR" | cut -f1)
        echo "  Size: $SIZE"
    fi
done

# Verify some critical files exist
echo "Checking for critical files..."
CRITICAL_FILES=(
    "home/.bashrc"
    "home/.zshrc"
    "home/.ssh/id_rsa"
    "system_config/etc/fstab"
)

for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -f "$LATEST_BACKUP/$FILE" ]; then
        echo "✓ Critical file exists: $FILE"
    else
        echo "WARNING: Missing critical file: $FILE"
    fi
done

echo "Backup verification completed at $(date)"
EOF

chmod +x ~/bin/verify_backups.sh

# Add to crontab for weekly execution (Saturday at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * 6 $HOME/bin/verify_backups.sh") | crontab -
```

### Cleanup Old Snapshots

```bash
# Create a script to clean up old LVM snapshots
cat > ~/bin/cleanup_snapshots.sh << 'EOF'
#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

echo "Checking for old LVM snapshots..."

# Find snapshots older than 7 days
OLD_SNAPSHOTS=$(lvs --noheadings -o lv_name,lv_time | grep "snap" | awk '$2 < systime()-604800 {print $1}')

if [ -z "$OLD_SNAPSHOTS" ]; then
    echo "No old snapshots found."
    exit 0
fi

echo "Found the following old snapshots:"
for SNAP in $OLD_SNAPSHOTS; do
    echo "- $SNAP"
done

echo "Do you want to remove these snapshots? (y/n)"
read CONFIRM

if [ "$CONFIRM" = "y" ]; then
    for SNAP in $OLD_SNAPSHOTS; do
        echo "Removing snapshot: $SNAP"
        lvremove -f /dev/vg_data/$SNAP
    done
    echo "Old snapshots removed successfully."
else
    echo "No snapshots were removed."
fi
EOF

chmod +x ~/bin/cleanup_snapshots.sh
```

## 6. Emergency Recovery USB Creation

### Create a Comprehensive Recovery USB

```bash
# Create a script to prepare a recovery USB
cat > ~/bin/create_recovery_usb.sh << 'EOF'
#!/bin/bash

# Define variables
USB_DEVICE="/dev/sdX"  # Update this with the actual USB device

echo "This script will create a recovery USB drive."
echo "WARNING: All data on $USB_DEVICE will be erased!"
echo "Press Enter to continue or Ctrl+C to cancel."
read

# Create partitions
echo "Creating partitions on $USB_DEVICE..."
sudo parted $USB_DEVICE --script mklabel gpt
sudo parted $USB_DEVICE --script mkpart primary fat32 1MiB 5000MiB
sudo parted $USB_DEVICE --script mkpart primary ext4 5000MiB 100%

# Format partitions
echo "Formatting partitions..."
sudo mkfs.fat -F 32 ${USB_DEVICE}1
sudo mkfs.ext4 ${USB_DEVICE}2

# Mount partitions
echo "Mounting partitions..."
mkdir -p /tmp/recovery_usb/boot
mkdir -p /tmp/recovery_usb/data
sudo mount ${USB_DEVICE}1 /tmp/recovery_usb/boot
sudo mount ${USB_DEVICE}2 /tmp/recovery_usb/data

# Copy ISO image
echo "Enter the path to your Kubuntu ISO:"
read ISO_PATH
sudo dd if=$ISO_PATH of=${USB_DEVICE}1 bs=4M status=progress oflag=sync

# Create recovery directories
sudo mkdir -p /tmp/recovery_usb/data/recovery/{scripts,configs,backups}

# Copy recovery scripts
echo "Copying recovery scripts..."
sudo cp ~/bin/restore_from_backup.sh /tmp/recovery_usb/data/recovery/scripts/
sudo cp /path/to/installation/scripts/* /tmp/recovery_usb/data/recovery/scripts/

# Backup LVM configuration
echo "Backing up LVM configuration..."
sudo vgcfgbackup -f /tmp/recovery_usb/data/recovery/configs/vg_data_backup vg_data

# Backup system configuration
echo "Backing up system configuration..."
sudo tar -czf /tmp/recovery_usb/data/recovery/backups/etc_backup.tar.gz /etc

# Create recovery instructions
cat > /tmp/recovery_usb/data/recovery/README.md << 'EOREADME'
# Kubuntu LVM System Recovery

This USB drive contains everything needed to recover your Kubuntu LVM system.

## Recovery Steps

1. Boot from this USB drive
2. Select "Try Kubuntu without installing"
3. Open a terminal
4. Mount the recovery partition:
   ```
   sudo mount /dev/sdX2 /mnt
   ```
5. Run the recovery script:
   ```
   sudo bash /mnt/recovery/scripts/restore_system.sh
   ```
6. Follow the prompts to restore your system

## Contents

- /recovery/scripts/ - Recovery and installation scripts
- /recovery/configs/ - LVM and system configurations
- /recovery/backups/ - Essential system backups
EOREADME

echo "Recovery USB created successfully."
sudo umount /tmp/recovery_usb/boot
sudo umount /tmp/recovery_usb/data
rmdir /tmp/recovery_usb/boot
rmdir /tmp/recovery_usb/data
rmdir /tmp/recovery_usb
EOF

chmod +x ~/bin/create_recovery_usb.sh
```

## 7. Recovery Testing

### Test Restore from Backup

Periodically test the recovery procedures to ensure they work as expected:

1. **Test File Restoration**
   ```bash
   # Create a test directory
   mkdir ~/restore_test
   
   # Restore a few files from backup
   rsync -avz /path/to/backup/home/Documents/important_file.txt ~/restore_test/
   
   # Verify file integrity
   diff ~/Documents/important_file.txt ~/restore_test/important_file.txt
   ```

2. **Test LVM Snapshot Recovery**
   ```bash
   # Create a test snapshot
   sudo lvcreate -s -n lv_test_snap -L 1G /dev/vg_data/lv_home
   
   # Make some changes to test recovery
   touch ~/test_file_before_restore.txt
   
   # Merge the snapshot
   sudo lvconvert --merge /dev/vg_data/lv_test_snap
   
   # Reboot and verify
   sudo reboot
   ```

3. **Full System Recovery Simulation**
   
   Perform a complete recovery simulation in a test environment:
   
   - Create a virtual machine
   - Follow the complete recovery procedure
   - Verify that all systems and data are properly restored
