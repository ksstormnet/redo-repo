# Bluetooth Troubleshooting Guide

## Issue Identified

We've been addressing the "br-connection-profile-unavailable" error when connecting Bluetooth audio devices. This is a known issue with PipeWire and the BlueZ stack where the audio profiles (A2DP/HSP) are not properly registered.

## Actions Taken

1. **Basic Audio Configuration**

   - Applied fixes for USB audio detection
   - Created improved PipeWire configuration for device detection
   - Modified USB power management settings

2. **Bluetooth-Specific Fixes**

   - Installed Bluetooth support packages
   - Created specialized Bluetooth configurations
   - Reset and reconfigured the Bluetooth stack
   - Created a minimal working configuration

3. **Complete System Reset**
   - Removed all custom configurations
   - Reset the Bluetooth adapter
   - Cleared previously paired devices
   - Applied default settings with minimal modifications

## Next Steps

1. **Reboot Your System**

   - Several low-level changes were made that require a full system restart
   - Run: `sudo reboot`

2. **After Reboot**

   - Wait for the system to fully initialize (about 1 minute after logging in)
   - Try connecting your Bluetooth speaker:
     ```
     bluetoothctl
     scan on
     # Wait for your device to appear
     pair [MAC_ADDRESS]
     connect [MAC_ADDRESS]
     ```

3. **If Issues Persist**
   - The root cause might be related to how PipeWire interacts with your specific Bluetooth device
   - Consider trying an alternative audio server:
     ```
     sudo apt install pulseaudio
     systemctl --user mask pipewire pipewire-pulse
     systemctl --user enable pulseaudio.service
     systemctl --user start pulseaudio.service
     ```
   - Then reboot and try connecting again

## Long-term Solution

In our script migration, we should provide an option to use either PipeWire (newer, lower latency) or PulseAudio (more compatible with some Bluetooth devices). This will give users flexibility depending on their specific hardware.

## References

- [PipeWire Bluetooth Troubleshooting](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Troubleshooting#bluetooth)
- [Ubuntu Studio Audio Handbook](https://help.ubuntu.com/community/UbuntuStudio/AudioHandbook)
