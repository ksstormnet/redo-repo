#!/bin/bash
# ============================================================================
# error_utils.sh
# ----------------------------------------------------------------------------
# Error handling utilities for installer scripts
# Provides functions for consistent error handling across all scripts
# ============================================================================

# Exit with error message
function exit_with_error() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "${message}"
    exit "${exit_code}"
}

# Try a command with error handling
function try_command() {
    local description="$1"
    local command="$2"
    local error_message="${3:-"Command failed"}"
    local exit_on_error="${4:-false}"
    
    log_info "${description}"
    
    # Log the command to the log file
    if [[ -n "${LOG_FILE:-}" ]]; then
        {
            echo "Command: ${command}"
            echo "----------------------------------------"
        } >> "${LOG_FILE}"
    fi
    
    # Execute the command
    local output
    local exit_code=0
    
    if ! output=$(eval "${command}" 2>&1); then
        exit_code=$?
    fi
    
    # Log the output to the log file
    if [[ -n "${LOG_FILE:-}" ]]; then
        {
            echo "${output}"
            echo "Exit code: ${exit_code}"
            echo "----------------------------------------"
        } >> "${LOG_FILE}"
    fi
    
    # Handle the result
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Command completed successfully"
        return 0
    else
        log_error "${error_message} (Exit code: ${exit_code})"
        
        # Show the output in case of error
        if [[ -n "${output}" ]]; then
            echo "Command output:"
            echo "----------------------------------------"
            echo "${output}"
            echo "----------------------------------------"
        fi
        
        if [[ "${exit_on_error}" == "true" ]]; then
            exit "${exit_code}"
        fi
        
        return "${exit_code}"
    fi
}

# Set up error handling traps
function setup_error_traps() {
    # Function to run on error - using 'function' keyword to make it clear this is a function definition
    # shellcheck disable=SC2317
    function trap_error() {
        local exit_code=$?
        local line_number=$1
        
        log_error "Error occurred at line ${line_number} with exit code ${exit_code}"
        
        # Get the command that failed
        local bash_command=${BASH_COMMAND}
        log_error "Failed command: ${bash_command}"
        
        # Get stack trace - using process substitution to avoid subshell issues
        local i=0
        local stack_trace=""
        
        # Use process substitution to capture caller output
        while read -r line func file < <(caller "${i}" 2>/dev/null || true); do
            stack_trace+="${i}: ${file}:${line} ${func}\n"
            ((i++))
        done
        
        # Log stack trace if available
        if [[ -n "${stack_trace}" ]]; then
            log_error "Stack trace:"
            echo -e "${stack_trace}"
        fi
        
        exit "${exit_code}"
    }
    
    # Set the trap - using single quotes to prevent expansion until trap is triggered
    trap 'trap_error $LINENO' ERR
}

# Handle command line errors
function handle_command_line_error() {
    local script_name="$1"
    local message="$2"
    
    echo "ERROR: ${message}" >&2
    echo "" >&2
    echo "Usage: ${script_name} [OPTIONS]" >&2
    echo "Try '${script_name} --help' for more information." >&2
    exit 1
}

# Show detailed error information from a file
function show_error_log() {
    local log_file="$1"
    local lines="${2:-20}"
    
    if [[ -f "${log_file}" ]]; then
        echo "Last ${lines} lines of error log:"
        echo "----------------------------------------"
        tail -n "${lines}" "${log_file}"
        echo "----------------------------------------"
        echo "Full log available at: ${log_file}"
    else
        log_error "Log file not found: ${log_file}"
    fi
}

# Verify command succeeded
function check_command_status() {
    local exit_code=$?
    local command_desc="$1"
    local error_message="${2:-"${command_desc} failed"}"
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "${error_message} (Exit code: ${exit_code})"
        return "${exit_code}"
    else
        log_success "${command_desc} completed successfully"
        return 0
    fi
}

# Run a command and ensure it succeeds
function ensure_command_succeeds() {
    local command="$1"
    local error_message="${2:-"Command failed"}"
    
    if ! eval "${command}"; then
        local exit_code=$?
        log_error "${error_message} (Exit code: ${exit_code})"
        exit "${exit_code}"
    fi
    
    return 0
}

# Check required commands
function check_required_commands() {
    local required_commands=("$@")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_commands+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Required commands not found: ${missing_commands[*]}"
        log_info "Please install the missing commands and try again."
        return 1
    fi
    
    return 0
}

# Validate environment
function validate_environment() {
    # Check if all required environment variables are set
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Required environment variables not set: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Handle cleanup on script exit
function setup_cleanup_trap() {
    local cleanup_function="$1"
    
    # Trap various signals to ensure cleanup is performed
    # Use single quotes to prevent expansion until trap is triggered
    trap '${cleanup_function}' EXIT
    trap '${cleanup_function}; exit 1' INT TERM HUP
    
    log_debug "Cleanup trap set to function: ${cleanup_function}"
}

# Create a temporary directory with auto-cleanup
function create_temp_dir() {
    local prefix="${1:-installer}"
    local tmp_dir
    
    # Declare first, then assign to avoid masking return values
    tmp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX") || true
    
    # Ensure the directory is removed on exit
    # Use single quotes to prevent expansion until trap is triggered
    trap 'rm -rf "${tmp_dir}"' EXIT
    
    echo "${tmp_dir}"
    log_debug "Created temporary directory: ${tmp_dir}"
    
    return 0
}

# Store error details for reporting
function store_error_details() {
    local error_message="$1"
    local exit_code="$2"
    local source_file="${3:-${BASH_SOURCE[1]}}"
    local line_number="${4:-${BASH_LINENO[0]}}"
    
    # STATE_DIR should be defined in common.sh, but set a default if not
    : "${STATE_DIR:=/var/cache/system-installer}"
    
    # Create error details directory if it doesn't exist
    mkdir -p "${STATE_DIR}/errors"
    
    # Create a unique error ID - declare first, then assign
    local error_id
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S) || true
    error_id="error_${timestamp}_${RANDOM}"
    
    # Get formatted date for timestamp
    local date_str
    date_str=$(date '+%Y-%m-%d %H:%M:%S') || true
    
    # Store error details
    cat > "${STATE_DIR}/errors/${error_id}.json" << EOF
{
    "timestamp": "${date_str}",
    "message": "${error_message}",
    "exit_code": ${exit_code},
    "source_file": "${source_file}",
    "line_number": ${line_number},
    "command": "${BASH_COMMAND}",
    "script": "$0"
}
EOF
    
    echo "${error_id}"
    log_debug "Stored error details with ID: ${error_id}"
    
    return 0
}

# Get error details by ID
function get_error_details() {
    local error_id="$1"
    
    # STATE_DIR should be defined in common.sh, but set a default if not
    : "${STATE_DIR:=/var/cache/system-installer}"
    
    if [[ -f "${STATE_DIR}/errors/${error_id}.json" ]]; then
        cat "${STATE_DIR}/errors/${error_id}.json"
        return 0
    else
        log_error "Error details not found for ID: ${error_id}"
        return 1
    fi
}

# Retry a command multiple times before giving up
function retry_command() {
    local max_attempts="$1"
    local command="$2"
    local delay="${3:-5}"
    local attempt=1
    local exit_code=0
    
    until eval "${command}"; do
        exit_code=$?
        
        if [[ ${attempt} -ge ${max_attempts} ]]; then
            log_error "Command failed after ${attempt} attempts: ${command}"
            return "${exit_code}"
        fi
        
        log_warning "Command failed (attempt ${attempt}/${max_attempts}) retrying in ${delay}s: ${command}"
        sleep "${delay}"
        ((attempt++))
    done
    
    return 0
}
