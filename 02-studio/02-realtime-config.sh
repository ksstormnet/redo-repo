#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154
# ============================================================================
# 02-realtime-config.sh
# ----------------------------------------------------------------------------
# Configures the system for real-time audio processing with low latency
# Sets up real-time priorities, resource limits, and optimizations for
# professional audio work
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck source=../lib/common.sh
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="02-realtime-config"

# ============================================================================
# Real-time Priorities Configuration
# ============================================================================

# Configure real-time priorities and resource limits for audio processing
function configure_realtime_limits() {
    log_section "Configuring Real-time Priorities and Limits"

    if check_state "${SCRIPT_NAME}_realtime_limits_configured"; then
        log_info "Real-time limits already configured. Skipping..."
        return 0
    fi

    # Configure the limits.conf for real-time audio
    local limits_conf="/etc/security/limits.d/99-audio-limits.conf"
    log_info "Creating audio limits configuration at ${limits_conf}"

    cat > "${limits_conf}" << 'EOL'
# Real-time audio configuration
# Allow audio group to use higher priority and locked memory
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
@audio   -  priority   99
EOL

    # Add current user to audio group if not already in it
    if [[ -n "${SUDO_USER}" ]]; then
        if ! groups "${SUDO_USER}" | grep -q '\baudio\b'; then
            log_info "Adding user ${SUDO_USER} to audio group"
            usermod -a -G audio "${SUDO_USER}"
        else
            log_info "User ${SUDO_USER} is already in audio group"
        fi
    fi

    # Configure PAM limits to include our limits
    local pam_limits="/etc/pam.d/common-session"
    if ! grep -q "pam_limits.so" "${pam_limits}"; then
        log_info "Adding pam_limits.so to PAM configuration"
        echo "session required pam_limits.so" >> "${pam_limits}"
    else
        log_info "PAM limits already configured"
    fi

    set_state "${SCRIPT_NAME}_realtime_limits_configured"
    log_success "Real-time priorities and limits configured"
    return 0
}

# ============================================================================
# USB Audio Optimization
# ============================================================================

# Optimize system settings for USB audio interfaces
function optimize_usb_audio() {
    log_section "Optimizing USB Audio Settings"

    if check_state "${SCRIPT_NAME}_usb_audio_optimized"; then
        log_info "USB audio already optimized. Skipping..."
        return 0
    fi

    # Configure USB power management for audio devices
    local usb_conf="/etc/modprobe.d/99-audio-usb.conf"
    log_info "Configuring USB power management"

    cat > "${usb_conf}" << 'EOL'
# Disable USB autosuspend for audio devices
options usbcore autosuspend=-1
EOL

    # Create udev rules for USB audio devices
    local udev_rules="/etc/udev/rules.d/99-audio-device-priority.rules"
    log_info "Creating udev rules for USB audio devices"

    cat > "${udev_rules}" << 'EOL'
# Set high priority for USB audio devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", ATTR{bInterfaceClass}=="01", ATTR{bInterfaceSubClass}=="01", ACTION=="add", RUN+="/usr/bin/ionice -c 1 -n 0 -p $DEVPATH"
# Set scheduler to deadline for audio devices
ACTION=="add|change", KERNEL=="sd[a-z]", ATTRS{idVendor}=="*", ATTRS{model}=="*Audio*", ATTR{queue/scheduler}="deadline"
EOL

    # Reload udev rules
    log_info "Reloading udev rules"
    udevadm control --reload-rules
    udevadm trigger

    set_state "${SCRIPT_NAME}_usb_audio_optimized"
    log_success "USB audio settings optimized"
    return 0
}

# ============================================================================
# System Tuning for Audio
# ============================================================================

# Configure system settings for optimal audio performance
function tune_system_for_audio() {
    log_section "Tuning System for Audio Performance"

    if check_state "${SCRIPT_NAME}_system_tuned"; then
        log_info "System already tuned for audio. Skipping..."
        return 0
    fi

    # Configure swappiness
    log_info "Setting vm.swappiness to 10"
    echo "vm.swappiness = 10" > /etc/sysctl.d/99-audio-swappiness.conf

    # Configure CPU scaling governor
    log_info "Setting CPU governor to performance"

    # Create a systemd service to set CPU governor on boot
    local service_file="/etc/systemd/system/cpu-performance-governor.service"

    cat > "${service_file}" << 'EOL'
[Unit]
Description=Set CPU Governor to Performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable cpu-performance-governor.service
    systemctl start cpu-performance-governor.service

    # Disable timer-based CPU scheduler
    log_info "Disabling timer-based CPU scheduler for lower latency"

    # Add kernel parameters for audio performance
    local grub_file="/etc/default/grub"
    if [[ -f "${grub_file}" ]]; then
        # Check if the audio parameters are already set
        if ! grep -q "threadirqs" "${grub_file}"; then
            log_info "Adding audio-focused kernel parameters to GRUB"

            # Get current GRUB_CMDLINE_LINUX_DEFAULT
            local current_params
            current_params=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "${grub_file}" | cut -d'"' -f2)

            # Add our parameters
            local new_params="${current_params} threadirqs nohz=off nowatchdog"

            # Update GRUB file
            sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="'"${new_params}"'"/' "${grub_file}"

            # Update GRUB
            update-grub
        else
            log_info "Audio kernel parameters already set in GRUB"
        fi
    fi

    set_state "${SCRIPT_NAME}_system_tuned"
    log_success "System tuned for audio performance"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_realtime_audio() {
    log_section "Setting Up Real-time Audio Configuration"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Real-time audio configuration has already been set up. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Configure real-time priorities and limits
    configure_realtime_limits || log_warning "Failed to configure real-time limits"

    # Optimize USB audio settings
    optimize_usb_audio || log_warning "Failed to optimize USB audio settings"

    # Tune system for audio
    tune_system_for_audio || log_warning "Failed to tune system for audio"

    # Ensure STATE_DIR is set, default to a sensible location if not defined
    STATE_DIR="${STATE_DIR:-/var/lib/system-setup/state}"
    # Create the directory if it doesn't exist
    mkdir -p "${STATE_DIR}"
    # Create a reboot marker for the main installer
    touch "${STATE_DIR}/reboot_required"

    # Display a reminder about rebooting
    log_warning "A system reboot is required to apply real-time audio settings"

    # Mark the entire script as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Real-time audio configuration completed successfully"

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
setup_realtime_audio

# Return the exit code
exit $?
