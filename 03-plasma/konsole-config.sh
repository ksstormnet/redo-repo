#!/usr/bin/env bash
# Konsole terminal configuration script
# Part of the theme-setup.sh script
# This sets up Konsole with developer-friendly themes and settings

# Source common library if running standalone
if [[ -z "${LIB_DIR}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
    LIB_DIR="${PARENT_DIR}/lib"
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
fi

# Configuration settings (can be overridden)
: "${THEME_STYLE:=dark}"
: "${FONT_SCALING:=1.2}"

# Configure Konsole terminal with themes
function configure_konsole() {
    log_section "Configuring Konsole Terminal"

    # Calculate scaled terminal font size
    local base_term_size=10
    local scaled_term_size=$(awk "BEGIN {printf \"%.0f\", ${base_term_size} * ${FONT_SCALING} + 2}")

    log_step "Creating Konsole color schemes"

    # Detect main user account
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -z "${main_user}" ]]; then
        log_warning "Could not detect main user account. Skipping Konsole configuration."
        return 0
    fi

    local user_home="/home/${main_user}"

    # Create Konsole color schemes directory
    mkdir -p "${user_home}/.local/share/konsole/"

    # Create Sweet color scheme
    cat > "${user_home}/.local/share/konsole/Sweet.colorscheme" << 'EOFSWEET'
[Background]
Color=22,25,37

[BackgroundFaint]
Color=22,25,37

[BackgroundIntense]
Color=22,25,37

[Color0]
Color=0,0,0

[Color0Faint]
Color=46,52,57

[Color0Intense]
Color=104,104,104

[Color1]
Color=237,37,78

[Color1Faint]
Color=237,37,78

[Color1Intense]
Color=237,37,78

[Color2]
Color=113,247,159

[Color2Faint]
Color=113,247,159

[Color2Intense]
Color=113,247,159

[Color3]
Color=249,220,92

[Color3Faint]
Color=249,220,92

[Color3Intense]
Color=249,220,92

[Color4]
Color=123,112,255

[Color4Faint]
Color=123,112,255

[Color4Intense]
Color=123,112,255

[Color5]
Color=199,77,237

[Color5Faint]
Color=199,77,237

[Color5Intense]
Color=199,77,237

[Color6]
Color=0,193,228

[Color6Faint]
Color=0,193,228

[Color6Intense]
Color=0,193,228

[Color7]
Color=220,223,228

[Color7Faint]
Color=220,223,228

[Color7Intense]
Color=220,223,228

[Foreground]
Color=255,255,255

[ForegroundFaint]
Color=210,210,210

[ForegroundIntense]
Color=235,235,235

[General]
Blur=true
Description=Sweet
Opacity=0.9
Wallpaper=
EOFSWEET

    # Create Nord color scheme
    cat > "${user_home}/.local/share/konsole/Nord.colorscheme" << 'EOFNORD'
[Background]
Color=46,52,64

[BackgroundFaint]
Color=46,52,64

[BackgroundIntense]
Color=46,52,64

[Color0]
Color=59,66,82

[Color0Faint]
Color=59,66,82

[Color0Intense]
Color=76,86,106

[Color1]
Color=191,97,106

[Color1Faint]
Color=191,97,106

[Color1Intense]
Color=191,97,106

[Color2]
Color=163,190,140

[Color2Faint]
Color=163,190,140

[Color2Intense]
Color=163,190,140

[Color3]
Color=235,203,139

[Color3Faint]
Color=235,203,139

[Color3Intense]
Color=235,203,139

[Color4]
Color=129,161,193

[Color4Faint]
Color=129,161,193

[Color4Intense]
Color=129,161,193

[Color5]
Color=180,142,173

[Color5Faint]
Color=180,142,173

[Color5Intense]
Color=180,142,173

[Color6]
Color=136,192,208

[Color6Faint]
Color=136,192,208

[Color6Intense]
Color=143,188,187

[Color7]
Color=229,233,240

[Color7Faint]
Color=229,233,240

[Color7Intense]
Color=236,239,244

[Foreground]
Color=216,222,233

[ForegroundFaint]
Color=216,222,233

[ForegroundIntense]
Color=216,222,233

[General]
Blur=true
Description=Nord
Opacity=0.9
Wallpaper=
EOFNORD

    # Create Aritim Dark color scheme
    cat > "${user_home}/.local/share/konsole/AritimDark.colorscheme" << 'EOFARITIM'
[Background]
Color=16,21,26

[BackgroundFaint]
Color=16,21,26

[BackgroundIntense]
Color=16,21,26

[Color0]
Color=43,43,43

[Color0Faint]
Color=43,43,43

[Color0Intense]
Color=43,43,43

[Color1]
Color=240,113,120

[Color1Faint]
Color=240,113,120

[Color1Intense]
Color=240,113,120

[Color2]
Color=195,232,141

[Color2Faint]
Color=195,232,141

[Color2Intense]
Color=195,232,141

[Color3]
Color=255,203,107

[Color3Faint]
Color=255,203,107

[Color3Intense]
Color=255,203,107

[Color4]
Color=130,170,255

[Color4Faint]
Color=130,170,255

[Color4Intense]
Color=130,170,255

[Color5]
Color=199,146,234

[Color5Faint]
Color=199,146,234

[Color5Intense]
Color=199,146,234

[Color6]
Color=137,221,255

[Color6Faint]
Color=137,221,255

[Color6Intense]
Color=137,221,255

[Color7]
Color=220,223,228

[Color7Faint]
Color=220,223,228

[Color7Intense]
Color=220,223,228

[Foreground]
Color=220,223,228

[ForegroundFaint]
Color=220,223,228

[ForegroundIntense]
Color=220,223,228

[General]
Blur=true
Description=Aritim Dark
Opacity=0.9
Wallpaper=
EOFARITIM

    # Create Arc color scheme
    cat > "${user_home}/.local/share/konsole/Arc.colorscheme" << 'EOFARC'
[Background]
Color=56,60,74

[BackgroundFaint]
Color=56,60,74

[BackgroundIntense]
Color=56,60,74

[Color0]
Color=75,81,98

[Color0Faint]
Color=75,81,98

[Color0Intense]
Color=99,104,122

[Color1]
Color=225,66,69

[Color1Faint]
Color=225,66,69

[Color1Intense]
Color=225,66,69

[Color2]
Color=92,167,91

[Color2Faint]
Color=92,167,91

[Color2Intense]
Color=92,167,91

[Color3]
Color=246,171,50

[Color3Faint]
Color=246,171,50

[Color3Intense]
Color=246,171,50

[Color4]
Color=72,119,177

[Color4Faint]
Color=72,119,177

[Color4Intense]
Color=72,119,177

[Color5]
Color=166,96,195

[Color5Faint]
Color=166,96,195

[Color5Intense]
Color=166,96,195

[Color6]
Color=82,148,226

[Color6Faint]
Color=82,148,226

[Color6Intense]
Color=82,148,226

[Color7]
Color=211,218,227

[Color7Faint]
Color=211,218,227

[Color7Intense]
Color=211,218,227

[Foreground]
Color=211,218,227

[ForegroundFaint]
Color=211,218,227

[ForegroundIntense]
Color=211,218,227

[General]
Blur=true
Description=Arc Dark
Opacity=0.9
Wallpaper=
EOFARC

    # Create Layan color scheme
    cat > "${user_home}/.local/share/konsole/Layan.colorscheme" << 'EOFLAYAN'
[Background]
Color=34,45,50

[BackgroundFaint]
Color=34,45,50

[BackgroundIntense]
Color=34,45,50

[Color0]
Color=33,33,33

[Color0Faint]
Color=33,33,33

[Color0Intense]
Color=97,97,97

[Color1]
Color=255,69,58

[Color1Faint]
Color=255,69,58

[Color1Intense]
Color=255,69,58

[Color2]
Color=120,205,65

[Color2Faint]
Color=120,205,65

[Color2Intense]
Color=120,205,65

[Color3]
Color=255,214,10

[Color3Faint]
Color=255,214,10

[Color3Intense]
Color=255,214,10

[Color4]
Color=45,144,255

[Color4Faint]
Color=45,144,255

[Color4Intense]
Color=45,144,255

[Color5]
Color=255,47,146

[Color5Faint]
Color=255,47,146

[Color5Intense]
Color=255,47,146

[Color6]
Color=90,216,210

[Color6Faint]
Color=90,216,210

[Color6Intense]
Color=90,216,210

[Color7]
Color=255,255,255

[Color7Faint]
Color=255,255,255

[Color7Intense]
Color=255,255,255

[Foreground]
Color=238,238,238

[ForegroundFaint]
Color=238,238,238

[ForegroundIntense]
Color=238,238,238

[General]
Blur=true
Description=Layan
Opacity=0.9
Wallpaper=
EOFLAYAN

    # Create Adapta color scheme
    cat > "${user_home}/.local/share/konsole/Adapta.colorscheme" << 'EOFADAPTA'
[Background]
Color=38,50,56

[BackgroundFaint]
Color=38,50,56

[BackgroundIntense]
Color=38,50,56

[Color0]
Color=38,50,56

[Color0Faint]
Color=38,50,56

[Color0Intense]
Color=55,71,79

[Color1]
Color=229,57,53

[Color1Faint]
Color=229,57,53

[Color1Intense]
Color=229,57,53

[Color2]
Color=129,199,132

[Color2Faint]
Color=129,199,132

[Color2Intense]
Color=129,199,132

[Color3]
Color=255,193,7

[Color3Faint]
Color=255,193,7

[Color3Intense]
Color=255,193,7

[Color4]
Color=100,181,246

[Color4Faint]
Color=100,181,246

[Color4Intense]
Color=100,181,246

[Color5]
Color=171,71,188

[Color5Faint]
Color=171,71,188

[Color5Intense]
Color=171,71,188

[Color6]
Color=0,188,212

[Color6Faint]
Color=0,188,212

[Color6Intense]
Color=0,188,212

[Color7]
Color=207,216,220

[Color7Faint]
Color=207,216,220

[Color7Intense]
Color=207,216,220

[Foreground]
Color=207,216,220

[ForegroundFaint]
Color=207,216,220

[ForegroundIntense]
Color=207,216,220

[General]
Blur=true
Description=Adapta Nokto
Opacity=0.9
Wallpaper=
EOFADAPTA

    # Create Materia color scheme
    cat > "${user_home}/.local/share/konsole/Materia.colorscheme" << 'EOFMATERIA'
[Background]
Color=40,45,52

[BackgroundFaint]
Color=40,45,52

[BackgroundIntense]
Color=40,45,52

[Color0]
Color=40,45,52

[Color0Faint]
Color=40,45,52

[Color0Intense]
Color=55,59,65

[Color1]
Color=233,86,86

[Color1Faint]
Color=233,86,86

[Color1Intense]
Color=233,86,86

[Color2]
Color=142,196,73

[Color2Faint]
Color=142,196,73

[Color2Intense]
Color=142,196,73

[Color3]
Color=247,154,24

[Color3Faint]
Color=247,154,24

[Color3Intense]
Color=247,154,24

[Color4]
Color=43,145,175

[Color4Faint]
Color=43,145,175

[Color4Intense]
Color=43,145,175

[Color5]
Color=192,97,203

[Color5Faint]
Color=192,97,203

[Color5Intense]
Color=192,97,203

[Color6]
Color=43,177,175

[Color6Faint]
Color=43,177,175

[Color6Intense]
Color=43,177,175

[Color7]
Color=210,210,210

[Color7Faint]
Color=210,210,210

[Color7Intense]
Color=210,210,210

[Foreground]
Color=238,238,238

[ForegroundFaint]
Color=238,238,238

[ForegroundIntense]
Color=238,238,238

[General]
Blur=true
Description=Materia
Opacity=0.9
Wallpaper=
EOFMATERIA

    # Create or update default Konsole profile
    log_step "Creating custom Konsole profile"

    cat > "${user_home}/.local/share/konsole/DeveloperProfile.profile" << EOF
[Appearance]
ColorScheme=$([ "${THEME_STYLE}" = "dark" ] && echo "AritimDark" || echo "Breeze")
Font=JetBrains Mono,${scaled_term_size},-1,5,50,0,0,0,0,0
LineSpacing=4
UseFontLineChararacters=true

[Cursor Options]
CursorShape=1
CustomCursorColor=136,192,208
UseCustomCursorColor=true

[General]
Command=/bin/bash
Name=DeveloperProfile
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=36

[Interaction Options]
AutoCopySelectedText=true
TrimLeadingSpacesInSelectedText=true
TrimTrailingSpacesInSelectedText=true

[Scrolling]
HistoryMode=2
HistorySize=10000
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
UrlHintsModifiers=100663296
EOF

    # Set as default profile
    mkdir -p "${user_home}/.config/"
    cat > "${user_home}/.config/konsolerc" << EOF
[Desktop Entry]
DefaultProfile=DeveloperProfile.profile

[KonsoleWindow]
ShowMenuBarByDefault=false
ShowWindowTitleOnTitleBar=true

[MainWindow]
MenuBar=Disabled
State=AAAA/wAAAAD9AAAAAQAAAAAAAAAAAAAAAPwCAAAAAvsAAAAiAFEAdQBpAGMAawBDAG8AbQBtAGEAbgBkAHMARABvAGMAawAAAAAA/////wAAAK0A////+wAAABwAUwBTAEgATQBhAG4AYQBnAGUAcgBEAG8AYwBrAAAAAAD/////AAAAWQD///8AAASwAAADLwAAAAQAAAAEAAAACAAAAAj8AAAAAQAAAAIAAAABAAAAFgBtAGEAaQBuAFQAbwBvAGwAQgBhAHIBAAAAAP////8AAAAAAAAAAA==
StatusBar=Disabled
ToolBarsMovable=Disabled

[TabBar]
CloseTabOnMiddleMouseButton=true
NewTabButton=true
TabBarPosition=Top
TabBarVisibility=ShowTabBarWhenNeeded
EOF

    # Set proper permissions
    chown -R "${main_user}:${main_user}" "${user_home}/.local/share/konsole"
    chown -R "${main_user}:${main_user}" "${user_home}/.config/konsolerc"

    log_success "Konsole configuration completed successfully"
    return 0
}

# Run the main function if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_konsole
fi
