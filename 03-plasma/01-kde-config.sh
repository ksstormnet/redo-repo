#!/usr/bin/env bash
# ============================================================================
# 01-kde-config.sh
# ----------------------------------------------------------------------------
# Configures KDE Plasma desktop to respect LVM paths and apply performance
# optimizations for the desktop environment
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="01-kde-config"

# Default for interactive mode and force mode
: "${INTERACTIVE:=true}"  # Default to interactive mode
: "${FORCE_MODE:=false}"  # Default to not forcing reinstallation

# State directory for tracking progress
: "${STATE_DIR:=/var/lib/system-setup/state}"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

# ============================================================================
# Main Function
# ============================================================================

function configure_kde() {
    log_section "Configuring KDE Plasma Desktop"

    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "KDE Plasma desktop has already been configured. Skipping..."
        return 0
    fi

    # Configure KDE to respect LVM paths
    if ! configure_lvm_paths; then
        log_warning "Failed to configure KDE LVM paths"
        # Continue anyway since this is not critical
    fi

    # Configure KDE performance settings
    if ! configure_kde_performance; then
        log_warning "Failed to configure KDE performance settings"
        # Continue anyway
    fi

    # Configure default applications
    if ! configure_default_applications; then
        log_warning "Failed to configure default applications"
        # Continue anyway
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "KDE Plasma desktop configuration completed successfully"

    return 0
}

# ============================================================================
# LVM Path Configuration
# ============================================================================

# Configure KDE to respect LVM paths
function configure_lvm_paths() {
    log_section "Configuring KDE to Respect LVM Paths"

    if check_state "${SCRIPT_NAME}_lvm_paths_configured"; then
        log_info "KDE LVM paths already configured. Skipping..."
        return 0
    fi

    # Detect main user account
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Using default paths."
        main_user="ubuntu"
    fi

    local user_home="/home/${main_user}"

    log_info "Configuring KDE for user: ${main_user}"

    # Create necessary directories if they don't exist
    mkdir -p "${user_home}/.config"

    # Check for LVM mounts
    log_step "Checking for LVM mounts"

    local lvm_mounts=()
    if grep -q "/dev/mapper/vg_data" /etc/fstab; then
        log_info "LVM mounts detected in /etc/fstab"

        # Check for specific LVM mounts
        if grep -q "/data" /etc/fstab; then
            lvm_mounts+=("/data")
            log_info "Found /data mount point"
        fi

        if grep -q "/home/${main_user}" /etc/fstab; then
            lvm_mounts+=("/home/${main_user}")
            log_info "Found /home/${main_user} mount point"
        fi

        if grep -q "/opt" /etc/fstab; then
            lvm_mounts+=("/opt")
            log_info "Found /opt mount point"
        fi

        if grep -q "/var" /etc/fstab; then
            lvm_mounts+=("/var")
            log_info "Found /var mount point"
        fi
    else
        log_warning "No LVM mounts detected in /etc/fstab. Using default paths."
    fi

    # Configure Dolphin file manager to show LVM mounts
    log_step "Configuring Dolphin file manager for LVM mounts"

    local dolphin_config_dir="${user_home}/.config/"
    mkdir -p "${dolphin_config_dir}"

    # Create Dolphin places configuration
    local dolphin_places="${dolphin_config_dir}/dolphinrc"

    # Create initial config if it doesn't exist
    if [[ ! -f "${dolphin_places}" ]]; then
        cat > "${dolphin_places}" << EOF
[General]
Version=200
ViewPropsTimestamp=2023,1,1,0,0,0

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled

[PlacesPanel]
IconSize=22
EOF
    fi

    # Add LVM mounts to Places panel
    if [[ ${#lvm_mounts[@]} -gt 0 ]]; then
        local places_section
        places_section=$(grep -n '\[PlacesPanel\]' "${dolphin_places}" | cut -d: -f1)
        if [[ -n "${places_section}" ]]; then
            log_info "Adding LVM mounts to Dolphin places"

            for mount in "${lvm_mounts[@]}"; do
                # Add mount to places if it's not already there
                if ! grep -q "Path=${mount}" "${dolphin_places}"; then
                    # Get a mount name from the path
                    local mount_name
                    mount_name=$(basename "${mount}")
                    echo "Places[$((places_section+10))]=file://${mount}" >> "${dolphin_places}"
                    log_info "Added ${mount} to Dolphin places"
                fi
            done
        else
            # Add Places section if it doesn't exist
            echo -e "\n[PlacesPanel]\nIconSize=22" >> "${dolphin_places}"

            for mount in "${lvm_mounts[@]}"; do
                # Get a mount name from the path
                local mount_name
                mount_name=$(basename "${mount}")
                echo "Places[10]=${mount_name},file://${mount},16" >> "${dolphin_places}"
                log_info "Added ${mount} to Dolphin places"
            done
        fi
    fi

    # Set proper ownership for all KDE configuration files
    chown -R "${main_user}:${main_user}" "${user_home}/.config"

    # Mark as completed
    set_state "${SCRIPT_NAME}_lvm_paths_configured"
    log_success "KDE LVM paths configured successfully"

    return 0
}

# ============================================================================
# KDE Performance Configuration
# ============================================================================

# Configure KDE for optimal performance
function configure_kde_performance() {
    log_section "Configuring KDE Performance Settings"

    if check_state "${SCRIPT_NAME}_performance_configured"; then
        log_info "KDE performance settings already configured. Skipping..."
        return 0
    fi

    # Detect main user account
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Using default user."
        main_user="ubuntu"
    fi

    local user_home="/home/${main_user}"

    # Create KDE config directories
    mkdir -p "${user_home}/.config/kwinrc"

    # Configure compositor for performance
    log_step "Configuring KDE compositor for performance"

    cat > "${user_home}/.config/kwinrc" << EOF
[Compositing]
AnimationSpeed=2
Backend=OpenGL
Enabled=true
GLCore=true
GLPreferBufferSwap=a
GLTextureFilter=1
HiddenPreviews=6
OpenGLIsUnsafe=false
WindowsBlockCompositing=true
XRenderSmoothScale=false

[Effect-CoverSwitch]
TabBox=false
TabBoxAlternative=false

[Effect-Cube]
BorderActivate=9
BorderActivateCylinder=9
BorderActivateSphere=9

[Effect-DesktopGrid]
BorderActivate=9

[Effect-PresentWindows]
BorderActivate=9
BorderActivateAll=9
BorderActivateClass=9

[ElectricBorders]
Bottom=None
BottomLeft=None
BottomRight=None
Left=None
Right=None
Top=None
TopLeft=None
TopRight=None

[TabBox]
BorderActivate=9
BorderAlternativeActivate=9
DesktopLayout=org.kde.breeze.desktop
DesktopListLayout=org.kde.breeze.desktop
LayoutName=org.kde.breeze.desktop

[Windows]
BorderlessMaximizedWindows=true
ElectricBorderCooldown=350
ElectricBorderCornerRatio=0.25
ElectricBorderDelay=150
ElectricBorderMaximize=true
ElectricBorderTiling=true
ElectricBorders=0
RollOverDesktops=true

[org.kde.kdecoration2]
BorderSize=Normal
ButtonsOnLeft=MS
ButtonsOnRight=HIAX
CloseOnDoubleClickOnMenu=false
ShowToolTips=true
theme=Breeze
EOF

    # Configure KWin for performance
    log_step "Configuring KWin window manager for performance"

    # Create kwinrulesrc for window rules
    cat > "${user_home}/.config/kwinrulesrc" << EOF
[General]
count=1
rules=1

[1]
Description=Performance settings for all windows
clientmachine=localhost
clientmachinematch=0
noborder=false
noborderrule=2
title=General Performance
titlematch=0
type=0
typerule=2
wmclass=.*
wmclasscomplete=false
wmclassmatch=3
EOF

    # Configure Plasma for performance
    log_step "Configuring Plasma desktop for performance"

    # Create kdeglobals configuration
    cat > "${user_home}/.config/kdeglobals" << EOF
[KDE]
AnimationDurationFactor=0.5
LookAndFeelPackage=org.kde.breeze.desktop
ShowDeleteCommand=true
SingleClick=false

[General]
AllowKDEAppsToRememberWindowPositions=true
BrowserApplication=firefox
ColorScheme=BreezeLight
XftHintStyle=hintslight
XftSubPixel=rgb
fixed=Monospace,9,-1,5,50,0,0,0,0,0
font=Sans Serif,9,-1,5,50,0,0,0,0,0
menuFont=Sans Serif,9,-1,5,50,0,0,0,0,0
smallestReadableFont=Sans Serif,8,-1,5,50,0,0,0,0,0
toolBarFont=Sans Serif,9,-1,5,50,0,0,0,0,0

[KDE Action Restrictions]
action/kwin_rmb=true

[KFileDialog Settings]
Allow Expansion=false
Automatically select filename extension=true
Breadcrumb Navigation=true
Decoration position=0
LocationCombo Completionmode=5
PathCombo Completionmode=5
Show Bookmarks=true
Show Full Path=false
Show Inline Previews=true
Show Preview=false
Show Speedbar=true
Show hidden files=false
Sort by=Name
Sort directories first=true
Sort reversed=false
Speedbar Width=133
View Style=Simple
listViewIconSize=0

[PreviewSettings]
MaximumRemoteSize=0

[WM]
activeFont=Sans Serif,8,-1,5,75,0,0,0,0,0
activeBackground=71,80,87
activeBlend=255,255,255
activeForeground=239,240,241
inactiveBackground=239,240,241
inactiveBlend=75,71,67
inactiveForeground=189,195,199
EOF

    # Create Plasma-org.kde.plasma.desktop-appletsrc configuration
    mkdir -p "${user_home}/.config"

    # Create baloo configuration (file indexer)
    log_step "Configuring Baloo file indexer for performance"

    # Create directory if it doesn't exist
    mkdir -p "${user_home}/.config/baloofilerc"

    # Create baloo configuration
    cat > "${user_home}/.config/baloofilerc" << EOF
[Basic Settings]
Indexing-Enabled=false

[General]
only basic indexing=true
exclude filters=*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CMakeFiles,CMakeTmp,CMakeTmpQmake,*.tmp,*.vmdk,*.vdi,*.vhd,*.qcow2,*.vhdx,*.vdi,*.raw,*.avi,*.iso,*.mp3,*.mp4,*.mkv,*.rar,*.zip,*.7z,*.gz,*.bz2,*.xz,*.crdownload,*.part,*.kate-swp,.git/*,.svn/*
exclude folders=${HOME}/.git/,${HOME}/.svn/
exclude filters version=8
folders[0]=file:///
folders[1]=file://${user_home}
EOF

    # Set proper ownership for all KDE configuration files
    chown -R "${main_user}:${main_user}" "${user_home}/.config"

    # Mark as completed
    set_state "${SCRIPT_NAME}_performance_configured"
    log_success "KDE performance settings configured successfully"

    return 0
}

# ============================================================================
# Default Application Configuration
# ============================================================================

# Configure default applications
function configure_default_applications() {
    log_section "Configuring Default Applications"

    if check_state "${SCRIPT_NAME}_default_apps_configured"; then
        log_info "Default applications already configured. Skipping..."
        return 0
    fi

    # Detect main user account
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Using default user."
        main_user="ubuntu"
    fi

    local user_home="/home/${main_user}"
    local apps_dir="${user_home}/.config"

    mkdir -p "${apps_dir}"

    # Create mimeapps.list
    log_step "Configuring default applications for file types"

    cat > "${apps_dir}/mimeapps.list" << EOF
[Default Applications]
application/pdf=okular.desktop
application/x-extension-htm=firefox.desktop
application/x-extension-html=firefox.desktop
application/x-extension-shtml=firefox.desktop
application/x-extension-xht=firefox.desktop
application/x-extension-xhtml=firefox.desktop
application/xhtml+xml=firefox.desktop
text/html=firefox.desktop
text/plain=kate.desktop
text/x-c++src=kate.desktop
text/x-csrc=kate.desktop
text/x-python=kate.desktop
text/x-script.python=kate.desktop
text/x-java=kate.desktop
application/x-shellscript=kate.desktop
audio/mpeg=vlc.desktop
audio/mp4=vlc.desktop
video/mp4=vlc.desktop
video/x-matroska=vlc.desktop
video/mpeg=vlc.desktop
image/jpeg=gwenview.desktop
image/png=gwenview.desktop
image/gif=gwenview.desktop
image/webp=gwenview.desktop
EOF

    # Set proper ownership for all configuration files
    chown -R "${main_user}:${main_user}" "${apps_dir}"

    # Mark as completed
    set_state "${SCRIPT_NAME}_default_apps_configured"
    log_success "Default applications configured successfully"

    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
configure_kde

# Return the exit code
exit $?
