#!/bin/bash
# ============================================================================
# state_utils.sh
# ----------------------------------------------------------------------------
# State management utilities for system installer scripts
# Tracks completion status of scripts and steps
# ============================================================================

# STATE_DIR should be defined in common.sh, but set a default if not
: "${STATE_DIR:=/var/cache/system-installer}"

# Initialize state management
function initialize_state() {
    local state_name="${1:-default}"
    
    # Create state directory if it doesn't exist
    mkdir -p "${STATE_DIR}"
    mkdir -p "${STATE_DIR}/completed"
    mkdir -p "${STATE_DIR}/values"
    
    # Create script-specific state directory
    mkdir -p "${STATE_DIR}/scripts/${state_name}"
    
    # Set correct permissions if running as sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${STATE_DIR}"
    fi
    
    log_debug "Initialized state management for ${state_name}"
    return 0
}

# Check if a step has been completed
function is_step_completed() {
    local step_id="$1"
    
    if [[ -f "${STATE_DIR}/completed/${step_id}" ]]; then
        log_debug "Step ${step_id} is already completed"
        return 0
    fi
    
    log_debug "Step ${step_id} is not completed"
    return 1
}

# Mark a step as completed
function mark_step_completed() {
    local step_id="$1"
    
    mkdir -p "${STATE_DIR}/completed"
    touch "${STATE_DIR}/completed/${step_id}"
    
    # Set correct permissions if running as sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${STATE_DIR}/completed"
    fi
    
    log_debug "Marked step ${step_id} as completed"
    return 0
}

# Reset a step (mark as not completed)
function reset_step() {
    local step_id="$1"
    
    if [[ -f "${STATE_DIR}/completed/${step_id}" ]]; then
        rm -f "${STATE_DIR}/completed/${step_id}"
        log_debug "Reset step ${step_id} (marked as not completed)"
    else
        log_debug "Step ${step_id} was not marked as completed, no action needed"
    fi
    
    return 0
}

# Legacy functions for backward compatibility

# Check if a state has been completed
function check_state() {
    local state_id="$1"
    is_step_completed "${state_id}"
}

# Set a state as completed
function set_state() {
    local state_id="$1"
    mark_step_completed "${state_id}"
}

# Alternative names for functions
function is_completed() {
    local state_id="$1"
    is_step_completed "${state_id}"
}

function mark_completed() {
    local state_id="$1"
    mark_step_completed "${state_id}"
}

# Store a value in the state
function state_set_value() {
    local key="$1"
    local value="$2"
    
    mkdir -p "${STATE_DIR}/values"
    echo "${value}" > "${STATE_DIR}/values/${key}"
    
    # Set correct permissions if running as sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${STATE_DIR}/values"
    fi
    
    log_debug "Stored value for ${key}: ${value}"
    return 0
}

# Get a value from the state
function state_get_value() {
    local key="$1"
    local default_value="${2:-}"
    
    if [[ -f "${STATE_DIR}/values/${key}" ]]; then
        cat "${STATE_DIR}/values/${key}"
        return 0
    else
        log_debug "No value found for ${key}, using default: ${default_value}"
        echo "${default_value}"
        return 1
    fi
}

# Check if a state value exists
function state_has_value() {
    local key="$1"
    
    if [[ -f "${STATE_DIR}/values/${key}" ]]; then
        return 0
    else
        return 1
    fi
}

# Save the current execution state for resuming after reboot
function save_execution_state() {
    local current_phase="$1"
    local next_script="$2"
    
    # Save current phase
    echo "${current_phase}" > "${STATE_DIR}/current_phase"
    
    # Save next script to run after reboot
    if [[ -n "${next_script}" ]]; then
        echo "${next_script}" > "${STATE_DIR}/next_script"
    fi
    
    # Create reboot marker
    touch "${STATE_DIR}/reboot_required"
    
    log_debug "Saved execution state: phase=${current_phase}, next_script=${next_script}"
    return 0
}

# Check if we are resuming after a reboot
function is_resuming_after_reboot() {
    if [[ -f "${STATE_DIR}/current_phase" && -f "${STATE_DIR}/next_script" ]]; then
        return 0
    else
        return 1
    fi
}

# Get the saved execution state
function get_saved_execution_state() {
    local current_phase=""
    local next_script=""
    
    if [[ -f "${STATE_DIR}/current_phase" ]]; then
        current_phase=$(cat "${STATE_DIR}/current_phase")
    fi
    
    if [[ -f "${STATE_DIR}/next_script" ]]; then
        next_script=$(cat "${STATE_DIR}/next_script")
    fi
    
    echo "phase=${current_phase},script=${next_script}"
    return 0
}

# Clear the saved execution state
function clear_execution_state() {
    rm -f "${STATE_DIR}/current_phase"
    rm -f "${STATE_DIR}/next_script"
    rm -f "${STATE_DIR}/reboot_required"
    
    log_debug "Cleared execution state"
    return 0
}

# Track script execution with checksums to handle script changes
function track_script_execution() {
    local script_path="$1"
    
    # Declare variables first, then assign to avoid masking return values
    local script_name
    script_name=$(basename "${script_path}") || true
    
    local script_hash
    script_hash=$(md5sum "${script_path}" | awk '{print $1}') || true
    
    local hash_file="${STATE_DIR}/completed/${script_name}.${script_hash}"
    
    # Check if the script with this hash has been executed
    if [[ -f "${hash_file}" ]]; then
        log_debug "Script ${script_name} (hash: ${script_hash}) has already been executed"
        return 0
    else
        # Mark as executed
        touch "${hash_file}"
        log_debug "Marked script ${script_name} (hash: ${script_hash}) as executed"
        return 1
    fi
}
