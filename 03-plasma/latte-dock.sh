#!/usr/bin/env bash
# Latte Dock installation and configuration script
# Part of the theme-setup.sh script
# Sets up Latte Dock with the Crystal theme

# Source common library if running standalone
if [[ -z "${LIB_DIR}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
    LIB_DIR="${PARENT_DIR}/lib"
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
fi

# Install and configure Latte Dock
function install_latte_dock() {
    log_section "Installing Latte Dock with Crystal Theme"

    # Check if already installed
    if check_state "latte_dock_installed"; then
        log_info "Latte Dock already installed. Skipping..."
        return 0
    fi

    # Install Latte Dock packages
    log_step "Installing Latte Dock"
    apt_install_if_needed latte-dock

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
        set_state "latte_dock_installed"
        return 0
    fi

    local user_home="/home/${main_user}"

    # Create Latte Dock configuration directory
    mkdir -p "${user_home}/.config/latte"

    # Create Crystal layout file
    log_step "Creating Crystal layout configuration"
    cat > "${user_home}/.config/latte/Crystal.layout.latte" << 'EOF'
[ActionPlugins][1]
RightButton;NoModifier=org.kde.latte.contextmenu

[Containments][1]
activityId=
byPassWM=false
dockWindowBehavior=true
enableKWinEdges=true
formfactor=2
immutability=1
isPreferredForShortcuts=false
lastScreen=10
layoutId=
location=4
name=Crystal Dock
onPrimary=true
plugin=org.kde.latte.containment
raiseOnActivityChange=false
raiseOnDesktopChange=false
screensGroup=0
timerHide=700
timerShow=200
viewType=0
visibility=2
wallpaperplugin=org.kde.image

[Containments][1][Applets][2]
immutability=1
plugin=org.kde.latte.plasmoid

[Containments][1][Applets][2][Configuration]
PreloadWeight=0

[Containments][1][Applets][2][Configuration][General]
isInLatteDock=true
launchers59=applications:firefox.desktop,applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:code.desktop,applications:systemsettings.desktop

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.plasma.analogclock

[Containments][1][ConfigDialog]
DialogHeight=600
DialogWidth=586

[Containments][1][Configuration]
PreloadWeight=0

[Containments][1][General]
advanced=false
alignment=0
alignmentUpgraded=true
appletOrder=2;3
backgroundRadius=25
backgroundShadowSize=45
configurationSticker=true
iconSize=48
durationTime=x1
maxLength=90
panelSize=100
panelTransparency=60
proportionIconSize=4.5
shadowOpacity=60
shadowSize=45
shadows=All
shadowsUpgraded=true
showGlow=false
solidBackgroundForMaximized=true
tasksUpgraded=true
themeColors=SmartThemeColors
thickMargin=11
titleTooltips=false
useThemePanel=false
zoomLevel=0

[Containments][7]
activityId=
byPassWM=false
dockWindowBehavior=true
enableKWinEdges=true
formfactor=2
immutability=1
isPreferredForShortcuts=false
lastScreen=10
layoutId=
location=3
name=Crystal Top Panel
onPrimary=true
plugin=org.kde.latte.containment
raiseOnActivityChange=false
raiseOnDesktopChange=false
screensGroup=0
timerHide=700
timerShow=200
viewType=1
visibility=0
wallpaperplugin=org.kde.image

[Containments][7][Applets][8]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][7][Applets][8][Configuration]
PreloadWeight=92

[Containments][7][Applets][8][Configuration][General]
favoritesPortedToKAstats=true

[Containments][7][Applets][8][Configuration][Shortcuts]
global=Alt+F1

[Containments][7][Applets][9]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][7][Applets][9][Configuration]
PreloadWeight=42
SystrayContainmentId=10

[Containments][7][ConfigDialog]
DialogHeight=600
DialogWidth=586

[Containments][7][Configuration]
PreloadWeight=0

[Containments][7][General]
advanced=false
alignment=10
alignmentUpgraded=true
appletOrder=8;9
appletShadowsEnabled=false
autoDecreaseIconSize=false
autoSizeEnabled=false
backgroundRadius=20
backgroundShadowSize=45
blurEnabled=false
configurationSticker=true
dragActiveWindowEnabled=true
durationTime=x1
floatingInternalGapIsForced=false
iconSize=24
maxLength=90
mouseWheelActions=false
panelPosition=10
panelSize=100
panelTransparency=55
plasmaBackgroundForPopups=true
shadowOpacity=40
shadowSize=45
shadows=None
shadowsUpgraded=true
splitterPosition=3
splitterPosition2=4
taskScrollAction=ScrollNone
tasksUpgraded=true
themeColors=SmartThemeColors
thickMargin=10
titleTooltips=false
useThemePanel=false
zoomLevel=0

[LayoutSettings]
activities=
backgroundStyle=0
color=blue
customBackground=
customTextColor=
disableBordersForMaximizedWindows=false
icon=
lastUsedActivity=
launchers=
preferredForShortcutsTouched=false
showInMenu=true
textColor=fcfcfc
version=2
EOF

    # Create autostart entry for Latte Dock
    mkdir -p "${user_home}/.config/autostart/"

    cat > "${user_home}/.config/autostart/org.kde.latte-dock.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Latte Dock
Exec=latte-dock --layout Crystal --replace
Icon=latte-dock
StartupNotify=false
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

    # Set up configuration for Latte Dock
    mkdir -p "${user_home}/.config/lattedockrc"

    cat > "${user_home}/.config/lattedockrc" << 'EOF'
[UniversalSettings]
badges3DStyle=false
canDisableBorders=false
contextMenuActionsAlwaysShown=_layouts,_preferences,_quit_latte,_separator1,_add_latte_widgets,_add_view
inAdvancedModeForEditSettings=true
isAvailableGeometryBroadcastedToPlasma=true
launchers=
memoryUsage=0
metaPressAndHoldEnabled=true
parabolicSpread=3
screenTrackerInterval=2500
showInfoWindow=true
singleModeLayoutName=Crystal
version=2
EOF

    # Set proper ownership
    chown -R "${main_user}:${main_user}" "${user_home}/.config/latte"
    chown -R "${main_user}:${main_user}" "${user_home}/.config/autostart/org.kde.latte-dock.desktop"
    chown -R "${main_user}:${main_user}" "${user_home}/.config/lattedockrc"

    # Create a theme switcher for Latte Dock
    log_step "Creating Latte Dock theme switcher script"
    mkdir -p "${user_home}/bin"

    cat > "${user_home}/bin/latte-theme.sh" << 'EOF'
#!/bin/bash
# Latte Dock theme switcher

THEME="${1:-crystal}"  # Default to crystal theme

# Kill any running Latte Dock instances
killall latte-dock 2>/dev/null

# Apply appropriate transparency based on theme
case "$THEME" in
  sweet)
    TRANSPARENCY=60
    ;;
  nordic)
    TRANSPARENCY=55
    ;;
  layan)
    TRANSPARENCY=60
    ;;
  aritim|arc)
    TRANSPARENCY=50
    ;;
  *)
    TRANSPARENCY=60
    ;;
esac

# Update Latte Dock configuration
sed -i "s/panelTransparency=.*/panelTransparency=${TRANSPARENCY}/" ~/.config/latte/Crystal.layout.latte

# Start Latte Dock with the crystal layout
latte-dock --layout Crystal --replace &
EOF

    chmod +x "${user_home}/bin/latte-theme.sh"
    chown "${main_user}:${main_user}" "${user_home}/bin/latte-theme.sh"

    # Ensure ~/bin is in PATH
    if grep -q "PATH=.*\$HOME/bin" "${user_home}/.bashrc"; then
        log_info "PATH already includes ~/bin"
    else
        echo 'export PATH="$HOME/bin:$PATH"' >> "${user_home}/.bashrc"
    fi

    # Start Latte Dock for the user
    log_step "Starting Latte Dock for user ${main_user}"

    # We can't start the dock directly for the user due to X authentication,
    # so we need to inform them to start it manually or log out and back in
    log_info "Latte Dock is configured and will start automatically on next login"
    log_info "To start Latte Dock now, run: latte-dock --layout Crystal"

    # Mark as installed
    set_state "latte_dock_installed"
    log_success "Latte Dock installed successfully with Crystal theme"

    return 0
}

# Run the main function if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_latte_dock
fi
