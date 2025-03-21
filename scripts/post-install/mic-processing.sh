#!/bin/bash

# Microphone Processing Setup for Vocaster 1 USB Interface
# Sets up real-time microphone processing with SoX or JACK

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "=== Setting up Microphone Processing for Vocaster 1 ==="

# Install necessary packages
echo "Installing required packages..."
sudo apt-get update
sudo apt-get install -y sox libsox-fmt-all jack-tools pulseaudio-module-jack qjackctl jack-capture

# Check if we can find the Vocaster interface
echo "Looking for Vocaster 1 USB interface..."
VOCASTER_CARD=$(aplay -l | grep -i "vocaster" | head -n 1 | sed -e 's/card \([0-9]*\).*/\1/') || true

if [[ -z "${VOCASTER_CARD}" ]]; then
    echo "Vocaster interface not found. Will use 'default' for the script. Please ensure the device is connected before using the processing chain."
    VOCASTER_DEVICE="default"
else
    echo "Found Vocaster interface at card ${VOCASTER_CARD}"
    VOCASTER_DEVICE="hw:${VOCASTER_CARD}"
fi

# Create microphone processing script with SoX
echo "Creating microphone processing script..."
mkdir -p "${HOME}/bin"
cat > "${HOME}/bin/process-mic.sh" << EOF
#!/bin/bash

# Microphone processing script using SoX
# This script applies:
# - Gain boost (can be adjusted)
# - Noise gate
# - Compression
# - EQ enhancement for vocals

# Configuration
INPUT_DEVICE="${VOCASTER_DEVICE}"
GAIN_BOOST=6  # dB of gain to add
OUTPUT_SINK="pipewiresink"

# Start processing
exec sox -q -t alsa \$INPUT_DEVICE -t pulseaudio \$OUTPUT_SINK \
    gain \$GAIN_BOOST \
    compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 \
    highpass 80 \
    equalizer 100 2q -3 \
    equalizer 200 1q -1 \
    equalizer 1200 2q 2 \
    equalizer 2500 2q 3 \
    equalizer 8000 2q 2
EOF

chmod +x "${HOME}/bin/process-mic.sh"

# Create a systemd user service for the microphone processing
echo "Creating systemd user service..."
mkdir -p "${HOME}/.config/systemd/user/"
cat > "${HOME}/.config/systemd/user/mic-processor.service" << EOF
[Unit]
Description=Real-time Microphone Processing
After=pipewire.service pipewire-pulse.service sound.target

[Service]
ExecStart=${HOME}/bin/process-mic.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Create an alternative JACK-based processing script for more advanced needs
echo "Creating JACK-based processing script..."
cat > "${HOME}/bin/jack-mic-processor.sh" << EOF
#!/bin/bash

# Start JACK with appropriate settings
jack_control start
sleep 2

# Connect the Vocaster to JACK inputs
VOCASTER_PORTS=\$(jack_lsp | grep -i "vocaster" | grep "capture" | head -n 2)
if [ -z "\$VOCASTER_PORTS" ]; then
    echo "Vocaster interface not detected in JACK. Please check connection."
    exit 1
fi

# Start JACK processing chain
# This example uses japa (JACK and PulseAudio Analyser) and JACK tools
# You may need to adapt this to your specific processing needs
japa & 
JAPA_PID=\$!

# Connect the processing chain
# Replace with actual connections for your processing setup
# Example: connect Vocaster to JAPA input
jack_connect system:capture_1 japa:in_1
jack_connect system:capture_2 japa:in_2

# Connect output to system
jack_connect japa:out_1 system:playback_1
jack_connect japa:out_2 system:playback_2

# Keep running until terminated
echo "Processing chain running. Press CTRL+C to stop."
trap "kill \$JAPA_PID; jack_control stop; exit 0" INT TERM
wait
EOF

chmod +x "${HOME}/bin/jack-mic-processor.sh"

# Create desktop entry for easy starting
echo "Creating desktop entries..."
mkdir -p "${HOME}/.local/share/applications/"

cat > "${HOME}/.local/share/applications/mic-processor.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Microphone Processor
Comment=Real-time processing for Vocaster microphone
Exec=${HOME}/bin/process-mic.sh
Icon=audio-input-microphone
Terminal=true
Categories=Audio;
EOF

cat > "${HOME}/.local/share/applications/jack-mic-processor.desktop" << EOF
[Desktop Entry]
Type=Application
Name=JACK Mic Processor
Comment=Advanced JACK-based processing for Vocaster microphone
Exec=${HOME}/bin/jack-mic-processor.sh
Icon=audio-input-microphone
Terminal=true
Categories=Audio;
EOF

# Optional: Enable the service for autostart
echo "Would you like to enable automatic microphone processing at login? (y/n)"
read -r AUTO_START
if [[ ${AUTO_START} == "y" || ${AUTO_START} == "Y" ]]; then
    systemctl --user enable mic-processor.service
    echo "Service enabled for autostart. Will begin processing at next login."
else
    echo "Service not enabled for autostart. You can start it manually with:"
    echo "  systemctl --user start mic-processor.service"
    echo "Or run the script directly:"
    echo "  ${HOME}/bin/process-mic.sh"
fi

echo "Microphone processing setup complete!"
echo "You can adjust the gain boost and other parameters by editing ${HOME}/bin/process-mic.sh"
