#!/bin/bash

# Enhanced backup_critical_data.sh
# This script performs a comprehensive backup of critical data
# with special handling for SSH keys, sourced files, and database backups

# Exit on error
set -e

# Define backup destination
BACKUP_DIR="/restart/prep/backups"
mkdir -p "${BACKUP_DIR}"

# Timestamp for the backup
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S) || true
BACKUP_NAME="critical_data_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
mkdir -p "${BACKUP_PATH}"

# Log function
log() {
    local timestamp
    timestamp=$(date +%H:%M:%S) || true
    echo "[${timestamp}] $1"
    echo "[${timestamp}] $1" >> "${BACKUP_PATH}/backup.log"
}

log "Starting critical data backup"

# Back up home directory config files
log "Backing up home directory configuration files"
mkdir -p "${BACKUP_PATH}/home_configs"

# SSH keys with encryption
if [[ -d /home/scott/.ssh ]]; then
    log "Backing up SSH keys with encryption"
    mkdir -p "${BACKUP_PATH}/ssh_backup"
    
    # Use sudo to copy SSH files while preserving permissions
    sudo cp -p -r /home/scott/.ssh/. "${BACKUP_PATH}/ssh_backup/"
    # Fix ownership of the copied files to match the backup directory
    sudo chown -R "$(id -u):$(id -g)" "${BACKUP_PATH}/ssh_backup/"
    
    # Create encrypted archive of SSH config
    ENCRYPTION_PASSWORD="Storm!Stream12"
    SSH_ARCHIVE="${BACKUP_PATH}/ssh_encrypted_${TIMESTAMP}.tar.gz.gpg"
    
    # Create tar archive first, using sudo to ensure access to all files
    sudo tar -czf "${BACKUP_PATH}/ssh_backup_temp.tar.gz" -C "${BACKUP_PATH}" ssh_backup
    sudo chown "$(id -u):$(id -g)" "${BACKUP_PATH}/ssh_backup_temp.tar.gz"
    
    # Encrypt the archive with the provided password
    gpg --batch --yes --passphrase "${ENCRYPTION_PASSWORD}" \
        --cipher-algo AES256 \
        -o "${SSH_ARCHIVE}" \
        --symmetric "${BACKUP_PATH}/ssh_backup_temp.tar.gz"
    
    # Remove the unencrypted files with sudo
    sudo rm -rf "${BACKUP_PATH}/ssh_backup"
    sudo rm -f "${BACKUP_PATH}/ssh_backup_temp.tar.gz"
    
    log "SSH keys backed up and encrypted to ${SSH_ARCHIVE}"
fi

# Git config
if [[ -f /home/scott/.gitconfig ]]; then
    cp /home/scott/.gitconfig "${BACKUP_PATH}/home_configs/"
    log "Git configuration backed up"
fi

# Nano configuration
if [[ -f /home/scott/.nanorc ]]; then
    cp /home/scott/.nanorc "${BACKUP_PATH}/home_configs/"
    log ".nanorc backed up"
fi

# Shell config files
for file in /home/scott/.bashrc /home/scott/.bash_profile /home/scott/bash_aliases /home/scott/.profile /home/scott/.zshrc /home/scott/.zsh_history; do
    if [[ -f "${file}" ]]; then
        cp "${file}" "${BACKUP_PATH}/home_configs/"
        basename_result=$(basename "${file}") || true
        log "${basename_result} backed up"
    fi
done

# Backup files sourced in .bashrc
if [[ -f /home/scott/.bashrc ]]; then
    log "Checking .bashrc for sourced files"
    mkdir -p "${BACKUP_PATH}/bashrc_sourced"
    
    # Find all sourced files in .bashrc
    # Use || true to avoid masking return values
    sourced_files=$(grep -E 'source |^\. ' /home/scott/.bashrc | grep -v "/home/scott/bin\|/usr/local/bin" | awk '{print $2}' | sed "s|~|/home/scott|g") || true
    
    if [[ -n "${sourced_files}" ]]; then
        while read -r file; do
            # Expand environment variables
            expanded_file="${file/\${HOME}/\/home\/scott}" || true
            
            if [[ -f "${expanded_file}" ]]; then
                # Create directory structure
                target_dir="${BACKUP_PATH}/bashrc_sourced/$(dirname "${expanded_file}" | sed "s|^/home/scott|home|")" || true
                mkdir -p "${target_dir}"
                
                # Copy the file
                cp "${expanded_file}" "${target_dir}/$(basename "${expanded_file}")"
                log "Sourced file backed up: ${expanded_file}"
            fi
        done <<< "${sourced_files}"
    else
        log "No additional sourced files found in .bashrc"
    fi
fi

# Backup config files referenced in installation scripts
log "Backing up configuration files referenced in installation scripts"
mkdir -p "${BACKUP_PATH}/config_files"

# Add function to check for potentially valuable config files
find_additional_configs() {
    log "Scanning for additional configuration files..."
    
    # Look for other dot directories in home that might contain configs
    for dotdir in /home/scott/.[a-zA-Z]*; do
        # Skip already included directories and those we want to exclude
        # Skip already included directories and those we want to exclude
        if [[ -d "${dotdir}" ]] && \
           [[ "${dotdir}" != "/home/scott/.cache" ]] && \
           [[ "${dotdir}" != "/home/scott/.local/share/Trash" ]] && \
           [[ "${dotdir}" != "/home/scott/.mozilla" ]] && \
           [[ "${dotdir}" != "/home/scott/.config/google-chrome" ]] && \
           [[ "${dotdir}" != "/home/scott/.config/chromium" ]] && \
           [[ "${dotdir}" != "/home/scott/.config/BraveSoftware" ]] && \
           [[ "${dotdir}" != "/home/scott/.config/microsoft-edge" ]] && \
           [[ ! "${dotdir}" == *"plasma"* ]]; then
            
            # Check if not already in our config paths
            local already_included=false
            for path in "${CONFIG_PATHS[@]}"; do
                local expanded_path
                expanded_path="${path/\~/\/home\/scott}" || true
                if [[ "${dotdir}" == "${expanded_path}" || "${dotdir}" == "${expanded_path}/"* ]]; then
                    already_included=true
                    break
                fi
            done
            
            if [[ "${already_included}" == false ]]; then
                local dirname
                dirname=$(basename "${dotdir}") || true
                log "Found additional config directory: ${dirname}"
                
                # Create the target directory
                local target_dir
                target_dir="${BACKUP_PATH}/additional_configs/${dirname}"
                mkdir -p "${target_dir}"
                
                # Copy with the same structure
                cp -r "${dotdir}"/* "${target_dir}"/ 2>/dev/null || true
            fi
        fi
    done
    
    # Look for config files from installation scripts that might not be in our list
    # Store the results in a variable to avoid masking return values in a pipe
    local config_paths
    config_paths=$(grep -r --include="*.sh" "\.config" /documents/ 2>/dev/null | \
                  grep -v "KDE\|kde\|plasma\|firefox\|chrome\|browser" | \
                  grep -o -E "/home/scott/\.config/[a-zA-Z0-9_/-]+" | \
                  sort | uniq) || true
    
    if [[ -n "${config_paths}" ]]; then
        while read -r config_path; do
            local expanded_path
            expanded_path="${config_path}" || true
            if [[ -e "${expanded_path}" ]]; then
                local rel_path
                rel_path=${expanded_path//\/home\/scott/home}
                local target_dir
                target_dir="${BACKUP_PATH}/script_referenced_configs/$(dirname "${rel_path}")"
                mkdir -p "${target_dir}"
                cp -r "${expanded_path}" "${target_dir}"/ 2>/dev/null || true
                log "Backed up script-referenced config: ${expanded_path}"
            fi
        done <<< "${config_paths}"
    fi
}

# Run the function to find additional configs
find_additional_configs

# List of config paths to check (excluding browser and KDE configs)
CONFIG_PATHS=(
    # Shell and terminal configs
    /home/scott/.config/tmux
    /home/scott/.tmux.conf
    /home/scott/.config/starship.toml
    /home/scott/.zshrc
    /home/scott/.config/zsh
    /home/scott/.oh-my-zsh
    
    # Editor configs
    /home/scott/.config/nvim
    /home/scott/.vimrc
    /home/scott/.config/micro
    /home/scott/.nanorc
    /home/scott/.config/nano
    /home/scott/.config/Code/User/settings.json
    /home/scott/.config/Code/User/keybindings.json
    /home/scott/.config/zed/settings.json
    /home/scott/.config/zed/keymap.json
    
    # Development tools
    /home/scott/.config/gh
    /home/scott/.config/git
    /home/scott/.gitconfig
    /home/scott/.gitignore_global
    /home/scott/.git-credentials
    /home/scott/.config/docker
    /home/scott/.docker
    /home/scott/.config/composer
    /home/scott/.composer
    /home/scott/.config/pip
    /home/scott/.pip
    /home/scott/.npmrc
    /home/scott/.config/configstore
    /home/scott/.wp-cli
    /home/scott/.wrangler
    /home/scott/.java
    
    # NodeJS and PHP configs
    /home/scott/.config/typescript
    /home/scott/.config/phpcs
    /home/scott/.eslintrc.json
    /home/scott/.prettierrc
    /home/scott/.config/php
    
    # Network and utility tools
    /home/scott/.config/remmina
    /home/scott/.config/filezilla
    /home/scott/.ssh/config
    /home/scott/.config/htop
    /home/scott/.local/share/rclone
    
    # Audio and video configs
    /home/scott/.config/audacity
    /home/scott/.config/vlc
    /home/scott/.config/pipewire
    /home/scott/.config/wireplumber
    /home/scott/.config/jack
    /home/scott/.asoundrc
    
    # Application configs
    /home/scott/.config/ollama
    /home/scott/.config/VirtualBox
    /home/scott/.config/appimagelauncher
    /home/scott/.local/share/appimagelauncher
    /home/scott/.local/share/applications/*.desktop
    
    # Terminal utilities
    /home/scott/.config/btop
    /home/scott/.config/ranger
    /home/scott/.nnnrc
    /home/scott/.local/bin
    /home/scott/bin
    
    # AppImages and custom applications
    /home/scott/Apps
    /home/scott/Templates/Development
    
    # Backup and system tools  
    /home/scott/config-backups
    /home/scott/.local/share/plasma_notes
)

for config_path in "${CONFIG_PATHS[@]}"; do
    expanded_path=$(eval echo "${config_path}") || true
    if [[ -e "${expanded_path}" ]]; then
        # Create target directory structure
        rel_path=${expanded_path//\/home\/scott/home}
        target_dir="${BACKUP_PATH}/config_files/$(dirname "${rel_path}")"
        mkdir -p "${target_dir}"
        
        # Copy the file or directory
        cp -r "${expanded_path}" "${target_dir}/"
        log "Config backed up: ${expanded_path}"
    fi
done

# Database dumps
log "Creating database dumps"
mkdir -p "${BACKUP_PATH}/databases"

# If MySQL/MariaDB is installed
if command -v mysql &> /dev/null; then
    if [[ -f /home/scott/.my.cnf ]]; then
        # Store databases in a variable
        databases=$(mysql -e "SHOW DATABASES" | grep -v "Database\|information_schema\|performance_schema\|sys\|mysql") || true
        
        db_count=0
        if [[ -n "${databases}" ]]; then
            while read -r db; do
                if [[ -n "${db}" ]]; then
                    mysqldump "${db}" > "${BACKUP_PATH}/databases/${db}.sql"
                    log "MySQL database ${db} backed up"
                    ((db_count++))
                fi
            done <<< "${databases}"
        fi
        
        # Compress database dumps if any were created
        if [[ ${db_count} -gt 0 ]]; then
            DB_ARCHIVE="${BACKUP_DIR}/${TIMESTAMP}-db.tar.gz"
            tar -czf "${DB_ARCHIVE}" -C "${BACKUP_PATH}" databases
            log "All database dumps compressed to ${DB_ARCHIVE}"
        fi
        
        # Copy MySQL config
        cp "/home/scott/.my.cnf" "${BACKUP_PATH}/my.cnf"
    else
        log "MySQL credentials not found in ~/.my.cnf - skipping MySQL backups"
    fi
fi

# Backup PostgreSQL if installed
if command -v psql &> /dev/null; then
    log "Backing up PostgreSQL databases"
    
    # Check for .pgpass
    if [[ -f /home/scott/.pgpass ]]; then
        cp /home/scott/.pgpass "${BACKUP_PATH}/home_configs/"
        log ".pgpass configuration backed up"
    fi
    
    # Try to dump databases using pg_dumpall
    if pg_dumpall -c > "${BACKUP_PATH}/databases/postgres_all.sql" 2>/dev/null; then
        log "PostgreSQL databases backed up using pg_dumpall"
    else
        log "Could not backup PostgreSQL databases, may need authentication"
    fi
fi

# Crontabs
mkdir -p "${BACKUP_PATH}/system"
if crontab -l &> /dev/null; then
    crontab -l > "${BACKUP_PATH}/system/user_crontab.txt"
    log "User crontab backed up"
    
    # Capture root crontab output separately
    root_crontab=$(sudo crontab -l 2>/dev/null) || true
    if [[ -n "${root_crontab}" ]]; then
        echo "${root_crontab}" > "${BACKUP_PATH}/system/root_crontab.txt"
        log "Root crontab backed up"
    fi
fi

# Backup Desktop folder - do not follow symlinks
log "Backing up Desktop files"
desktop_files=$(ls -A /home/scott/Desktop 2>/dev/null) || true
if [[ -d /home/scott/Desktop && -n "${desktop_files}" ]]; then
    DESKTOP_ARCHIVE="${BACKUP_DIR}/desktop_${TIMESTAMP}.tar.gz"
    tar -hczf "${DESKTOP_ARCHIVE}" -C "/home/scott" Desktop
    log "Desktop files backed up to ${DESKTOP_ARCHIVE}"
else
    log "Desktop folder does not exist or is empty, skipping"
fi

# Create a compressed archive of all remaining files (not already in archives)
log "Creating compressed archive of all backup files"
MAIN_ARCHIVE="${BACKUP_DIR}/main_backup_${TIMESTAMP}.tar.gz"
tar -czf "${MAIN_ARCHIVE}" -C "${BACKUP_DIR}" \
    --exclude="*.tar.gz" \
    --exclude="*.tar.gz.gpg" \
    --exclude="*-db.tar.gz" \
    "${BACKUP_NAME}"
log "Main backup archive created at ${MAIN_ARCHIVE}"

# Create a metadata file with summary information
log "Creating backup metadata file"
META_FILE="${BACKUP_DIR}/backup_metadata_${TIMESTAMP}.txt"

# Get system information separately to avoid masking return values
os_info=$(lsb_release -ds 2>/dev/null) || true
if [[ -z "${os_info}" ]]; then
    pretty_name=$(grep PRETTY_NAME /etc/os-release) || true
    os_info=$(echo "${pretty_name}" | cut -d= -f2- | tr -d '"') || true
    if [[ -z "${os_info}" ]]; then
        os_info="Unknown"
    fi
fi

kernel_info=$(uname -r) || kernel_info="Unknown"
date_info=$(date) || date_info="Unknown"
hostname_info=$(hostname) || hostname_info="Unknown"

# Get config file counts
config_dirs_count=$(find "${BACKUP_PATH}/config_files" -type d | wc -l || true) || config_dirs_count="Unknown"
config_files_count=$(find "${BACKUP_PATH}/config_files" -type f | wc -l || true) || config_files_count="Unknown"

# Find installation scripts
installation_scripts=$(find /home -name "[0-9][0-9]-*.sh" -type f 2>/dev/null) || installation_scripts=""

{
    echo "===== BACKUP METADATA ====="
    echo "Date: ${date_info}"
    echo "User: ${USER}"
    echo "Hostname: ${hostname_info}"
    
    echo -e "\n===== SYSTEM INFORMATION ====="
    echo "OS: ${os_info}"
    echo "Kernel: ${kernel_info}"
    
    echo -e "\n===== CONFIGURATION FILES SUMMARY ====="
    echo "Config directories backed up: ${config_dirs_count}"
    echo "Config files backed up: ${config_files_count}"
    
    echo -e "\n===== INSTALLATION SCRIPTS FOUND ====="
    # Find all relevant installation scripts - safer approach
    if [[ -n "${installation_scripts}" ]]; then
        while IFS= read -r script; do
            script_name=$(basename "${script}") || script_name="${script}"
            echo "- ${script_name}"
        done <<< "${installation_scripts}"
    else
        echo "No installation scripts found"
    fi
    
    echo -e "\n===== BACKUP FILE MANIFEST ====="
    echo "SSH Archive (encrypted): ${SSH_ARCHIVE}"
    echo "Databases Archive: ${DB_ARCHIVE}"
    echo "Desktop Files Archive: ${DESKTOP_ARCHIVE}"
    echo "Main Backup Archive: ${MAIN_ARCHIVE}"
    
    echo -e "\n===== IMPORTANT PATHS SUMMARY ====="
    echo "Paths containing configurations:"
    for config_path in "${CONFIG_PATHS[@]}"; do
        expanded_path=$(eval echo "${config_path}") || true
        if [[ -e "${expanded_path}" ]]; then
            echo "- ${expanded_path}"
        fi
    done
} > "${META_FILE}"

# Create a final tar archive containing all compressed archives
log "Creating final archive containing all compressed archives"
FINAL_ARCHIVE="${BACKUP_DIR}/complete_backup_${TIMESTAMP}.tar"

# Get the list of archives to include
archive_list=$(find "${BACKUP_DIR}" -maxdepth 1 \( -name "*.tar.gz" -o -name "*.tar.gz.gpg" -o -name "*-db.tar.gz" \) -printf "%f\n") || true

tar -cf "${FINAL_ARCHIVE}" -C "${BACKUP_DIR}" "${META_FILE##*/}"

# Add each archive file individually to the final archive
if [[ -n "${archive_list}" ]]; then
    while IFS= read -r archive; do
        tar -rf "${FINAL_ARCHIVE}" -C "${BACKUP_DIR}" "${archive}"
    done <<< "${archive_list}"
fi
log "Final archive created at ${FINAL_ARCHIVE}"

log "Critical data backup completed successfully"
echo "=================================================="
echo "Backup completed successfully!"
echo "Complete backup location: ${FINAL_ARCHIVE}"
echo "Individual archives:"
echo "  - SSH (encrypted): ${SSH_ARCHIVE}"
echo "  - Databases: ${DB_ARCHIVE}"
echo "  - Desktop files: ${DESKTOP_ARCHIVE}"
echo "  - Main backup: ${MAIN_ARCHIVE}"
echo "  - Metadata file: ${META_FILE}"
echo "=================================================="
echo "To extract specific archives from the complete backup:"
echo "tar -xf ${FINAL_ARCHIVE} [archive-name.tar.gz]"
echo "=================================================="

# Clean up the uncompressed backup directory if everything succeeded
rm -rf "${BACKUP_PATH}"
