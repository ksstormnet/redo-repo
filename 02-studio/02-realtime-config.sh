#!/usr/bin/env bash
# ============================================================================
# 02-realtime-config.sh
# ----------------------------------------------------------------------------
# Configures the system for real-time audio processing
# Sets up real-time privileges, kernel parameters, and system optimizations
# necessary for professional audio work
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PARENT_DIR/lib"

# Source the common library functions
if [[ -f "$LIB_DIR/common.sh" ]]; then
    source "$LIB_DIR/common.sh"
else
    echo "ERROR: common.sh library not found at $LIB_DIR"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="02-realtime-config"

# ============================================================================
# System Variables
# ============================================================================

# Define audio user(s)
AUDIO_USER=${SUDO_USER:-$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)}


# ============================================================================
# Real-time Configuration
# ============================================================================

# Configure real-time scheduling and memory locking
function configure_realtime_limits() {
    log_section "Configuring Real-time Scheduling and Memory Locking"
    
    if check_state "${SCRIPT_NAME}_realtime_limits_configured"; then
        log_info "Real-time limits have already been configured. Skipping..."
        return 0
    fi
    
    # Install required packages
    log_step "Installing required packages"
    if ! apt_install rtirq-init; then
        log_warning "Failed to install rtirq-init package"
        # Continue anyway as not critical
    fi
    
    # Configure limits.conf for real-time audio
    log_step "Configuring limits.conf for real-time audio"
    
    # Check if audio limits file exists
    if [[ ! -f /etc/security/limits.d/audio.conf ]]; then
        cat > /etc/security/limits.d/audio.conf << 'EOF'
# Real-time audio configuration
# Allow audio group to use higher priority and locked memory
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
@audio   -  priority   99
EOF
        log_info "Created real-time limits configuration for audio group"
    else
        log_info "Audio limits configuration already exists"
    fi
    
    # Configure PAM limits to include our limits
    log_step "Configuring PAM to include limits"
    
    # Ensure pam_limits.so is included in common-session
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
        log_info "Added pam_limits.so to PAM configuration"
    else
        log_info "PAM limits already configured"
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_realtime_limits_configured"
    log_success "Real-time limits configured successfully"
    
    return 0
}

# Configure kernel parameters for real-time audio
function configure_kernel_parameters() {
    log_section "Configuring Kernel Parameters for Real-time Audio"
    
    if check_state "${SCRIPT_NAME}_kernel_parameters_configured"; then
        log_info "Kernel parameters have already been configured. Skipping..."
        return 0
    fi
    
    # Create sysctl configuration
    log_step "Creating sysctl configuration for real-time audio"
    
    cat > /etc/sysctl.d/99-audio-realtime.conf << 'EOF'
# Kernel parameters for real-time audio
# Increase timer frequency for better audio timing
dev.hpet.max-user-freq = 3072
# Improve filesystem performance
fs.inotify.max_user_watches = 524288
# Improve network performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
# Improve virtual memory behavior
vm.swappiness = 10
# Lock shared memory in RAM
vm.mmap_min_addr = 16384
EOF
    
    # Apply settings
    log_info "Applying sysctl settings"
    sysctl -p /etc/sysctl.d/99-audio-realtime.conf
    
    # Disable CPU power saving features
    log_step "Disabling CPU power saving features"
    
    # Check if powersave utilities are installed
    if command -v x86_energy_perf_policy &>/dev/null; then
        log_info "Setting CPU energy policy to performance"
        x86_energy_perf_policy performance
    fi
    
    # Disable CPU idle states for better real-time performance
    if [[ -d /sys/devices/system/cpu/intel_pstate ]]; then
        log_info "Configuring Intel P-State driver for performance"
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_kernel_parameters_configured"
    log_success "Kernel parameters configured for real-time audio"
    
    return 0
}

# Configure audio group and user settings
function configure_audio_user() {
    log_section "Configuring Audio Group and User Settings"
    
    if check_state "${SCRIPT_NAME}_audio_user_configured"; then
        log_info "Audio user settings have already been configured. Skipping..."
        return 0
    fi
    
    # Ensure audio user exists
    log_step "Ensuring audio user exists and has correct group memberships"
    
    if [[ -n "$AUDIO_USER" ]]; then
        log_info "Configuring user $AUDIO_USER for audio work"
        
        # Add user to necessary groups
        usermod -a -G audio,video,plugdev "$AUDIO_USER"
        
        # Create audio user directories if needed
        local audio_user_home="/home/$AUDIO_USER"
        if [[ -d "$audio_user_home" ]]; then
            # Create audio project directories that respect LVM setup
            log_info "Creating audio project directories for $AUDIO_USER"
            
            # Use /data directory if it exists (respecting LVM setup)
            if [[ -d "/data" ]]; then
                mkdir -p "/data/Audio/Projects" "/data/Audio/Samples" "/data/Audio/Recordings"
                
                # Create symlinks to the user's home directory
                sudo -u "$AUDIO_USER" mkdir -p "$audio_user_home/Audio"
                
                # Only create symlinks if they don't exist
                if [[ ! -L "$audio_user_home/Audio/Projects" ]]; then
                    sudo -u "$AUDIO_USER" ln -sf "/data/Audio/Projects" "$audio_user_home/Audio/Projects"
                fi
                
                if [[ ! -L "$audio_user_home/Audio/Samples" ]]; then
                    sudo -u "$AUDIO_USER" ln -sf "/data/Audio/Samples" "$audio_user_home/Audio/Samples"
                fi
                
                if [[ ! -L "$audio_user_home/Audio/Recordings" ]]; then
                    sudo -u "$AUDIO_USER" ln -sf "/data/Audio/Recordings" "$audio_user_home/Audio/Recordings"
                fi
                
                # Set proper permissions
                chown -R "$AUDIO_USER:$AUDIO_USER" "/data/Audio"
                chmod -R 755 "/data/Audio"
            else
                # If no LVM setup detected, create directories in home
                sudo -u "$AUDIO_USER" mkdir -p "$audio_user_home/Audio/Projects" "$audio_user_home/Audio/Samples" "$audio_user_home/Audio/Recordings"
            fi
        else
            log_warning "Home directory for $AUDIO_USER not found. Skipping directory creation."
        fi
    else
        log_warning "No audio user identified. Skipping user configuration."
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_audio_user_configured"
    log_success "Audio user settings configured successfully"
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_realtime_config() {
    log_section "Setting Up Real-time Audio Configuration"
    
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
    
    # Configure real-time limits
    if ! configure_realtime_limits; then
        log_warning "Failed to configure real-time limits"
        # Continue anyway since other optimizations may still be beneficial
    fi
    
    # Configure CPU scheduler for real-time audio
    if ! configure_cpu_scheduler; then
        log_warning "Failed to configure CPU scheduler"
        # Continue anyway
    fi
    
    # Configure kernel parameters
    if ! configure_kernel_parameters; then
        log_warning "Failed to configure kernel parameters"
        # Continue anyway
    fi
    
    # Configure audio user settings
    if ! configure_audio_user; then
        log_warning "Failed to configure audio user settings"
        # Continue anyway
    fi
    
    # Create a reboot marker for the main installer
    touch "${STATE_DIR}/reboot_required"
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Real-time audio configuration completed successfully"
    log_warning "A system reboot is required to apply all real-time audio settings"
    
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
setup_realtime_config

# Return the exit code
exit $?

# Configure CPU scheduler for real-time audio
function configure_cpu_scheduler() {
    log_section "Configuring CPU Scheduler for Real-time Audio"
    
    if check_state "${SCRIPT_NAME}_cpu_scheduler_configured"; then
        log_info "CPU scheduler has already been configured. Skipping..."
        return 0
    fi
    
    # Set up IRQ thread priorities
    log_step "Setting up IRQ thread priorities for audio"
    
    # Configure rtirq if installed
    if command -v rtirq &>/dev/null; then
        log_info "Configuring rtirq for audio interfaces"
        
        # Create rtirq configuration file
        cat > /etc/default/rtirq << 'EOF'
# Default settings for rtirq
# This file is part of rtirq

# List of IRQs for sound cards (space separated)
# Make sure to adjust this to your system
RTIRQ_NAME_LIST="snd usb i915"

# Highest priority for sound cards
RTIRQ_PRIO_HIGH=90

# Lowest priority for sound cards
RTIRQ_PRIO_LOW=85

# Priority for USB-related processes
RTIRQ_PRIO_USB=80

# Priority decrease step
RTIRQ_PRIO_DECR=5

# Whether to reset all IRQ threads
RTIRQ_RESET_ALL=0

# Additional options for rtirq
RTIRQ_OPTS=""
EOF
        
        # Enable and start rtirq service
        log_info "Enabling rtirq service"
        systemctl enable rtirq
        systemctl start rtirq
        
        log_success "rtirq configured for audio interfaces"
    else
        log_warning "rtirq-init not found. Skipping IRQ thread priority configuration."
    fi
    
    # Configure CPU governor
    log_step "Configuring CPU governor for audio performance"
    
    # Install cpufrequtils if needed
    if ! command -v cpufreq-set &>/dev/null; then
        log_info "Installing cpufrequtils"
        if ! apt_install cpufrequtils; then
            log_warning "Failed to install cpufrequtils. Skipping CPU governor configuration."
        fi
    fi
    
    # Create CPU governor configuration
    if command -v cpufreq-set &>/dev/null; then
        log_info "Setting CPU governor to performance"
        
        # Create configuration file
        cat > /etc/default/cpufrequtils << 'EOF'
# Configuration for cpufrequtils
GOVERNOR="performance"
MAX_SPEED=0
MIN_SPEED=0
EOF
        
        # Apply settings
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" > "$cpu" 2>/dev/null || true
        done
        
        log_success "CPU governor set to performance"
    fi
    
    # Create systemd service to set governor on boot
    log_step "Creating systemd service for CPU governor"
    
    cat > /etc/systemd/system/audio-cpu-performance.service << 'EOF'
[Unit]
Description=Audio CPU Performance Settings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable service
    systemctl daemon-reload
    systemctl enable audio-cpu-performance.service
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_cpu_scheduler_configured"
    log_success "CPU scheduler configured for audio performance"
    
    return 0
}