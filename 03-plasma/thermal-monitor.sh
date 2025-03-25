#!/usr/bin/env bash
# Thermal monitor script for CPU and GPU
# Part of the theme-setup.sh script
# This sets up system temperature monitoring for KDE Plasma

# Source common library if running standalone
if [[ -z "${LIB_DIR}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
    LIB_DIR="${PARENT_DIR}/lib"
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
fi

# Install and configure thermal monitoring
function install_thermal_monitor() {
    log_section "Installing Thermal Monitoring"

    # Check if already installed
    if check_state "thermal_monitor_installed"; then
        log_info "Thermal monitoring already installed. Skipping..."
        return 0
    fi

    # Install required packages
    log_step "Installing monitoring packages"
    apt_install_if_needed lm-sensors ksysguard plasma-pa plasma-systemmonitor

    # Install GPU-specific packages
    if lspci | grep -i nvidia &>/dev/null; then
        log_step "Installing NVIDIA monitoring tools"
        apt_install_if_needed nvidia-smi
    elif lspci | grep -i amd &>/dev/null; then
        log_step "Installing AMD monitoring tools"
        apt_install_if_needed radeontop
    fi

    # Run sensors-detect to find hardware sensors (accept all defaults)
    log_step "Detecting hardware sensors"
    yes | sudo sensors-detect --auto

    # Create the GPU temperature script
    log_step "Creating GPU temperature monitoring script"
    mkdir -p /usr/local/bin

    cat > /usr/local/bin/gpu-temp.sh << 'EOF'
#!/bin/bash
# Get GPU temperature

# For NVIDIA GPUs
if command -v nvidia-smi &> /dev/null; then
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)
    if [[ -n "${GPU_TEMP}" ]]; then
        echo "${GPU_TEMP}°C"
        exit 0
    fi
fi

# For AMD GPUs
if [ -f /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input ]; then
    GPU_TEMP=$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null)
    if [[ -n "${GPU_TEMP}" ]]; then
        # Convert from millidegrees to degrees
        GPU_TEMP=$((GPU_TEMP/1000))
        echo "${GPU_TEMP}°C"
        exit 0
    fi
fi

# If we get here, we couldn't detect GPU temp
echo "N/A"
exit 1
EOF

    # Create combined CPU/GPU temperature script
    cat > /usr/local/bin/system-temps.sh << 'EOF'
#!/bin/bash
# Display CPU and GPU temperatures

# Get CPU temperature
CPU_TEMP=$(sensors | grep -E "Package id 0:|Tdie:" | awk '{print $4}' | tr -d '+°C' | head -n 1)
if [[ -z "${CPU_TEMP}" ]]; then
    # Try alternative sensor format
    CPU_TEMP=$(sensors | grep -E "CPU:" | awk '{print $2}' | tr -d '+°C' | head -n 1)
fi
if [[ -z "${CPU_TEMP}" ]]; then
    CPU_TEMP="N/A"
fi

# Get GPU temperature using our script
GPU_TEMP=$(/usr/local/bin/gpu-temp.sh | tr -d '°C')

echo "CPU: ${CPU_TEMP}°C | GPU: ${GPU_TEMP}°C"
EOF

    # Make scripts executable
    chmod +x /usr/local/bin/gpu-temp.sh
    chmod +x /usr/local/bin/system-temps.sh

    # Create a custom plasma widget for temperature monitoring
    log_step "Creating temperature monitoring widget"

    # Detect main user
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Skipping user-specific setup."
        set_state "thermal_monitor_installed"
        return 0
    fi

    local user_home="/home/${main_user}"

    # Create plasmoid directories
    mkdir -p "${user_home}/.local/share/plasma/plasmoids/org.kde.plasma.systemtemps/contents/ui/"
    mkdir -p "${user_home}/.local/share/plasma/plasmoids/org.kde.plasma.systemtemps/contents/config/"

    # Create the main QML file for the widget
    cat > "${user_home}/.local/share/plasma/plasmoids/org.kde.plasma.systemtemps/contents/ui/main.qml" << 'EOF'
import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0

Item {
    id: root

    property string cpuTemp: "N/A"
    property string gpuTemp: "N/A"

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ShadowBackground

    Plasmoid.fullRepresentation: ColumnLayout {
        anchors.fill: parent
        spacing: units.smallSpacing

        PlasmaCore.DataSource {
            id: tempSource
            engine: "executable"
            connectedSources: ["/usr/local/bin/system-temps.sh"]
            interval: 2000 // Update every 2 seconds

            onNewData: {
                if (data["exit code"] > 0) {
                    return;
                }

                var output = data.stdout.trim();
                var temps = output.split('|');

                if (temps.length >= 2) {
                    root.cpuTemp = temps[0].trim();
                    root.gpuTemp = temps[1].trim();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: units.largeSpacing

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter

                PlasmaComponents3.Label {
                    text: "CPU"
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    font.pointSize: theme.smallestFont.pointSize * 1.1
                    opacity: 0.8
                }

                PlasmaComponents3.Label {
                    text: root.cpuTemp
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    font.pointSize: theme.defaultFont.pointSize * 1.2
                    font.bold: true
                    color: {
                        var temp = parseFloat(root.cpuTemp.replace("CPU: ", "").replace("°C", ""));
                        if (isNaN(temp)) return theme.textColor;
                        if (temp > 80) return "#FF5252";
                        if (temp > 70) return "#FFB224";
                        return theme.textColor;
                    }
                }
            }

            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.2
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter

                PlasmaComponents3.Label {
                    text: "GPU"
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    font.pointSize: theme.smallestFont.pointSize * 1.1
                    opacity: 0.8
                }

                PlasmaComponents3.Label {
                    text: root.gpuTemp
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    font.pointSize: theme.defaultFont.pointSize * 1.2
                    font.bold: true
                    color: {
                        var temp = parseFloat(root.gpuTemp.replace("GPU: ", "").replace("°C", ""));
                        if (isNaN(temp)) return theme.textColor;
                        if (temp > 85) return "#FF5252";
                        if (temp > 75) return "#FFB224";
                        return theme.textColor;
                    }
                }
            }
        }
    }
}
EOF

    # Create the metadata.desktop file for the widget
    cat > "${user_home}/.local/share/plasma/plasmoids/org.kde.plasma.systemtemps/metadata.desktop" << 'EOF'
[Desktop Entry]
Name=System Temperatures
Comment=Monitor CPU and GPU temperatures
Icon=temperature-normal
Type=Service
X-KDE-ServiceTypes=Plasma/Applet
X-KDE-PluginInfo-Author=KDE Custom
X-KDE-PluginInfo-Email=user@example.com
X-KDE-PluginInfo-Name=org.kde.plasma.systemtemps
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-Website=https://kde.org/
X-KDE-PluginInfo-Category=System Information
X-KDE-PluginInfo-License=GPL
X-Plasma-API=declarativeappletscript
X-Plasma-MainScript=ui/main.qml
EOF

    # Configure KDE System Monitor page for detailed monitoring
    mkdir -p "${user_home}/.config/plasma-systemmonitor/"

    cat > "${user_home}/.config/plasma-systemmonitor/temperatures.page" << 'EOF'
{
    "ActualSize": 1,
    "ConfigVersion": 1,
    "Title": "Temperatures",
    "chartFace": {
        "rangeAuto": true,
        "rangeFrom": 0,
        "rangeTo": 100,
        "showGridLines": false,
        "showLegend": true,
        "showTitle": true,
        "showYAxisLabels": true
    },
    "dialogHeight": 0,
    "dialogWidth": 0,
    "face": "SensorFace",
    "faceId": "org.kde.ksysguard.linechart",
    "groupByProcess": false,
    "horizontalPosition": 0,
    "id": "temps",
    "interval": 1000,
    "maximized": false,
    "name": "Temperatures",
    "sensors": [
        "lmsensors/all/temp1",
        "cpu/all/temperature"
    ],
    "showBackground": false,
    "title": "System Temperatures",
    "updateRanges": false,
    "verticalPosition": 0
}
EOF

    # Set permissions
    chown -R "${main_user}:${main_user}" "${user_home}/.local/share/plasma/plasmoids"
    chown -R "${main_user}:${main_user}" "${user_home}/.config/plasma-systemmonitor"

    # Add to panel (optional - user may need to add widget manually)
    # This command may not work reliably, so we'll skip it and inform the user

    log_success "Thermal monitoring installed successfully"
    log_info "To add the temperature widget to your panel:"
    log_info "1. Right-click on your panel"
    log_info "2. Select 'Add Widgets...'"
    log_info "3. Find and add 'System Temperatures'"

    # Mark as installed
    set_state "thermal_monitor_installed"
    return 0
}

# Run the main function if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_thermal_monitor
fi
