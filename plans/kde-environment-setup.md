# KDE Environment Setup Guide for Multiple Workflows

This guide will help you configure a highly efficient KDE Plasma desktop environment optimized for multiple workflows: project management, development, audio production, and travel agent tasks. It leverages KDE's Activities feature, custom keyboard shortcuts, and integration with StreamDeck, all optimized for your dual curved screen setup.

## 1. Setting Up KDE Activities

### Creating Activities

1. Open the Activities sidebar with `Meta+Q` or by clicking on the Activities icon in your panel
2. Click "Create Activity" and set up the following:

#### Project Management Activity
```
Name: Project Management
Icon: office-chart
Description: For Clickup, Slack, Zoom, and project coordination
```

#### Development Activity
```
Name: Development
Icon: applications-development
Description: For coding and software development tasks
```

#### Audio Production Activity
```
Name: Audio Production
Icon: audio-headphones
Description: For Audacity and audio production workflows
```

#### Travel Agent Activity
```
Name: Travel Agent
Icon: globe
Description: For travel research, booking, and client communications
```

### Configuring Activity Switching

1. Go to System Settings > Workspace > Shortcuts
2. Search for "Activity" to find the activity-related shortcuts
3. Set these recommended shortcuts:
   - Switch to Previous Activity: `Meta+Tab`
   - Switch to Next Activity: `Meta+Shift+Tab`
   - Show Activities Switcher: `Meta+Q`

## 2. Dual Screen Panel Configuration

Before customizing each activity, let's set up your persistent panels that will remain consistent across all activities:

### Primary Center Panel (Between Screens)
1. Create a vertical panel positioned at the right edge of screen 1 (left monitor):
   - Right-click on desktop > Add Panel > Default Panel
   - Right-click on new panel > Edit Panel
   - Set position to "Right" and adjust height as needed
   - Configure panel behavior to "Always Visible"

2. Add these widgets to this panel:
   - Application Launcher (at top)
   - Activity-specific application shortcuts (middle section)
   - System tray (lower section)

### Secondary Center Panel (Between Screens)
1. Create a vertical panel positioned at the left edge of screen 2 (right monitor, your primary):
   - Follow same steps as above
   - Position at "Left" 
   - Configure with application shortcuts specific to screen 2 (your primary)

### Bottom Panels (One per Screen)
1. Create narrow horizontal panel at the bottom of screen 1 (left monitor):
   - Task Manager (set to "Only show tasks from the current screen")
   - System Monitoring widgets (left-aligned)
   - Digital Clock widget (left-aligned)

2. Create narrow horizontal panel at the bottom of screen 2 (right monitor, your primary):
   - Task Manager (set to "Only show tasks from the current screen")
   - Digital Clock widget (right-aligned)
   - Notifications widget (right-aligned)
   - Calendar widget (right-aligned)

### Panel Widget Settings
1. For all Task Managers:
   - Right-click > Configure Task Manager
   - Enable "Only show tasks from the current screen"
   - Set "Sorting" to "Manual" for better control

2. For Application Launchers:
   - Configure to show your most-used applications
   - Organize into categories that make sense for your workflow

## 3. Customizing Each Activity

### Project Management Activity

#### Desktop Layout
1. **Screen 2** (Right monitor - Primary focus):
   - Right-click on desktop > Add Widgets
   - Folder View widget with Clickup and project dashboards shortcuts
   - Notes widget for quick task notes
   - System monitor for resource usage

2. **Screen 1** (Left monitor - Secondary/reference):
   - Folder View widget with reference documents
   - Calendar widget for schedule overview
   - Weather widget (if relevant to project planning)

#### Primary Center Panel Modification
1. Add these application shortcuts specifically for Project Management:
   - Clickup (configured to open on Screen 2, your primary)
   - Slack (configured to open on Screen 2, your primary)
   - Zoom (configured to open on Screen 1, for reference/secondary view)
   - Edge browser (configured to open on Screen 2, your primary work screen)

#### Virtual Desktops Setup
1. Go to System Settings > Workspace > Virtual Desktops
2. Set up 3 desktops with these names:
   - "Projects" (for Clickup and project dashboards)
   - "Communication" (for Slack and Zoom)
   - "Reference" (for documentation and resources)

#### Default Applications
Configure these applications to auto-start with this activity:
1. Go to System Settings > Startup and Shutdown > Autostart
2. Add Edge, Slack, and Zoom with the condition to only start with the Project Management activity

### Development Activity

#### Desktop Layout
1. **Screen 2** (Right monitor - Primary coding):
   - Folder View widget pointed to your active project directories
   - Git Branch widget (if available) or similar VCS indicator
   - System Monitor widget focused on CPU/RAM usage

2. **Screen 1** (Left monitor - Documentation/Reference):
   - Folder View widget pointing to documentation/reference materials
   - Quick Notes widget for code snippets and ideas
   - Browser bookmark widget for quick access to dev resources

#### Primary Center Panel Modification
1. Add these application shortcuts specifically for Development:
   - VSCode (configured to open on Screen 2, your primary)
   - Warp/Terminal (configured to open on Screen 2, your primary)
   - Browser for documentation (configured to open on Screen 1)
   - Database tools (configured to open on Screen 1)

#### Virtual Desktops Setup
1. Set up 4-6 virtual desktops named after your main projects or development contexts
2. Configure each to have its own wallpaper for quick visual identification

#### Default Applications
Configure VSCode and Warp Terminal to auto-start with this activity

### Audio Production Activity

#### Desktop Layout
1. **Screen 2** (Right monitor - Production workspace):
   - Folder View widget pointing to your audio projects
   - System monitor focused on CPU usage for audio processing
   - Audio volume widget with quick mixer access

2. **Screen 1** (Left monitor - Reference/Controls):
   - Media player controls for reference tracks
   - Folder View widget pointed to your audio samples or libraries
   - Notes widget for production notes and ideas

#### Primary Center Panel Modification
1. Add these application shortcuts specifically for Audio Production:
   - Audacity (configured to open maximized on Screen 2, your primary)
   - Browser for audio reference (configured to open on Screen 1)
   - Terminal/Warp (configured to open on Screen 2, your primary)
   - File manager pointed to audio samples (configured to open on Screen 1)

#### Virtual Desktops Setup
1. Set up 3 desktops:
   - "Production" (for Audacity and main work)
   - "Reference" (browser for tutorials/reference)
   - "Utilities" (for additional tools)

#### Default Applications
Configure Audacity to auto-start with this activity

### Travel Agent Activity

#### Desktop Layout
1. **Screen 2** (Right monitor - Booking/Research):
   - Browser bookmarks widget with travel sites
   - Folder View with client information and itineraries
   - Currency converter widget
   - World clock widget showing multiple time zones

2. **Screen 1** (Left monitor - Client Communication):
   - Calendar widget for appointment tracking
   - Notes widget for client preferences
   - Weather widget for destination forecasts

#### Primary Center Panel Modification
1. Add these application shortcuts specifically for Travel Agent work:
   - Edge browser for booking sites (configured to open on Screen 2, your primary)
   - Secondary browser for research (configured to open on Screen 1)
   - Zoom for client calls (configured to open on Screen 1)
   - Email client (configured to open on Screen 2, your primary)

#### Virtual Desktops Setup
1. Set up 4 desktops:
   - "Client Research" (for customer profiles and preferences)
   - "Booking" (for reservation systems)
   - "Itinerary Planning" (for creating travel plans)
   - "Communication" (for client emails and calls)

#### Default Applications
Configure Edge browser and email client to auto-start with this activity

## 3. Global Keyboard Shortcuts

Configure these global shortcuts that work across all activities:

1. Go to System Settings > Shortcuts
2. Set up the following:
   - `Meta+E`: File Manager
   - `Meta+T`: Terminal/Warp
   - `Meta+B`: Default Browser (Edge)
   - `Meta+C`: VSCode
   - `Meta+A`: Audacity
   - `Meta+S`: Slack
   - `Meta+Z`: Zoom
   - `Meta+1/2/3`: Switch to virtual desktop 1/2/3
   - `Meta+Ctrl+Left/Right`: Move window to left/right virtual desktop
   - `Meta+Up`: Maximize window
   - `Meta+Down`: Minimize window
   - `Meta+Left/Right`: Tile window to left/right half of screen

## 4. StreamDeck Integration

### Basic StreamDeck Configuration

Set up your StreamDeck with these button layouts:

#### Page 1: Activity Switcher
- Button 1: Switch to Project Management Activity
- Button 2: Switch to Development Activity
- Button 3: Switch to Audio Production Activity
- Button 4: Switch to Travel Agent Activity
- Button 5-7: Common applications (Edge, VSCode, Terminal)
- Button 8-9: System controls (volume, media playback)

#### Page 2: Project Management Tools
- Buttons for launching or focusing Clickup, Slack, Zoom
- Buttons for common project management tasks
- Buttons for moving applications between screens
- Buttons for switching between the virtual desktops in this activity

#### Page 3: Development Tools
- Buttons for each development project
- Buttons for common git commands
- Buttons for building, testing, and deploying
- Buttons for multi-screen layouts (code on screen 1, docs on screen 2)
- Buttons for switching between virtual desktops in this activity

#### Page 4: Audio Production Tools
- Buttons for Audacity controls
- Buttons for audio settings
- Buttons for specific dual-screen configurations
- Buttons for switching between virtual desktops in this activity

#### Page 5: Travel Agent Tools
- Buttons for common travel booking sites
- Buttons for client communication tools
- Buttons for screen layouts (booking on screen 1, research on screen 2)
- Buttons for switching between virtual desktops in this activity

### StreamDeck Technical Setup

1. Install the StreamDeck software for Linux
2. For KDE integration, use scripts that leverage `qdbus` to control KDE:

```bash
# Example script to switch to Project Management activity
qdbus org.kde.ActivityManager /ActivityManager/Activities SetCurrentActivity "activity-uuid-for-project-management"
```

3. Find your activity UUIDs with:
```bash
qdbus org.kde.ActivityManager /ActivityManager/Activities ListActivities
```

4. Create a script for each activity and assign it to your StreamDeck buttons

## 5. Window Rules for Multi-Screen and Automatic Placement

Configure KDE Window Rules to automatically place applications on specific screens and virtual desktops:

1. Go to System Settings > Window Management > Window Rules
2. Create new rules for each application:

### Screen Placement Rules

#### Example: Edge Browser on Screen 2 (Primary)
```
Description: Place Edge on Screen 2 (Primary)
Property: Window class (application)
Value: microsoft-edge
Action: Screen
Value: 1 (Your Screen 2/Primary screen number)
Action: Position
Value: Remember
```

#### Example: Documentation Browser on Screen 1
```
Description: Place Documentation Browser on Screen 1
Property: Window class (application) 
Value: firefox
Property: Window title
Value: *Documentation*
Action: Screen
Value: 0 (Your Screen 1/Left screen number)
```

### Virtual Desktop Rules

#### Example: Slack Rule
```
Description: Place Slack on Communication Desktop
Property: Window class (application)
Value: slack
Action: Virtual Desktop
Value: 2 (Communication)
```

#### Example: VSCode Project-Specific Rules
```
Description: Place VSCode Project A on Project A Desktop
Property: Window title
Value: Project A - Visual Studio Code
Action: Virtual Desktop
Value: 1 (Project A)
```

### Activity-Specific Rules

#### Example: Audacity in Audio Production Activity
```
Description: Audacity in Audio Production Activity
Property: Window class (application)
Value: audacity
Action: Activity
Value: (Your Audio Production Activity ID)
Action: Screen
Value: 1 (Screen 2/Primary)
```

## 6. Fine-tuning Performance

### Compositor Settings
1. Go to System Settings > Display and Monitor > Compositor
2. Adjust for your preference of performance vs. visual effects:
   - Animation speed: set to fastest
   - Scale method: Accurate
   - Rendering backend: OpenGL 3.1
   - Only check necessary effects

### Desktop Effects Settings
1. Go to System Settings > Workspace Behavior > Desktop Effects
2. Disable unnecessary effects like:
   - Blur
   - Sliding pop-ups
   - Wobbly windows
3. Keep useful ones like:
   - Present Windows
   - Desktop Grid
   - Screen Edge effects

## 7. Task-Specific Configurations

### For Project Management

#### Clickup Optimization
- Create a web app shortcut for Clickup in Edge
- Configure it to open maximized on Screen 2 (primary)
- Set up window rules to ensure it always opens on the correct screen

#### Communication Tools Setup
- Configure Slack to start on Screen 2 (primary)
- Set up Zoom to open on Screen 1 (secondary) for better presentation viewing
- Configure Zoom to remember your last audio/video settings

### For Development

#### VSCode Workspace-Specific Settings
- Create workspace-specific settings files for different projects
- Configure each with appropriate extensions and settings
- Set up multi-root workspaces that span across your dual screens
- Position VSCode on Screen 2 (primary) as your main coding environment

#### Terminal Profile
- Create a custom Warp Terminal profile for each project
- Position terminal windows strategically on Screen 2 (primary)
- Set up project-specific aliases and environment variables

### For Audio Production

#### Audacity Configuration
- Configure Audacity to use specific audio devices
- Set window position to maximize Screen 2 (primary) usage
- Set up preferred export formats and quality settings

#### Audio System Settings
- Configure KDE sound settings for optimal latency
- Position audio monitoring widgets on Screen 1 (secondary)
- Set up shortcuts for quick audio device switching

### For Travel Agent Work

#### Browser Profiles
- Create dedicated browser profiles for travel research
- Set up travel booking sites to open on Screen 2 (primary)
- Configure research tools and references to open on Screen 1 (secondary)

#### Client Communication Setup
- Position Zoom windows on Screen 1 (secondary) during client calls
- Keep itinerary development tools on Screen 2 (primary)
- Create templates for common travel documents

## 8. Backup and Restore Configuration

Always back up your KDE configuration to easily restore it:

1. Back up these directories:
   - `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (plasma layout)
   - `~/.config/kactivitymanagerdrc` (activities configuration)
   - `~/.config/kglobalshortcutsrc` (shortcuts)
   - `~/.local/share/kactivitymanager/resources/` (activity-specific resources)

2. Create a script that restores your configuration:
```bash
#!/bin/bash
# Backup current config
mkdir -p ~/kde-backup/$(date +%Y-%m-%d)
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc ~/kde-backup/$(date +%Y-%m-%d)/
# More backup commands...

# Restore from backup
cp ~/kde-backup/favorite-config/plasma-org.kde.plasma.desktop-appletsrc ~/.config/
# More restore commands...

# Restart Plasma
plasmashell --replace &
```

## 9. Regular Maintenance

To keep your environment running smoothly:

1. Periodically clear KDE's cache:
   ```bash
   rm -rf ~/.cache/plasma*
   ```

2. Update your StreamDeck configurations as your workflow evolves

3. Review and refine your activities and shortcuts monthly
