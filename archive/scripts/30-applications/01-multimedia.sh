#!/usr/bin/env bash
# ============================================================================
# 01-multimedia.sh
# ----------------------------------------------------------------------------
# Installs multimedia applications including:
# - Audio/Video players and editors
# - Image editing and processing tools
# - Graphics design tools
# ============================================================================

# Exit on error, but handle errors gracefully
set -o pipefail

# Determine script directory regardless of symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
LIB_DIR="${PARENT_DIR}/lib"

# Default values for variables that might be referenced but not assigned
: "${INTERACTIVE:=false}"
: "${FORCE_MODE:=false}"

# Source the common library functions
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
else
    echo "ERROR: common.sh library not found at ${LIB_DIR}"
    exit 1
fi

# Script name for state management and logging
SCRIPT_NAME="01-multimedia"

# ============================================================================
# Audio/Video Applications
# ============================================================================

# Install audio and video applications
function install_audio_video_tools() {
    log_step "Installing audio and video applications"
    
    if check_state "${SCRIPT_NAME}_audio_video_installed"; then
        log_info "Audio/Video applications already installed. Skipping..."
        return 0
    fi
    
    # Audio/Video Players and Editors
    local audio_video_packages=(
        vlc                # Media player
        audacity           # Audio editor
        ffmpeg             # Media converter
        pavucontrol        # PulseAudio volume control
        sox                # Sound processing tools
        libsox-fmt-mp3     # MP3 format for SOX
        rhythmbox          # Music player
        obs-studio         # Screen recording and streaming
    )
    
    log_info "Installing audio/video applications"
    if ! DEBIAN_FRONTEND=noninteractive apt_install "${audio_video_packages[@]}"; then
        log_error "Failed to install some audio/video applications"
        return 1
    fi
    
    # Always set VLC as default media player in non-interactive mode
    log_info "Setting VLC as default media player"
    if command -v xdg-mime &> /dev/null; then
        local media_types=(
            "video/mp4"
            "video/x-matroska"
            "video/mpeg"
            "video/ogg"
            "video/webm"
            "video/quicktime"
            "video/x-msvideo"
            "video/x-flv"
            "audio/mpeg"
            "audio/mp4"
            "audio/ogg"
            "audio/flac"
            "audio/x-wav"
        )
        
        for type in "${media_types[@]}"; do
            xdg-mime default vlc.desktop "${type}" || log_warning "Failed to set VLC as default for ${type}"
        done
        
        log_info "VLC set as default for common media types"
    else
        log_warning "xdg-mime not found, skipping default player configuration"
    fi
    
    set_state "${SCRIPT_NAME}_audio_video_installed"
    log_success "Audio/Video applications installed successfully"
    return 0
}

# ============================================================================
# Image Editing Applications
# ============================================================================

# Install image editing and processing tools
function install_image_editing_tools() {
    log_step "Installing image editing and processing tools"
    
    if check_state "${SCRIPT_NAME}_image_editing_installed"; then
        log_info "Image editing tools already installed. Skipping..."
        return 0
    fi
    
    # Image Editing and Processing Tools
    local image_editing_packages=(
        darktable          # Photography workflow application
        pinta              # Simple image editor (like Paint.NET)
        digikam            # Photo management
    )
    
    log_info "Installing image editing applications"
    if ! DEBIAN_FRONTEND=noninteractive apt_install "${image_editing_packages[@]}"; then
        log_error "Failed to install some image editing applications"
        # Continue anyway since some of these packages might be large or optional
    fi

    set_state "${SCRIPT_NAME}_image_editing_installed"
    log_success "Image editing tools installed successfully"
    return 0
}

# ============================================================================
# Additional Multimedia Tools
# ============================================================================

# Install additional multimedia tools (optional)
function install_additional_multimedia_tools() {
    log_step "Installing additional multimedia tools"
    
    if check_state "${SCRIPT_NAME}_additional_tools_installed"; then
        log_info "Additional multimedia tools already installed. Skipping..."
        return 0
    fi
    
    # Always install additional tools in non-interactive mode
    log_info "Installing additional multimedia tools in non-interactive mode"
    
    # Additional Multimedia Tools
    local additional_tools=(
        handbrake          # Video transcoder
        handbrake-cli      # Command line interface for HandBrake
        qwinff             # Media converter GUI
        kazam              # Screencasting program
        simplescreenrecorder # Screen recorder
        vokoscreen         # Screencast creator
    )
    
    log_info "Installing additional multimedia tools"
    if ! DEBIAN_FRONTEND=noninteractive apt_install "${additional_tools[@]}"; then
        log_warning "Failed to install some additional multimedia tools"
        # Continue anyway since these are optional
    fi
    
    # Try to install MakeMKV from third-party repository
    log_info "Checking if MakeMKV can be installed from repositories"
    if apt_cache_policy makemkv-bin | grep -q "Candidate:"; then
        log_info "Installing MakeMKV"
        if ! DEBIAN_FRONTEND=noninteractive apt_install makemkv-bin makemkv-oss; then
            log_warning "Failed to install MakeMKV"
        else
            log_success "MakeMKV installed successfully"
        fi
    else
        log_info "MakeMKV not found in repositories, skipping"
    fi
    
    set_state "${SCRIPT_NAME}_additional_tools_installed"
    log_success "Additional multimedia tools installed successfully"
    return 0
}

# ============================================================================
# System Codecs and Libraries
# ============================================================================

# Install multimedia codecs and libraries
function install_multimedia_codecs() {
    log_step "Installing multimedia codecs and libraries"
    
    if check_state "${SCRIPT_NAME}_codecs_installed"; then
        log_info "Multimedia codecs already installed. Skipping..."
        return 0
    fi
    
    # Multimedia Codecs and Libraries
    local codec_packages=(
        ubuntu-restricted-extras    # Restricted extras
        libavcodec-extra            # Extra Libav codecs
        libdvdread8                 # DVD reading library
        libdvdnav4                  # DVD navigation library
        libaacs0                    # AACS support library
        libbluray-bdj               # Blu-ray Disc Java support
        libvpx7                     # VP8/VP9 codec
        libx264-163                 # H.264 codec
        libx265-199                 # H.265 codec
    )
    
    log_info "Installing multimedia codecs"
    if ! DEBIAN_FRONTEND=noninteractive apt_install "${codec_packages[@]}"; then
        log_warning "Failed to install some multimedia codecs"
        # Continue anyway since package names might change
    fi
    
    # Install libdvd-pkg for DVD playback
    if apt_cache_policy libdvd-pkg | grep -q "Candidate:"; then
        log_info "Installing libdvd-pkg"
        if ! DEBIAN_FRONTEND=noninteractive apt_install libdvd-pkg; then
            log_warning "Failed to install libdvd-pkg"
        else
            log_info "Configuring libdvd-pkg"
            if ! echo "y" | DEBIAN_FRONTEND=noninteractive sudo dpkg-reconfigure libdvd-pkg; then
                log_warning "Failed to configure libdvd-pkg"
            fi
        fi
    fi
    
    set_state "${SCRIPT_NAME}_codecs_installed"
    log_success "Multimedia codecs installed successfully"
    return 0
}

# ============================================================================
# Main Function
# ============================================================================

# Main installation function
function install_multimedia_applications() {
    log_section "Installing Multimedia Applications"
    
    # Exit if this script has already been completed successfully and not in force mode
    if check_state "${SCRIPT_NAME}_completed" && ! is_force_mode; then
        log_info "Multimedia applications have already been installed. Skipping..."
        return 0
    fi
    
    # Update package repositories
    log_step "Updating package repositories"
    if ! apt_update; then
        log_error "Failed to update package repositories"
        return 1
    fi
    
    # Install multimedia codecs first (may be required by other applications)
    if ! install_multimedia_codecs; then
        log_warning "Failed to install some multimedia codecs"
        # Continue anyway as other applications might still work
    fi
    
    # Install audio/video tools
    if ! install_audio_video_tools; then
        log_error "Failed to install audio/video tools"
        return 1
    fi
    
    # Install image editing tools
    if ! install_image_editing_tools; then
        log_warning "Failed to install some image editing tools"
        # Continue anyway since audio/video might still be useful
    fi
    
    # Install additional multimedia tools
    install_additional_multimedia_tools
    
    # Final cleanup
    log_step "Cleaning up"
    apt_autoremove
    apt_clean
    
    # Mark as completed
    set_state "${SCRIPT_NAME}_completed"
    log_success "Multimedia applications installation completed successfully"
    
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
install_multimedia_applications

# Return the exit code
exit $?
