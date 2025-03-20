#!/bin/bash

# Define backup destination
BACKUP_DIR="/restart/prep/backups"
mkdir -p "$BACKUP_DIR"

# Timestamp for the backup
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="critical_data_$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_PATH"

# Log function
log() {
    echo "[$(date +%H:%M:%S)] $1"
    echo "[$(date +%H:%M:%S)] $1" >> "$BACKUP_PATH/backup.log"
}

log "Starting critical data backup"

# Back up home directory config files
log "Backing up home directory configuration files"
mkdir -p "$BACKUP_PATH/home_configs"

# SSH keys
if [ -d ~/.ssh ]; then
    cp -r ~/.ssh "$BACKUP_PATH/home_configs/"
    log "SSH keys backed up"
fi

# Git config
if [ -f ~/.gitconfig ]; then
    cp ~/.gitconfig "$BACKUP_PATH/home_configs/"
    log "Git configuration backed up"
fi

# Shell config files
for file in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.zsh_history ~/.profile; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_PATH/home_configs/"
        log "$(basename "$file") backed up"
    fi
done

# Important config directories
for dir in ~/.config/KDE ~/.config/plasma-workspace ~/.config/konsolerc ~/.config/QtProject ~/.config/VirtualBox; do
    if [ -d "$dir" ]; then
        mkdir -p "$BACKUP_PATH/home_configs/$(dirname "${dir#~/.}")"
        cp -r "$dir" "$BACKUP_PATH/home_configs/$(dirname "${dir#~/.}")/"
        log "$(basename "$dir") configuration backed up"
    fi
done

# Database dumps
log "Creating database dumps"
mkdir -p "$BACKUP_PATH/databases"

# If MySQL/MariaDB is installed
if command -v mysql &> /dev/null; then
    if [ -f ~/.my.cnf ]; then
        mysql -e "SHOW DATABASES" | grep -v "Database\|information_schema\|performance_schema\|sys\|mysql" | while read db; do
            mysqldump "$db" > "$BACKUP_PATH/databases/$db.sql"
            log "MySQL database $db backed up"
        done
    else
        log "MySQL credentials not found in ~/.my.cnf - skipping MySQL backups"
    fi
fi

# Document list of installed packages
log "Documenting installed packages"
mkdir -p "$BACKUP_PATH/system"
dpkg --get-selections > "$BACKUP_PATH/system/installed_packages.txt"
apt-mark showmanual > "$BACKUP_PATH/system/manually_installed.txt"
if command -v snap &> /dev/null; then
    snap list > "$BACKUP_PATH/system/snap_packages.txt"
fi

# GPG keys
if [ -d ~/.gnupg ]; then
    mkdir -p "$BACKUP_PATH/home_configs/gnupg"
    cp -r ~/.gnupg/* "$BACKUP_PATH/home_configs/gnupg/"
    log "GPG keys backed up"
fi

# Crontabs
if crontab -l &> /dev/null; then
    crontab -l > "$BACKUP_PATH/system/user_crontab.txt"
    log "User crontab backed up"
fi

# Create archive of the backup
log "Creating compressed archive"
tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
log "Backup archive created at $BACKUP_DIR/${BACKUP_NAME}.tar.gz"

log "Critical data backup completed"
