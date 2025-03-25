#!/usr/bin/env bash
# ============================================================================
# 03-theme-setup.sh
# ----------------------------------------------------------------------------
# Installs and configures themes, icons, and appearance settings for KDE Plasma
# Sets up global theme defaults and user-specific customizations
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
SCRIPT_NAME="03-theme-setup"

# Theme configuration
THEME_STYLE="dark"  # Options: light, dark, system (uses system preference)
PREFER_GTK_APPS=false  # Set to true to use GTK file dialogs for Qt/KDE apps

# ============================================================================
# Command Line Argument Processing
# ============================================================================

# Display help information
function show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure themes and appearance for KDE Plasma"
    echo
    echo "Options:"
    echo "  --light           Use light theme (default is dark)"
    echo "  --dark            Use dark theme"
    echo "  --system          Use system preference for theme"
    echo "  --gtk-dialogs     Use GTK file dialogs for Qt/KDE apps"
    echo "  --help            Display this help message and exit"
    echo
}

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --light)
                THEME_STYLE="light"
                shift
                ;;
            --dark)
                THEME_STYLE="dark"
                shift
                ;;
            --system)
                THEME_STYLE="system"
                shift
                ;;
            --gtk-dialogs)
                PREFER_GTK_APPS=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Log selected options
    log_info "Selected theme style: ${THEME_STYLE}"
    if [[ "${PREFER_GTK_APPS}" == "true" ]]; then
        log_info "Will use GTK file dialogs for Qt/KDE apps"
    fi
}

# ============================================================================
# Theme Installation Functions
# ============================================================================

# Install theme packages
function install_theme_packages() {
    log_section "Installing Theme Packages"
    
    if check_state "${SCRIPT_NAME}_theme_packages_installed"; then
        log_info "Theme packages already installed. Skipping..."
        return 0
    fi
    
    # Update package lists
    log_step "Updating package lists"
    if ! apt_update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install basic theme packages
    log_step "Installing basic theme packages"
    local theme_packages=(
        breeze
        breeze-icon-theme
        breeze-gtk-theme
        breeze-cursor-theme
        kde-style-breeze
        papirus-icon-theme
        qt5-style-plugins
    )
    
    if ! apt_install "${theme_packages[@]}"; then
        log_error "Failed to install basic theme packages"
        return 1
    fi
    
    # Install additional themes if available
    log_step "Installing additional theme packages"
    local additional_themes=(
        papirus-folders
        materia-kde
        materia-gtk-theme
        kvantum
        qt5-style-kvantum
        qt5-style-kvantum-themes
    )
    
    if ! apt_install "${additional_themes[@]}"; then
        log_warning "Failed to install some additional theme packages"
        # Continue anyway as these are not critical
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_theme_packages_installed"
    log_success "Theme packages installed successfully"
    
    return 0
}

# ============================================================================
# System-wide Theme Configuration
# ============================================================================

# Configure system-wide theme defaults
function configure_system_theme() {
    log_section "Configuring System-wide Theme Defaults"
    
    if check_state "${SCRIPT_NAME}_system_theme_configured"; then
        log_info "System-wide theme already configured. Skipping..."
        return 0
    fi
    
    # Create global theme defaults directory
    log_step "Creating global theme defaults directory"
    mkdir -p /etc/xdg/kdeglobals /etc/xdg/kwinrc
    
    # Set default theme based on chosen style
    log_step "Setting default theme style: ${THEME_STYLE}"
    
    # Create kdeglobals for system-wide defaults
    cat > /etc/xdg/kdeglobals << EOF
[General]
ColorScheme=$([ "${THEME_STYLE}" = "dark" ] && echo "BreezeDark" || echo "BreezeLight")
Name=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze Dark" || echo "Breeze Light")
shadeSortColumn=true
font=Noto Sans,10,-1,5,50,0,0,0,0,0
fixed=Hack,10,-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0
menuFont=Noto Sans,10,-1,5,50,0,0,0,0,0

[Icons]
Theme=Papirus$([ "${THEME_STYLE}" = "dark" ] && echo "-Dark" || echo "")

[KDE]
LookAndFeelPackage=$([ "${THEME_STYLE}" = "dark" ] && echo "org.kde.breezedark.desktop" || echo "org.kde.breeze.desktop")
SingleClick=false
AnimationDurationFactor=0.5
ShowDeleteCommand=true
contrast=4

[WM]
activeFont=Noto Sans,10,-1,5,50,0,0,0,0,0
EOF
    
    # Create kwinrc for system-wide window manager settings
    cat > /etc/xdg/kwinrc << EOF
[Windows]
BorderlessMaximizedWindows=true
Placement=Smart
ShowDesktopIsMinimizeAll=false

[org.kde.kdecoration2]
NoPlugin=false
library=org.kde.breeze
theme=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze Dark" || echo "Breeze Light")

[Compositing]
Backend=OpenGL
Enabled=true
GLCore=true
GLTextureFilter=2
HiddenPreviews=6
WindowsBlockCompositing=true
EOF
    
    # Create a system-wide Qt5 configuration
    log_step "Creating system-wide Qt5 configuration"
    mkdir -p /etc/xdg/qt5ct
    
    cat > /etc/xdg/qt5ct/qt5ct.conf << EOF
[Appearance]
color_scheme_path=
custom_palette=false
icon_theme=Papirus$([ "${THEME_STYLE}" = "dark" ] && echo "-Dark" || echo "")
standard_dialogs=$([ "${PREFER_GTK_APPS}" = "true" ] && echo "gtk3" || echo "default")
style=Breeze

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0\x46\0i\0x\0\x65\0\x64\0 \0\x46\0o\0n\0t@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0\x46\0i\0x\0\x65\0\x64\0 \0\x46\0o\0n\0t@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)

[Interface]
activate_item_on_single_click=false
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=true
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=true
wheel_scroll_lines=3
EOF
    
    # Create a system-wide GTK configuration
    log_step "Creating system-wide GTK configuration"
    mkdir -p /etc/gtk-3.0 /etc/gtk-2.0
    
    # GTK 3 settings
    cat > /etc/gtk-3.0/settings.ini << EOF
[Settings]
gtk-application-prefer-dark-theme=$([ "${THEME_STYLE}" = "dark" ] && echo "1" || echo "0")
gtk-button-images=1
gtk-cursor-theme-name=breeze_cursors
gtk-cursor-theme-size=24
gtk-decoration-layout=icon:minimize,maximize,close
gtk-enable-animations=1
gtk-fallback-icon-theme=breeze
gtk-font-name=Noto Sans 10
gtk-icon-theme-name=Papirus$([ "${THEME_STYLE}" = "dark" ] && echo "-Dark" || echo "")
gtk-menu-images=1
gtk-modules=colorreload-gtk-module:window-decorations-gtk-module
gtk-primary-button-warps-slider=0
gtk-sound-theme-name=ocean
gtk-theme-name=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze-Dark" || echo "Breeze")
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
EOF
    
    # GTK 2 settings
    cat > /etc/gtk-2.0/gtkrc << EOF
gtk-theme-name="$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze-Dark" || echo "Breeze")"
gtk-icon-theme-name="Papirus$([ "${THEME_STYLE}" = "dark" ] && echo "-Dark" || echo "")"
gtk-font-name="Noto Sans 10"
gtk-cursor-theme-name="breeze_cursors"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-animations=1
gtk-primary-button-warps-slider=0
gtk-sound-theme-name="ocean"
gtk-modules="colorreload-gtk-module:window-decorations-gtk-module"
gtk-decoration-layout="icon:minimize,maximize,close"
gtk-fallback-icon-theme="breeze"
EOF
    
    # Create user template configuration
    log_step "Creating user template configuration"
    mkdir -p /etc/skel/.config
    
    # Copy global defaults to user template
    cp -a /etc/xdg/kdeglobals /etc/skel/.config/
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_system_theme_configured"
    log_success "System-wide theme configured successfully"
    
    return 0
}

# ============================================================================
# User-specific Theme Configuration
# ============================================================================

# Configure user-specific theme settings
function configure_user_theme() {
    log_section "Configuring User-specific Theme Settings"
    
    if check_state "${SCRIPT_NAME}_user_theme_configured"; then
        log_info "User-specific theme already configured. Skipping..."
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
        log_warning "Could not detect main user account. Skipping user-specific theme configuration."
        return 0
    fi
    
    log_info "Configuring theme for user: ${main_user}"
    local user_home="/home/${main_user}"
    
    # Create necessary config directories
    mkdir -p "${user_home}/.config"
    
    # Copy system theme settings to user config
    cp -a /etc/xdg/kdeglobals "${user_home}/.config/" 2>/dev/null || true
    cp -a /etc/xdg/kwinrc "${user_home}/.config/" 2>/dev/null || true
    
    # Set user-specific theme settings
    log_step "Setting user-specific theme preferences"
    
    # Create kdedefaults directory
    mkdir -p "${user_home}/.config/kdedefaults"
    
    # Configure default plasma theme
    cat > "${user_home}/.config/kdedefaults/kdeglobals" << EOF
[KDE]
widgetStyle=Breeze

[General]
ColorScheme=$([ "${THEME_STYLE}" = "dark" ] && echo "BreezeDark" || echo "BreezeLight")
Name=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze Dark" || echo "Breeze Light")

[Icons]
Theme=Papirus$([ "${THEME_STYLE}" = "dark" ] && echo "-Dark" || echo "")

[WM]
activeFont=Noto Sans,10,-1,5,50,0,0,0,0,0
EOF
    
    # Configure KWin settings
    cat > "${user_home}/.config/kdedefaults/kwinrc" << EOF
[org.kde.kdecoration2]
NoPlugin=false
library=org.kde.breeze
theme=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze Dark" || echo "Breeze Light")
EOF
    
    # Configure Konsole profile
    mkdir -p "${user_home}/.local/share/konsole"
    
    # Create Konsole profile
    cat > "${user_home}/.local/share/konsole/Studio.profile" << EOF
[Appearance]
ColorScheme=$([ "${THEME_STYLE}" = "dark" ] && echo "Breeze Dark" || echo "Breeze Light")
Font=Hack,10,-1,5,50,0,0,0,0,0

[General]
Name=Studio
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=32

[Keyboard]
KeyBindings=default

[Scrolling]
HistoryMode=2
ScrollBarPosition=2
ScrollFullPage=false
EOF
    
    # Create default Konsole settings
    mkdir -p "${user_home}/.config/konsolerc"
    cat > "${user_home}/.config/konsolerc" << EOF
[Desktop Entry]
DefaultProfile=Studio.profile

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
EOF
    
    # Set proper ownership for all user configuration files
    chown -R "${main_user}:${main_user}" "${user_home}/.config" "${user_home}/.local"
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_user_theme_configured"
    log_success "User-specific theme configured successfully"
    
    return 0
}

# ============================================================================
# Font Installation
# ============================================================================

# Install and configure fonts
function install_fonts() {
    log_section "Installing and Configuring Fonts"
    
    if check_state "${SCRIPT_NAME}_fonts_installed"; then
        log_info "Fonts already installed. Skipping..."
        return 0
    fi
    
    # Install fonts packages
    log_step "Installing font packages"
    local font_packages=(
        fonts-noto
        fonts-noto-cjk
        fonts-noto-mono
        fonts-hack
        fonts-firacode
        fonts-dejavu
        fonts-liberation
        fonts-liberation2
        fonts-freefont-ttf
    )
    
    if ! apt_install "${font_packages[@]}"; then
        log_warning "Failed to install some font packages"
        # Continue anyway as this is not critical
    fi
    
    # Configure font settings
    log_step "Configuring font settings"
    
    # Create system-wide font configuration
    mkdir -p /etc/fonts/conf.d
    
    # Create a fontconfig configuration for better font rendering
    cat > /etc/fonts/local.conf << EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="font">
        <edit name="antialias" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="autohint" mode="assign">
            <bool>false</bool>
        </edit>
        <edit name="hinting" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
        </edit>
        <edit name="rgba" mode="assign">
            <const>rgb</const>
        </edit>
        <edit name="lcdfilter" mode="assign">
            <const>lcddefault</const>
        </edit>
    </match>
    
    <!-- Set preferred serif, sans-serif, and monospace fonts -->
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif</family>
        </prefer>
    </alias>
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans</family>
        </prefer>
    </alias>
    <alias>
        <family>monospace</family>
        <prefer>
            <family>Hack</family>
            <family>Fira Code</family>
        </prefer>
    </alias>
</fontconfig>
EOF
    
    # Update fontconfig cache
    fc-cache -f
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_fonts_installed"
    log_success "Fonts installed and configured successfully"
    
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

function setup_theme() {
    log_section "Setting Up Themes and Appearance"
    
    # Exit if this script has already been completed successfully
    if check_state "${SCRIPT_NAME}_completed" && [[ "${FORCE_MODE}" != "true" ]]; then
        log_info "Themes and appearance have already been set up. Skipping..."
        return 0
    fi
    
    # Install theme packages
    if ! install_theme_packages; then
        log_error "Failed to install theme packages"
        return 1
    fi
    
    # Configure system-wide theme defaults
    if ! configure_system_theme; then
        log_warning "Failed to configure system-wide theme defaults"
        # Continue anyway as this is not critical
    fi
    
    # Configure user-specific theme settings
    if ! configure_user_theme; then
        log_warning "Failed to configure user-specific theme settings"
        # Continue anyway
    fi
    
    # Install and configure fonts
    if ! install_fonts; then
        log_warning "Failed to install and configure fonts"
        # Continue anyway
    fi
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Themes and appearance setup completed successfully"
    
    return 0
}

# ============================================================================
# Script Execution
# ============================================================================

# Initialize script
initialize

# Parse command line arguments
parse_args "$@"

# Check for root privileges
check_root

# Set the sudo password timeout to avoid frequent password prompts
set_sudo_timeout 3600

# Call the main function
setup_theme

# Return the exit code
exit $?