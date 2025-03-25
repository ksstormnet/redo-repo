#!/usr/bin/env bash
# ============================================================================
# 00-lowlatency-kernel.sh
# ----------------------------------------------------------------------------
# Installs and configures the Linux low-latency kernel for better system
# responsiveness and reduced audio latency.
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
SCRIPT_NAME="00-lowlatency-kernel"

# ============================================================================
# Kernel Installation
# ============================================================================

# Install the low-latency kernel packages
function install_lowlatency_kernel() {
    log_section "Installing Low-Latency Kernel"
    
    if check_state "${SCRIPT_NAME}_kernel_installed"; then
        log_info "Low-latency kernel has already been installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install linux-lowlatency kernel packages
    log_step "Installing linux-lowlatency kernel packages"
    local kernel_packages=(
        linux-lowlatency
        linux-headers-lowlatency
        linux-tools-lowlatency
    )
    
    if ! apt_install "${kernel_packages[@]}"; then
        log_error "Failed to install low-latency kernel"
        return 1
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_kernel_installed"
    log_success "Low-latency kernel installed successfully"
    
    return 0
}

# ============================================================================
# Kernel Configuration
# ============================================================================

# Configure the low-latency kernel as default
function configure_lowlatency_kernel() {
    log_section "Configuring Low-Latency Kernel as Default"
    
    if check_state "${SCRIPT_NAME}_kernel_configured"; then
        log_info "Low-latency kernel configuration has already been completed. Skipping..."
        return 0
    fi
    
    # Update GRUB configuration to set low-latency kernel as default
    log_step "Setting low-latency kernel as default boot option"
    
    # Check if the low-latency kernel is already the default
    local default_kernel
    default_kernel=$(grep "^GRUB_DEFAULT=" /etc/default/grub | cut -d'"' -f2)
    
    if [[ "$default_kernel" == *"lowlatency"* ]]; then
        log_info "Low-latency kernel is already set as default"
    else
        # Get the menuentry for the low-latency kernel
        local kernel_version
        kernel_version=$(dpkg -l | grep 'linux-image-.*-lowlatency' | awk '{print $2}' | sed 's/linux-image-//' | sort -V | tail -n1)
        
        if [[ -z "$kernel_version" ]]; then
            log_warning "Could not find installed low-latency kernel version"
            return 1
        fi
        
        # Set the low-latency kernel as default in GRUB
        log_info "Setting GRUB_DEFAULT to low-latency kernel"
        if ! sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux '"$kernel_version"'"/g' /etc/default/grub; then
            log_error "Failed to update GRUB_DEFAULT setting"
            return 1
        fi
        
        # Update GRUB config
        log_info "Updating GRUB configuration"
        if ! update-grub; then
            log_error "Failed to update GRUB configuration"
            return 1
        fi
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_kernel_configured"
    log_success "Low-latency kernel configured as default successfully"
    
    return 0
}

# ============================================================================
# System Settings
# ============================================================================

# Configure system settings for low-latency operation
function configure_system_settings() {
    log_section "Configuring System for Low-Latency Operation"
    
    if check_state "${SCRIPT_NAME}_system_configured"; then
        log_info "Low-latency system settings have already been configured. Skipping..."
        return 0
    fi
    
    # Set CPU governor to performance
    log_step "Setting CPU governor to performance"
    
    # Check if cpufrequtils is installed
    if ! command -v cpufreq-set &> /dev/null; then
        log_info "Installing cpufrequtils package"
        if ! apt_install cpufrequtils; then
            log_warning "Failed to install cpufrequtils, skipping CPU governor setting"
        else
            # Set CPU governor to performance for all CPUs
            for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
                cpu_num=${cpu##*/cpu}
                log_info "Setting CPU $cpu_num governor to performance"
                if ! cpufreq-set -c "$cpu_num" -g performance; then
                    log_warning "Failed to set CPU $cpu_num governor to performance"
                fi
            done
        fi
    else
        # Set CPU governor to performance for all CPUs
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            cpu_num=${cpu##*/cpu}
            log_info "Setting CPU $cpu_num governor to performance"
            if ! cpufreq-set -c "$cpu_num" -g performance; then
                log_warning "Failed to set CPU $cpu_num governor to performance"
            fi
        done
    fi
    
    # Create sysctl configuration for low-latency
    log_step "Creating sysctl configuration for low-latency operation"
    
    cat > /etc/sysctl.d/99-lowlatency.conf << 'EOF'
# Kernel sysctl configuration for low-latency operation
# See sysctl.d(5) for details

# Increase the maximum number of memory map areas a process may have
vm.max_map_count = 1048576

# Improve system responsiveness under memory pressure
vm.swappiness = 10

# Improve filesystem performance
fs.inotify.max_user_watches = 524288

# Improve network performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF
    
    # Apply sysctl settings
    log_info "Applying sysctl settings"
    if ! sysctl -p /etc/sysctl.d/99-lowlatency.conf; then
        log_warning "Failed to apply some sysctl settings"
    fi
    
    # Create limits configuration for low-latency
    log_step "Creating limits configuration for low-latency operation"
    
    cat > /etc/security/limits.d/99-lowlatency.conf << 'EOF'
# Limits configuration for low-latency operation
# See limits.conf(5) for details

# Increase maximum number of open files
* soft nofile 1048576
* hard nofile 1048576

# Allow real-time scheduling
@audio soft rtprio 99
@audio hard rtprio 99
@audio soft memlock unlimited
@audio hard memlock unlimited
EOF
    
    # Create systemd service to set CPU governor on boot
    log_step "Creating systemd service for CPU governor"
    
    # Create the service file
    cat > /etc/systemd/system/cpu-governor.service << 'EOF'
[Unit]
Description=Set CPU Governor to Performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    systemctl daemon-reload
    systemctl enable cpu-governor.service
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_system_configured"
    log_success "Low-latency system settings configured successfully"
    
    log_warning "A system reboot is required to activate the low-latency kernel and settings"
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_lowlatency_kernel() {
    log_section "Setting Up Low-Latency Kernel"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Low-latency kernel has already been set up. Skipping..."
        return 0
    fi
    
    # Install the low-latency kernel
    if ! install_lowlatency_kernel; then
        log_error "Failed to install low-latency kernel"
        return 1
    fi
    
    # Configure the low-latency kernel as default
    if ! configure_lowlatency_kernel; then
        log_warning "Failed to configure low-latency kernel as default"
        # Continue anyway since the kernel is installed
    fi
    
    # Configure system settings for low-latency operation
    if ! configure_system_settings; then
        log_warning "Failed to configure some low-latency system settings"
        # Continue anyway since the kernel is installed
    fi
    
    # Create a reboot marker for the main installer
    touch "${STATE_DIR}/reboot_required"
    
    # Display a reminder about rebooting
    log_warning "Please reboot your system to start using the low-latency kernel"
    
    # Mark the entire script as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Low-latency kernel setup completed successfully"
    
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
setup_lowlatency_kernel

# Return the exit code
exit $?
