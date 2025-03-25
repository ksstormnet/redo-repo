#!/bin/bash

# 17-system-tuning-tweaks.sh
# This script applies advanced system tuning configurations for optimized performance
# with development work, audio production, and ML/LLM inference.
# Modified to use restored configurations from critical backup

# Exit on any error
set -e

# Function to display section headers
section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Check if script is run as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Display welcome message
section "Advanced System Tuning"
echo "This script will apply advanced performance tuning configurations for:"
echo "  - Development workloads"
echo "  - Audio production with low latency"
echo "  - Machine learning with NVIDIA RTX GPU"
echo "  - General system responsiveness"
echo

read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# ======================================================================
# 1. Advanced sysctl Parameter Configuration
# ======================================================================
section "Configuring Advanced sysctl Parameters"

echo "Creating sysctl configuration..."
cat > /etc/sysctl.d/99-system-optimizations.conf << 'EOF'
# -----------------------------------------------------------------------------------
# MEMORY MANAGEMENT
# -----------------------------------------------------------------------------------

# VM settings for improved memory management
vm.swappiness = 10                # Reduce swap usage, prefer to keep things in RAM
vm.vfs_cache_pressure = 50        # Don't aggressively remove inode/dentry cache
vm.dirty_ratio = 10               # Percentage of memory that can be filled with dirty pages before processes are forced to write out
vm.dirty_background_ratio = 5     # Percentage of memory that can be filled with dirty pages before background processes kick in
vm.dirty_expire_centisecs = 1000  # When to write out dirty data (10 seconds)
vm.dirty_writeback_centisecs = 500 # How often to check for dirty data (5 seconds)
vm.max_map_count = 1048576        # Increase maximum number of memory map areas a process may have (helps with CUDA and ML workloads)

# -----------------------------------------------------------------------------------
# FILE SYSTEM & I/O PERFORMANCE
# -----------------------------------------------------------------------------------

# Increase file max limits
fs.file-max = 2097152             # Maximum number of file descriptors
fs.inotify.max_user_watches = 524288 # Increase inotify watches (helps with file watching tools)
fs.inotify.max_user_instances = 512  # Increase for development environments

# AIO limits for intensive I/O operations
fs.aio-max-nr = 1048576           # Increase max outstanding async I/O operations

# -----------------------------------------------------------------------------------
# NETWORK PERFORMANCE
# -----------------------------------------------------------------------------------

# TCP settings
net.core.somaxconn = 1024         # Increase the TCP socket queue size
net.core.netdev_max_backlog = 5000 # Maximum number of packets in the network receive queue
net.ipv4.tcp_max_syn_backlog = 8192 # Maximum SYN backlog queue size
net.ipv4.tcp_slow_start_after_idle = 0 # Disable TCP slow start after connection idle
net.ipv4.tcp_rmem = 4096 87380 16777216 # TCP receive buffer sizes (min, default, max)
net.ipv4.tcp_wmem = 4096 65536 16777216 # TCP send buffer sizes (min, default, max)
net.core.rmem_max = 16777216      # Maximum receive socket buffer size
net.core.wmem_max = 16777216      # Maximum send socket buffer size
net.ipv4.tcp_mtu_probing = 1      # Enable MTU probing

# IPv4 networking
net.ipv4.ip_local_port_range = 1024 65535 # Increase available local ports
net.ipv4.tcp_fin_timeout = 15     # Reduce TCP FIN timeout to free up connections faster
net.ipv4.tcp_keepalive_time = 300 # Reduce keepalive time to detect dead connections faster
net.ipv4.tcp_keepalive_probes = 5 # Number of probes before dropping a connection
net.ipv4.tcp_keepalive_intvl = 15 # Interval between keepalive probes

# -----------------------------------------------------------------------------------
# KERNEL & SYSTEM PERFORMANCE
# -----------------------------------------------------------------------------------

# General kernel parameters
kernel.sched_autogroup_enabled = 1 # Enable scheduler autogroups (better desktop experience)
kernel.pid_max = 4194304          # Increase maximum number of process IDs
kernel.threads-max = 4194304      # Increase maximum number of threads

# Increase kernel shared memory parameters (helps with CUDA and ML workloads)
kernel.shmmax = 34359738368       # Maximum shared memory segment size (32GB)
kernel.shmall = 8388608           # Maximum total shared memory

# -----------------------------------------------------------------------------------
# SECURITY SETTINGS (with reasonable defaults)
# -----------------------------------------------------------------------------------

# Protect against various network attacks
net.ipv4.conf.all.log_martians = 1       # Log packets with impossible addresses
net.ipv4.conf.all.rp_filter = 1          # Enable source route verification
net.ipv4.conf.default.rp_filter = 1       
net.ipv4.tcp_syncookies = 1              # Enable SYN cookies for SYN flood protection

# -----------------------------------------------------------------------------------
# REAL-TIME & LOW-LATENCY AUDIO
# -----------------------------------------------------------------------------------

# PREEMPT & RT settings
kernel.sched_rt_runtime_us = -1   # Allow RT tasks to run indefinitely (for audio)
kernel.sched_rt_period_us = 1000000 # Default period for RT tasks

# -----------------------------------------------------------------------------------
# GPU & COMPUTE WORKLOAD OPTIMIZATIONS
# -----------------------------------------------------------------------------------

# NUMA settings (if applicable - helps with GPU performance)
kernel.numa_balancing = 0         # Disable automatic NUMA balancing for CUDA workloads

# -----------------------------------------------------------------------------------
# FILESYSTEM OPTIMIZATIONS
# -----------------------------------------------------------------------------------

# Extend writeback for SSD/NVMe drives
vm.dirty_background_bytes = 104857600 # 100MB - When to start background writeback
vm.dirty_bytes = 524288000         # 500MB - When to force synchronous writeback

# -----------------------------------------------------------------------------------
# DMESG RESTRICTIONS (development friendly)
# -----------------------------------------------------------------------------------

# Allow regular users to see kernel logs (useful for debugging)
kernel.dmesg_restrict = 0
EOF


echo "Applying sysctl settings..."
sysctl -p /etc/sysctl.d/99-system-optimizations.conf

echo "✓ Configured advanced sysctl parameters"

# ======================================================================
# 2. System Profile Manager
# ======================================================================
section "Setting Up System Profile Manager"

cat > /usr/local/bin/toggle-system-profile << 'EOF'
#!/bin/bash
# Toggle between performance and normal system profiles

PROFILE_FLAG="/tmp/system-performance-profile"

if [[ -f "${PROFILE_FLAG}" ]]; then
    # Switch to normal profile
    echo "Switching to normal system profile"
    
    # Memory management
    sysctl -w vm.swappiness=10
    sysctl -w vm.vfs_cache_pressure=50
    sysctl -w vm.dirty_ratio=10
    sysctl -w vm.dirty_background_ratio=5
    
    # CPU governor (if cpufreq is available)
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "powersave" | tee "${cpu}"
        done
    fi
    
    # NVIDIA settings (if nvidia-settings is installed)
    if command -v nvidia-settings &> /dev/null; then
        # Reset to balanced power management
        nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=0" > /dev/null 2>&1
    fi
    
    # Remove the flag file
    rm "${PROFILE_FLAG}"
    
    notify-send "System Profile" "Switched to normal profile" --icon=preferences-system
else
    # Switch to performance profile
    echo "Switching to performance system profile"
    
    # Memory management for performance
    sysctl -w vm.swappiness=1
    sysctl -w vm.vfs_cache_pressure=20
    sysctl -w vm.dirty_ratio=30
    sysctl -w vm.dirty_background_ratio=10
    
    # CPU governor (if cpufreq is available)
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "performance" | tee "${cpu}"
        done
    fi
    
    # NVIDIA settings (if nvidia-settings is installed)
    if command -v nvidia-settings &> /dev/null; then
        # Set to maximum performance
        nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1
    fi
    
    # Create the flag file
    touch "${PROFILE_FLAG}"
    
    notify-send "System Profile" "Switched to performance profile" --icon=preferences-system-performance
fi
EOF

chmod +x /usr/local/bin/toggle-system-profile

# Create desktop entry for system profile toggle
if [[ ! -f "/usr/share/applications/toggle-system-profile.desktop" ]]; then
    echo "Creating desktop entry for system profile toggle..."
    cat > /usr/share/applications/toggle-system-profile.desktop << EOF
[Desktop Entry]
Name=Toggle System Profile
Comment=Switch between performance and normal system profiles
Exec=pkexec /usr/local/bin/toggle-system-profile
Icon=preferences-system-performance
Terminal=false
Type=Application
Categories=System;
EOF
fi

# Create polkit rules for passwordless execution
if [[ ! -f "/etc/polkit-1/rules.d/91-system-profile.rules" ]]; then
    echo "Setting up polkit rules for passwordless execution..."
    cat > /etc/polkit-1/rules.d/91-system-profile.rules << EOF
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/bin/toggle-system-profile" &&
        subject.isInGroup("sudo")) {
            return polkit.Result.YES;
    }
});
EOF
fi

echo "✓ System profile manager installed"

# ======================================================================
# 3. NVIDIA Optimization (if NVIDIA GPU is detected)
# ======================================================================
section "NVIDIA GPU Optimizations"

# Check if NVIDIA GPU is present
if lspci | grep -i nvidia > /dev/null || true; then
    echo "NVIDIA GPU detected, applying optimizations..."
    
    if [[ "${NVIDIA_CONFIG_RESTORED}" = false ]]; then
        # Create NVIDIA configuration directory if it doesn't exist
        mkdir -p /etc/X11/xorg.conf.d/
        
        # Create NVIDIA configuration file
        cat > /etc/X11/xorg.conf.d/20-nvidia.conf << EOF
Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    Option         "NoLogo" "1"
    Option         "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x3322; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
    Option         "TripleBuffer" "True"
    Option         "metamodes" "nvidia-auto-select +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
    Option         "AllowIndirectGLXProtocol" "off"
EndSection
EOF
    fi
    
    # Create NVIDIA persistent settings script if not already present
    if [[ ! -f "/etc/X11/xinit/xinitrc.d/30-nvidia-settings.sh" ]]; then
        # Create directory if it doesn't exist
        mkdir -p /etc/X11/xinit/xinitrc.d/
        
        # Create NVIDIA persistent settings script
        cat > /etc/X11/xinit/xinitrc.d/30-nvidia-settings.sh << 'EOF'
#!/bin/sh

# Apply NVIDIA settings on X startup
if command -v nvidia-settings > /dev/null; then
    # Set power management mode to "Prefer Maximum Performance"
    nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" > /dev/null 2>&1
    
    # Enable persistence mode
    if command -v nvidia-smi > /dev/null; then
        nvidia-smi -pm 1 > /dev/null 2>&1
    fi
fi
EOF
        
        chmod +x /etc/X11/xinit/xinitrc.d/30-nvidia-settings.sh
    fi
    
    # Create CUDA optimizations if not already present
    if [[ ! -f "/etc/profile.d/cuda-optimization.sh" ]]; then
        # Create CUDA optimizations
        cat > /etc/profile.d/cuda-optimization.sh << 'EOF'
#!/bin/sh

# Set CUDA environment variables for performance
export CUDA_CACHE_DISABLE=0
export CUDA_CACHE_MAXSIZE=2147483648  # 2GB
export __GL_THREADED_OPTIMIZATIONS=1
EOF
        
        chmod +x /etc/profile.d/cuda-optimization.sh
    fi
    
    echo "✓ NVIDIA optimizations applied"
else
    echo "No NVIDIA GPU detected, skipping NVIDIA-specific optimizations"
fi

# ======================================================================
# 4. I/O Scheduler Optimization
# ======================================================================
section "Storage I/O Scheduler Optimization"

    cat > /etc/udev/rules.d/60-ioschedulers.rules << EOF
# Set scheduler for NVMe drives
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# Set scheduler for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# Set scheduler for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

# Apply to current devices
echo "Applying I/O scheduler settings to current devices..."
for device in /sys/block/sd*; do
    if [[ -e "${device}/queue/rotational" ]]; then
        rotational=$(cat "${device}/queue/rotational") || true
        dev_name=$(basename "${device}") || true
        
        if [[ "${rotational}" -eq 0 ]]; then
            # This is an SSD
            echo "mq-deadline" > "${device}/queue/scheduler"
            echo "  ✓ Set mq-deadline scheduler for SSD ${dev_name}"
        else
            # This is an HDD
            echo "bfq" > "${device}/queue/scheduler"
            echo "  ✓ Set bfq scheduler for HDD ${dev_name}"
        fi
    fi
done

# Apply to NVMe devices
for device in /sys/block/nvme*; do
    if [[ -e "${device}" ]]; then
        dev_name=$(basename "${device}") || true
        echo "none" > "${device}/queue/scheduler"
        echo "  ✓ Set none scheduler for NVMe ${dev_name}"
    fi
done

echo "✓ I/O scheduler optimization completed"

# ======================================================================
# 5. System Resource Limits
# ======================================================================
section "System Resource Limits Configuration"

cat > /etc/security/limits.d/99-system-limits.conf << EOF
# Increase file limits for all users
*               soft    nofile          65536
*               hard    nofile          65536

# Limits for real-time audio
@audio          -       rtprio          95
@audio          -       memlock         unlimited

# Higher limits for development work
@sudo           -       nproc           unlimited
@sudo           -       memlock         unlimited
EOF

echo "✓ System resource limits configured"

# ======================================================================
# Restore Custom Scripts from Backup
# ======================================================================
section "Restoring Custom System Tuning Scripts"

# Check for custom scripts in the backup
if [[ -n "${RESTORED_SYSCTL_CONFIG}" ]] && [[ -d "${RESTORED_SYSCTL_CONFIG}/scripts" ]]; then
    echo "Found custom system tuning scripts in backup:"
    mkdir -p /usr/local/bin/system-tuning/
    
    # Copy each custom script
    for script in "${RESTORED_SYSCTL_CONFIG}/scripts"/*; do
        if [[ -f "${script}" ]]; then
            script_name=$(basename "${script}")
            cp -f "${script}" /usr/local/bin/system-tuning/
            chmod +x "/usr/local/bin/system-tuning/${script_name}"
            echo "✓ Restored custom script: ${script_name}"
            
            # Create desktop entry for script if it ends with -optimizer.sh
            if [[ "${script_name}" == *-optimizer.sh ]]; then
                # Process the display name safely
                display_name=""
                display_name=$(echo "${script_name}" | sed 's/-optimizer.sh//g' | tr -d '_' || true)
                display_name=$(echo "${display_name}" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1' || true)
                display_name=$(echo "${display_name}" | tr ' ' '_' || true)
                
                cat > "/usr/share/applications/${script_name%.sh}.desktop" << EOF
[Desktop Entry]
Name=${display_name} Optimizer
Comment=Optimize system for ${display_name}
Exec=pkexec /usr/local/bin/system-tuning/${script_name}
Icon=preferences-system-performance
Terminal=false
Type=Application
Categories=System;
EOF
	        echo "✓ Created desktop entry for ${display_name} Optimizer"
            fi
        fi
    done
else
    # Check for ollama-optimizer.sh specifically and create it if not restored
    if [[ ! -f "/usr/local/bin/system-tuning/ollama-optimizer.sh" ]]; then
        mkdir -p /usr/local/bin/system-tuning/
        cat > /usr/local/bin/system-tuning/ollama-optimizer.sh << 'EOF'
#!/bin/bash
# Ollama RTX 3090 Optimizer
# Save this script to ~/ollama-optimizer.sh and chmod +x ~/ollama-optimizer.sh

# Exit on error
set -e

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "🚀 Optimizing system for Ollama on RTX 3090..."

# Set up NVIDIA driver optimizations
echo "📊 Configuring NVIDIA driver settings..."
nvidia-smi -pm 1
nvidia-smi --gpu-reset-applications-clocks
nvidia-smi -ac 1395,1695

# Optional: Increase power limit if thermals allow
# nvidia-smi -pl 400

# Set CPU governor to performance
echo "⚙️ Setting CPU governor to performance mode..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance > "${cpu}"
done

# Optimize kernel parameters
echo "🔧 Optimizing kernel parameters..."
cat > /etc/sysctl.d/99-ollama-optimization.conf << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.max_map_count=1048576
kernel.numa_balancing=0
EOF

sysctl -p /etc/sysctl.d/99-ollama-optimization.conf

# Clear cache to free up memory
echo "🧹 Clearing memory caches..."
sync
echo 3 > /proc/sys/vm/drop_caches

# Stop and restart Ollama service
echo "🔄 Restarting Ollama service..."
systemctl restart ollama

# Check Ollama status
echo "✅ Checking Ollama service status..."
systemctl status ollama

echo
echo "🎮 RTX 3090 Status:"
nvidia-smi

echo
echo "✨ Optimization complete! Ollama is now optimized for your RTX 3090."
echo "   Run your models with: ollama run llama3"
EOF
        chmod +x /usr/local/bin/system-tuning/ollama-optimizer.sh
        
        # Create desktop entry for Ollama optimizer
        cat > /usr/share/applications/ollama-optimizer.desktop << EOF
[Desktop Entry]
Name=Ollama Optimizer
Comment=Optimize system for Ollama LLM inference
Exec=pkexec /usr/local/bin/system-tuning/ollama-optimizer.sh
Icon=preferences-system-performance
Terminal=false
Type=Application
Categories=System;
EOF
        echo "✓ Created Ollama optimizer script and desktop entry"
    fi
    
    # Check for audio optimizer script
    if [[ ! -f "/usr/local/bin/system-tuning/realtime-audio-setup.sh" ]]; then
        mkdir -p /usr/local/bin/system-tuning/
        
        cat > /usr/local/bin/system-tuning/realtime-audio-setup.sh << 'EOF'
#!/bin/bash

# Real-time Audio Performance Configuration for KDE
# This script configures the system for optimal real-time audio performance

set -e

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

echo "=== Setting up Real-time Audio Performance ==="

# Install necessary packages if not already installed
echo "Installing required packages..."
apt-get update
apt-get install -y rtirq-init rtkit linux-lowlatency pipewire pipewire-audio \
                   pipewire-pulse pipewire-jack wireplumber \
                   ubuntustudio-audio-core ubuntustudio-pipewire-config \
                   ubuntustudio-lowlatency-settings

# Create/configure limits.conf for real-time priority
echo "Configuring real-time priorities..."
cat > /etc/security/limits.d/99-realtime-audio.conf << EOF
# Real-time audio configuration
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
EOF

# Add user to audio group if not already a member
if [[ -n "${SUDO_USER}" ]]; then
    USERNAME=$(logname || echo "${SUDO_USER}") || true
else
    USERNAME=$(logname) || true
fi

if ! groups "${USERNAME}" | grep -q '\baudio\b' || true; then
    echo "Adding user ${USERNAME} to audio group..."
    usermod -a -G audio "${USERNAME}"
fi

# Configure CPU governor for performance
echo "Configuring CPU governor..."
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "${governor}"
    done								
    echo "CPU governor set to performance"
else
    echo "CPU governor settings not available"
fi

# Configure PipeWire for low latency
echo "Configuring PipeWire for low latency..."

# Create PipeWire config directories if they don't exist
mkdir -p /etc/pipewire/pipewire.conf.d

# Create low latency configuration
cat > /etc/pipewire/pipewire.conf.d/99-low-latency.conf << EOF
# Low latency PipeWire configuration
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 128
    default.clock.min-quantum = 128
    default.clock.max-quantum = 256
}
EOF

# Create JACK compatibility settings
cat > /etc/pipewire/pipewire.conf.d/99-jack-settings.conf << EOF
# JACK compatibility settings
context.modules = [
    { name = libpipewire-module-rt
        args = {
            nice.level = -15
            rt.prio = 88
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
]

context.objects = [
    { factory = adapter
        args = {
            factory.name     = support.null-audio-sink
            node.name        = "JACK-null"
            node.description = "JACK Compatible Null Output"
            media.class      = "Audio/Sink"
            adapter.auto-port-config = {
                mode = dsp
                monitor = true
                position = [ FL FR ]
            }
        }
    }
]
EOF

# Set up RTIRQ configuration
echo "Configuring RTIRQ..."
if [[ -f /etc/default/rtirq ]]; then
    sed -i 's/^RTIRQ_NAME_LIST=.*/RTIRQ_NAME_LIST="snd_usb_audio snd usb i8042"/' /etc/default/rtirq
    sed -i 's/^RTIRQ_PRIO_HIGH=.*/RTIRQ_PRIO_HIGH=90/' /etc/default/rtirq
    sed -i 's/^RTIRQ_PRIO_LOW=.*/RTIRQ_PRIO_LOW=75/' /etc/default/rtirq
    systemctl enable rtirq
    systemctl restart rtirq
fi

# Configure the system to disable power management for USB audio
echo "Configuring USB power management for audio devices..."
cat > /etc/udev/rules.d/90-usb-audio-power.rules << EOF
# Disable USB power management for audio devices
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
EOF

# Restart PipeWire services
echo "Restarting PipeWire services..."
systemctl --user daemon-reload
systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service

echo "Real-time audio configuration complete!"
echo "Please reboot your system for all changes to take effect."
EOF
        chmod +x /usr/local/bin/system-tuning/realtime-audio-setup.sh
        
        # Create desktop entry for audio setup
        cat > /usr/share/applications/realtime-audio-setup.desktop << EOF
[Desktop Entry]
Name=Real-time Audio Setup
Comment=Configure system for professional audio production
Exec=pkexec /usr/local/bin/system-tuning/realtime-audio-setup.sh
Icon=audio-card
Terminal=false
Type=Application
Categories=System;Audio;
EOF
        echo "✓ Created real-time audio setup script and desktop entry"
    fi
fi

# ======================================================================
# Final Summary
# ======================================================================
section "Advanced System Tuning Complete"

echo "The following optimizations have been applied:"
echo "  1. Advanced sysctl parameters for system performance"
echo "  2. System profile manager for toggling between normal and performance modes"
echo "  3. NVIDIA GPU optimizations (if NVIDIA GPU detected)"
echo "  4. Storage I/O scheduler optimization for different device types"
echo "  5. System resource limits for development and audio work"

if [[ -n "${RESTORED_SYSCTL_CONFIG}" ]]; then
    echo "  6. Restored custom system tuning configurations from backup"
fi

echo
echo "You can toggle between system profiles using the 'Toggle System Profile'"
echo "application in your system menu."
echo

if [[ -d "/usr/local/bin/system-tuning/" ]]; then
    echo "The following specialized optimization scripts are available:"
    for script in /usr/local/bin/system-tuning/*.sh; do
        if [[ -f "${script}" ]]; then
            script_name=$(basename "${script}")
            echo "  - ${script_name}"
        fi
    done
    echo "You can find these scripts in your application menu or run them directly."
fi

echo "✅ Advanced system tuning completed successfully!"
echo "A system reboot is recommended to fully apply all settings."
