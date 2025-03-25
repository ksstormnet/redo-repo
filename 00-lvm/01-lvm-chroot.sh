#!/bin/bash
# shellcheck disable=SC1091,SC2154,SC2310,SC2311,SC2312

# lvm-chroot.sh
# Version: 1.0
# Date: March 25, 2025
#
# This script automates the chroot setup process and configures mount points
# for the LVM volumes in the chroot environment.

# Exit on any error
set -e
shopt -s inherit_errexit

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
section() {
    echo
    echo -e "${BOLD}========================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BOLD}========================================================${NC}"
    echo
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Create a cleanup function for error handling
cleanup() {
    echo "Cleaning up mounts..."
    umount -l "/mnt/dev/pts" 2>/dev/null || true
    umount -l "/mnt/dev" 2>/dev/null || true
    umount -l "/mnt/proc" 2>/dev/null || true
    umount -l "/mnt/sys" 2>/dev/null || true
    umount -l "/mnt/run" 2>/dev/null || true
    umount -l "/mnt/boot/efi" 2>/dev/null || true
    if [[ -n "${USB_DEVICE}" ]]; then
        umount -l "/mnt/media/usb" 2>/dev/null || true
    fi
    umount -l "/mnt" 2>/dev/null || true
}

# Set up trap to call cleanup function on exit
trap cleanup EXIT

confirm() {
    local prompt="$1"
    local default="$2"

    if [[ "${default}" = "Y" ]]; then
        local options="[Y/n]"
        local default_value="Y"
    else
        local options="[y/N]"
        local default_value="N"
    fi

    read -p "${prompt} ${options}: " -r REPLY
    REPLY=${REPLY:-${default_value}}

    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if script is run as root
if [[ "${EUID}" -ne 0 ]]; then
    error "Please run this script as root (use sudo)."
fi

# Display welcome message
section "LVM Chroot Configuration"
echo "This script does two things:"
echo "1. Sets up a chroot environment for the newly installed system"
echo "2. Configures mount points and fstab for LVM volumes in the chroot"
echo
echo "This should be run after completing the Ubuntu Server installation"
echo "but before the first boot of the installed system."
echo

# Ask for the root partition
read -r -p "Enter the root partition device (e.g., /dev/sda2): " ROOT_DEVICE
if [[ -z "${ROOT_DEVICE}" ]]; then
    error "Root partition device cannot be empty."
fi

# Ask for the EFI partition
read -r -p "Enter the EFI partition device (e.g., /dev/sda1): " EFI_DEVICE
if [[ -z "${EFI_DEVICE}" ]]; then
    error "EFI partition device cannot be empty."
fi

# Ask for the USB drive partition
read -r -p "Enter the USB drive device containing scripts (e.g., /dev/sdd1): " USB_DEVICE
if [[ -z "${USB_DEVICE}" ]]; then
    warning "USB drive device not specified. USB drive won't be mounted in chroot."
    USB_DEVICE=""
else
    if [[ ! -b "${USB_DEVICE}" ]]; then
        warning "Device ${USB_DEVICE} does not exist or is not a block device."
        if ! confirm "Continue anyway?" "N"; then
            error "Operation canceled."
        fi
        USB_DEVICE=""
    fi
fi

# Check if LVM is properly installed
if ! command -v lvs &> /dev/null; then
    error "LVM commands not found. Please install lvm2 package first."
fi

# Verify the required volumes exist
section "Verifying LVM Volumes"
LVS_OUTPUT=$(lvs || true)
if ! echo "${LVS_OUTPUT}" | grep -q vg_data; then
    error "No logical volumes found in vg_data. Run lvm-setup.sh first."
fi

required_volumes=("lv_data" "lv_home" "lv_docker" "lv_virtualbox" "lv_models")
missing_volumes=0

for vol in "${required_volumes[@]}"; do
    if ! echo "${LVS_OUTPUT}" | grep -q "${vol}"; then
        warning "Required volume ${vol} not found."
        missing_volumes=$((missing_volumes + 1))
    else
        success "Volume ${vol} exists"
    fi
done

if [[ ${missing_volumes} -gt 0 ]]; then
    if ! confirm "Some required volumes are missing. Continue anyway?" "N"; then
        error "Please create all required logical volumes first."
    fi
fi

# Mount the root volume
section "Setting Up Chroot Environment"
echo "Creating mount point /mnt if it doesn't exist..."
mkdir -p /mnt

echo "Mounting root volume to /mnt..."
if ! mount "${ROOT_DEVICE}" /mnt; then
    error "Failed to mount root volume to /mnt."
fi
success "Root volume mounted to /mnt"

# Mount EFI partition
echo "Creating EFI mount point if it doesn't exist..."
mkdir -p /mnt/boot/efi

echo "Mounting EFI partition to /mnt/boot/efi..."
if ! mount "${EFI_DEVICE}" /mnt/boot/efi; then
    warning "Failed to mount EFI partition. You may need to do this manually."
else
    success "EFI partition mounted to /mnt/boot/efi"
fi

# Mount USB drive if specified
if [[ -n "${USB_DEVICE}" ]]; then
    echo "Creating USB mount point if it doesn't exist..."
    mkdir -p /mnt/media/usb

    echo "Mounting USB drive to /mnt/media/usb..."
    if ! mount "${USB_DEVICE}" /mnt/media/usb; then
        warning "Failed to mount USB drive. Scripts won't be accessible in chroot."
    else
        success "USB drive mounted to /mnt/media/usb"
    fi
fi

# Bind mount essential filesystems
echo "Binding essential filesystems for chroot..."
for fs in /dev /dev/pts /proc /sys /run; do
    mkdir -p "/mnt${fs}"
    if ! mount --bind "${fs}" "/mnt${fs}"; then
        warning "Failed to bind mount ${fs}, trying to continue..."
    else
        success "Bind mounted ${fs}"
    fi
done

# Create the fstab modification script
section "Creating Chroot Script"
echo "Creating a script to run inside the chroot environment..."

cat > /mnt/fstab-setup.sh << 'EOF'
#!/bin/bash

# Text formatting
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Check for LVM tools
if ! command -v lvs &> /dev/null; then
    apt update
    apt install -y lvm2
    success "LVM tools installed"
fi

# Backup existing fstab
echo "Backing up existing fstab..."
cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d%H%M%S)"
success "Backup created at /etc/fstab.backup.$(date +%Y%m%d%H%M%S)"

# Add LVM entries to fstab
echo "Adding LVM entries to fstab..."
cat >> /etc/fstab << 'END'

# LVM volumes - mount order matters!
/dev/vg_data/lv_home      /home/scott     ext4    defaults        0       2
/dev/vg_data/lv_docker    /docker         ext4    defaults        0       2
/dev/vg_data/lv_data      /data           ext4    defaults        0       2
/dev/vg_data/lv_virtualbox /data/virtualbox ext4  defaults        0       2
/dev/vg_data/lv_models    /opt/models     ext4    defaults        0       2
END

success "LVM entries added to fstab"

# Create mount points
echo "Creating mount points..."
mkdir -p /home/scott
mkdir -p /docker
mkdir -p /var/lib/docker
mkdir -p /data
mkdir -p /data/virtualbox
mkdir -p /opt/models

# Create symlink for Docker
echo "Creating symlink for Docker..."
ln -sf /docker /var/lib/docker

success "Mount points created"

# Update initramfs to include LVM modules
echo "Updating initramfs to include LVM modules..."
update-initramfs -u
success "Initramfs updated"

echo "All done! The system is configured for the custom LVM setup."
echo "Please exit the chroot environment and reboot into your new system."
echo "After reboot, run lvm-finish.sh to complete the setup."
EOF

chmod +x /mnt/fstab-setup.sh
success "Chroot script created"

# Execute the script in the chroot environment
section "Executing Chroot Script"
echo "Entering chroot environment to configure fstab..."

# First check if chroot can be accessed
if ! chroot /mnt echo "Chroot environment is accessible"; then
    warning "The chroot environment cannot be accessed. This might indicate a problem with the installation."
    # Cleanup is handled by trap
    error "Chroot setup failed."
fi

# Execute the script in the chroot
if ! chroot /mnt /fstab-setup.sh; then
    warning "The script in chroot environment exited with an error."
    # Cleanup is handled by trap
    error "Chroot script execution failed."
fi

success "Successfully configured fstab in chroot environment"

# Clean up and unmount
section "Cleaning Up"
echo "Removing temporary script..."
rm -f /mnt/fstab-setup.sh

echo "Unmounting filesystems..."
# Cleanup is handled by trap when the script exits
trap - EXIT
cleanup

success "Cleanup completed"

# Final instructions
section "Chroot Configuration Complete"
echo "The chroot configuration is now complete."
echo "You can now reboot into your new system:"
echo "sudo reboot"
echo
echo "After booting into your new system, run the final script:"
echo "lvm-finish.sh"
echo
echo "This will set up the necessary symlinks and user configuration."

exit 0
