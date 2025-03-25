#!/usr/bin/env bash
# ============================================================================
# 03-theme-setup.sh
# ----------------------------------------------------------------------------
# Installs and configures themes, icons, and appearance settings for KDE Plasma
# Sets up global theme defaults and user-specific customizations
# Includes developer themes, VS Code integration, and system monitoring
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

# Source component scripts
if [[ -f "${SCRIPT_DIR}/konsole-config.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/konsole-config.sh"
else
    log_warning "konsole-config.sh not found, terminal customization will be skipped"
fi

if [[ -f "${SCRIPT_DIR}/thermal-monitor.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/thermal-monitor.sh"
else
    log_warning "thermal-monitor.sh not found, temperature monitoring will be skipped"
fi

if [[ -f "${SCRIPT_DIR}/latte-dock.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/latte-dock.sh"
else
    log_warning "latte-dock.sh not found, dock customization will be skipped"
fi

if [[ -f "${SCRIPT_DIR}/vscode-config.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/vscode-config.sh"
else
    log_warning "vscode-config.sh not found, VS Code customization will be skipped"
fi

# Script name for state management and logging
SCRIPT_NAME="03-theme-setup"

# Theme configuration
THEME_STYLE="dark"  # Options: light, dark, system (uses system preference)
PREFER_GTK_APPS=false  # Set to true to use GTK file dialogs for Qt/KDE apps
FONT_SCALING=1.2  # 1.2x font scaling for better readability
INSTALL_VS_CODE=true  # Install Visual Studio Code with matching themes
INSTALL_LATTE_DOCK=true  # Install Latte Dock (Crystal theme)
INSTALL_THERMAL_MONITOR=true  # Install CPU/GPU temperature monitoring

# Default for interactive mode and force mode
: "${INTERACTIVE:=true}"  # Default to interactive mode
: "${FORCE_MODE:=false}"  # Default to not forcing reinstallation

# State directory for tracking progress
: "${STATE_DIR:=/var/lib/system-setup/state}"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

# ============================================================================
# Command Line Argument Processing
# ============================================================================

# Display help information
function show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure themes and appearance for KDE Plasma"
    echo
    echo "Options:"
    echo "  --light             Use light theme (default is dark)"
    echo "  --dark              Use dark theme"
    echo "  --system            Use system preference for theme"
    echo "  --gtk-dialogs       Use GTK file dialogs for Qt/KDE apps"
    echo "  --font-scale SCALE  Set font scaling factor (default: 1.2)"
    echo "  --no-vscode         Skip VS Code installation and configuration"
    echo "  --no-latte-dock     Skip Latte Dock installation"
    echo "  --no-thermal        Skip thermal monitor installation"
    echo "  --help              Display this help message and exit"
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
            --font-scale)
                if [[ -n "$2" && "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    FONT_SCALING="$2"
                    shift 2
                else
                    log_error "Font scaling requires a numeric value"
                    show_help
                    exit 1
                fi
                ;;
            --no-vscode)
                INSTALL_VS_CODE=false
                shift
                ;;
            --no-latte-dock)
                INSTALL_LATTE_DOCK=false
                shift
                ;;
            --no-thermal)
                INSTALL_THERMAL_MONITOR=false
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
    log_info "Font scaling: ${FONT_SCALING}x"
    if [[ "${PREFER_GTK_APPS}" == "true" ]]; then
        log_info "Will use GTK file dialogs for Qt/KDE apps"
    fi
    if [[ "${INSTALL_VS_CODE}" == "true" ]]; then
        log_info "Will install and configure VS Code"
    fi
    if [[ "${INSTALL_LATTE_DOCK}" == "true" ]]; then
        log_info "Will install and configure Latte Dock (Crystal theme)"
    fi
    if [[ "${INSTALL_THERMAL_MONITOR}" == "true" ]]; then
        log_info "Will install CPU/GPU temperature monitoring"
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
        arc-theme
        arc-kde
        adapta-kde
    )

    if ! apt_install "${additional_themes[@]}"; then
        log_warning "Failed to install some additional theme packages"
        # Continue anyway as these are not critical
    fi

    # Install git for cloning theme repositories
    apt_install git

    # Mark as completed
    set_state "${SCRIPT_NAME}_theme_packages_installed"
    log_success "Theme packages installed successfully"

    return 0
}

# ============================================================================
# Developer-focused Theme Installation
# ============================================================================

# Install developer-focused themes from git repositories
function install_developer_themes() {
    log_section "Installing Developer-Focused Themes"

    if check_state "${SCRIPT_NAME}_developer_themes_installed"; then
        log_info "Developer themes already installed. Skipping..."
        return 0
    fi

    # Ensure git is installed
    if ! command -v git &> /dev/null; then
        log_step "Installing git"
        apt_install git
    fi

    # Create temp directory for cloning
    mkdir -p /tmp/kde-themes
    cd /tmp/kde-themes || return 1

    # Install Sweet theme
    log_step "Installing Sweet KDE theme"
    if [[ ! -d ~/.local/share/plasma/desktoptheme/Sweet ]]; then
        git clone https://github.com/EliverLara/Sweet.git
        # Create directories if they don't exist
        mkdir -p ~/.local/share/plasma/desktoptheme/
        mkdir -p ~/.local/share/aurorae/themes/
        mkdir -p ~/.local/share/color-schemes/
        mkdir -p ~/.local/share/kvantum/

        cp -r Sweet/kde/. ~/.local/share/plasma/desktoptheme/Sweet
        cp -r Sweet/aurorae/. ~/.local/share/aurorae/themes/
        cp -r Sweet/color-schemes/. ~/.local/share/color-schemes/
        cp -r Sweet/Kvantum/. ~/.local/share/kvantum/
    fi

    # Install Nordic theme
    log_step "Installing Nordic theme"
    if [[ ! -d ~/.local/share/plasma/look-and-feel/Nordic ]]; then
        git clone https://github.com/EliverLara/Nordic
        mkdir -p ~/.local/share/plasma/look-and-feel/Nordic
        cp -r Nordic/kde/. ~/.local/share/plasma/look-and-feel/Nordic
    fi

    # Install Layan theme
    log_step "Installing Layan theme"
    if [[ ! -d ~/.local/share/plasma/look-and-feel/com.github.vinceliuice.Layan ]]; then
        git clone https://github.com/vinceliuice/Layan-kde
        (
            cd Layan-kde || return 1
            ./install.sh
        )
    fi

    # Install Aritim-Dark theme
    log_step "Installing Aritim-Dark theme"
    if [[ ! -d ~/.local/share/plasma/look-and-feel/com.github.mrcuve0.Aritim-Dark ]]; then
        git clone https://github.com/Mrcuve0/Aritim-Dark.git
        (
            cd Aritim-Dark || return 1
            ./install_local.sh
        )
    fi

    # Install Tela icon theme
    log_step "Installing Tela icon theme"
    if [[ ! -d ~/.local/share/icons/Tela ]]; then
        git clone https://github.com/vinceliuice/Tela-icon-theme
        (
            cd Tela-icon-theme || return 1
            ./install.sh -a
        )
    fi

    # Set proper ownership for the current user
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -n "${main_user}" ]]; then
        log_step "Setting correct ownership for user: ${main_user}"
        chown -R "${main_user}:${main_user}" /home/"${main_user}"/.local/share/plasma
        chown -R "${main_user}:${main_user}" /home/"${main_user}"/.local/share/aurorae
        chown -R "${main_user}:${main_user}" /home/"${main_user}"/.local/share/color-schemes
        chown -R "${main_user}:${main_user}" /home/"${main_user}"/.local/share/kvantum
        chown -R "${main_user}:${main_user}" /home/"${main_user}"/.local/share/icons
    fi

    # Clean up
    cd /
    rm -rf /tmp/kde-themes

    # Mark as completed
    set_state "${SCRIPT_NAME}_developer_themes_installed"
    log_success "Developer themes installed successfully"

    return 0
}

# ============================================================================
# Font Installation and Configuration
# ============================================================================

# Install and configure fonts with scaling
function install_fonts() {
    log_section "Installing and Configuring Fonts"

    if check_state "${SCRIPT_NAME}_fonts_installed"; then
        log_info "Fonts already installed. Skipping..."
        return 0
    fi

    # Install fonts packages
    log_step "Installing developer-friendly font packages"
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
        fonts-jetbrains-mono
    )

    if ! apt_install "${font_packages[@]}"; then
        log_warning "Failed to install some font packages"
        # Continue anyway as this is not critical
    fi

    # Calculate scaled font sizes based on FONT_SCALING
    local base_font_size=10
    local base_small_size=8
    local scaled_font_size
    local scaled_small_size
    local scaled_fixed_size
    scaled_font_size=$(awk "BEGIN {printf \"%.0f\", ${base_font_size} * ${FONT_SCALING}}")
    scaled_small_size=$(awk "BEGIN {printf \"%.0f\", ${base_small_size} * ${FONT_SCALING}}")
    scaled_fixed_size=$(awk "BEGIN {printf \"%.0f\", ${base_font_size} * ${FONT_SCALING} + 2}")

    log_info "Scaling fonts: regular ${scaled_font_size}pt, small ${scaled_small_size}pt, monospace ${scaled_fixed_size}pt"

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
            <family>JetBrains Mono</family>
            <family>Hack</family>
            <family>Fira Code</family>
        </prefer>
    </alias>
</fontconfig>
EOF

    # Determine color scheme based on theme style
    local is_dark_theme
    [[ "${THEME_STYLE}" = "dark" ]] && is_dark_theme=true || is_dark_theme=false

    # Prepare theme variables
    local kde_color_scheme
    local kde_theme_name
    local icon_theme_suffix
    local look_and_feel_package

    if [[ "${is_dark_theme}" = true ]]; then
        kde_color_scheme="BreezeDark"
        kde_theme_name="Breeze Dark"
        icon_theme_suffix="-Dark"
        look_and_feel_package="org.kde.breezedark.desktop"
    else
        kde_color_scheme="BreezeLight"
        kde_theme_name="Breeze Light"
        icon_theme_suffix=""
        look_and_feel_package="org.kde.breeze.desktop"
    fi

    # Update system-wide KDE font configuration
    cat > /etc/xdg/kdeglobals << EOF
[General]
ColorScheme=${kde_color_scheme}
Name=${kde_theme_name}
shadeSortColumn=true
font=Noto Sans,${scaled_font_size},-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,${scaled_fixed_size},-1,5,50,0,0,0,0,0
smallestReadableFont=Noto Sans,${scaled_small_size},-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,${scaled_font_size},-1,5,50,0,0,0,0,0
menuFont=Noto Sans,${scaled_font_size},-1,5,50,0,0,0,0,0

[Icons]
Theme=Papirus${icon_theme_suffix}

[KDE]
LookAndFeelPackage=${look_and_feel_package}
SingleClick=false
AnimationDurationFactor=0.5
ShowDeleteCommand=true
contrast=4

[WM]
activeFont=Noto Sans,${scaled_font_size},-1,5,50,0,0,0,0,0
EOF

    # Configure DPI scaling
    local scaled_dpi
    scaled_dpi=$(awk "BEGIN {printf \"%.0f\", 96 * ${FONT_SCALING}}")

    # Setup user-specific font configuration
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -n "${main_user}" ]]; then
        local user_home="/home/${main_user}"

        # Create user font config directory
        mkdir -p "${user_home}/.config/fontconfig"

        # Set DPI in KDE configuration
        mkdir -p "${user_home}/.config/kcmfonts"
        cat > "${user_home}/.config/kcmfonts" << EOF
[General]
forceFontDPI=${scaled_dpi}
EOF

        # Set correct ownership
        chown -R "${main_user}:${main_user}" "${user_home}/.config/fontconfig" "${user_home}/.config/kcmfonts"
    fi

    # Update fontconfig cache
    fc-cache -f

    # Mark as completed
    set_state "${SCRIPT_NAME}_fonts_installed"
    log_success "Fonts installed and configured with ${FONT_SCALING}x scaling"

    return 0
}

# ============================================================================
# Theme Switching Utility
# ============================================================================

# Create a unified theme switching utility
function create_theme_switcher() {
    log_section "Creating Theme Switching Utility"

    if check_state "${SCRIPT_NAME}_theme_switcher_created"; then
        log_info "Theme switcher already created. Skipping..."
        return 0
    fi

    # Detect main user
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Skipping theme switcher creation."
        return 0
    fi

    local user_home="/home/${main_user}"

    # Create bin directory if it doesn't exist
    mkdir -p "${user_home}/bin"

    # Create the theme-switch.sh script
    log_step "Creating theme switcher script"

    cat > "${user_home}/bin/theme-switch.sh" << 'EOF'
#!/bin/bash
# KDE Theme Switcher
# This script switches between different themes and applies the changes to:
# - KDE Plasma
# - VS Code
# - Konsole
# - Latte Dock

# Default to aritim if no theme is specified
THEME="${1:-aritim}"

# Valid themes
VALID_THEMES="sweet nordic layan aritim arc materia adapta"

# Check if the theme is valid
if ! echo "$VALID_THEMES" | grep -q -w "$THEME"; then
    echo "Error: '$THEME' is not a valid theme."
    echo "Valid themes: $VALID_THEMES"
    exit 1
fi

echo "Switching to $THEME theme..."

# 1. Apply KDE Plasma theme
case "$THEME" in
    sweet)
        lookandfeeltool -a com.github.eliverlara.sweet
        ;;
    nordic)
        lookandfeeltool -a Nordic
        ;;
    layan)
        lookandfeeltool -a com.github.vinceliuice.Layan
        ;;
    aritim)
        lookandfeeltool -a com.github.mrcuve0.Aritim-Dark
        ;;
    arc)
        lookandfeeltool -a com.github.PapirusDevelopmentTeam.arc-dark
        ;;
    materia)
        lookandfeeltool -a com.github.PapirusDevelopmentTeam.materia-dark
        ;;
    adapta)
        lookandfeeltool -a com.github.PapirusDevelopmentTeam.adapta
        ;;
esac

# Apply appropriate Kvantum theme
case "$THEME" in
    sweet)
        kvantummanager --set Sweet
        ;;
    nordic)
        kvantummanager --set Nordic
        ;;
    layan)
        kvantummanager --set Layan
        ;;
    arc)
        kvantummanager --set KvArcDark
        ;;
    aritim)
        kvantummanager --set KvAritimDark
        ;;
    materia)
        kvantummanager --set MateriaDark
        ;;
    adapta)
        kvantummanager --set KvAdaptaDark
        ;;
esac

# 2. Update VS Code theme
if [[ -f ~/.config/Code/User/settings.json ]]; then
    VSCODE_THEME=$(case "$THEME" in
        sweet) echo "Palenight (Material)";;
        nordic) echo "Nord";;
        arc) echo "Atom One Dark";;
        layan) echo "One Dark Pro Darker";;
        aritim) echo "One Dark Pro";;
        materia) echo "Material Theme Darker";;
        adapta) echo "Atom One Dark";;
        *) echo "One Dark Pro";;
    esac)

    sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$VSCODE_THEME\"/" ~/.config/Code/User/settings.json
    echo "VS Code theme updated to $VSCODE_THEME"
fi

# 3. Update Konsole theme
if [[ -d ~/.local/share/konsole ]]; then
    KONSOLE_THEME=$(case "$THEME" in
        sweet) echo "Sweet";;
        nordic) echo "Nord";;
        arc) echo "Arc";;
        layan) echo "Layan";;
        aritim) echo "AritimDark";;
        materia) echo "Materia";;
        adapta) echo "Adapta";;
        *) echo "AritimDark";;
    esac)

    # Update default profile
    for profile in ~/.local/share/konsole/*.profile; do
        if grep -q "ColorScheme=" "$profile"; then
            sed -i "s/ColorScheme=.*/ColorScheme=${KONSOLE_THEME}/" "$profile"
        fi
    done

    # If Konsole is running, try to update the current session
    if pgrep -x "konsole" > /dev/null; then
        for i in $(qdbus | grep -i konsole); do
            for session in $(qdbus $i | grep /Sessions/ | head -1); do
                qdbus $i $session setProfile "Main"
            done
        done
    fi

    echo "Konsole theme updated to $KONSOLE_THEME"
fi

# 4. Update Latte Dock
if command -v latte-dock > /dev/null && [[ -f ~/.config/latte/Crystal.layout.latte ]]; then
    # Apply transparency based on theme
    TRANSPARENCY=$(case "$THEME" in
        sweet) echo "60";;
        nordic) echo "55";;
        layan) echo "60";;
        aritim) echo "65";;
        arc) echo "50";;
        materia) echo "55";;
        adapta) echo "50";;
        *) echo "60";;
    esac)

    sed -i "s/panelTransparency=.*/panelTransparency=${TRANSPARENCY}/" ~/.config/latte/Crystal.layout.latte

    # Restart Latte Dock if it's running
    if pgrep -x "latte-dock" > /dev/null; then
        # We don't want to interrupt the user's workflow, so just inform them
        echo "Latte Dock configuration updated. You may need to restart Latte Dock to apply the changes:"
        echo "  latte-dock --layout Crystal --replace"
    fi
fi

echo "Theme switch complete! Some applications may need to be restarted to apply the theme."
EOF

    # Make script executable
    chmod +x "${user_home}/bin/theme-switch.sh"

    # Ensure bin directory is in the user's PATH
    if ! grep -q "PATH=\"\$HOME/bin:\$PATH\"" "${user_home}/.bashrc"; then
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "${user_home}/.bashrc"
    fi

    # Set correct ownership
    chown -R "${main_user}:${main_user}" "${user_home}/bin"

    # Create a desktop file for the theme switcher
    mkdir -p "${user_home}/.local/share/applications"

    cat > "${user_home}/.local/share/applications/theme-switcher.desktop" << EOF
[Desktop Entry]
Name=Theme Switcher
Comment=Switch between different KDE themes
Exec=${user_home}/bin/theme-switch.sh %f
Icon=preferences-desktop-theme
Terminal=true
Type=Application
Categories=Settings;DesktopSettings;
Keywords=Theme;Switch;KDE;
EOF

    chown "${main_user}:${main_user}" "${user_home}/.local/share/applications/theme-switcher.desktop"

    # Mark as completed
    set_state "${SCRIPT_NAME}_theme_switcher_created"
    log_success "Theme switcher created successfully"
    log_info "Theme switcher script created at: ${user_home}/bin/theme-switch.sh"
    log_info "Run it with: theme-switch.sh [sweet|nordic|layan|aritim|arc|materia|adapta]"

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

    # Configure fonts
    if ! install_fonts; then
        log_warning "Failed to configure fonts"
        # Continue anyway
    fi

    # Install and configure developer themes
    if ! install_developer_themes; then
        log_warning "Failed to install developer themes"
        # Continue anyway
    fi

    # Install and configure Konsole terminal if available
    if type configure_konsole &>/dev/null; then
        if ! configure_konsole; then
            log_warning "Failed to configure Konsole terminal"
            # Continue anyway
        fi
    else
        log_info "Skipping Konsole terminal customization (function not found)"
    fi

    # Install and configure Latte Dock if requested
    if [[ "${INSTALL_LATTE_DOCK}" == "true" ]] && type install_latte_dock &>/dev/null; then
        if ! install_latte_dock; then
            log_warning "Failed to install and configure Latte Dock"
            # Continue anyway
        fi
    else
        log_info "Skipping Latte Dock installation as requested or function not found"
    fi

    # Install and configure VS Code if requested
    if [[ "${INSTALL_VS_CODE}" == "true" ]] && type install_vscode &>/dev/null; then
        if ! install_vscode; then
            log_warning "Failed to install and configure VS Code"
            # Continue anyway
        fi
    else
        log_info "Skipping VS Code installation as requested or function not found"
    fi

    # Install and configure temperature monitoring if requested
    if [[ "${INSTALL_THERMAL_MONITOR}" == "true" ]] && type install_thermal_monitor &>/dev/null; then
        if ! install_thermal_monitor; then
            log_warning "Failed to install and configure thermal monitoring"
            # Continue anyway
        fi
    else
        log_info "Skipping thermal monitoring installation as requested or function not found"
    fi

    # Create theme switcher utility
    if ! create_theme_switcher; then
        log_warning "Failed to create theme switcher"
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
