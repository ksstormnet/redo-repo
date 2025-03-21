#!/bin/bash

# 02-audio-system-setup.sh
# This script sets up the optimized audio system
# Part of the sequential Ubuntu Server to KDE conversion process
# Modified to use restored configurations from /restart/critical_backups

# Exit on any error
set -e

# Source common functions
# shellcheck disable=SC1091
source /usr/local/lib/kde-installer/functions.sh

# Determine user home directory
if [[ -n "${SUDO_USER}" ]]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6) || true
    # shellcheck disable=SC2034
    ACTUAL_USER="${SUDO_USER}"
else
    USER_HOME="${HOME}"
    # shellcheck disable=SC2034
    ACTUAL_USER="${USER}"
fi

# Check for restored configurations
CONFIG_MAPPING="/restart/critical_backups/config_mapping.txt"
RESTORED_CONFIGS_AVAILABLE=false

if [[ -f "${CONFIG_MAPPING}" ]]; then
    echo "Found restored configuration mapping at ${CONFIG_MAPPING}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING}"
    RESTORED_CONFIGS_AVAILABLE=true
else
    echo "No restored configuration mapping found at ${CONFIG_MAPPING}"
    echo "Will proceed with default configurations."
fi

# Define configuration files for audio system
PIPEWIRE_CONFIG_FILES=(
    "${USER_HOME}/.config/pipewire/pipewire.conf"
    "${USER_HOME}/.config/pipewire/client.conf"
    "${USER_HOME}/.config/pipewire/client-rt.conf"
    "${USER_HOME}/.config/pipewire/jack.conf"
)

WIREPLUMBER_CONFIG_FILES=(
    "${USER_HOME}/.config/wireplumber/wireplumber.conf"
    "${USER_HOME}/.config/wireplumber/main.lua.d/51-alsa-custom.lua"
)

ALSA_CONFIG_FILES=(
    "${USER_HOME}/.asoundrc"
)

JACK_CONFIG_FILES=(
    "${USER_HOME}/.config/jack/conf.xml"
)

# Update package lists
section "Updating Package Lists"
apt-get update

# === STAGE 1: Pre-Installation Configuration ===
section "Setting Up Pre-Installation Configurations"

# Set up pre-installation configurations for audio system
handle_pre_installation_config "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
handle_pre_installation_config "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
handle_pre_installation_config "alsa" "${ALSA_CONFIG_FILES[@]}"
handle_pre_installation_config "jack" "${JACK_CONFIG_FILES[@]}"

# === STAGE 2: PipeWire Audio System ===
section "Setting Up Professional Audio System"

# Install PipeWire audio system (modern replacement for PulseAudio)
install_packages "PipeWire Audio System" \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    pipewire-audio \
    wireplumber \
    ubuntustudio-audio-core \
    ubuntustudio-pipewire-config

# Audio utilities and Sox with MP3 support
install_packages "Audio Utilities" \
    rtkit \
    sox \
    libsox-fmt-mp3

# === STAGE 3: Configure Audio System ===
section "Configuring Audio System"

# Check for restored rtirq config
RESTORED_RTIRQ=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    RTIRQ_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/default/rtirq"
        "${GENERAL_CONFIGS_PATH}/default/rtirq"
    )
    
    for path in "${RTIRQ_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored rtirq configuration at ${path}"
            cp "${path}" /etc/default/rtirq
            RESTORED_RTIRQ=true
            break
        fi
    done
fi

# Set up realtime privileges for audio
section "Configuring Realtime Audio Privileges"

# Check if the audio group exists, create it if not
getent group audio > /dev/null || groupadd audio

# Add current user to audio group if running as sudo
if [[ -n "${SUDO_USER}" ]]; then
    usermod -a -G audio "${SUDO_USER}"
    echo "✓ Added user ${SUDO_USER} to audio group"
fi

# Check for restored realtime audio limits config
RESTORED_LIMITS=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    LIMITS_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/security/limits.d/99-realtime-audio.conf"
        "${GENERAL_CONFIGS_PATH}/security/limits.d/99-realtime-audio.conf"
        "${GENERAL_CONFIGS_PATH}/etc/security/limits.d/audio.conf"
    )
    
    for path in "${LIMITS_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored realtime audio limits at ${path}"
            cp "${path}" /etc/security/limits.d/99-realtime-audio.conf
            RESTORED_LIMITS=true
            break
        fi
    done
fi

# Set up limits for realtime audio if not restored
if [[ "${RESTORED_LIMITS}" = false ]]; then
    cat > /etc/security/limits.d/99-realtime-audio.conf << EOF
# Realtime Audio Configuration
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
EOF
    echo "✓ Configured default realtime audio privileges"
else
    echo "✓ Restored realtime audio privileges configuration"
fi

# Set up RTIRQ configuration if not restored
if [[ "${RESTORED_RTIRQ}" = false ]] && [[ -f /etc/default/rtirq ]]; then
    sed -i 's/^RTIRQ_NAME_LIST=.*/RTIRQ_NAME_LIST="snd_usb_audio snd usb i8042"/' /etc/default/rtirq
    sed -i 's/^RTIRQ_PRIO_HIGH=.*/RTIRQ_PRIO_HIGH=90/' /etc/default/rtirq
    sed -i 's/^RTIRQ_PRIO_LOW=.*/RTIRQ_PRIO_LOW=75/' /etc/default/rtirq
    echo "✓ Configured default RTIRQ settings"
else
    echo "✓ Using existing or restored RTIRQ configuration"
fi

systemctl enable rtirq
systemctl restart rtirq

# Check for restored USB audio power management config
RESTORED_USB_POWER=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    USB_POWER_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/udev/rules.d/90-usb-audio-power.rules"
        "${GENERAL_CONFIGS_PATH}/udev/rules.d/90-usb-audio-power.rules"
    )
    
    for path in "${USB_POWER_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored USB audio power management rules at ${path}"
            cp "${path}" /etc/udev/rules.d/90-usb-audio-power.rules
            RESTORED_USB_POWER=true
            break
        fi
    done
fi

# Configure the system to disable power management for USB audio if not restored
if [[ "${RESTORED_USB_POWER}" = false ]]; then
    echo "Configuring USB power management for audio devices..."
    cat > /etc/udev/rules.d/90-usb-audio-power.rules << EOF
# Disable USB power management for audio devices
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
EOF
    echo "✓ Configured default USB power management for audio devices"
else
    echo "✓ Restored USB audio power management configuration"
fi

# === STAGE 4: Configure PipeWire ===
section "Configuring PipeWire Settings"

# Create PipeWire config directories if they don't exist
mkdir -p /etc/pipewire/pipewire.conf.d

# Check for restored PipeWire configs
RESTORED_PIPEWIRE_CONFIGS=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    PIPEWIRE_CONF_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/pipewire/pipewire.conf.d"
        "${GENERAL_CONFIGS_PATH}/pipewire/pipewire.conf.d"
    )
    
    for path in "${PIPEWIRE_CONF_PATHS[@]}"; do
        if [[ -d "${path}" ]] && [[ -n "$(ls -A "${path}" 2>/dev/null || true)" ]]; then
            echo "Found restored PipeWire configurations at ${path}"
            cp -r "${path}"/* /etc/pipewire/pipewire.conf.d/
            RESTORED_PIPEWIRE_CONFIGS=true
            break
        fi
    done
fi

# Create low latency configuration if not restored
if [[ "${RESTORED_PIPEWIRE_CONFIGS}" = false ]]; then
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
    echo "✓ Created default PipeWire low-latency and JACK compatibility configurations"
else
    echo "✓ Restored PipeWire configurations"
fi

# === STAGE 5: Configure user-specific PipeWire settings ===
section "Configuring User-Specific PipeWire Settings"

# Create user config directories
mkdir -p "${USER_HOME}/.config/pipewire"
mkdir -p "${USER_HOME}/.config/wireplumber"
mkdir -p "${USER_HOME}/.config/jack"

# Check for restored user-specific audio configurations
RESTORED_USER_AUDIO_CONFIGS=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    USER_PIPEWIRE_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/pipewire"
        "${HOME_CONFIGS_PATH}/.config/pipewire"
    )
    
    for path in "${USER_PIPEWIRE_PATHS[@]}"; do
        if [[ -d "${path}" ]] && [[ -n "$(ls -A "${path}" 2>/dev/null || true)" ]]; then
            echo "Found restored user PipeWire configurations at ${path}"
            cp -r "${path}"/* "${USER_HOME}/.config/pipewire/"
            RESTORED_USER_AUDIO_CONFIGS=true
            break
        fi
    done
    
    USER_WIREPLUMBER_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/wireplumber"
        "${HOME_CONFIGS_PATH}/.config/wireplumber"
    )
    
    for path in "${USER_WIREPLUMBER_PATHS[@]}"; do
        if [[ -d "${path}" ]] && [[ -n "$(ls -A "${path}" 2>/dev/null || true)" ]]; then
            echo "Found restored user WirePlumber configurations at ${path}"
            cp -r "${path}"/* "${USER_HOME}/.config/wireplumber/"
            RESTORED_USER_AUDIO_CONFIGS=true
            break
        fi
    done
    
    USER_JACK_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/jack"
        "${HOME_CONFIGS_PATH}/.config/jack"
    )
    
    for path in "${USER_JACK_PATHS[@]}"; do
        if [[ -d "${path}" ]] && [[ -n "$(ls -A "${path}" 2>/dev/null || true)" ]]; then
            echo "Found restored user JACK configurations at ${path}"
            cp -r "${path}"/* "${USER_HOME}/.config/jack/"
            RESTORED_USER_AUDIO_CONFIGS=true
            break
        fi
    done
    
    USER_ASOUNDRC_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.asoundrc"
        "${HOME_CONFIGS_PATH}/.asoundrc"
    )
    
    for path in "${USER_ASOUNDRC_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "Found restored user .asoundrc at ${path}"
            cp "${path}" "${USER_HOME}/.asoundrc"
            RESTORED_USER_AUDIO_CONFIGS=true
            break
        fi
    done
fi

# If user configs weren't restored, handle them through the config management system
if [[ "${RESTORED_USER_AUDIO_CONFIGS}" = false ]]; then
    # Handle configuration files
    handle_installed_software_config "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
    handle_installed_software_config "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
    handle_installed_software_config "alsa" "${ALSA_CONFIG_FILES[@]}"
    handle_installed_software_config "jack" "${JACK_CONFIG_FILES[@]}"
    echo "✓ Managed audio configurations through config repository"
else
    # Set ownership for restored user configs
    if [[ -n "${SUDO_USER}" ]]; then
        chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/pipewire"
        chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/wireplumber"
        chown -R "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.config/jack"
        [[ -f "${USER_HOME}/.asoundrc" ]] && chown "${SUDO_USER}":"${SUDO_USER}" "${USER_HOME}/.asoundrc"
    fi
    echo "✓ Restored user-specific audio configurations from backup"
fi

# Check for restored audio-related scripts
RESTORED_AUDIO_SCRIPTS=()
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    SCRIPT_PATHS=(
        "${GENERAL_CONFIGS_PATH}/usr/local/bin"
        "${GENERAL_CONFIGS_PATH}/bin"
        "${HOME_CONFIGS_PATH}/bin"
    )
    
    AUDIO_SCRIPT_NAMES=(
        "mic-processing.sh"
        "realtime-audio-setup.sh"
        "virtualbox-audio-bridge.sh"
    )
    
    for script_dir in "${SCRIPT_PATHS[@]}"; do
        if [[ -d "${script_dir}" ]]; then
            for script in "${AUDIO_SCRIPT_NAMES[@]}"; do
                if [[ -f "${script_dir}/${script}" ]]; then
                    echo "Found restored audio script: ${script}"
                    mkdir -p /usr/local/bin
                    cp "${script_dir}/${script}" /usr/local/bin/
                    chmod +x "/usr/local/bin/${script}"
                    RESTORED_AUDIO_SCRIPTS+=("${script}")
                fi
            done
        fi
    done
    
    if [[ ${#RESTORED_AUDIO_SCRIPTS[@]} -gt 0 ]]; then
        echo "✓ Restored ${#RESTORED_AUDIO_SCRIPTS[@]} audio-related scripts"
    fi
fi

# Restart PipeWire services
echo "Restarting PipeWire services to apply configurations..."
if [[ -n "${SUDO_USER}" ]]; then
    systemctl --user -M "${SUDO_USER}@.host" restart pipewire.service pipewire-pulse.service wireplumber.service || true
else
    systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service || true
fi
echo "✓ Restarted PipeWire services"

# === STAGE 6: Check for New Configuration Files ===
section "Checking for New Configuration Files"

# Only check for new configs if we didn't restore from backup
if [[ "${RESTORED_USER_AUDIO_CONFIGS}" = false ]]; then
    # Check for any new configuration files created during installation
    check_post_installation_configs "pipewire" "${PIPEWIRE_CONFIG_FILES[@]}"
    check_post_installation_configs "wireplumber" "${WIREPLUMBER_CONFIG_FILES[@]}"
    check_post_installation_configs "alsa" "${ALSA_CONFIG_FILES[@]}"
    check_post_installation_configs "jack" "${JACK_CONFIG_FILES[@]}"
fi

section "Audio System Setup Complete!"
echo "A professional audio system with PipeWire has been set up and configured."

if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    echo
    echo "Restoration status:"
    echo "  ✓ Configuration files restored from /restart/critical_backups"
    
    if [[ "${RESTORED_RTIRQ}" = true ]]; then
        echo "  ✓ Restored RTIRQ configuration"
    fi
    
    if [[ "${RESTORED_LIMITS}" = true ]]; then
        echo "  ✓ Restored realtime audio limits configuration"
    fi
    
    if [[ "${RESTORED_USB_POWER}" = true ]]; then
        echo "  ✓ Restored USB audio power management rules"
    fi
    
    if [[ "${RESTORED_PIPEWIRE_CONFIGS}" = true ]]; then
        echo "  ✓ Restored system-wide PipeWire configurations"
    fi
    
    if [[ "${RESTORED_USER_AUDIO_CONFIGS}" = true ]]; then
        echo "  ✓ Restored user-specific audio configurations"
    fi
    
    if [[ ${#RESTORED_AUDIO_SCRIPTS[@]} -gt 0 ]]; then
        echo "  ✓ Restored audio scripts: ${RESTORED_AUDIO_SCRIPTS[*]}"
    fi
    
    echo
    echo "Your previous audio configuration has been successfully restored."
else
    echo "All configurations are managed through the repository at: /repo/personal/core-configs/"
    echo "  - If a configuration existed in the repo, it was symlinked to the correct location"
    echo "  - If a configuration was created during installation, it was moved to the repo and symlinked"
    echo "  - Any changes to configurations should be made in the repository"
fi

echo
echo "Note: You may need to log out and back in for group changes to take effect."
echo "Command: sudo systemctl reboot"
