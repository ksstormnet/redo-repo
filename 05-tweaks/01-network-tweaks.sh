#!/usr/bin/env bash
# ============================================================================
# 01-network-tweaks.sh
# ----------------------------------------------------------------------------
# Script to optimize network settings for wired (Ethernet) connections
# Implements advanced network tweaks for better performance and DNS configuration
# ============================================================================

# shellcheck disable=SC1091,SC2250

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
SCRIPT_NAME="01-network-tweaks"

# ============================================================================
# Network Optimization Functions
# ============================================================================

# Function to optimize TCP/IP stack for wired connections
function optimize_tcp_ip_stack() {
    log_step "Optimizing TCP/IP Stack for Wired Connections"

    if check_state "${SCRIPT_NAME}_tcp_ip_optimized"; then
        log_info "TCP/IP stack already optimized. Skipping..."
        return 0
    fi

    # Create the sysctl configuration file
    log_info "Creating sysctl network optimization configuration"

    cat > /etc/sysctl.d/99-network-tuning.conf << 'EOF'
# TCP/IP Stack Optimizations for Wired Connections

# Increase TCP max buffer sizes for high-bandwidth connections
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.netdev_max_backlog = 5000
net.core.optmem_max = 16777216

# Increase TCP buffer limits
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP fast open for both incoming and outgoing connections
net.ipv4.tcp_fastopen = 3

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Enable timestamps as defined in RFC1323
net.ipv4.tcp_timestamps = 1

# Enable select acknowledgments
net.ipv4.tcp_sack = 1

# Increase maximum number of connections waiting to be accepted
net.core.somaxconn = 65535

# Set maximum number of remembered connection requests
net.ipv4.tcp_max_syn_backlog = 65536

# Maximum number of packets queued on the INPUT side
net.ipv4.tcp_max_tw_buckets = 1440000

# Reuse sockets in TIME_WAIT state when safe
net.ipv4.tcp_tw_reuse = 1

# Disable TCP slow start after idle
net.ipv4.tcp_slow_start_after_idle = 0

# Use BBR TCP congestion control algorithm
net.ipv4.tcp_congestion_control = bbr

# Prefer low latency to higher throughput
net.ipv4.tcp_low_latency = 1

# Reduce TCP keepalive time to free resources more quickly
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5

# Increase ephemeral port range
net.ipv4.ip_local_port_range = 1024 65535

# Enable IP forwarding if needed for containers
net.ipv4.ip_forward = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
EOF

    # Apply sysctl settings
    log_info "Applying sysctl network optimization settings"
    sysctl -p /etc/sysctl.d/99-network-tuning.conf

    # Check if the bbr module is available
    if ! lsmod | grep -q "tcp_bbr"; then
        log_info "Loading BBR TCP congestion control module"
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/tcp_bbr.conf
    fi

    set_state "${SCRIPT_NAME}_tcp_ip_optimized"
    log_success "TCP/IP stack optimized successfully"
    return 0
}

# Function to set up NetworkManager dispatcher script
function setup_network_dispatcher() {
    log_step "Setting Up NetworkManager Dispatcher Script"

    if check_state "${SCRIPT_NAME}_network_dispatcher_setup"; then
        log_info "Network dispatcher script already set up. Skipping..."
        return 0
    fi

    # Create the dispatcher directory if it doesn't exist
    mkdir -p /etc/NetworkManager/dispatcher.d

    # Create the dispatcher script for Ethernet connections
    log_info "Creating NetworkManager dispatcher script for Ethernet"

    cat > /etc/NetworkManager/dispatcher.d/99-ethernet-optimizations << 'EOF'
#!/bin/bash
# This script applies network optimizations when Ethernet connections are established

INTERFACE="$1"
ACTION="$2"

# Only act on Ethernet interfaces when they go up
if [[ "$ACTION" == "up" ]]; then
    # Check if this is an Ethernet interface
    if nmcli -g GENERAL.TYPE device show "$INTERFACE" | grep -q "ethernet"; then
        logger -t network-tweaks "Applying optimizations to Ethernet interface $INTERFACE"

        # Set interface queue length
        ip link set "$INTERFACE" txqueuelen 10000

        # Disable TCP segmentation offload if it causes issues
        # ethtool -K "$INTERFACE" tso off gso off

        # Set the MTU to 9000 for jumbo frames if your network supports it
        # Note: Only enable this if your entire network path supports jumbo frames
        # ip link set "$INTERFACE" mtu 9000

        # This might not be needed on all systems, but can help with some hardware
        # ethtool -G "$INTERFACE" rx 4096 tx 4096

        # Apply receive packet steering if supported (for multi-CPU systems)
        if [ -f /proc/irq/default_smp_affinity ]; then
            find /sys/class/net/$INTERFACE/queues/rx-* -name rps_cpus | while read file; do
                echo "f" > $file
            done
            find /sys/class/net/$INTERFACE/queues/tx-* -name xps_cpus | while read file; do
                echo "f" > $file
            done
        fi

        logger -t network-tweaks "Successfully applied optimizations to $INTERFACE"
    fi
fi
EOF

    # Set execute permissions
    chmod +x /etc/NetworkManager/dispatcher.d/99-ethernet-optimizations

    # Restart NetworkManager to apply changes
    log_info "Restarting NetworkManager service"
    systemctl restart NetworkManager

    set_state "${SCRIPT_NAME}_network_dispatcher_setup"
    log_success "Network dispatcher script set up successfully"
    return 0
}

# Function to configure DNS settings
function configure_dns_settings() {
    log_step "Configuring DNS Settings"

    if check_state "${SCRIPT_NAME}_dns_configured"; then
        log_info "DNS settings already configured. Skipping..."
        return 0
    fi

    # Configure systemd-resolved for better DNS resolution
    log_info "Configuring systemd-resolved for optimal DNS performance"

    cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
# Use Cloudflare and Google DNS servers
DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
# Fallback to using system DHCP-provided DNS if needed
FallbackDNS=9.9.9.9 149.112.112.112
# Set DNS over TLS mode to opportunistic
DNSOverTLS=opportunistic
# Enable DNSSEC validation
DNSSEC=allow-downgrade
# Set cache size (in bytes)
CacheSize=32M
# Set DNS query timeout
DNSStubListenerExtra=127.0.0.1
ReadEtcHosts=yes
EOF

    # Configure NSS for proper name resolution
    log_info "Configuring Name Service Switch (NSS)"

    cat > /etc/nsswitch.conf << 'EOF'
# /etc/nsswitch.conf
# Example Name Service Switch config file.

passwd:         files systemd
group:          files systemd
shadow:         files
gshadow:        files

hosts:          files resolve [!UNAVAIL=return] dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

    # Configure Avahi for local network discovery
    log_info "Configuring Avahi daemon for local network discovery"

    # Install Avahi if not already installed
    if ! command -v avahi-daemon &> /dev/null; then
        log_info "Installing Avahi daemon packages"
        apt_install avahi-daemon libnss-mdns
    fi

    # Configure Avahi
    cat > /etc/avahi/avahi-daemon.conf << 'EOF'
[server]
host-name-from-machine-id=yes
use-ipv4=yes
use-ipv6=no
allow-interfaces=eth0,en*
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-hinfo=no
publish-workstation=no

[reflector]
enable-reflector=yes

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
EOF

    # Restart services to apply changes
    log_info "Restarting DNS-related services"
    systemctl restart systemd-resolved
    systemctl restart avahi-daemon
    systemctl enable avahi-daemon

    set_state "${SCRIPT_NAME}_dns_configured"
    log_success "DNS settings configured successfully"
    return 0
}

# Function to perform basic networking tests
function test_network_settings() {
    log_step "Testing Network Optimizations"

    # Test DNS resolution
    log_info "Testing DNS resolution..."
    if host -t A google.com > /dev/null; then
        log_success "DNS resolution working correctly"
    else
        log_warning "DNS resolution test failed. Check your network settings."
    fi

    # Test TCP connection
    log_info "Testing TCP connection..."
    if ping -c 4 1.1.1.1 > /dev/null; then
        log_success "TCP connection working correctly"
    else
        log_warning "TCP connection test failed. Check your network settings."
    fi

    # Display information about network throughput testing
    log_info "Network optimizations applied. For throughput testing, consider using:"
    log_info "  - iperf3 for bandwidth testing"
    log_info "  - ping for latency testing"
    log_info "  - traceroute for path analysis"

    return 0
}

# ============================================================================
# Main Function
# ============================================================================
function network_tweaks_main() {
    log_section "Network Tweaks for Wired Connections"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Network tweaks have already been applied. Skipping..."
        return 0
    fi

    # Optimize TCP/IP stack
    optimize_tcp_ip_stack || log_warning "Failed to optimize some TCP/IP stack settings"

    # Set up NetworkManager dispatcher script
    setup_network_dispatcher || log_warning "Failed to set up NetworkManager dispatcher script"

    # Configure DNS settings
    configure_dns_settings || log_warning "Failed to configure some DNS settings"

    # Test network settings
    test_network_settings

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Network optimization completed successfully"

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

# Parse command line arguments
FORCE_MODE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_MODE="true"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force    Force re-application of network tweaks"
            echo "  --help     Display this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Call the main function
network_tweaks_main

# Return the exit code
exit $?
