#!/bin/bash

# VirtualBox Audio Bridge Configuration
# This script sets up audio routing between Linux host and VirtualBox guests
# Specifically optimized for RadioDJ and StereoTool
# Includes dedicated cue channel routing to center speaker

set -e

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

echo "=== Setting up VirtualBox Audio Bridge ==="

# Install necessary packages
echo "Installing required packages..."
apt-get update
apt-get install -y pulseaudio-module-jack bridge-utils qjackctl pamixer pulseaudio-utils

# Create the audio bridge script
echo "Creating audio bridge script..."
BRIDGE_SCRIPT="/usr/local/bin/vbox-audio-bridge.sh"

cat > "${BRIDGE_SCRIPT}" << 'EOF'
#!/bin/bash

# VirtualBox Audio Bridge Script
# This script creates virtual audio devices and routes audio between host and VM

# Exit if any command fails
set -e

# Configuration
VM_NAME="$1"
if [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <vm_name>"
    echo "Please provide the name of your VirtualBox VM"
    exit 1
fi

# Function to check if VM is running
is_vm_running() {
    VBoxManage list runningvms | grep -q "\"$VM_NAME\""
    return $?
}

# Create virtual audio devices
echo "Creating virtual audio devices..."
pactl load-module module-null-sink sink_name=VirtualInput sink_properties=device.description="VM_Input"
pactl load-module module-null-sink sink_name=VirtualOutput sink_properties=device.description="VM_Output"
pactl load-module module-null-sink sink_name=VirtualCue sink_properties=device.description="VM_Cue"

# Get the monitor source of the virtual output
VIRTUAL_OUTPUT_SOURCE=$(pactl list sources | grep -A 10 "Name: VirtualOutput" | grep "Monitor Source:" | cut -d ":" -f2 | tr -d ' ')
VIRTUAL_INPUT_SOURCE=$(pactl list sources | grep -A 10 "Name: VirtualInput" | grep "Monitor Source:" | cut -d ":" -f2 | tr -d ' ')
VIRTUAL_CUE_SOURCE=$(pactl list sources | grep -A 10 "Name: VirtualCue" | grep "Monitor Source:" | cut -d ":" -f2 | tr -d ' ')

# Ensure VM is running
if ! is_vm_running; then
    echo "Starting VM $VM_NAME..."
    VBoxManage startvm "$VM_NAME" --type headless
    
    # Wait for VM to fully start
    echo "Waiting for VM to start..."
    while ! is_vm_running; do
        sleep 2
    done
    sleep 10  # Additional time for audio devices to initialize
fi

# Configure VM audio
echo "Configuring VM audio devices..."
VBoxManage controlvm "$VM_NAME" audioin on
VBoxManage controlvm "$VM_NAME" audioout on

# Configure additional audio device for VM
echo "Adding second audio adapter for cue output..."
VBoxManage modifyvm "$VM_NAME" --audio-controller hda
VBoxManage modifyvm "$VM_NAME" --audio-enableout on

# If VM is running, ensure both audio devices are enabled
if is_vm_running; then
    echo "Ensuring both audio devices are enabled..."
    VBoxManage controlvm "$VM_NAME" audioin on
    VBoxManage controlvm "$VM_NAME" audioout on
fi

# Create routing script for continuous operation
TMP_SCRIPT=$(mktemp)
cat > $TMP_SCRIPT << 'INNEREOF'
#!/bin/bash

# This script runs in the background to maintain audio routing

# Set up signal handling
trap "echo 'Stopping audio routing...'; exit 0" SIGINT SIGTERM

# Function to create audio routing
setup_routing() {
    # Route host audio to VM input
    pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=VirtualInput latency_msec=10

    # Route VM output to host output
    pactl load-module module-loopback source=$VIRTUAL_OUTPUT_SOURCE sink=@DEFAULT_SINK@ latency_msec=10
    
    # Setup for center channel cue output
    # Find the surround sink (usually alsa_output.pci-*.surround-51 or similar)
    SURROUND_SINK=$(pactl list sinks short | grep surround | head -n1 | cut -f1)
    
    if [ -n "$SURROUND_SINK" ]; then
        echo "Found surround sink: $SURROUND_SINK"
        
        # Create a virtual sink specifically for center channel output
        CENTER_CHANNEL_MAP="[ FL FR LFE CENTER na na ]"
        
        # Create a filtered sink with only center channel enabled
        CENTER_SINK_ID=$(pactl load-module module-remap-sink sink_name=center_only master=$SURROUND_SINK channels=6 master_channel_map=$CENTER_CHANNEL_MAP channel_map="[ na na na CENTER na na ]" remix=false)
        
        # Route VirtualCue to the center channel only
        pactl load-module module-loopback source=$VIRTUAL_CUE_SOURCE sink=center_only latency_msec=5
        
        echo "Created center channel route for cue output"
    else
        echo "No surround sink found. Routing cue to default output instead."
        pactl load-module module-loopback source=$VIRTUAL_CUE_SOURCE sink=@DEFAULT_SINK@ latency_msec=5
    fi
}

# Initial setup
setup_routing

# Monitor for changes in audio devices and re-establish routing if needed
while true; do
    sleep 10
    
    # Check if routing is still active, repair if needed
    LOOPBACK_COUNT=$(pactl list modules | grep -c "module-loopback")
    if [ $LOOPBACK_COUNT -lt 2 ]; then
        echo "Repairing audio routing..."
        setup_routing
    fi
done
INNEREOF

chmod +x $TMP_SCRIPT

# Start the routing script in the background
echo "Starting audio routing in the background..."
nohup $TMP_SCRIPT > /tmp/vbox-audio-bridge.log 2>&1 &
ROUTING_PID=$!

echo "Audio bridge is running with PID $ROUTING_PID"
echo "To stop the bridge, run: kill $ROUTING_PID"
echo "VM audio routing has been established between host and $VM_NAME"
echo "VM Input device: VirtualInput"
echo "VM Output device: VirtualOutput"
echo "Log file: /tmp/vbox-audio-bridge.log"
EOF

chmod +x "${BRIDGE_SCRIPT}"

# Create a systemd service for the audio bridge
echo "Creating systemd service for VirtualBox audio bridge..."

cat > /etc/systemd/system/vbox-audio-bridge@.service << EOF
[Unit]
Description=VirtualBox Audio Bridge for %i
After=network.target virtualbox.service

[Service]
Type=simple
ExecStart=/usr/local/bin/vbox-audio-bridge.sh %i
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create a helper script for RadioDJ/StereoTool specific setup
echo "Creating RadioDJ/StereoTool helper script..."
HELPER_SCRIPT="/usr/local/bin/setup-radiodj-audio.sh"

cat > "${HELPER_SCRIPT}" << 'EOF'
#!/bin/bash

# RadioDJ and StereoTool Audio Setup Helper
# This script configures audio routing optimized for RadioDJ and StereoTool

VM_NAME="$1"
if [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <vm_name>"
    echo "Please provide the name of your RadioDJ VirtualBox VM"
    exit 1
fi

# Start the audio bridge if not already running
if ! pgrep -f "vbox-audio-bridge.sh $VM_NAME" > /dev/null; then
    echo "Starting audio bridge for $VM_NAME..."
    sudo systemctl start vbox-audio-bridge@$VM_NAME.service
fi

# Instructions for VM configuration
cat << INSTRUCTIONS

====================================================
RadioDJ and StereoTool Audio Bridge Setup
====================================================

The audio bridge is now running. Please configure your Windows VM as follows:

1. In Windows sound settings, set:
   - Recording device: VirtualBox Audio Input
   - Main Playback device: VirtualBox Audio Output
   - Secondary Playback device (for cue): VirtualBox Audio Output #2

2. In RadioDJ:
   - Configure main output to use VirtualBox Audio Output
   - Configure CUE output to use VirtualBox Audio Output #2
   - Set any additional input monitoring to VirtualBox Audio Input

3. In StereoTool:
   - Input: VirtualBox Audio Input
   - Output: VirtualBox Audio Output
   - Adjust processing settings as needed

4. For best performance:
   - Set buffer sizes to 128 or 256 samples
   - Use 48000Hz sample rate throughout the chain
   - Make sure all audio devices use the same sample rate

To stop the audio bridge: sudo systemctl stop vbox-audio-bridge@$VM_NAME.service
To make bridge start automatically: sudo systemctl enable vbox-audio-bridge@$VM_NAME.service

NOTE: The CUE output will be routed exclusively to your center speaker!

====================================================

INSTRUCTIONS

# Create KDE desktop entry for easy access
mkdir -p $HOME/.local/share/applications/
cat > $HOME/.local/share/applications/radiodj-audio-bridge.desktop << DESKTOPENTRY
[Desktop Entry]
Type=Application
Name=RadioDJ Audio Bridge
Comment=Start Audio Bridge for RadioDJ VM
Exec=sudo $HELPER_SCRIPT $VM_NAME
Icon=audio-card
Terminal=true
Categories=Audio;
DESKTOPENTRY

echo "Created desktop entry: RadioDJ Audio Bridge"
echo "You can find it in your application menu under Audio"
EOF

chmod +x "${HELPER_SCRIPT}"

# Create config file for easy VM name substitution
echo "Creating configuration file..."
mkdir -p /etc/vbox-audio-bridge/
cat > /etc/vbox-audio-bridge/config << EOF
# VirtualBox Audio Bridge Configuration
# Set your VM name here

# Default VM name for RadioDJ
RADIODJ_VM="Windows"

# Uncomment and modify if you have multiple VMs
# SECONDARY_VM="Windows2"
EOF

# Create a script to adjust center channel volume
cat > /usr/local/bin/adjust-cue-volume.sh << 'EOF'
#!/bin/bash

# Script to adjust the volume of the center channel for cue output

# Find the center channel sink
CENTER_SINK=$(pactl list sinks short | grep center_only | cut -f1)

if [ -z "$CENTER_SINK" ]; then
    echo "Error: Center channel sink not found."
    echo "Make sure the audio bridge is running first."
    exit 1
fi

# Get volume argument
VOLUME="$1"
if [ -z "$VOLUME" ]; then
    echo "Usage: $0 <volume_percentage>"
    echo "Example: $0 80"
    echo "Current volume is: $(pamixer --sink $CENTER_SINK --get-volume)%"
    exit 1
fi

# Set volume
pamixer --sink $CENTER_SINK --set-volume "$VOLUME"
echo "Center channel cue volume set to $VOLUME%"
EOF

chmod +x /usr/local/bin/adjust-cue-volume.sh

# Create a KDE desktop entry for volume control
mkdir -p "${HOME}/.local/share/applications/"
cat > "${HOME}/.local/share/applications/cue-volume.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Cue Channel Volume
Comment=Adjust the volume of the RadioDJ cue channel
Exec=zenity --scale --text="Adjust Cue Volume" --min-value=0 --max-value=100 --value=80 --step=5 --print-partial | xargs -I{} sudo /usr/local/bin/adjust-cue-volume.sh {}
Icon=audio-volume-medium
Terminal=false
Categories=Audio;
EOF

echo "VirtualBox Audio Bridge configuration complete!"
echo 
echo "To use with your RadioDJ VM:"
echo "1. Edit /etc/vbox-audio-bridge/config to set your VM name"
echo "2. Run: sudo setup-radiodj-audio.sh \$RADIODJ_VM"
echo "3. Or use the desktop entry: RadioDJ Audio Bridge"
echo
echo "For automatic startup when VM launches:"
echo "sudo systemctl enable vbox-audio-bridge@\$RADIODJ_VM.service"
echo
echo "To adjust center channel cue volume:"
echo "1. Use the 'Cue Channel Volume' desktop entry"
echo "2. Or run: sudo adjust-cue-volume.sh <volume_percentage>"
