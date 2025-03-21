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
