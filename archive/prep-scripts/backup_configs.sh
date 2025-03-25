#!/bin/bash

# Configuration backup script
# This script reads a CSV file of program config paths, validates their existence,
# and backs them up to /restart/config-backup/ preserving path structure and permissions

# Set variables
CSV_FILE="programs_config.csv"
BACKUP_DIR="/restart/config-backup"
LOG_FILE="backup.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Array to store valid paths
valid_paths=()

# Function to log messages
log_info() {
    echo "[${DATE}] INFO: $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo "[${DATE}] WARNING: $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[${DATE}] ERROR: $1" | tee -a "${LOG_FILE}"
}

# Function to check if a path is a system path (requiring sudo)
is_system_path() {
    local path="$1"
    if [[ "${path}" == /etc/* || "${path}" == /usr/* || "${path}" == /var/* || "${path}" == /opt/* ]]; then
        return 0  # True - is a system path
    else
        return 1  # False - not a system path
    fi
}

# Ensure backup directory exists (using sudo since it's in /restart)
sudo mkdir -p "${BACKUP_DIR}" || { log_error "Failed to create backup directory: ${BACKUP_DIR}"; exit 1; }
sudo chmod 755 "${BACKUP_DIR}" || { log_error "Failed to set permissions on backup directory"; exit 1; }

log_info "Starting configuration backup process"

# Skip header if present
if [[ -f "${CSV_FILE}" ]]; then
    # Check if first line is a header
    first_line=$(head -n 1 "${CSV_FILE}")
    if [[ "${first_line}" == "Program"*"Config"* ]]; then
        # Skip header and process remaining lines
        csv_content=$(tail -n +2 "${CSV_FILE}")
    else
        # No header, use the whole file
        csv_content=$(cat "${CSV_FILE}")
    fi
else
    log_error "CSV file not found: ${CSV_FILE}"
    exit 1
fi

# Validate paths and collect valid ones
while IFS=, read -r program_name config_path || [[ -n "${program_name}" ]]; do
    # Skip empty lines
    if [[ -z "${program_name}" || -z "${config_path}" ]]; then
        continue
    fi

    # Replace ~ with the actual home directory
    expanded_path="${config_path/#\~/${HOME}}"
    
    # Check if path exists (file, directory, or symlink)
    if [[ -e "${expanded_path}" ]] || [[ -L "${expanded_path}" ]]; then
        valid_paths+=("${expanded_path}")
        log_info "Found valid path: ${expanded_path}"
    else
        log_warning "Source path does not exist: ${expanded_path}"
    fi
done <<< "${csv_content}"

# Check if any valid paths were found
if [[ ${#valid_paths[@]} -eq 0 ]]; then
    log_error "No configuration files found in ${CSV_FILE}"
    exit 1
fi

log_info "Found ${#valid_paths[@]} valid configuration paths to backup"
# Create all target directories first using sudo
log_info "Creating target directories for all paths"
for path in "${valid_paths[@]}"; do
    target_dir="${BACKUP_DIR}$(dirname "${path}")"
    if sudo mkdir -p "${target_dir}"; then
        log_info "Created directory: ${target_dir}"
    else
        log_error "Failed to create directory: ${target_dir}"
    fi
done

# Create backup for each valid path (always using sudo)
for path in "${valid_paths[@]}"; do
    if is_system_path "${path}"; then
        log_info "Backing up system path: ${path}"
    else
        log_info "Backing up user path: ${path}"
    fi
    
    # Use sudo for rsync to ensure we can write to all directories
    if sudo rsync -aL --relative "${path}" "${BACKUP_DIR}"; then
        log_info "Successfully backed up: ${path}"
    else
        log_error "Failed to backup: ${path}"
    fi
done

log_info "Backup process completed. Files stored in ${BACKUP_DIR}"

# Ensure the backup directory has appropriate ownership and permissions
if [[ "${BACKUP_DIR}" == /restart* ]]; then
    # Set ownership of system files to root:root
    # Use a temporary file to store paths to avoid pipe issues
    temp_file=$(mktemp)
    sudo find "${BACKUP_DIR}/etc" "${BACKUP_DIR}/usr" "${BACKUP_DIR}/var" "${BACKUP_DIR}/opt" -type f -o -type d 2>/dev/null | tee "${temp_file}" >/dev/null || true
    
    # Process each path from the temp file
    while read -r path; do 
        sudo chown root:root "${path}" 2>/dev/null
    done < "${temp_file}"
    
    # Clean up temp file
    rm -f "${temp_file}"
    
    # Set ownership of user files to current user
    if [[ -d "${BACKUP_DIR}/home" ]]; then
        # Store command results in variables to avoid masking return values
        user=$(whoami)
        group=$(id -gn)
        sudo chown -R "${user}:${group}" "${BACKUP_DIR}/home" 2>/dev/null
        log_info "Set ownership of user files to current user"
    fi
    
    # Make sure directories are accessible but preserve file permissions
    # Find all directories and set them to 755
    sudo find "${BACKUP_DIR}" -type d -exec chmod 755 {} \;
    log_info "Set permissions on backup directories while preserving file permissions"
    
    # Ensure SSH keys have restricted permissions if they exist
    # Store whoami result in a variable to avoid masking return value
    user=$(whoami)
    if [[ -d "${BACKUP_DIR}/home/${user}/.ssh" ]]; then
        log_info "Securing SSH directory permissions"
        sudo find "${BACKUP_DIR}/home/${user}/.ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
        sudo find "${BACKUP_DIR}/home/${user}/.ssh" -name "authorized_keys" -o -name "known_hosts" -exec chmod 600 {} \;
    fi
fi

exit 0
