#!/usr/bin/env bash
# ============================================================================
# vscode-config.sh
# ----------------------------------------------------------------------------
# VS Code installation and theme integration for KDE Plasma
# This script installs VS Code and configures it to match the KDE theme
# ============================================================================

# Source common library if running standalone
if [[ -z "${LIB_DIR}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
    LIB_DIR="${PARENT_DIR}/lib"
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
fi

# Configuration variables (can be overridden by parent script)
: "${THEME_STYLE:=dark}"
: "${FONT_SCALING:=1.2}"
: "${SCRIPT_NAME:=vscode-config}"

# ============================================================================
# VS Code Installation and Integration
# ============================================================================

# Install and configure VS Code
function install_vscode() {
    log_section "Installing VS Code with Theme Integration"

    if check_state "${SCRIPT_NAME}_vscode_installed"; then
        log_info "VS Code already installed. Skipping..."
        return 0
    fi

    # Add VS Code repository
    log_step "Adding Microsoft VS Code repository"

    # Install dependencies
    apt_install software-properties-common apt-transport-https wget gpg

    # Import Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

    # Add the repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

    # Update package lists
    apt_update

    # Install VS Code
    log_step "Installing VS Code"
    if ! apt_install code; then
        log_error "Failed to install VS Code"
        return 1
    fi

    # Configure VS Code for the main user
    local main_user
    if [[ -n "${SUDO_USER}" ]]; then
        main_user="${SUDO_USER}"
    else
        # Try to find the first regular user account
        main_user=$(grep -E "^[^:]+:[^:]+:1000:" /etc/passwd | cut -d: -f1)
    fi

    if [[ -n "${main_user}" ]]; then
        local user_home="/home/${main_user}"

        log_step "Configuring VS Code for user: ${main_user}"

        # Ensure directory exists
        mkdir -p "${user_home}/.config/Code/User"

        # Install extensions as the user
        su - "${main_user}" -c "code --install-extension zhuangtongfa.material-theme" # One Dark Pro
        su - "${main_user}" -c "code --install-extension arcticicestudio.nord-visual-studio-code" # Nord
        su - "${main_user}" -c "code --install-extension pkief.material-icon-theme" # Material Icon Theme
        su - "${main_user}" -c "code --install-extension dracula-theme.theme-dracula" # Dracula
        su - "${main_user}" -c "code --install-extension akamud.vscode-theme-onedark" # Atom One Dark

        # Calculate scaled VS Code font size
        local base_vscode_size=11
        local scaled_vscode_size=$(awk "BEGIN {printf \"%.0f\", ${base_vscode_size} * ${FONT_SCALING}}")
        local zoom_level=$(awk "BEGIN {printf \"%.1f\", (${FONT_SCALING} - 1) * 5}")  # Convert scaling to zoom level

        # Create VS Code settings
        cat > "${user_home}/.config/Code/User/settings.json" << EOF
{
    "editor.fontFamily": "'JetBrains Mono', 'Fira Code', 'Droid Sans Mono', 'monospace'",
    "editor.fontSize": ${scaled_vscode_size},
    "editor.fontLigatures": true,
    "editor.renderWhitespace": "selection",
    "editor.lineHeight": 1.5,
    "editor.cursorBlinking": "smooth",
    "editor.cursorSmoothCaretAnimation": "on",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": true,
    "window.zoomLevel": ${zoom_level},
    "workbench.colorTheme": "One Dark Pro",
    "workbench.iconTheme": "material-icon-theme",
    "workbench.tree.indent": 20,
    "terminal.integrated.fontFamily": "JetBrains Mono",
    "terminal.integrated.fontSize": ${scaled_vscode_size},
    "breadcrumbs.enabled": true,
    "telemetry.telemetryLevel": "off"
}
EOF

        # Set correct ownership
        chown -R "${main_user}:${main_user}" "${user_home}/.config/Code"
    fi

    # Mark as completed
    set_state "${SCRIPT_NAME}_vscode_installed"
    log_success "VS Code installed and configured successfully"

    return 0
}

# Run the main function if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_vscode
fi
