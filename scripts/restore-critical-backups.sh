#!/bin/bash

# restore-critical-backups.sh
# This script restores critical backups after LVM setup but before installer scripts
# It extracts backup archives to /restart/critical_backups for use by installer scripts

# Exit on error
set -e

# Define color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}       Critical Backup Restoration - Intermediate Step      ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo

# Define locations
BACKUP_SOURCE="/restart/prep/backups"
RESTORE_DIR="/restart/critical_backups"
GPG_PASSWORD="Storm!Stream12"

# Function for logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function for error logging
error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Function for warnings
warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if backup source directory exists
if [ ! -d "$BACKUP_SOURCE" ]; then
    error "Backup source directory $BACKUP_SOURCE does not exist!"
    exit 1
fi

# Create restore directory if it doesn't exist
log "Creating restore directory at $RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

# Find the most recent complete backup archive
log "Looking for the most recent complete backup archive..."
COMPLETE_BACKUP=$(find "$BACKUP_SOURCE" -name "complete_backup_*.tar" -type f | sort -r | head -n 1)

if [ -z "$COMPLETE_BACKUP" ]; then
    error "No complete backup archive found in $BACKUP_SOURCE"
    
    # Try to find individual archives instead
    warn "Trying to find individual archives instead..."
    FOUND_ARCHIVES=$(find "$BACKUP_SOURCE" -name "*.tar.gz" -o -name "*.tar.gz.gpg" | wc -l)
    
    if [ "$FOUND_ARCHIVES" -gt 0 ]; then
        log "Found $FOUND_ARCHIVES individual archives. Will process them directly."
    else
        error "No backup archives found at all. Exiting."
        exit 1
    fi
else
    log "Found complete backup: $(basename "$COMPLETE_BACKUP")"
    
    # Extract the complete backup to a temporary directory
    TEMP_DIR="$RESTORE_DIR/temp"
    mkdir -p "$TEMP_DIR"
    log "Extracting complete backup to temporary directory..."
    
    tar -xf "$COMPLETE_BACKUP" -C "$TEMP_DIR"
    log "Complete backup extracted successfully."
    
    # Move the individual archives to the restore directory
    log "Moving individual archives to restore directory..."
    find "$TEMP_DIR" -name "*.tar.gz" -o -name "*.tar.gz.gpg" -o -name "*-db.tar.gz" | while read -r archive; do
        cp "$archive" "$RESTORE_DIR/"
        log "Moved $(basename "$archive")"
    done
    
    # Check for metadata file
    METADATA=$(find "$TEMP_DIR" -name "backup_metadata_*.txt" | head -n 1)
    if [ -n "$METADATA" ]; then
        cp "$METADATA" "$RESTORE_DIR/backup_metadata.txt"
        log "Copied backup metadata file."
    fi
    
    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
fi

# Process each archive in the restore directory
log "Processing archives in restore directory..."

# Create directories for extracted content
mkdir -p "$RESTORE_DIR/configs"
mkdir -p "$RESTORE_DIR/databases"
mkdir -p "$RESTORE_DIR/ssh"
mkdir -p "$RESTORE_DIR/desktop"
mkdir -p "$RESTORE_DIR/system"

# Process main backup archive
MAIN_BACKUP=$(find "$RESTORE_DIR" -name "main_backup_*.tar.gz" | sort -r | head -n 1)
if [ -n "$MAIN_BACKUP" ]; then
    log "Extracting main backup: $(basename "$MAIN_BACKUP")"
    tar -xzf "$MAIN_BACKUP" -C "$RESTORE_DIR/configs"
    log "Main backup extracted successfully."
else
    warn "No main backup archive found."
fi

# Process database backup
DB_BACKUP=$(find "$RESTORE_DIR" -name "*-db.tar.gz" | sort -r | head -n 1)
if [ -n "$DB_BACKUP" ]; then
    log "Extracting database backup: $(basename "$DB_BACKUP")"
    tar -xzf "$DB_BACKUP" -C "$RESTORE_DIR/databases"
    log "Database backup extracted successfully."
else
    warn "No database backup archive found."
fi

# Process desktop backup
DESKTOP_BACKUP=$(find "$RESTORE_DIR" -name "desktop_*.tar.gz" | sort -r | head -n 1)
if [ -n "$DESKTOP_BACKUP" ]; then
    log "Extracting desktop backup: $(basename "$DESKTOP_BACKUP")"
    tar -xzf "$DESKTOP_BACKUP" -C "$RESTORE_DIR/desktop"
    log "Desktop backup extracted successfully."
else
    warn "No desktop backup archive found."
fi

# Process encrypted SSH backup
SSH_BACKUP=$(find "$RESTORE_DIR" -name "ssh_encrypted_*.tar.gz.gpg" | sort -r | head -n 1)
if [ -n "$SSH_BACKUP" ]; then
    log "Decrypting and extracting SSH backup: $(basename "$SSH_BACKUP")"
    
    # Create a temporary file for the decrypted archive
    TEMP_SSH="/tmp/ssh_backup_decrypted.tar.gz"
    
    # Decrypt the archive
    gpg --batch --yes --passphrase "$GPG_PASSWORD" --output "$TEMP_SSH" --decrypt "$SSH_BACKUP"
    
    # Extract the decrypted archive
    tar -xzf "$TEMP_SSH" -C "$RESTORE_DIR/ssh"
    
    # Remove the temporary decrypted file
    rm -f "$TEMP_SSH"
    
    log "SSH backup extracted successfully."
else
    warn "No encrypted SSH backup archive found."
fi

# Create symlinks for important config directories
log "Creating symlinks for important config directories..."

# Define directories to symlink
CONFIG_DIRS=(
    "home_configs"
    "config_files"
    "bashrc_sourced"
    "additional_configs"
    "script_referenced_configs"
)

# Create symlinks for each config directory if it exists
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$RESTORE_DIR/configs/critical_data_"*"/$dir" ]; then
        SOURCE=$(find "$RESTORE_DIR/configs/critical_data_"* -name "$dir" -type d | head -n 1)
        if [ -n "$SOURCE" ]; then
            ln -sf "$SOURCE" "$RESTORE_DIR/$dir"
            log "Created symlink: $RESTORE_DIR/$dir -> $SOURCE"
        fi
    else
        warn "Directory $dir not found in backup."
    fi
done

# Create a mapping file to help installer scripts locate configurations
log "Creating configuration mapping file..."
MAPPING_FILE="$RESTORE_DIR/config_mapping.txt"

{
    echo "# Configuration Path Mapping"
    echo "# Generated on: $(date)"
    echo "#"
    echo "# This file helps installer scripts locate configuration files in the backup"
    echo ""
    
    echo "# SSH Configuration"
    if [ -d "$RESTORE_DIR/ssh/ssh_backup" ]; then
        echo "SSH_PATH=$RESTORE_DIR/ssh/ssh_backup/.ssh"
    else
        echo "# SSH_PATH=Not found in backup"
    fi
    
    echo ""
    echo "# Shell Configurations"
    if [ -d "$RESTORE_DIR/home_configs" ]; then
        echo "SHELL_CONFIGS_PATH=$RESTORE_DIR/home_configs"
    else
        echo "# SHELL_CONFIGS_PATH=Not found in backup"
    fi
    
    echo ""
    echo "# Database Dumps"
    if [ -d "$RESTORE_DIR/databases" ]; then
        echo "DATABASE_PATH=$RESTORE_DIR/databases"
    else
        echo "# DATABASE_PATH=Not found in backup"
    fi
    
    echo ""
    echo "# Additional Configuration Paths"
    if [ -d "$RESTORE_DIR/config_files" ]; then
        echo "GENERAL_CONFIGS_PATH=$RESTORE_DIR/config_files"
    fi
    if [ -d "$RESTORE_DIR/additional_configs" ]; then
        echo "ADDITIONAL_CONFIGS_PATH=$RESTORE_DIR/additional_configs"
    fi
    if [ -d "$RESTORE_DIR/script_referenced_configs" ]; then
        echo "SCRIPT_CONFIGS_PATH=$RESTORE_DIR/script_referenced_configs"
    fi
} > "$MAPPING_FILE"

log "Configuration mapping file created at $MAPPING_FILE"

# Create a validation script to verify that configurations are accessible
VALIDATION_SCRIPT="$RESTORE_DIR/validate_configs.sh"
log "Creating configuration validation script..."

cat > "$VALIDATION_SCRIPT" << 'EOF'
#!/bin/bash

# validate_configs.sh
# Run this script to verify that configurations are properly extracted and accessible

source /restart/critical_backups/config_mapping.txt

echo "Validating critical backup configurations..."

# Function to check if a path exists
check_path() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        echo "✓ $description exists at $path"
        return 0
    else
        echo "✗ $description not found at $path"
        return 1
    fi
}

# Check SSH path
if [ -n "$SSH_PATH" ]; then
    check_path "$SSH_PATH" "SSH configuration"
else
    echo "✗ SSH_PATH not defined in config_mapping.txt"
fi

# Check shell config path
if [ -n "$SHELL_CONFIGS_PATH" ]; then
    check_path "$SHELL_CONFIGS_PATH" "Shell configurations"
    
    # Check for specific shell config files
    for file in .bashrc .bash_profile .zshrc .nanorc; do
        if [ -f "$SHELL_CONFIGS_PATH/$file" ]; then
            echo "  ✓ Found $file"
        fi
    done
else
    echo "✗ SHELL_CONFIGS_PATH not defined in config_mapping.txt"
fi

# Check database path
if [ -n "$DATABASE_PATH" ]; then
    check_path "$DATABASE_PATH" "Database dumps"
    
    # Count SQL files
    SQL_FILES=$(find "$DATABASE_PATH" -name "*.sql" | wc -l)
    echo "  ✓ Found $SQL_FILES database dump files"
else
    echo "✗ DATABASE_PATH not defined in config_mapping.txt"
fi

echo
echo "Run this validation script at any time to verify config accessibility."
echo "Installer scripts can source config_mapping.txt to locate configuration files."
EOF

chmod +x "$VALIDATION_SCRIPT"
log "Validation script created at $VALIDATION_SCRIPT"

# Run the validation script
log "Running validation script to verify configuration accessibility..."
$VALIDATION_SCRIPT

# Final summary
echo
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}                Backup Restoration Complete                 ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo
echo -e "Critical configurations have been extracted to: ${YELLOW}$RESTORE_DIR${NC}"
echo -e "Configuration mapping file: ${YELLOW}$MAPPING_FILE${NC}"
echo -e "To verify configurations at any time, run: ${YELLOW}$VALIDATION_SCRIPT${NC}"
echo
echo -e "You can now proceed with running the installer scripts,"
echo -e "which can access these configurations using the mapping file."
echo -e "${BLUE}============================================================${NC}"
