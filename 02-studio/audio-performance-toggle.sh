#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2034
# ============================================================================
# audio-performance-toggle.sh
# ----------------------------------------------------------------------------
# Toggles between conservative (safe) and performance (low-latency)
# audio settings for professional audio work
#
# This script will be installed to /usr/local/bin/audio-toggle
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail
set -o errtrace

# Script version
VERSION="1.0.0"

# Default mode if no arguments provided
DEFAULT_MODE="status"

# Configuration files
PIPEWIRE_CONF="/etc/pipewire/pipewire.conf.d/10-low-latency.conf"
RT_LIMITS_CONF="/etc/security/limits.d/99-audio-limits.conf"
CPU_SERVICE="/etc/systemd/system/cpu-performance-governor.service"

# User-specific PipeWire configuration paths
USER_CONFIG_DIR="${HOME}/.config/pipewire/pipewire.conf.d"
USER_CONFIG_FILE="${USER_CONFIG_DIR}/51-user-low-latency.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Print section header
print_header() {
    local message="$1"
    echo
    print_color "${BOLD}${BLUE}" "============================================"
    print_color "${BOLD}${BLUE}" "  ${message}"
    print_color "${BOLD}${BLUE}" "============================================"
    echo
}

# Print status message
print_status() {
    local message="$1"
    print_color "${CYAN}" "  → ${message}"
}

# Print success message
print_success() {
    local message="$1"
    print_color "${GREEN}" "  ✓ ${message}"
}

# Print warning message
print_warning() {
    local message="$1"
    print_color "${YELLOW}" "  ⚠ ${message}"
}

# Print error message
print_error() {
    local message="$1"
    print_color "${RED}" "  ✗ ${message}"
}

# Check if script is running as root
check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        print_error "This script must be run as root"
        print_status "Try: sudo $0"
        exit 1
    fi
}

# Check if a service is active
is_service_active() {
    local service_name="$1"
    systemctl is-active --quiet "${service_name}"
    return $?
}

# Restart PipeWire and related services
restart_pipewire() {
    print_status "Restarting PipeWire services..."

    # Find all active user sessions
    local users
    local who_output
    who_output=$(who || true)
    local user_list
    user_list=$(echo "${who_output}" | awk '{print $1}' | sort -u || true)
    mapfile -t users < <(echo "${user_list}")

    for user in "${users[@]}"; do
        local uid
        uid=$(id -u "${user}")
        if [[ ${uid} -ge 1000 ]]; then
            print_status "Restarting PipeWire for user ${user}"

            # Run as the user to restart their services
            su - "${user}" -c "systemctl --user restart pipewire pipewire-pulse wireplumber" || true
        fi
    done

    print_success "PipeWire services restarted"
}

# ============================================================================
# Configuration Functions
# ============================================================================

# Apply conservative (safe) audio settings
apply_conservative_settings() {
    print_header "Applying Conservative Audio Settings"

    # 1. Update PipeWire configuration for higher buffers
    print_status "Configuring PipeWire for conservative settings..."

    # System-wide configuration
    cat > "${PIPEWIRE_CONF}" << 'EOL'
# Conservative PipeWire configuration for stable audio
#
context.properties = {
    # Set higher buffer sizes for stability
    default.clock.rate = 48000
    default.clock.quantum = 256
    default.clock.min-quantum = 256
    default.clock.max-quantum = 8192
}

# Configure real-time properties with moderate priority
context.modules = [
    {   name = libpipewire-module-rt
        args = {
            # Use moderate nice level and RT priority
            nice.level = -10
            rt.prio = 79
            # Set reasonable real-time limits
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
]
EOL

    # 2. Update real-time limits to moderate values
    print_status "Setting moderate real-time limits..."

    cat > "${RT_LIMITS_CONF}" << 'EOL'
# Moderate real-time audio configuration
# Balance between performance and system stability
@audio   -  rtprio     79
@audio   -  memlock    4194304
@audio   -  nice       -10
@audio   -  priority   89
EOL

    # 3. Disable CPU performance governor service
    print_status "Setting CPU governor to powersave/ondemand..."
    if [[ -f "${CPU_SERVICE}" ]]; then
        systemctl stop cpu-performance-governor.service
        systemctl disable cpu-performance-governor.service

        # Reset CPU governors to default
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "ondemand" > "${cpu}" 2>/dev/null || echo "powersave" > "${cpu}" 2>/dev/null || true
        done
    fi

    # 4. Restart PipeWire
    restart_pipewire

    print_success "Conservative audio settings applied successfully"
    print_status "Your system is now configured for stable audio operation."
    print_status "These settings prioritize stability over absolute lowest latency."
    print_status "To switch to performance mode, run: sudo audio-toggle performance"
}

# Apply performance (low-latency) audio settings
apply_performance_settings() {
    print_header "Applying Performance Audio Settings"

    # 1. Update PipeWire configuration for lower buffers
    print_status "Configuring PipeWire for low-latency performance..."

    # System-wide configuration
    cat > "${PIPEWIRE_CONF}" << 'EOL'
# High-performance PipeWire configuration for low-latency audio
#
context.properties = {
    # Set low buffer sizes for minimal latency
    default.clock.rate = 48000
    default.clock.quantum = 64
    default.clock.min-quantum = 32
    default.clock.max-quantum = 8192
}

# Configure real-time properties with high priority
context.modules = [
    {   name = libpipewire-module-rt
        args = {
            # Use aggressive nice level and RT priority
            nice.level = -20
            rt.prio = 95
            # No real-time limits
            rt.time.soft = -1
            rt.time.hard = -1
        }
        flags = [ ifexists nofail ]
    }
]
EOL

    # 2. Update real-time limits to high values
    print_status "Setting high real-time limits..."

    cat > "${RT_LIMITS_CONF}" << 'EOL'
# High-performance real-time audio configuration
# Optimized for lowest possible latency
@audio   -  rtprio     99
@audio   -  memlock    unlimited
@audio   -  nice       -20
@audio   -  priority   99
EOL

    # 3. Enable and start CPU performance governor service
    print_status "Setting CPU governor to performance mode..."
    if [[ -f "${CPU_SERVICE}" ]]; then
        systemctl enable cpu-performance-governor.service
        systemctl start cpu-performance-governor.service
    else
        # Create the service if it doesn't exist
        cat > "${CPU_SERVICE}" << 'EOL'
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
        systemctl daemon-reload
        systemctl enable cpu-performance-governor.service
        systemctl start cpu-performance-governor.service
    fi

    # 4. Restart PipeWire
    restart_pipewire

    print_success "Performance audio settings applied successfully"
    print_status "Your system is now configured for low-latency audio operation."
    print_status "These settings prioritize lowest latency over absolute stability."
    print_status "Your CPU is locked in performance mode, which uses more power."
    print_status "To switch to conservative mode, run: sudo audio-toggle conservative"
}

# Show current audio configuration status
show_status() {
    print_header "Audio Configuration Status"

    # Check PipeWire configuration
    print_status "PipeWire Configuration:"
    if [[ -f "${PIPEWIRE_CONF}" ]]; then
        local quantum
        quantum=$(grep -o "default.clock.quantum = [0-9]*" "${PIPEWIRE_CONF}" | awk '{print $3}')
        local rt_prio
        rt_prio=$(grep -o "rt.prio = [0-9]*" "${PIPEWIRE_CONF}" | awk '{print $3}')

        echo -n "    Buffer size: "
        if [[ -n "${quantum}" ]]; then
            if [[ "${quantum}" -le 64 ]]; then
                print_color "${GREEN}" "${quantum} frames (low-latency mode)"
            else
                print_color "${YELLOW}" "${quantum} frames (conservative mode)"
            fi
        else
            print_color "${RED}" "unknown"
        fi

        echo -n "    Real-time priority: "
        if [[ -n "${rt_prio}" ]]; then
            if [[ "${rt_prio}" -ge 90 ]]; then
                print_color "${GREEN}" "${rt_prio} (high performance)"
            else
                print_color "${YELLOW}" "${rt_prio} (moderate)"
            fi
        else
            print_color "${RED}" "unknown"
        fi
    else
        print_color "${RED}" "    PipeWire low-latency configuration not found"
    fi

    # Check real-time limits
    print_status "Real-time Limits:"
    if [[ -f "${RT_LIMITS_CONF}" ]]; then
        local rtprio
        rtprio=$(grep -o "rtprio *[0-9]*" "${RT_LIMITS_CONF}" | awk '{print $2}')
        local memlock
        memlock=$(grep -o "memlock *[0-9a-z]*" "${RT_LIMITS_CONF}" | awk '{print $2}')

        echo -n "    RT priority limit: "
        if [[ -n "${rtprio}" ]]; then
            if [[ "${rtprio}" -ge 90 ]]; then
                print_color "${GREEN}" "${rtprio} (high performance)"
            else
                print_color "${YELLOW}" "${rtprio} (moderate)"
            fi
        else
            print_color "${RED}" "unknown"
        fi

        echo -n "    Memory lock limit: "
        if [[ -n "${memlock}" ]]; then
            if [[ "${memlock}" == "unlimited" ]]; then
                print_color "${GREEN}" "unlimited (high performance)"
            else
                print_color "${YELLOW}" "${memlock} (conservative)"
            fi
        else
            print_color "${RED}" "unknown"
        fi
    else
        print_color "${RED}" "    Real-time limits configuration not found"
    fi

    # Check CPU governor
    print_status "CPU Governor:"
    local cpu_service_status="inactive"
    if [[ -f "${CPU_SERVICE}" ]]; then
        if is_service_active "cpu-performance-governor"; then
            cpu_service_status="active"
        fi
    fi

    local governors=()
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "${cpu}" ]]; then
            local gov
            gov=$(cat "${cpu}")
            governors+=("${gov}")
        fi
    done

    if [[ "${governors[*]}" =~ "performance" ]]; then
        echo -n "    Current governor: "
        print_color "${GREEN}" "performance (high performance mode)"
        echo -n "    CPU governor service: "
        if [[ "${cpu_service_status}" == "active" ]]; then
            print_color "${GREEN}" "active and enabled"
        else
            print_color "${YELLOW}" "Performance mode is temporary (service not active)"
        fi
    else
        echo -n "    Current governor: "
        print_color "${YELLOW}" "${governors[0]} (power saving mode)"
        echo -n "    CPU governor service: "
        print_color "${YELLOW}" "${cpu_service_status}"
    fi

    # Overall assessment
    print_status "Overall Configuration:"
    local mode="mixed"

    # Check if performance mode
    if [[ -n "${quantum}" && "${quantum}" -le 64 && -n "${rtprio}" && "${rtprio}" -ge 90 &&
          "${governors[*]}" =~ "performance" && "${cpu_service_status}" == "active" ]]; then
        mode="performance"
    fi

    # Check if conservative mode
    if [[ -n "${quantum}" && "${quantum}" -ge 128 && -n "${rtprio}" && "${rtprio}" -le 80 &&
          ! "${governors[*]}" =~ "performance" ]]; then
        mode="conservative"
    fi

    echo -n "    Current mode: "
    if [[ "${mode}" == "performance" ]]; then
        print_color "${GREEN}" "PERFORMANCE (optimized for lowest latency)"
        print_status "To switch to conservative mode: sudo audio-toggle conservative"
    elif [[ "${mode}" == "conservative" ]]; then
        print_color "${YELLOW}" "CONSERVATIVE (optimized for stability)"
        print_status "To switch to performance mode: sudo audio-toggle performance"
    else
        print_color "${MAGENTA}" "MIXED (custom configuration)"
        print_status "To use a standard preset, run either:"
        print_status "  sudo audio-toggle performance"
        print_status "  sudo audio-toggle conservative"
    fi
}

# Show usage information
show_usage() {
    print_header "Audio Performance Toggle v${VERSION}"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  conservative    Apply conservative settings for stability"
    echo "  performance     Apply high-performance settings for low-latency"
    echo "  status          Show current configuration status (default)"
    echo "  help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 performance     # Switch to performance mode"
    echo "  $0 conservative    # Switch to conservative mode"
    echo "  $0 status          # Show current status"
    echo
    print_status "This script toggles between audio configuration presets"
    print_status "Performance mode: optimized for lowest latency (may be less stable)"
    print_status "Conservative mode: optimized for stability (higher latency)"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # If no arguments provided, use default mode
    local mode="${1:-${DEFAULT_MODE}}"

    case "${mode}" in
        conservative)
            check_root
            apply_conservative_settings
            ;;
        performance)
            check_root
            apply_performance_settings
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown option: ${mode}"
            show_usage
            exit 1
            ;;
    esac

    exit 0
}

# Run main function with all arguments
main "$@"
