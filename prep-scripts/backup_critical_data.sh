#!/bin/bash
# shellcheck disable=SC2317

# Enhanced backup_critical_data.sh
# This script performs a comprehensive backup of critical data
# with special handling for SSH keys, sourced files, and database backups

# Define global variables
BACKUP_STATUS=0
BACKUP_DIR="/restart/prep/backups"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S || true)
BACKUP_NAME="critical_data_${TIMESTAMP}"
BACKUP_PATH=""
COMPRESS_ONLY=false
NO_COMPRESS=false
LOG_FILE=""

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-compress)
                NO_COMPRESS=true
                shift
                ;;
            --compress)
                COMPRESS_ONLY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --no-compress    Perform backup without final compression and cleanup"
                echo "  --compress       Only perform final compression and cleanup"
                echo "  --help           Display this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Validate arguments
    if [[ "${COMPRESS_ONLY}" == true && "${NO_COMPRESS}" == true ]]; then
        echo "Error: Cannot use both --compress and --no-compress options together"
        exit 1
    fi
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_no=$1
    local command=$2
    
    log "ERROR: Command '${command}' failed on line ${line_no} with exit code ${exit_code}"
    BACKUP_STATUS=1
    return "${exit_code}"
}

# Set up error trap - capture the command being executed
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Find the most recent backup directory
find_latest_backup() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo "Backup directory does not exist: ${BACKUP_DIR}"
        return 1
    fi
    
    # Find the most recent critical_data_* directory
    local latest_dir
    latest_dir=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "critical_data_*" | sort -r | head -n 1)
    
    if [[ -z "${latest_dir}" ]]; then
        echo "No existing backup directories found in ${BACKUP_DIR}"
        return 1
    fi
    
    # Extract just the directory name without the path
    BACKUP_NAME=$(basename "${latest_dir}")
    echo "Found latest backup directory: ${BACKUP_NAME}"
    return 0
}

# Initialize backup environment
initialize_backup() {
    # Create backup directory if it doesn't exist
    if ! mkdir -p "${BACKUP_DIR}" 2>/dev/null; then
        echo "Failed to create backup directory: ${BACKUP_DIR}"
        return 1
    fi

    # If in compress-only mode, find the latest backup directory
    if [[ "${COMPRESS_ONLY}" == true ]]; then
        if ! find_latest_backup; then
            echo "Failed to find latest backup directory for compression"
            return 1
        fi
    fi

    # Set up backup path
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
    
    # Create the directory if it doesn't exist (not needed in compress-only mode)
    if [[ "${COMPRESS_ONLY}" != true ]]; then
        if ! mkdir -p "${BACKUP_PATH}" 2>/dev/null; then
            echo "Failed to create backup path: ${BACKUP_PATH}"
            return 1
        fi
    elif [[ ! -d "${BACKUP_PATH}" ]]; then
        echo "Backup directory does not exist: ${BACKUP_PATH}"
        return 1
    fi

    # Initialize log file
    LOG_FILE="${BACKUP_PATH}/backup.log"
    if [[ "${COMPRESS_ONLY}" != true ]]; then
        touch "${LOG_FILE}" || {
            echo "Failed to create log file"
            return 1
        }
    elif [[ ! -f "${LOG_FILE}" ]]; then
        # In compress-only mode, create the log file if it doesn't exist
        touch "${LOG_FILE}" || {
            echo "Failed to create log file"
            return 1
        }
    fi

    # Log starting information
    log "=== Backup started at $(date) ==="
    log "Mode: $([[ ${COMPRESS_ONLY} == true ]] && echo "Compression only" || 
                [[ ${NO_COMPRESS} == true ]] && echo "No compression" || 
                echo "Full backup")"
    
    return 0
}

# Log function
log() {
    local timestamp
    timestamp=$(date +%H:%M:%S) || true
    echo "[${timestamp}] $1"
    echo "[${timestamp}] $1" >> "${LOG_FILE}" 2>/dev/null
}

# Check if a command exists, log result
command_exists() {
    local cmd="$1"
    if command -v "${cmd}" &>/dev/null; then
        log "Command '${cmd}' is available"
        return 0
    else
        log "Command '${cmd}' is not available"
        return 1
    fi
}

# Safely execute a command with error handling
safe_execute() {
    local cmd_description="$1"
    shift
    
    log "Executing: ${cmd_description}"
    
    if "$@" 2>>"${LOG_FILE}.err"; then
        log "${cmd_description} completed successfully"
        return 0
    else
        local exit_code=$?
        log "ERROR: ${cmd_description} failed with exit code ${exit_code}"
        BACKUP_STATUS=1
        return "${exit_code}"
    fi
}

# Back up SSH keys with encryption
backup_ssh_keys() {
    if [[ ! -d /home/scott/.ssh ]]; then
        log "SSH directory not found, skipping SSH backup"
        return 0
    fi

    log "Backing up SSH keys with encryption"
    mkdir -p "${BACKUP_PATH}/ssh_backup" || {
        log "Failed to create SSH backup directory"
        BACKUP_STATUS=1
        return 1
    }
    
    # Use sudo to copy SSH files while preserving permissions
    if ! sudo cp -p -r /home/scott/.ssh/. "${BACKUP_PATH}/ssh_backup/" 2>>"${LOG_FILE}.err"; then
        log "Failed to copy SSH files"
        BACKUP_STATUS=1
        return 1
    fi
    
    # Fix ownership of the copied files to match the backup directory
    if ! sudo chown -R "$(id -u):$(id -g)" "${BACKUP_PATH}/ssh_backup/" 2>>"${LOG_FILE}.err"; then
        log "Failed to fix ownership of SSH backup files"
        BACKUP_STATUS=1
        return 1
    fi
    
    # Create encrypted archive of SSH config
    ENCRYPTION_PASSWORD="Storm!Stream12"
    SSH_ARCHIVE="${BACKUP_PATH}/ssh_encrypted_${TIMESTAMP}.tar.gz.gpg"
    
    # Create tar archive first, using sudo to ensure access to all files
    if ! sudo tar -czf "${BACKUP_PATH}/ssh_backup_temp.tar.gz" -C "${BACKUP_PATH}" ssh_backup 2>>"${LOG_FILE}.err"; then
        log "Failed to create SSH backup archive"
        BACKUP_STATUS=1
        return 1
    fi
    
    if ! sudo chown "$(id -u):$(id -g)" "${BACKUP_PATH}/ssh_backup_temp.tar.gz" 2>>"${LOG_FILE}.err"; then
        log "Failed to fix ownership of SSH backup archive"
        BACKUP_STATUS=1
        return 1
    fi
    
    # Encrypt the archive with the provided password
    if ! gpg --batch --yes --passphrase "${ENCRYPTION_PASSWORD}" \
        --cipher-algo AES256 \
        -o "${SSH_ARCHIVE}" \
        --symmetric "${BACKUP_PATH}/ssh_backup_temp.tar.gz" 2>>"${LOG_FILE}.err"; then
        log "Failed to encrypt SSH backup archive"
        BACKUP_STATUS=1
        return 1
    fi
    
    # Remove the unencrypted files with sudo
    sudo rm -rf "${BACKUP_PATH}/ssh_backup" 2>/dev/null
    sudo rm -f "${BACKUP_PATH}/ssh_backup_temp.tar.gz" 2>/dev/null
    
    log "SSH keys backed up and encrypted to ${SSH_ARCHIVE}"
    return 0
}

# Back up home directory config files
backup_home_configs() {
    log "Backing up home directory configuration files"
    
    if ! mkdir -p "${BACKUP_PATH}/home_configs"; then
        log "Failed to create home_configs directory"
        BACKUP_STATUS=1
        return 1
    fi

    # Git config
    if [[ -f /home/scott/.gitconfig ]]; then
        if cp /home/scott/.gitconfig "${BACKUP_PATH}/home_configs/" 2>>"${LOG_FILE}.err"; then
            log "Git configuration backed up"
        else
            log "Failed to backup Git configuration"
            BACKUP_STATUS=1
        fi
    fi

    # Nano configuration
    if [[ -f /home/scott/.nanorc ]]; then
        if cp /home/scott/.nanorc "${BACKUP_PATH}/home_configs/" 2>>"${LOG_FILE}.err"; then
            log ".nanorc backed up"
        else
            log "Failed to backup .nanorc"
            BACKUP_STATUS=1
        fi
    fi

    # Shell config files
    for file in /home/scott/.bashrc /home/scott/.bash_profile /home/scott/bash_aliases /home/scott/.profile /home/scott/.zshrc /home/scott/.zsh_history; do
        if [[ -f "${file}" ]]; then
            if cp "${file}" "${BACKUP_PATH}/home_configs/" 2>>"${LOG_FILE}.err"; then
                basename_result=$(basename "${file}") || true
                log "${basename_result} backed up"
            else
                basename_result=$(basename "${file}") || true
                log "Failed to backup ${basename_result}"
                BACKUP_STATUS=1
            fi
        fi
    done

    return 0
}

# Back up files sourced in .bashrc
backup_sourced_files() {
    if [[ ! -f /home/scott/.bashrc ]]; then
        log "No .bashrc file found, skipping sourced files backup"
        return 0
    fi

    log "Checking .bashrc for sourced files"
    
    if ! mkdir -p "${BACKUP_PATH}/bashrc_sourced"; then
        log "Failed to create bashrc_sourced directory"
        BACKUP_STATUS=1
        return 1
    fi
    
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
                
                if ! mkdir -p "${target_dir}"; then
                    log "Failed to create directory for sourced file: ${expanded_file}"
                    BACKUP_STATUS=1
                    continue
                fi
                
                # Copy the file
                if cp "${expanded_file}" "${target_dir}/$(basename "${expanded_file}")" 2>>"${LOG_FILE}.err"; then
                    log "Sourced file backed up: ${expanded_file}"
                else
                    log "Failed to backup sourced file: ${expanded_file}"
                    BACKUP_STATUS=1
                fi
            fi
        done <<< "${sourced_files}"
    else
        log "No additional sourced files found in .bashrc"
    fi

    return 0
}

# Scan for additional configuration files
find_additional_configs() {
    log "Scanning for additional configuration files..."
    
    if ! mkdir -p "${BACKUP_PATH}/additional_configs"; then
        log "Failed to create additional_configs directory"
        BACKUP_STATUS=1
        return 1
    fi
    
    # Look for other dot directories in home that might contain configs
    for dotdir in /home/scott/.[a-zA-Z]*; do
        # Skip already included directories and those we want to exclude
        if [[ ! -d "${dotdir}" ]] || \
           [[ "${dotdir}" == "/home/scott/.cache" ]] || \
           [[ "${dotdir}" == "/home/scott/.local/share/Trash" ]] || \
           [[ "${dotdir}" == "/home/scott/.mozilla" ]] || \
           [[ "${dotdir}" == "/home/scott/.config/google-chrome" ]] || \
           [[ "${dotdir}" == "/home/scott/.config/chromium" ]] || \
           [[ "${dotdir}" == "/home/scott/.config/BraveSoftware" ]] || \
           [[ "${dotdir}" == "/home/scott/.config/microsoft-edge" ]] || \
           [[ "${dotdir}" == *"plasma"* ]]; then
            continue
        fi
        
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
            if ! mkdir -p "${target_dir}"; then
                log "Failed to create directory for additional config: ${dirname}"
                BACKUP_STATUS=1
                continue
            fi
            
            # Copy with the same structure
            if cp -r "${dotdir}"/* "${target_dir}"/ 2>/dev/null; then
                log "Additional config directory copied: ${dirname}"
            else
                # This might fail if there are no files, which is okay
                log "Note: Could not copy all files from ${dirname} (may be empty or have permission issues)"
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
        if ! mkdir -p "${BACKUP_PATH}/script_referenced_configs"; then
            log "Failed to create script_referenced_configs directory"
            BACKUP_STATUS=1
            return 1
        fi
        
        while read -r config_path; do
            local expanded_path
            expanded_path="${config_path}" || true
            if [[ -e "${expanded_path}" ]]; then
                local rel_path
                rel_path=${expanded_path//\/home\/scott/home}
                local target_dir
                target_dir="${BACKUP_PATH}/script_referenced_configs/$(dirname "${rel_path}")"
                
                if ! mkdir -p "${target_dir}"; then
                    log "Failed to create directory for script-referenced config: ${expanded_path}"
                    BACKUP_STATUS=1
                    continue
                fi
                
                if cp -r "${expanded_path}" "${target_dir}"/ 2>/dev/null; then
                    log "Backed up script-referenced config: ${expanded_path}"
                else
                    log "Failed to backup script-referenced config: ${expanded_path}"
                    BACKUP_STATUS=1
                fi
            fi
        done <<< "${config_paths}"
    fi

    return 0
}

# Back up configuration files
backup_config_files() {
    log "Backing up configuration files referenced in installation scripts"
    
    if ! mkdir -p "${BACKUP_PATH}/config_files"; then
        log "Failed to create config_files directory"
        BACKUP_STATUS=1
        return 1
    fi

    # Define the list of config paths to check
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
            
            if ! mkdir -p "${target_dir}"; then
                log "Failed to create directory for config: ${expanded_path}"
                BACKUP_STATUS=1
                continue
            fi
            
            # Copy the file or directory
            if cp -r "${expanded_path}" "${target_dir}/" 2>>"${LOG_FILE}.err"; then
                log "Config backed up: ${expanded_path}"
            else
                log "Failed to backup config: ${expanded_path}"
                BACKUP_STATUS=1
            fi
        fi
    done

    return 0
}

# Back up database dumps
backup_databases() {
    log "Creating database dumps"
    
    if ! mkdir -p "${BACKUP_PATH}/databases"; then
        log "Failed to create database backup directory"
        BACKUP_STATUS=1
        return 1
    fi

    # MySQL/MariaDB backup
    if command_exists mysql; then
        if [[ -f /home/scott/.my.cnf ]]; then
            # Store databases in a variable
            databases=$(mysql -e "SHOW DATABASES" | grep -v "Database\|information_schema\|performance_schema\|sys\|mysql") || true
            
            db_count=0
            db_errors=0
            if [[ -n "${databases}" ]]; then
                while read -r db; do
                    if [[ -n "${db}" ]]; then
                        dump_file="${BACKUP_PATH}/databases/${db}.sql"
                        log "Attempting to backup database: ${db}"
                        if mysqldump "${db}" > "${dump_file}" 2>>"${BACKUP_PATH}/mysql_errors.log"; then
                            if [[ -s "${dump_file}" ]]; then
                                log "MySQL database ${db} backed up successfully"
                                ((db_count++))
                            else
                                log "Failed to backup MySQL database ${db} (empty dump)"
                                rm -f "${dump_file}"
                                ((db_errors++))
                                BACKUP_STATUS=1
                            fi
                        else
                            dump_error=$?
                            log "Failed to backup MySQL database ${db} with exit code ${dump_error}"
                            rm -f "${dump_file}"
                            ((db_errors++))
                            BACKUP_STATUS=1
                        fi
                    fi
                done <<< "${databases}"
                
                log "Database backup: ${db_count} succeeded, ${db_errors} failed"
            else
                log "No MySQL databases found to backup"
            fi
            
            # Copy MySQL config
            if ! cp "/home/scott/.my.cnf" "${BACKUP_PATH}/my.cnf" 2>/dev/null; then
                log "Failed to backup MySQL configuration"
                BACKUP_STATUS=1
            fi
        else
            log "MySQL configuration file not found, skipping MySQL backup"
        fi
    else
        log "MySQL not installed, skipping MySQL backup"
    fi


    return 0
}

# Back up crontabs
backup_crontabs() {
    log "Backing up crontabs"
    
    if ! mkdir -p "${BACKUP_PATH}/system"; then
        log "Failed to create system backup directory"
        BACKUP_STATUS=1
        return 1
    fi

    # User crontab
    if crontab -l &> /dev/null; then
        if ! crontab -l > "${BACKUP_PATH}/system/user_crontab.txt" 2>/dev/null; then
            log "Failed to backup user crontab"
            BACKUP_STATUS=1
        else
            log "User crontab backed up"
        fi
        
        # Capture root crontab output separately
        root_crontab=$(sudo crontab -l 2>/dev/null) || true
        if [[ -n "${root_crontab}" ]]; then
            if ! echo "${root_crontab}" > "${BACKUP_PATH}/system/root_crontab.txt"; then
                log "Failed to backup root crontab"
                BACKUP_STATUS=1
            else
                log "Root crontab backed up"
            fi
        fi
    else
        log "No user crontab found, skipping crontab backup"
    fi

    return 0
}

# Back up Desktop folder
backup_desktop() {
    log "Backing up Desktop files"
    
    desktop_files=$(ls -A /home/scott/Desktop 2>/dev/null) || true
    if [[ -d /home/scott/Desktop && -n "${desktop_files}" ]]; then
        DESKTOP_ARCHIVE="${BACKUP_DIR}/desktop_${TIMESTAMP}.tar.gz"
        if ! tar -hczf "${DESKTOP_ARCHIVE}" -C "/home/scott" Desktop 2>>"${LOG_FILE}.err"; then
            log "Failed to backup Desktop files"
            BACKUP_STATUS=1
            return 1
        else
            log "Desktop files backed up to ${DESKTOP_ARCHIVE}"
        fi
    else
        log "Desktop folder does not exist or is empty, skipping"
    fi

    return 0
}

# Compress database dumps
compress_databases() {
    if [[ ! -d "${BACKUP_PATH}/databases" ]]; then
        log "No database dumps to compress"
        return 0
    fi
    
    # Check if directory has any files
    if [[ -z "$(ls -A "${BACKUP_PATH}/databases" 2>/dev/null)" ]]; then
        log "No database dumps to compress (directory empty)"
        return 0
    fi
    
    DB_ARCHIVE="${BACKUP_DIR}/${TIMESTAMP}-db.tar.gz"
    log "Compressing database dumps..."
    
    if ! tar -czf "${DB_ARCHIVE}" -C "${BACKUP_PATH}" databases/ 2>>"${LOG_FILE}.err"; then
        log "Failed to compress database dumps"
        BACKUP_STATUS=1
        return 1
    fi
    
    log "Database dumps compressed successfully to ${DB_ARCHIVE}"
    rm -rf "${BACKUP_PATH}/databases"
    
    return 0
}

# Create metadata file
create_metadata() {
    log "Creating backup metadata file"
    META_FILE="${BACKUP_DIR}/backup_metadata_${TIMESTAMP}.txt"

    {
        echo "Backup Metadata - ${TIMESTAMP}"
        echo "======================="
        echo "Operating System: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo 'Unknown')"
        echo "Kernel Version: $(uname -r || echo 'Unknown')"
        echo "Backup Date: $(date || echo 'Unknown')"
        echo "Hostname: $(hostname || echo 'Unknown')"
        echo "Backup Status: $([[ ${BACKUP_STATUS} -eq 0 ]] && echo 'Success' || echo 'Completed with errors')"
        echo "Compression Mode: $([[ ${NO_COMPRESS} == true ]] && echo 'No compression' || [[ ${COMPRESS_ONLY} == true ]] && echo 'Compression only' || echo 'Full backup with compression')"
        
        echo -e "\n===== BACKUP FILE MANIFEST ====="
        [[ -f "${SSH_ARCHIVE}" ]] && echo "SSH Archive (encrypted): ${SSH_ARCHIVE}"
        [[ -f "${DB_ARCHIVE}" ]] && echo "Databases Archive: ${DB_ARCHIVE}"
        [[ -f "${DESKTOP_ARCHIVE}" ]] && echo "Desktop Files Archive: ${DESKTOP_ARCHIVE}"
        [[ -f "${MAIN_ARCHIVE}" ]] && echo "Main Backup Archive: ${MAIN_ARCHIVE}"
        [[ -f "${FINAL_ARCHIVE}" ]] && echo "Final Archive: ${FINAL_ARCHIVE}"
    } > "${META_FILE}" || {
        log "Failed to create metadata file"
        BACKUP_STATUS=1
        return 1
    }

    log "Metadata file created at ${META_FILE}"
    return 0
}

# Perform compression of all backup files
compress_backup() {
    # Compress databases if needed
    if [[ -d "${BACKUP_PATH}/databases" ]]; then
        compress_databases
    fi
    
    # Create a compressed archive of all remaining files (not already in archives)
    log "Creating compressed archive of all backup files"
    MAIN_ARCHIVE="${BACKUP_DIR}/main_backup_${TIMESTAMP}.tar.gz"
    if ! tar -czf "${MAIN_ARCHIVE}" -C "${BACKUP_DIR}" \
        --exclude="*.tar.gz" \
        --exclude="*.tar.gz.gpg" \
        --exclude="*-db.tar.gz" \
        "${BACKUP_NAME}" 2>>"${LOG_FILE}.err"; then
        log "Failed to create main backup archive"
        BACKUP_STATUS=1
        return 1
    else
        log "Main backup archive created at ${MAIN_ARCHIVE}"
    fi
    
    # Create metadata before final archive
    create_metadata
    
    # Create a final tar archive containing all compressed archives
    log "Creating final archive containing all compressed archives"
    FINAL_ARCHIVE="${BACKUP_DIR}/complete_backup_${TIMESTAMP}.tar"

    # Get the list of archives to include
    archive_list=$(find "${BACKUP_DIR}" -maxdepth 1 \
        \( -name "*.tar.gz" -o -name "*.tar.gz.gpg" -o -name "*-db.tar.gz" \) \
        -not -name "complete_backup_*.tar" \
        -printf "%f\n") || true

    if ! tar -cf "${FINAL_ARCHIVE}" -C "${BACKUP_DIR}" "backup_metadata_${TIMESTAMP}.txt" 2>>"${LOG_FILE}.err"; then
        log "Failed to create initial final archive with metadata"
        BACKUP_STATUS=1
        return 1
    fi

    # Add each archive file individually to the final archive
    if [[ -n "${archive_list}" ]]; then
        while IFS= read -r archive; do
            if ! tar -rf "${FINAL_ARCHIVE}" -C "${BACKUP_DIR}" "${archive}" 2>>"${LOG_FILE}.err"; then
                log "Failed to add ${archive} to final archive"
                BACKUP_STATUS=1
            fi
        done <<< "${archive_list}"
    fi
    
    log "Final archive created at ${FINAL_ARCHIVE}"
    
    # Clean up temporary files unless --no-compress was specified
    if [[ "${NO_COMPRESS}" != true ]]; then
        log "Cleaning up temporary files"
        rm -rf "${BACKUP_PATH}"
    else
        log "Keeping temporary files due to --no-compress option"
    fi
    
    return 0
}

# Display final status report
display_status() {
    if [[ ${BACKUP_STATUS} -eq 0 ]]; then
        log "All backup operations completed successfully"
        echo "=================================================="
        echo "Backup completed successfully!"
        echo "Location: ${BACKUP_DIR}"
        echo "Individual archives:"
        [[ -f "${SSH_ARCHIVE}" ]] && echo "  - SSH (encrypted): ${SSH_ARCHIVE}"
        [[ -f "${DB_ARCHIVE}" ]] && echo "  - Databases: ${DB_ARCHIVE}"
        [[ -f "${DESKTOP_ARCHIVE}" ]] && echo "  - Desktop files: ${DESKTOP_ARCHIVE}"
        [[ -f "${MAIN_ARCHIVE}" ]] && echo "  - Main backup: ${MAIN_ARCHIVE}"
        [[ -f "${FINAL_ARCHIVE}" ]] && echo "  - Final archive: ${FINAL_ARCHIVE}"
        echo "  - Metadata file: ${META_FILE}"
        echo "=================================================="
    else
        log "Backup completed with errors - check logs for details"
        echo "=================================================="
        echo "Backup completed with ERRORS!"
        echo "Please check the log file for details: ${LOG_FILE}"
        echo "=================================================="
    fi
}

# Main function to run backup operations
perform_backup() {
    # Skip backup operations if in compress-only mode
    if [[ "${COMPRESS_ONLY}" == true ]]; then
        log "Running in compression-only mode, skipping backup operations"
        return 0
    fi

    # Perform backup operations
    backup_ssh_keys
    backup_home_configs
    backup_sourced_files
    backup_config_files
    find_additional_configs
    backup_databases
    backup_crontabs
    backup_desktop
    
    log "All backup operations completed with status: ${BACKUP_STATUS}"
    return ${BACKUP_STATUS}
}

# Main script execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize backup environment
    if ! initialize_backup; then
        echo "Failed to initialize backup environment"
        exit 1
    fi
    
    # If in compress-only mode, skip to compression
    if [[ "${COMPRESS_ONLY}" == true ]]; then
        log "Running in compression-only mode"
    else
        # Perform backup operations
        perform_backup
    fi
    
    # Compress backup unless --no-compress is specified
    if [[ "${NO_COMPRESS}" != true ]]; then
        compress_backup
    else
        log "Skipping compression due to --no-compress option"
    fi
    
    # Display final status
    display_status
    
    # Return final status
    return ${BACKUP_STATUS}
}

# Run the script
main "$@"
exit ${BACKUP_STATUS}
