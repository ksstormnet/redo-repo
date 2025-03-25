#!/usr/bin/env bash
# ============================================================================
# install-audio-toggle.sh
# ----------------------------------------------------------------------------
# Installs the audio-performance-toggle.sh script to /usr/local/bin/audio-toggle
# and sets it as the default audio configuration with conservative settings
# This script should be run with root privileges
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="install-audio-toggle"

# Initialize FORCE_MODE to false by default
FORCE_MODE="false"

# Check if script was called with force option
if [[ "$1" == "--force" ]]; then
    FORCE_MODE="true"
    log_info "Force mode enabled. Will reinstall components even if previously installed."
fi

# ============================================================================
# Installation Functions
# ============================================================================

# Install the audio-toggle script
function install_audio_toggle() {
    log_section "Installing Audio Performance Toggle Script"

    if check_state "${SCRIPT_NAME}_script_installed"; then
        log_info "Audio toggle script already installed. Skipping..."
        return 0
    fi

    # Source script path
    local source_script="${SCRIPT_DIR}/audio-performance-toggle.sh"
    local target_script="/usr/local/bin/audio-toggle"

    # Check if source script exists
    if [[ ! -f "${source_script}" ]]; then
        log_error "Source script not found at: ${source_script}"
        return 1
    fi

    # Install the script
    log_step "Installing audio-toggle script to ${target_script}"
    cp "${source_script}" "${target_script}"
    chmod 755 "${target_script}"

    # Test the script
    log_step "Testing the audio-toggle script"
    if ! "${target_script}" help >/dev/null 2>&1; then
        log_error "Failed to run the audio-toggle script"
        return 1
    fi

    log_success "Audio toggle script installed successfully"
    set_state "${SCRIPT_NAME}_script_installed"
    return 0
}

# Apply conservative settings by default
function apply_conservative_settings() {
    log_section "Applying Conservative Audio Settings by Default"

    if check_state "${SCRIPT_NAME}_settings_applied"; then
        log_info "Default audio settings already applied. Skipping..."
        return 0
    fi

    # Apply conservative settings
    log_step "Setting conservative audio settings as default"
    if ! /usr/local/bin/audio-toggle conservative; then
        log_error "Failed to apply conservative audio settings"
        return 1
    fi

    log_success "Conservative audio settings applied successfully"
    set_state "${SCRIPT_NAME}_settings_applied"
    return 0
}

# Create desktop entry for audio-toggle
function create_desktop_entry() {
    log_section "Creating Desktop Entry for Audio Toggle"

    if check_state "${SCRIPT_NAME}_desktop_entry_created"; then
        log_info "Desktop entry already created. Skipping..."
        return 0
    fi

    # Create desktop entry
    log_step "Creating desktop entry for audio-toggle"
    local desktop_file="/usr/share/applications/audio-toggle.desktop"

    cat > "${desktop_file}" << 'EOF'
[Desktop Entry]
Name=Audio Performance Toggle
Comment=Toggle between conservative and performance audio settings
Exec=pkexec /usr/local/bin/audio-toggle
Icon=preferences-system-sound
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Settings;
Keywords=audio;performance;latency;pipewire;jack;
EOF

    # Create PolicyKit policy for audio-toggle
    log_step "Creating PolicyKit policy for audio-toggle"
    local polkit_file="/usr/share/polkit-1/actions/org.local.audio-toggle.policy"

    mkdir -p /usr/share/polkit-1/actions/

    cat > "${polkit_file}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.local.audio-toggle">
    <description>Run Audio Performance Toggle</description>
    <message>Authentication is required to change audio performance settings</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/audio-toggle</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
EOF

    log_success "Desktop entry and PolicyKit policy created successfully"
    set_state "${SCRIPT_NAME}_desktop_entry_created"
    return 0
}

# Configure system for audio toggle
function configure_desktop_integration() {
    log_section "Configuring Desktop Integration"

    if check_state "${SCRIPT_NAME}_desktop_integration_configured"; then
        log_info "Desktop integration already configured. Skipping..."
        return 0
    fi

    # Check if notification service is available
    log_step "Setting up notification helper"
    local notification_helper="/usr/local/bin/audio-toggle-notify"

    cat > "${notification_helper}" << 'EOF'
#!/bin/bash
# Helper script to show notifications about audio mode changes

# Exit if no arguments provided
if [ -z "$1" ]; then
    echo "Usage: $0 performance|conservative|status"
    exit 1
fi

# Determine notification parameters based on mode
case "$1" in
    performance)
        title="Audio Performance Mode Enabled"
        message="Your system is now configured for low-latency audio. CPU is running at maximum performance."
        icon="audio-card"
        ;;
    conservative)
        title="Audio Conservative Mode Enabled"
        message="Your system is now configured for stable audio operation. CPU is in power-saving mode."
        icon="audio-card"
        ;;
    status)
        title="Audio Configuration Status"
        message="Use audio-toggle to switch between performance and conservative modes."
        icon="dialog-information"
        ;;
    *)
        title="Audio Toggle"
        message="Unknown operation: $1"
        icon="dialog-error"
        ;;
esac

# Send notification if users are logged in (skip if running from boot script)
if who | grep -q -v "root" && pgrep -x systemd > /dev/null; then
    for user in $(who | awk '{print $1}' | sort -u); do
        uid=$(id -u "$user")
        if [ $uid -ge 1000 ]; then
            # Send notification as the user
            su - "$user" -c "XDG_RUNTIME_DIR=/run/user/$uid DISPLAY=:0 notify-send -i '$icon' '$title' '$message'"
        fi
    done
fi

# Also log the change
logger -t audio-toggle "Changed to $1 mode"
EOF

    chmod 755 "${notification_helper}"

    # Update audio-toggle to use the notification helper
    log_step "Configuring audio-toggle to show notifications"
    local audio_toggle="/usr/local/bin/audio-toggle"

    # Add notification call after each mode change
    if grep -q "apply_conservative_settings" "${audio_toggle}"; then
        sed -i '/print_success "Conservative audio settings applied successfully"/a \    # Show notification\n    /usr/local/bin/audio-toggle-notify conservative' "${audio_toggle}"
        sed -i '/print_success "Performance audio settings applied successfully"/a \    # Show notification\n    /usr/local/bin/audio-toggle-notify performance' "${audio_toggle}"
    fi

    log_success "Desktop integration configured successfully"
    set_state "${SCRIPT_NAME}_desktop_integration_configured"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function install_audio_toggle_main() {
    log_section "Installing Audio Performance Toggle"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Audio toggle has already been installed. Skipping..."
        return 0
    fi

    # Install the audio-toggle script
    if ! install_audio_toggle; then
        log_error "Failed to install audio-toggle script"
        return 1
    fi

    # Apply conservative settings by default
    if ! apply_conservative_settings; then
        log_warning "Failed to apply conservative settings"
        # Continue anyway as the script is still installed
    fi

    # Create desktop entry
    if ! create_desktop_entry; then
        log_warning "Failed to create desktop entry"
        # Continue anyway as this is not critical
    fi

    # Configure desktop integration
    if ! configure_desktop_integration; then
        log_warning "Failed to configure desktop integration"
        # Continue anyway as this is not critical
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Audio toggle installed and configured successfully"

    # Display information to the user
    log_info "The audio-toggle script has been installed to /usr/local/bin/audio-toggle"
    log_info "Default conservative audio settings have been applied"
    log_info "Run 'sudo audio-toggle performance' to switch to low-latency mode"
    log_info "Run 'audio-toggle status' to check current configuration"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
install_audio_toggle_main

# Return the exit code
exit $?
