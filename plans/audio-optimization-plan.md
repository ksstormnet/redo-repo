# KDE Audio Production Optimization Implementation Plan

## Overview

This plan outlines the steps to optimize your KDE audio production environment with a focus on:

1. Real-time audio performance optimization
2. Vocaster 1 USB microphone processing with level boosting
3. Audacity workflow improvements
4. VirtualBox audio routing for RadioDJ and StereoTool

## Phase 1: System-Level Audio Optimization

### Step 1: Configure Real-time Audio Performance

Run the real-time audio configuration script to optimize system settings:

```bash
sudo ./realtime-audio-setup.sh
```

This script will:
- Install necessary packages (rtirq-init, rtkit, pipewire, etc.)
- Configure real-time privileges for audio users
- Set CPU governor to performance mode
- Configure PipeWire for low-latency operation
- Set up RTIRQ for audio device prioritization
- Configure USB power management for audio devices

### Step 2: Reboot and Verify Configuration

Reboot your system to ensure all real-time audio settings take effect:

```bash
sudo reboot
```

After reboot, verify the configuration:

```bash
# Check if you're in the audio group
groups | grep audio

# Check CPU governor settings
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check PipeWire settings
systemctl --user status pipewire pipewire-pulse wireplumber
```

## Phase 2: Application-Specific Configuration

### Step 1: Configure Audacity

Run the Audacity configuration script to improve workflow:

```bash
./audacity-config.sh
```

This will:
- Disable overwrite warnings
- Disable project save prompts when exiting
- Set appropriate default behaviors

Launch Audacity to verify the changes have taken effect.

### Step 2: Set Up Microphone Processing

Run the microphone processing setup script:

```bash
./mic-processing.sh
```

This script will:
- Set up SoX for real-time microphone processing
- Create a systemd user service for automatic processing
- Configure gain boosting and vocal enhancement
- Create desktop entries for easy access

Test the microphone processing:

```bash
# Start the processor manually
~/bin/process-mic.sh

# Or use systemd service
systemctl --user start mic-processor.service
```

Adjust the gain and processing parameters in `~/bin/process-mic.sh` as needed.

## Phase 3: VirtualBox Audio Integration

### Step 1: Set Up VirtualBox Audio Bridge

Run the VirtualBox audio bridge configuration script:

```bash
sudo ./virtualbox-audio-bridge.sh
```

This will:
- Install necessary packages for audio routing
- Set up virtual audio devices for VM communication
- Create scripts and services for automatic routing
- Configure dedicated center channel output for RadioDJ cue

### Step 2: Configure RadioDJ and StereoTool VM

Run the RadioDJ/StereoTool helper script, specifying your VM name:

```bash
sudo setup-radiodj-audio.sh Windows
```

Follow the on-screen instructions to configure your Windows VM:
1. Set Windows audio devices to use VirtualBox Audio Input/Output
2. Configure RadioDJ to use these devices:
   - Main output to VirtualBox Audio Output
   - CUE output to VirtualBox Audio Output #2 (routes to center speaker)
3. Set up StereoTool with appropriate audio routing

Enable automatic startup of the audio bridge:

```bash
sudo systemctl enable vbox-audio-bridge@Windows.service
```

### Step 3: Configure Center Channel Cue Output

Test the center channel cue output:

```bash
# Play a test tone through RadioDJ's cue output
# This should only come through your center speaker
```

Adjust the center channel volume as needed:

```bash
sudo adjust-cue-volume.sh 80  # Set to 80%
```

Or use the desktop entry "Cue Channel Volume" for a graphical volume adjustment.

## Phase 4: Testing and Fine-Tuning

### Step 1: Test Full Audio Chain

1. Start your VM and the audio bridge
2. Launch RadioDJ and StereoTool in the VM
3. Test microphone input processing
4. Verify audio routing from host to VM and back

### Step 2: Fine-Tune Settings

Adjust the following settings as needed:

1. Microphone processing parameters in `~/bin/process-mic.sh`:
   - Gain level (increase or decrease the 6dB boost)
   - EQ settings
   - Compression settings

2. Buffer sizes for PipeWire/JACK:
   - Edit `/etc/pipewire/pipewire.conf.d/99-low-latency.conf`
   - Try different quantum values (64, 128, 256) based on performance

3. VirtualBox audio latency:
   - Edit the latency_msec parameter in the audio bridge script
   - Lower values reduce latency but may cause dropouts

## Maintenance and Troubleshooting

### Regular Maintenance Tasks

1. Check for PipeWire updates:
   ```bash
   sudo apt update && sudo apt upgrade
   ```

2. Monitor audio service status:
   ```bash
   systemctl --user status pipewire pipewire-pulse wireplumber
   ```

3. Review log files for issues:
   ```bash
   journalctl --user -u pipewire
   journalctl --user -u mic-processor
   ```

### Troubleshooting Common Issues

1. **Audio Dropouts or Crackling**:
   - Increase buffer size in PipeWire config
   - Check for CPU throttling
   - Verify RTIRQ is working properly

2. **No Audio in VM**:
   - Restart the audio bridge service
   - Check VirtualBox audio settings
   - Verify loopback modules are loaded

3. **Microphone Processing Issues**:
   - Check Vocaster connection and settings
   - Verify SoX is running correctly
   - Adjust processing parameters

4. **High CPU Usage**:
   - Adjust buffer sizes
   - Reduce processing complexity
   - Check for background processes

## Future Enhancements

Consider these additional enhancements:

1. **Advanced Processing Chain**:
   - Implement a more sophisticated JACK-based processing chain
   - Explore LV2 plugins for vocal enhancement
   - Set up multi-band compression

2. **Session Management**:
   - Create session profiles for different use cases
   - Set up Non Session Manager for saving/restoring audio routings

3. **Remote Control**:
   - Configure network control of your audio setup
   - Set up OSC control for adjusting processing parameters

4. **Recording Automation**:
   - Create scripts for scheduled recording
   - Set up automatic post-processing of recordings
