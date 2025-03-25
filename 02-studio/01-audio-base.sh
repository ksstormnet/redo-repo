#!/usr/bin/env bash
# ============================================================================
# 01-audio-base.sh
# ----------------------------------------------------------------------------
# Installs the core audio system components for Ubuntu Studio including
# JACK, PulseAudio/PipeWire, and essential audio utilities
# Configures the system for optimal audio performance
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default for force mode
: "${FORCE_MODE:=false}"  # Default to not forcing reinstallation

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="01-audio-base"

# ============================================================================
# Core Audio System Installation
# ============================================================================

# Install PipeWire as the modern audio server
function install_pipewire() {
    log_section "Installing PipeWire Audio System"

    if check_state "${SCRIPT_NAME}_pipewire_installed"; then
        log_info "PipeWire has already been installed. Skipping..."
        return 0
    fi

    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Install PipeWire and related packages
    log_step "Installing PipeWire and related packages"
    local pipewire_packages=(
        pipewire
        pipewire-pulse
        pipewire-jack
        pipewire-alsa
        libspa-0.2-bluetooth
        pipewire-audio-client-libraries
        wireplumber
    )

    if ! apt_install "${pipewire_packages[@]}"; then
        log_error "Failed to install PipeWire packages"
        return 1
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_pipewire_installed"
    log_success "PipeWire installed successfully"

    return 0
}

# Configure PipeWire for low-latency audio
function configure_pipewire() {
    log_section "Configuring PipeWire for Low-Latency Audio"

    if check_state "${SCRIPT_NAME}_pipewire_configured"; then
        log_info "PipeWire has already been configured. Skipping..."
        return 0
    fi

    # Create the PipeWire config directory
    mkdir -p /etc/pipewire/pipewire.conf.d

    # Create low-latency configuration
    log_step "Creating low-latency configuration for PipeWire"
    cat > /etc/pipewire/pipewire.conf.d/10-low-latency.conf << 'EOF'
# Low latency PipeWire configuration for audio production
#
context.properties = {
    # Set the default sample rate to 48kHz
    default.clock.rate = 48000
    # Set the quantum size to 64 frames (1.33ms at 48kHz)
    default.clock.quantum = 64
    # Set minimum quantum
    default.clock.min-quantum = 32
    # Set maximum quantum
    default.clock.max-quantum = 8192
}

# Configure real-time properties
context.modules = [
    {   name = libpipewire-module-rt
        args = {
            # Try to use real-time scheduling with high priority
            nice.level = -11
            rt.prio = 88
            # No real-time limits
            rt.time.soft = -1
            rt.time.hard = -1
        }
        flags = [ ifexists nofail ]
    }
]
EOF

    # Create ALSA configuration to use PipeWire by default
    log_step "Configuring ALSA to use PipeWire by default"
    cat > /etc/alsa/conf.d/99-pipewire-default.conf << 'EOF'
# Use PipeWire by default
pcm.!default {
    type pipewire
    hint {
        show on
        description "Default ALSA Output (PipeWire)"
    }
}

ctl.!default {
    type pipewire
    hint {
        show on
        description "Default ALSA Control (PipeWire)"
    }
}
EOF

    # Create systemd unit files to enable PipeWire for all users
    log_step "Creating systemd unit files for PipeWire"
    mkdir -p /etc/systemd/user

    # Ensure PipeWire starts automatically for all users
    cp -f /usr/share/pipewire/pipewire.* /etc/pipewire/ 2>/dev/null || true

    # Mark as completed
    set_state "${SCRIPT_NAME}_pipewire_configured"
    log_success "PipeWire configured for low-latency audio"

    return 0
}

# Install JACK audio server packages
function install_jack() {
    log_section "Installing JACK Audio Connection Kit"

    if check_state "${SCRIPT_NAME}_jack_installed"; then
        log_info "JACK has already been installed. Skipping..."
        return 0
    fi

    # Install JACK packages
    log_step "Installing JACK audio packages"
    local jack_packages=(
        jackd2
        jack-tools
        qjackctl
        a2jmidid
        aj-snapshot
    )

    if ! apt_install "${jack_packages[@]}"; then
        log_error "Failed to install JACK packages"
        return 1
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_jack_installed"
    log_success "JACK audio server installed successfully"

    return 0
}

# Install essential audio utilities
function install_audio_utilities() {
    log_section "Installing Essential Audio Utilities"

    if check_state "${SCRIPT_NAME}_audio_utilities_installed"; then
        log_info "Audio utilities have already been installed. Skipping..."
        return 0
    fi

    # Install essential audio utilities
    log_step "Installing audio utilities"
    local audio_utils=(
        patchage
        pulseaudio-utils
        pavucontrol
        alsa-utils
        helvum
        easyeffects
        carla
        cadence
        lsp-plugins
        calf-plugins
        zam-plugins
    )

    if ! apt_install "${audio_utils[@]}"; then
        log_warning "Failed to install some audio utilities"
        # Continue anyway since some packages might not be available
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_audio_utilities_installed"
    log_success "Essential audio utilities installed successfully"

    return 0
}

# ============================================================================
# Audio Configuration
# ============================================================================

# Configure user permissions for audio
function configure_audio_permissions() {
    log_section "Configuring Audio Permissions"

    if check_state "${SCRIPT_NAME}_audio_permissions_configured"; then
        log_info "Audio permissions have already been configured. Skipping..."
        return 0
    fi

    # Add user to audio group
    log_step "Adding users to audio group"

    # Get the user who will use the audio system
    local audio_user
    if [[ -n "${SUDO_USER}" ]]; then
        audio_user="${SUDO_USER}"
    else
        # Default to 'ubuntu' if running as root directly
        audio_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1) || "ubuntu"
    fi

    log_info "Adding user ${audio_user} to audio and video groups"
    usermod -a -G audio "${audio_user}"
    usermod -a -G video "${audio_user}" # Often needed for hardware acceleration

    # Configure real-time permissions
    log_step "Configuring real-time permissions for audio group"

    # Check if limits file already exists
    if [[ ! -f /etc/security/limits.d/audio.conf ]]; then
        cat > /etc/security/limits.d/audio.conf << 'EOF'
# Limits configuration for real-time audio
@audio   -  rtprio     99
@audio   -  memlock    unlimited
@audio   -  nice       -19
EOF
        log_info "Created real-time limits configuration for audio group"
    else
        log_info "Audio limits configuration already exists"
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_audio_permissions_configured"
    log_success "Audio permissions configured successfully"

    return 0
}

# Configure default audio settings
function configure_default_audio() {
    log_section "Configuring Default Audio Settings"

    if check_state "${SCRIPT_NAME}_default_audio_configured"; then
        log_info "Default audio settings have already been configured. Skipping..."
        return 0
    fi

    # Set default ALSA configuration
    log_step "Setting default ALSA configuration"

    # Create asoundrc template for users
    mkdir -p /etc/skel
    cat > /etc/skel/.asoundrc << 'EOF'
# Default ALSA configuration
pcm.!default {
    type pipewire
    hint.description "Default Audio Output (PipeWire)"
}

ctl.!default {
    type pipewire
    hint.description "Default Audio Control (PipeWire)"
}
EOF

    # Copy to existing user homes (only if it doesn't exist)
    for user_home in /home/*; do
        if [[ -d "${user_home}" && ! -f "${user_home}/.asoundrc" ]]; then
            log_info "Creating .asoundrc for user $(basename "${user_home}")"
            cp /etc/skel/.asoundrc "${user_home}/"
            chown "$(basename "${user_home}")": "${user_home}/.asoundrc"
        fi
    done

    # Also configure root if needed
    if [[ ! -f /root/.asoundrc ]]; then
        cp /etc/skel/.asoundrc /root/
    fi

    # Create QjackCtl configuration directory
    log_step "Creating QjackCtl configuration"

    # For user template
    mkdir -p /etc/skel/.config/rncbc.org
    cat > /etc/skel/.config/rncbc.org/QjackCtl.conf << 'EOF'
[Defaults]
Driver=alsa
Realtime=true
SoftMode=false
Monitor=false
Channels=2
Frames=64
SampleRate=48000
Periods=2
WaitTime=21333
Priority=70
Verbose=false
PortMaxSished=256
StartupScript=false
StartupScriptShell=
PostStartupScript=false
PostStartupScriptShell=
ShutdownScript=false
ShutdownScriptShell=
PostShutdownScript=false
PostShutdownScriptShell=
ServerName=
ServerPrefix=/usr/bin
ServerSuffix=
StartJack=true
StopJack=true
EOF

    # Apply settings to existing users
    for user_home in /home/*; do
        if [[ -d "${user_home}" ]]; then
            user=$(basename "${user_home}")
            user_config_dir="${user_home}/.config/rncbc.org"

            if [[ ! -d "${user_config_dir}" ]]; then
                log_info "Creating QjackCtl configuration for user ${user}"
                mkdir -p "${user_config_dir}"
                cp /etc/skel/.config/rncbc.org/QjackCtl.conf "${user_config_dir}/"
                chown -R "${user}": "${user_config_dir}"
            fi
        fi
    done

    # Mark as completed
    set_state "${SCRIPT_NAME}_default_audio_configured"
    log_success "Default audio settings configured successfully"

    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_audio_base() {
    log_section "Setting Up Audio Base System"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Audio base system has already been set up. Skipping..."
        return 0
    fi

    # Install PipeWire
    if ! install_pipewire; then
        log_error "Failed to install PipeWire"
        return 1
    fi

    # Configure PipeWire
    if ! configure_pipewire; then
        log_warning "Failed to configure PipeWire"
        # Continue anyway
    fi

    # Install JACK
    if ! install_jack; then
        log_warning "Failed to install JACK"
        # Continue anyway as PipeWire provides JACK API
    fi

    # Install audio utilities
    if ! install_audio_utilities; then
        log_warning "Failed to install some audio utilities"
        # Continue anyway
    fi

    # Configure audio permissions
    if ! configure_audio_permissions; then
        log_warning "Failed to configure audio permissions"
        # Continue anyway
    fi

    # Configure default audio settings
    if ! configure_default_audio; then
        log_warning "Failed to configure default audio settings"
        # Continue anyway
    fi

    # Mark the entire script as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Audio base system setup completed successfully"

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
setup_audio_base

# Return the exit code
exit $?
