#!/usr/bin/env bash
# ============================================================================
# 02-real-time-audio.sh
# ----------------------------------------------------------------------------
# Configures the system for real-time audio processing
# Sets up low-latency audio, real-time priorities, and system optimizations
# necessary for professional audio work
# ============================================================================
exit 0
# shellcheck disable=SC1091,SC2154,SC2250

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="02-real-time-audio"

# ============================================================================
# PipeWire Configuration for Low Latency
# ============================================================================

function configure_pipewire_low_latency() {
    log_step "Configuring PipeWire for Low Latency Audio"

    # Skip if already completed
    if check_state "${SCRIPT_NAME}_pipewire_configured"; then
        log_info "PipeWire already configured for low latency. Skipping..."
        return 0
    fi

    # Ensure PipeWire is installed
    if ! command -v pipewire &> /dev/null; then
        log_warning "PipeWire not found. Installing PipeWire..."
        if ! apt_install pipewire pipewire-pulse pipewire-audio-client-libraries pipewire-alsa; then
            log_error "Failed to install PipeWire"
            return 1
        fi
    fi

    # Get user's home directory
    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi

    # Create the pipewire config directory if it doesn't exist
    local config_dir="${user_home}/.config/pipewire"
    mkdir -p "${config_dir}"

    # Create low latency config file
    local conf_file="${config_dir}/pipewire.conf.d"
    mkdir -p "${conf_file}"

    # Create the low latency configuration
    local low_latency_conf="${conf_file}/99-low-latency.conf"
    log_info "Creating low latency configuration at ${low_latency_conf}"

    cat > "${low_latency_conf}" << 'EOF'
# Low latency PipeWire configuration
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 64
    default.clock.min-quantum = 64
    default.clock.max-quantum = 1024
    default.video.rate = { num = 30, denom = 1 }
}

context.modules = [
    { name = libpipewire-module-rt
        args = {
            nice.level = -15
            rt.prio = 88
            rt.time.soft = -1
            rt.time.hard = -1
        }
        flags = [ ifexists nofail ]
    }
]

context.objects = [
    { factory = spa-node-factory
        args = {
            factory.name = support.node.driver
            node.name = Dummy-Driver
            node.group = pipewire.dummy
            priority.driver = 20000
        }
    }
]
EOF

    # Fix permissions
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${config_dir}"
    fi

    # Create PulseAudio daemon.conf for compatibility
    log_info "Creating compatible PulseAudio configuration"
    local pulse_dir="${user_home}/.config/pulse"
    mkdir -p "${pulse_dir}"

    cat > "${pulse_dir}/daemon.conf" << 'EOF'
# PulseAudio daemon configuration
high-priority = yes
nice-level = -15
realtime-scheduling = yes
realtime-priority = 50
flat-volumes = no
resample-method = speex-float-1
default-sample-format = float32le
default-sample-rate = 48000
alternate-sample-rate = 44100
default-sample-channels = 2
default-fragments = 2
default-fragment-size-msec = 4
EOF

    # Fix permissions
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${pulse_dir}"
    fi

    # Set PipeWire service to start on boot
    if systemctl --user -q is-enabled pipewire.service 2>/dev/null; then
        log_info "PipeWire service already enabled"
    else
        log_info "Enabling PipeWire service"
        if [[ -n "${SUDO_USER}" ]]; then
            runuser -l "${SUDO_USER}" -c "systemctl --user enable pipewire.service pipewire-pulse.service"
            runuser -l "${SUDO_USER}" -c "systemctl --user start pipewire.service pipewire-pulse.service"
        else
            systemctl --user enable pipewire.service pipewire-pulse.service
            systemctl --user start pipewire.service pipewire-pulse.service
        fi
    fi

    set_state "${SCRIPT_NAME}_pipewire_configured"
    log_success "PipeWire configured for low latency audio"
    return 0
}

# ============================================================================
# Real-time Priorities Configuration
# ============================================================================

function configure_realtime_limits() {
    log_step "Configuring Real-time Priorities and Limits"

    if check_state "${SCRIPT_NAME}_realtime_limits_configured"; then
        log_info "Real-time limits already configured. Skipping..."
        return 0
    fi

    # Configure the limits.conf for real-time audio
    local limits_conf="/etc/security/limits.d/99-audio-limits.conf"
    log_info "Creating audio limits configuration at ${limits_conf}"

    cat > "${limits_conf}" << 'EOF'
# Real-time audio configuration
# Allow audio group to use higher priority and locked memory
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
@audio   -  priority   99
EOF

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
# CPU Governor Configuration for Audio
# ============================================================================

function configure_cpu_for_audio() {
    log_step "Configuring CPU Governor for Audio Performance"

    if check_state "${SCRIPT_NAME}_cpu_governor_configured"; then
        log_info "CPU governor already configured. Skipping..."
        return 0
    fi

    # Ensure cpufrequtils is installed
    if ! command -v cpufreq-info &> /dev/null; then
        log_info "Installing CPU frequency utilities"
        if ! apt_install cpufrequtils; then
            log_warning "Failed to install CPU frequency utilities"
            # Continue anyway as this is not critical
        fi
    fi

    # Create CPU governor configuration
    local governor_conf="/etc/default/cpufrequtils"
    log_info "Setting CPU governor to performance"

    cat > "${governor_conf}" << 'EOF'
# CPU governor configuration for audio work
GOVERNOR="performance"
MAX_SPEED=0
MIN_SPEED=0
EOF

    # Apply the new governor settings
    log_info "Applying CPU governor settings"
    if command -v systemctl &> /dev/null && systemctl list-unit-files | grep -q cpufrequtils; then
        systemctl restart cpufrequtils
    else
        service cpufrequtils restart
    fi

    # Create a script to set governor at boot
    local governor_script="/usr/local/bin/set-performance-governor.sh"
    log_info "Creating boot script for CPU governor at ${governor_script}"

    cat > "${governor_script}" << 'EOF'
#!/bin/bash
# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu
done
EOF

    chmod +x "${governor_script}"

    # Create systemd service to run at boot
    local service_file="/etc/systemd/system/cpu-performance-governor.service"
    log_info "Creating systemd service for CPU governor"

    cat > "${service_file}" << EOF
[Unit]
Description=Set CPU Governor to Performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-performance-governor.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable cpu-performance-governor.service
    systemctl start cpu-performance-governor.service

    set_state "${SCRIPT_NAME}_cpu_governor_configured"
    log_success "CPU governor configured for audio performance"
    return 0
}

# ============================================================================
# USB Audio Optimization
# ============================================================================

function optimize_usb_audio() {
    log_step "Optimizing USB Audio Settings"

    if check_state "${SCRIPT_NAME}_usb_audio_optimized"; then
        log_info "USB audio already optimized. Skipping..."
        return 0
    fi

    # Configure USB power management for audio devices
    local usb_conf="/etc/modprobe.d/99-audio-usb.conf"
    log_info "Configuring USB power management"

    cat > "${usb_conf}" << 'EOF'
# Disable USB autosuspend for audio devices
options usbcore autosuspend=-1
EOF

    # Create udev rules for USB audio devices
    local udev_rules="/etc/udev/rules.d/99-audio-device-priority.rules"
    log_info "Creating udev rules for USB audio devices"

    cat > "${udev_rules}" << 'EOF'
# Set high priority for USB audio devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", ATTR{bInterfaceClass}=="01", ATTR{bInterfaceSubClass}=="01", ACTION=="add", RUN+="/usr/bin/ionice -c 1 -n 0 -p $DEVPATH"
# Set scheduler to deadline for audio devices
ACTION=="add|change", KERNEL=="sd[a-z]", ATTRS{idVendor}=="*", ATTRS{model}=="*Audio*", ATTR{queue/scheduler}="deadline"
EOF

    # Reload udev rules
    log_info "Reloading udev rules"
    udevadm control --reload-rules
    udevadm trigger

    set_state "${SCRIPT_NAME}_usb_audio_optimized"
    log_success "USB audio settings optimized"
    return 0
}

# ============================================================================
# JACK Audio Server Configuration
# ============================================================================

function configure_jack_audio() {
    log_step "Configuring JACK Audio Server"

    if check_state "${SCRIPT_NAME}_jack_configured"; then
        log_info "JACK already configured. Skipping..."
        return 0
    fi

    # Install JACK and related packages if not already installed
    if ! command -v jackd &> /dev/null; then
        log_info "Installing JACK Audio Server"
        if ! apt_install jackd2 jack-tools qjackctl pulseaudio-module-jack; then
            log_warning "Failed to install JACK Audio Server"
            # Continue anyway as this is not critical
        fi
    fi

    local user_home
    if [[ -n "${SUDO_USER}" ]]; then
        user_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    else
        user_home="${HOME}"
    fi

    # Create QjackCtl configuration
    local qjackctl_dir="${user_home}/.config/rncbc.org"
    mkdir -p "${qjackctl_dir}"

    local qjackctl_conf="${qjackctl_dir}/QjackCtl.conf"
    log_info "Creating QjackCtl configuration at ${qjackctl_conf}"

    cat > "${qjackctl_conf}" << 'EOF'
[Defaults]
PatchbayPath=
MessagesLogPath=
SessionDir=
Preset=default
Driver=alsa
Interface=hw:0
Audio=0
MIDI=0
Dither=0
Timeout=500
Server=jackd
ServerPath=jackd
ServerPrefix=
StartJack=true
StopJack=true
StartupScript=false
StartupScriptShell=
PostStartupScript=false
PostStartupScriptShell=
ShutdownScript=false
ShutdownScriptShell=
PostShutdownScript=false
PostShutdownScriptShell=
StartupLocked=false
PortMaxSished=0
XrunRegex=xrun of at least ([0-9]+) msecs

[Settings]
Server=jackd
ServerPrefix=
ServerName=
Realtime=true
SoftMode=false
Monitor=false
Shorts=false
NoMemLock=false
UnlockMem=false
HWMeter=false
HWMon=false
IgnoreHW=false
Priority=5
Frames=64
SampleRate=48000
Periods=2
WordLength=16
Wait=21333
Chan=0
Driver=alsa
Interface=hw:0
Audio=0
MIDI=0
InChannels=0
OutChannels=0
InLatency=0
OutLatency=0
StartDelay=2
Verbose=false
PortMax=256
MidiDriver=none
ServerSuffix=
AlsaDriver=
SeqDriver=
Dither=0
Timeout=500
EOF

    # Fix permissions
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${qjackctl_dir}"
    fi

    # Create JACK configuration file
    local jack_conf="/etc/security/limits.d/95-jack.conf"
    log_info "Creating JACK security limits configuration"

    cat > "${jack_conf}" << 'EOF'
# JACK Audio Connection Kit settings
# Allow realtime priority for JACK
@audio   -  rtprio     99
@audio   -  memlock    unlimited
EOF

    set_state "${SCRIPT_NAME}_jack_configured"
    log_success "JACK Audio Server configured"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_realtime_audio() {
    log_section "Setting Up Real-time Audio"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Real-time audio has already been configured. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Configure PipeWire for low latency
    configure_pipewire_low_latency || log_warning "Failed to configure PipeWire"

    # Configure real-time priorities and limits
    configure_realtime_limits || log_warning "Failed to configure real-time limits"

    # Configure CPU governor for audio performance
    configure_cpu_for_audio || log_warning "Failed to configure CPU governor"

    # Optimize USB audio settings
    optimize_usb_audio || log_warning "Failed to optimize USB audio settings"

    # Configure JACK Audio Server
    configure_jack_audio || log_warning "Failed to configure JACK Audio Server"

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Real-time audio configuration completed successfully"

    # Remind user to reboot
    log_warning "A system reboot is required to apply real-time audio settings"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set sudo timeout to 1 hour
set_sudo_timeout 3600

# Call the main function
setup_realtime_audio

# Return the exit code
exit $?
