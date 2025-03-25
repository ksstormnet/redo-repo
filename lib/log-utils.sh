#!/bin/bash
# ============================================================================
# log_utils.sh
# ----------------------------------------------------------------------------
# Logging utilities for system installer scripts
# Provides consistent logging across all scripts
# ============================================================================

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_SUCCESS=4

# Default log level (can be overridden by environment)
CURRENT_LOG_LEVEL=${LOG_LEVEL:-${LOG_LEVEL_INFO}}

# Default log mode
LOG_MODE=${LOG_MODE:-"normal"}  # Options: full, normal, minimal, quiet

# These variables are set in common.sh and referenced here
# Default values if not set elsewhere
: "${NO_COLOR:=false}"
: "${LOG_DIR:=/var/log/system-installer}"

# Terminal colors if stdout is a terminal
if [[ -t 1 ]]; then
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_MAGENTA='\033[0;35m'
    COLOR_CYAN='\033[0;36m'
    COLOR_RESET='\033[0m'
    USE_COLOR=true
else
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_RESET=''
    USE_COLOR=false
fi

# Disable colors if explicitly requested
if [[ "${NO_COLOR}" == "true" ]]; then
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_RESET=''
    USE_COLOR=false
fi

# Initialize logging system
function init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    # Create script-specific log file
    local script_basename
    script_basename=$(basename "$0" .sh) || true
    local date_stamp
    date_stamp=$(date '+%Y%m%d') || true
    LOG_FILE="${LOG_DIR}/${script_basename}-${date_stamp}.log"
    
    # Create symlink to latest log
    LATEST_LOG="${LOG_DIR}/${script_basename}-latest.log"
    ln -sf "${LOG_FILE}" "${LATEST_LOG}"
    
    # Set correct permissions if running as sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${LOG_DIR}"
    fi
    
    # Get date for log header
    local date_str
    date_str=$(date) || true
    
    # Log start of script - use a single redirection for multiple lines
    {
        echo "===== Script started at ${date_str} ====="
        echo "Command line: $0 $*"
        
        # Get environment info
        local env_info
        env_info=$(env | sort) || true
        echo "Environment: ${env_info}"
        echo "----------------------------------------"
    } >> "${LOG_FILE}"
}

# Main log function with level control
function log() {
    local level="$1"
    local message="$2"
    
    # Declare first, then assign to avoid masking return values
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S') || true
    
    local level_name=""
    local color=""
    local level_num=1
    
    # Default to INFO if level is not recognized
    case "${level}" in
        "DEBUG")
            level_name="DEBUG"
            color="${COLOR_BLUE}"
            level_num=${LOG_LEVEL_DEBUG}
            ;;
        "INFO")
            level_name="INFO"
            color="${COLOR_GREEN}"
            level_num=${LOG_LEVEL_INFO}
            ;;
        "WARNING")
            level_name="WARNING"
            color="${COLOR_YELLOW}"
            level_num=${LOG_LEVEL_WARNING}
            ;;
        "ERROR")
            level_name="ERROR"
            color="${COLOR_RED}"
            level_num=${LOG_LEVEL_ERROR}
            ;;
        "SUCCESS")
            level_name="SUCCESS"
            color="${COLOR_GREEN}"
            level_num=${LOG_LEVEL_SUCCESS}
            ;;
        *)
            level_name="INFO"
            color="${COLOR_GREEN}"
            level_num=${LOG_LEVEL_INFO}
            ;;
    esac
    
    # Always log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [${level_name}] ${message}" >> "${LOG_FILE}"
    fi
    
    # Determine if message should be displayed based on log mode
    local display=true
    
    case "${LOG_MODE}" in
        full)    ;;  # Show all messages
        normal)  if [[ "${level}" == "DEBUG" ]]; then display=false; fi ;;
        minimal) if [[ "${level}" == "DEBUG" || "${level}" == "INFO" && "${level_name}" != "SUCCESS" ]]; then display=false; fi ;;
        quiet)   if [[ "${level}" != "ERROR" && "${level}" != "WARNING" ]]; then display=false; fi ;;
        *)       log_warning "Unknown LOG_MODE: ${LOG_MODE}, defaulting to normal" ;;
    esac
    
    # Only show if level is sufficient and display flag is true
    if [[ ${level_num} -ge ${CURRENT_LOG_LEVEL} && "${display}" == "true" ]]; then
        if [[ "${USE_COLOR}" == "true" ]]; then
            echo -e "  ${color}[${level_name}]${COLOR_RESET} ${message}"
        else
            echo "  [${level_name}] ${message}"
        fi
    fi
}

# Convenience logging functions
function log_debug() {
    log "DEBUG" "$1"
}

function log_info() {
    log "INFO" "$1"
}

function log_warning() {
    log "WARNING" "$1"
}

function log_error() {
    log "ERROR" "$1"
}

function log_success() {
    log "SUCCESS" "$1"
}

# Create a visual section header
function log_section() {
    local section_title="$1"
    
    # Log to file
    if [[ -n "${LOG_FILE:-}" ]]; then
        {
            echo ""
            echo "===== ${section_title} ====="
            echo ""
        } >> "${LOG_FILE}"
    fi
    
    # Display on console
    if [[ "${USE_COLOR}" == "true" ]]; then
        echo -e "\n${COLOR_MAGENTA}════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "${COLOR_MAGENTA}  ${section_title} ${COLOR_RESET}"
        echo -e "${COLOR_MAGENTA}════════════════════════════════════════════════════${COLOR_RESET}\n"
    else
        echo -e "\n=============================================="
        echo -e "  ${section_title} "
        echo -e "==============================================\n"
    fi
}

# Log a step (sub-section) in the process
function log_step() {
    local step_description="$1"
    
    # Log to file
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "--- ${step_description} ---" >> "${LOG_FILE}"
    fi
    
    # Display on console
    if [[ "${USE_COLOR}" == "true" ]]; then
        echo -e "${COLOR_CYAN}▶ ${step_description}${COLOR_RESET}"
    else
        echo "▶ ${step_description}"
    fi
}

# Log a command execution with proper separation of output
function log_command() {
    local command_desc="$1"
    local command="$2"
    local exit_on_error="${3:-true}"
    
    log_info "${command_desc}"
    
    # Log the command to the log file
    if [[ -n "${LOG_FILE:-}" ]]; then
        {
            echo "Command: ${command}"
            echo "----------------------------------------"
        } >> "${LOG_FILE}"
    fi
    
    # Execute the command and capture output
    local output
    local exit_code=0
    
    # Actually run the command and capture stdout/stderr
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
        log_error "Command failed with exit code ${exit_code}"
        
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

# Show progress as a percentage
function show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-"Processing"}"
    
    local percentage=$((current * 100 / total))
    
    if [[ "${USE_COLOR}" == "true" ]]; then
        echo -ne "${COLOR_CYAN}[${percentage}%] ${COLOR_RESET}${message} (${current}/${total})\r"
    else
        echo -ne "[${percentage}%] ${message} (${current}/${total})\r"
    fi
    
    if [[ ${current} -eq ${total} ]]; then
        echo
    fi
}

# Log the execution of a script
function log_script_execution() {
    local script_path="$1"
    
    # Declare first, then assign to avoid masking return values
    local script_name
    script_name=$(basename "${script_path}") || true
    local script_log="${LOG_DIR}/${script_name}.log"
    
    log_info "Executing script: ${script_name}"
    
    # Execute the script with output redirection to both console and log file
    # Avoid using eval in a process substitution to prevent masking return values
    local exit_code=0
    {
        # We're capturing the return value with PIPESTATUS below, so this warning can be ignored
        # shellcheck disable=SC2312
        bash "${script_path}" 2>&1 | tee -a "${script_log}"
        exit_code=${PIPESTATUS[0]}
    }
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Script ${script_name} executed successfully"
        return 0
    else
        log_error "Script ${script_name} failed with exit code ${exit_code}"
        return "${exit_code}"
    fi
}
