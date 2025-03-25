#!/usr/bin/env bash
# ============================================================================
# 00-system-performance.sh
# ----------------------------------------------------------------------------
# System performance optimization script that applies various optimizations:
# - I/O scheduler tuning
# - System resource limits
# - Kernel parameter optimization
# - System profile manager for performance/power balance
# ============================================================================

# shellcheck disable=SC1091,SC2154,SC2312

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
SCRIPT_NAME="00-system-performance"

# ============================================================================
# I/O Scheduler Optimization
# ============================================================================
function optimize_io_scheduler() {
    log_step "Optimizing I/O Scheduler Settings"

    if check_state "${SCRIPT_NAME}_io_scheduler_optimized"; then
        log_info "I/O scheduler optimization already completed. Skipping..."
        return 0
    fi

    log_info "Detecting available block devices..."
    # Get all block devices except loop devices, ram, and optical drives
    local block_devices
    mapfile -t block_devices < <(lsblk -d -o NAME | grep -v "loop\|ram\|sr" | tail -n +2)

    if [[ ${#block_devices[@]} -eq 0 ]]; then
        log_warning "No suitable block devices found for optimization."
        return 1
    fi

    log_info "Found block devices: ${block_devices[*]}"

    # Detect if we're using SSDs or HDDs
    local ssd_devices=()
    local hdd_devices=()

    for device in "${block_devices[@]}"; do
        if [[ -d "/sys/block/${device}/queue" ]]; then
            # Check if the device is rotational (0 = SSD, 1 = HDD)
            local rotational
            rotational=$(cat "/sys/block/${device}/queue/rotational") || true
            if [[ ${rotational} -eq 0 ]]; then
                ssd_devices+=("${device}")
            else
                hdd_devices+=("${device}")
            fi
        fi
    done

    log_info "SSD devices: ${ssd_devices[*]:-None}"
    log_info "HDD devices: ${hdd_devices[*]:-None}"

    # Apply optimizations for SSD devices
    for device in "${ssd_devices[@]}"; do
        log_info "Applying SSD optimizations for /dev/${device}"

        # Set scheduler to 'none' or 'deadline' for SSDs
        if [[ -f "/sys/block/${device}/queue/scheduler" ]]; then
            local schedulers
            schedulers=$(cat "/sys/block/${device}/queue/scheduler")

            # Check available schedulers
            if [[ ${schedulers} == *"[none]"* ]]; then
                # none is already set as default
                log_info "Scheduler 'none' is already active for /dev/${device}"
            elif [[ ${schedulers} == *"none"* ]]; then
                echo "none" > "/sys/block/${device}/queue/scheduler"
                log_info "Set scheduler to 'none' for /dev/${device}"
            elif [[ ${schedulers} == *"deadline"* ]]; then
                echo "deadline" > "/sys/block/${device}/queue/scheduler"
                log_info "Set scheduler to 'deadline' for /dev/${device}"
            else
                log_warning "Could not set optimal scheduler for /dev/${device}, available schedulers: ${schedulers}"
            fi
        else
            log_warning "Scheduler configuration not available for /dev/${device}"
        fi

        # Optimize read-ahead for SSDs
        if [[ -f "/sys/block/${device}/queue/read_ahead_kb" ]]; then
            echo "256" > "/sys/block/${device}/queue/read_ahead_kb"
            log_info "Set read_ahead_kb to 256 for /dev/${device}"
        fi

        # Reduce disk I/O queuing (good for SSDs)
        if [[ -f "/sys/block/${device}/queue/nr_requests" ]]; then
            echo "64" > "/sys/block/${device}/queue/nr_requests"
            log_info "Set nr_requests to 64 for /dev/${device}"
        fi

        # Enable TRIM if available (this is for permanent configuration)
        if command -v fstrim &>/dev/null; then
            fstrim -v / || log_warning "TRIM failed for /"
            log_info "Enabled weekly TRIM via systemd timer"
            if ! systemctl is-enabled fstrim.timer &>/dev/null; then
                systemctl enable fstrim.timer
            fi
        fi
    done

    # Apply optimizations for HDD devices
    for device in "${hdd_devices[@]}"; do
        log_info "Applying HDD optimizations for /dev/${device}"

        # Set scheduler to 'bfq' or 'cfq' for HDDs
        if [[ -f "/sys/block/${device}/queue/scheduler" ]]; then
            local schedulers
            schedulers=$(cat "/sys/block/${device}/queue/scheduler")

            # Check available schedulers
            if [[ ${schedulers} == *"[bfq]"* ]]; then
                # bfq is already set as default
                log_info "Scheduler 'bfq' is already active for /dev/${device}"
            elif [[ ${schedulers} == *"bfq"* ]]; then
                echo "bfq" > "/sys/block/${device}/queue/scheduler"
                log_info "Set scheduler to 'bfq' for /dev/${device}"
            elif [[ ${schedulers} == *"cfq"* ]]; then
                echo "cfq" > "/sys/block/${device}/queue/scheduler"
                log_info "Set scheduler to 'cfq' for /dev/${device}"
            else
                log_warning "Could not set optimal scheduler for /dev/${device}, available schedulers: ${schedulers}"
            fi
        else
            log_warning "Scheduler configuration not available for /dev/${device}"
        fi

        # Optimize read-ahead for HDDs
        if [[ -f "/sys/block/${device}/queue/read_ahead_kb" ]]; then
            echo "1024" > "/sys/block/${device}/queue/read_ahead_kb"
            log_info "Set read_ahead_kb to 1024 for /dev/${device}"
        fi

        # Set higher nr_requests for HDDs (deeper queue)
        if [[ -f "/sys/block/${device}/queue/nr_requests" ]]; then
            echo "128" > "/sys/block/${device}/queue/nr_requests"
            log_info "Set nr_requests to 128 for /dev/${device}"
        fi
    done

    # Make scheduler settings persistent
    log_info "Making I/O scheduler settings persistent..."
    local udev_rules_file="/etc/udev/rules.d/60-scheduler.rules"

    rm -f "${udev_rules_file}"
    touch "${udev_rules_file}"

    # Add rules for SSD devices
    for device in "${ssd_devices[@]}"; do
        {
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"none\""
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"0\", ATTR{queue/read_ahead_kb}=\"256\""
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"0\", ATTR{queue/nr_requests}=\"64\""
        } >> "${udev_rules_file}"
    done

    # Add rules for HDD devices
    for device in "${hdd_devices[@]}"; do
        {
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"1\", ATTR{queue/scheduler}=\"bfq\""
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"1\", ATTR{queue/read_ahead_kb}=\"1024\""
            echo "ACTION==\"add|change\", KERNEL==\"${device}\", ATTR{queue/rotational}==\"1\", ATTR{queue/nr_requests}=\"128\""
        } >> "${udev_rules_file}"
    done

    log_info "Created udev rules at ${udev_rules_file}"

    # Reload udev rules
    udevadm control --reload-rules || log_warning "Failed to reload udev rules"

    set_state "${SCRIPT_NAME}_io_scheduler_optimized"
    log_success "I/O scheduler optimization completed"
    return 0
}

# ============================================================================
# System Resource Limits Optimization
# ============================================================================
function optimize_system_limits() {
    log_step "Optimizing System Resource Limits"

    if check_state "${SCRIPT_NAME}_system_limits_optimized"; then
        log_info "System resource limits optimization already completed. Skipping..."
        return 0
    fi

    log_info "Configuring system resource limits..."

    # Backup existing limits.conf file
    if [[ -f "/etc/security/limits.conf" ]]; then
        cp "/etc/security/limits.conf" "/etc/security/limits.conf.bak"
        log_info "Backed up original limits.conf to limits.conf.bak"
    fi

    # Create/update limits.conf with optimized settings
    cat > "/etc/security/limits.conf" << EOF
# /etc/security/limits.conf
#
# Each line describes a limit for a user in the form:
# <domain> <type> <item> <value>
#
# Modified by system-performance optimization script

# Increase max user processes
*       soft    nproc     65535
*       hard    nproc     65535

# Increase open file limits
*       soft    nofile    65535
*       hard    nofile    65535

# Increase max memory locked - needed for audio work
@audio  soft    memlock   unlimited
@audio  hard    memlock   unlimited

# For regular users, set a smaller but still large memlock limit
*       soft    memlock   16384
*       hard    memlock   32768

# Increase max number of memory map areas
*       soft    rss       unlimited
*       hard    rss       unlimited

# End of file
EOF

    log_info "Updated /etc/security/limits.conf with optimized resource limits"

    # Update PAM configuration to ensure limits are applied
    if [[ -f "/etc/pam.d/common-session" ]]; then
        if ! grep -q "pam_limits.so" "/etc/pam.d/common-session"; then
            echo "session required pam_limits.so" >> "/etc/pam.d/common-session"
            log_info "Updated PAM configuration to apply limits"
        else
            log_info "PAM already configured to apply limits"
        fi
    fi

    # Configure system-wide limits in sysctl
    log_info "Configuring system-wide kernel limits..."

    local sysctl_conf="/etc/sysctl.d/99-system-limits.conf"

    cat > "${sysctl_conf}" << EOF
# Kernel system limits - configured by system optimization script

# Maximum number of file handles
fs.file-max = 2097152

# Maximum number of inotify watches
fs.inotify.max_user_watches = 524288

# Maximum number of inotify instances
fs.inotify.max_user_instances = 1024

# Increase the maximum amount of memory map areas a process may have
vm.max_map_count = 262144

# Increase kernel.pid_max for systems with many processes
kernel.pid_max = 4194304

# Increase network limits
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 16384
EOF

    log_info "Applied system-wide kernel limits in ${sysctl_conf}"

    # Apply sysctl settings
    sysctl -p "${sysctl_conf}" || log_warning "Failed to apply some sysctl settings"

    set_state "${SCRIPT_NAME}_system_limits_optimized"
    log_success "System resource limits optimization completed"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function optimize_system_performance() {
    log_section "Optimizing System Performance"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "System performance optimization has already been completed. Skipping..."
        return 0
    fi

    # Run I/O scheduler optimization
    if ! optimize_io_scheduler; then
        log_warning "I/O scheduler optimization encountered issues"
    fi

    # Run system resource limits optimization
    if ! optimize_system_limits; then
        log_warning "System resource limits optimization encountered issues"
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "System performance optimization completed successfully"

    log_warning "A system reboot is recommended to apply all optimizations"

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

# Run the main optimization function
optimize_system_performance

# Return the exit code
exit $?
