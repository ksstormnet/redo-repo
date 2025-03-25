#!/bin/bash

# 19-networking-enhancements.sh
# This script configures networking enhancements, including SMB/CIFS setup, 
# DNS configuration, browser safe search, and network performance optimizations.
# Modified to use restored configurations from /restart/critical_backups

# Exit on any error
set -e

# Function to display section headers
section() {
    echo
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
    echo
}

# Check if script is run as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run this script as root (use sudo)."
    exit 1
fi

# Get the actual user (not root)
if [[ -n "${SUDO_USER}" ]]; then
    ACTUAL_USER="${SUDO_USER}"
else
    ACTUAL_USER="$(whoami)"
    if [[ "${ACTUAL_USER}" == "root" ]]; then
        read -r -p "Enter the username to set up for: " ACTUAL_USER
        
        # Verify the user exists
        if ! id "${ACTUAL_USER}" &>/dev/null; then
            echo "User ${ACTUAL_USER} does not exist."
            exit 1
        fi
    fi
fi

# Get the actual user's home directory
USER_HOME=$(getent passwd "${ACTUAL_USER}" | cut -d: -f6) || true

# Check for restored configurations
CONFIG_MAPPING="/restart/critical_backups/config_mapping.txt"
RESTORED_CONFIGS_AVAILABLE=false

if [[ -f "${CONFIG_MAPPING}" ]]; then
    echo "Found restored configuration mapping at ${CONFIG_MAPPING}"
    # shellcheck disable=SC1090
    source "${CONFIG_MAPPING}"
    RESTORED_CONFIGS_AVAILABLE=true
else
    echo "No restored configuration mapping found at ${CONFIG_MAPPING}"
    echo "Will proceed with default configurations."
fi

# Display welcome message
section "Network Enhancement Setup"
echo "This script will set up network enhancements for ${ACTUAL_USER}."
echo "Home directory: ${USER_HOME}"
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]]; then
    echo "Using restored configurations from /restart/critical_backups"
fi
echo

read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# ======================================================================
# 1. SMB/CIFS Setup
# ======================================================================
section "Setting Up SMB/CIFS File Sharing"

echo "Installing SMB/CIFS packages..."
apt update
apt install -y samba cifs-utils

# Back up the original smb.conf if it exists
if [[ -f /etc/samba/smb.conf ]]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
fi

# Check for restored SMB configuration
RESTORED_SMB_CONF=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    # Check various possible locations for smb.conf in the restored configs
    POSSIBLE_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/samba/smb.conf"
        "${GENERAL_CONFIGS_PATH}/samba/smb.conf"
        "${ADDITIONAL_CONFIGS_PATH}/samba/smb.conf"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_SMB_CONF="${path}"
            echo "Found restored SMB configuration at ${RESTORED_SMB_CONF}"
            break
        fi
    done
fi

# Use restored SMB config or create a basic one
if [[ -n "${RESTORED_SMB_CONF}" ]]; then
    echo "Using restored SMB configuration from backup..."
    cp "${RESTORED_SMB_CONF}" /etc/samba/smb.conf
else
    echo "Creating default SMB configuration..."
    # Create a basic smb.conf file
    cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = NEWBERRY
   server string = %h server
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes
   security = user
   encrypt passwords = true
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
   min receivefile size = 16384
   use sendfile = true
   aio read size = 16384
   aio write size = 16384

# Share home directory
[homes]
   comment = Home Directories
   browseable = no
   read only = no
   create mask = 0700
   directory mask = 0700
   valid users = %S

# Public share example (commented out by default)
[Public]
   comment = Public Shared Folder
   path = /data/public
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0755
   directory mask = 0755
EOF
fi

# Check for restored SMB credentials
RESTORED_SMB_CREDS=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_CRED_PATHS=(
        "${GENERAL_CONFIGS_PATH}/home/.config/smb/credentials"
        "${GENERAL_CONFIGS_PATH}/.config/smb/credentials"
        "${GENERAL_CONFIGS_PATH}/smb/credentials"
        "${HOME_CONFIGS_PATH}/.config/smb/credentials"
    )
    
    for path in "${POSSIBLE_CRED_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_SMB_CREDS="${path}"
            echo "Found restored SMB credentials at ${RESTORED_SMB_CREDS}"
            break
        fi
    done
fi

# Create a credentials template file for mounting shares
mkdir -p "${USER_HOME}/.config/smb"

# Use restored credentials or create a template
if [[ -n "${RESTORED_SMB_CREDS}" ]]; then
    echo "Using restored SMB credentials template..."
    cp "${RESTORED_SMB_CREDS}" "${USER_HOME}/.config/smb/credentials.template"
else
    echo "Creating default SMB credentials template..."
    cat > "${USER_HOME}/.config/smb/credentials.template" << EOF
username=your_username
password=your_password
domain=your_domain
EOF
fi

# Set proper permissions for credentials
chmod 600 "${USER_HOME}/.config/smb/credentials.template"
chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${USER_HOME}/.config/smb"

# Create a helper script for mounting SMB shares
cat > /usr/local/bin/mount-smb << 'EOF'
#!/bin/bash

# mount-smb: Helper script to mount SMB/CIFS shares with proper options

if [[ "$#" -lt 2 ]]; then
    echo "Usage: mount-smb //server/share /mount/point [options]"
    echo "Options:"
    echo "  -c, --credentials FILE  Use credentials file"
    echo "  -u, --user USERNAME     Specify username"
    echo "  -p, --permanent         Add to fstab for permanent mounting"
    echo "  -v, --vers VERSION      Specify SMB protocol version (2.0, 2.1, 3.0)"
    exit 1
fi

SERVER_SHARE="$1"
MOUNT_POINT="$2"
shift 2

# Default options
CREDS=""
USERNAME=""
ADD_TO_FSTAB=0
SMB_VERSION="3.0"

# Parse options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -c|--credentials)
            CREDS="credentials=$2"
            shift 2
            ;;
        -u|--user)
            USERNAME="username=$2"
            shift 2
            ;;
        -p|--permanent)
            ADD_TO_FSTAB=1
            shift
            ;;
        -v|--vers)
            SMB_VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create mount point if it doesn't exist
if [[ ! -d "${MOUNT_POINT}" ]]; then
    mkdir -p "${MOUNT_POINT}"
fi

# Build mount options
MOUNT_OPTIONS="vers=${SMB_VERSION},rw,iocharset=utf8,file_mode=0755,dir_mode=0755"

if [[ -n "${CREDS}" ]]; then
    MOUNT_OPTIONS="${MOUNT_OPTIONS},${CREDS}"
elif [[ -n "${USERNAME}" ]]; then
    MOUNT_OPTIONS="${MOUNT_OPTIONS},${USERNAME}"
fi

# Mount the share
mount -t cifs "${SERVER_SHARE}" "${MOUNT_POINT}" -o "${MOUNT_OPTIONS}"

if [[ $? -eq 0 ]]; then
    echo "Successfully mounted ${SERVER_SHARE} to ${MOUNT_POINT}"
    
    # Add to fstab if requested
    if [[ ${ADD_TO_FSTAB} -eq 1 ]]; then
        # Check if entry already exists
        if ! grep -q "${SERVER_SHARE}" /etc/fstab; then
            echo "${SERVER_SHARE} ${MOUNT_POINT} cifs ${MOUNT_OPTIONS} 0 0" >> /etc/fstab
            echo "Added mount to /etc/fstab for permanent mounting"
        else
            echo "Mount entry already exists in /etc/fstab"
        fi
    fi
else
    echo "Failed to mount ${SERVER_SHARE}"
    exit 1
fi
EOF

chmod +x /usr/local/bin/mount-smb

# Create a folder for custom SMB mounts
mkdir -p /mnt/smb
chown root:root /mnt/smb
chmod 755 /mnt/smb

# Add SMB browsing KDE integration
apt install -y kdenetwork-filesharing

# Restart Samba services
systemctl restart smbd nmbd

echo "✓ SMB/CIFS setup completed"
echo "  - Created template credentials file at ${USER_HOME}/.config/smb/credentials.template"
echo "  - Added mount-smb helper script for easy SMB mounting"
echo "  - Added KDE integration for SMB browsing"

# ======================================================================
# 2. DNS Configuration with Local Network Host Discovery
# ======================================================================
section "Configuring DNS with Local Network Host Discovery"

echo "Setting up DNS configuration with local network host discovery..."

# Check for restored hosts file
RESTORED_HOSTS=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_HOSTS_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/hosts"
        "${GENERAL_CONFIGS_PATH}/hosts"
    )
    
    for path in "${POSSIBLE_HOSTS_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_HOSTS="${path}"
            echo "Found restored hosts file at ${RESTORED_HOSTS}"
            break
        fi
    done
fi

# Detect router IP (usually the default gateway)
ROUTER_IP=$(ip route | grep default | awk '{print $3}') || true
if [[ -z "${ROUTER_IP}" ]]; then
    echo "Could not detect router IP. Please enter your router's IP address:"
    read -r ROUTER_IP
fi

echo "Detected router IP: ${ROUTER_IP}"

# Install required packages for DNS and network discovery
apt install -y avahi-daemon libnss-mdns net-tools

# Check for restored resolved.conf
RESTORED_RESOLVED_CONF=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_RESOLVED_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/systemd/resolved.conf"
        "${GENERAL_CONFIGS_PATH}/systemd/resolved.conf"
    )
    
    for path in "${POSSIBLE_RESOLVED_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_RESOLVED_CONF="${path}"
            echo "Found restored systemd-resolved config at ${RESTORED_RESOLVED_CONF}"
            break
        fi
    done
fi

# Configure systemd-resolved with custom settings
if [[ -n "${RESTORED_RESOLVED_CONF}" ]]; then
    echo "Using restored systemd-resolved configuration..."
    cp "${RESTORED_RESOLVED_CONF}" /etc/systemd/resolved.conf
else
    echo "Creating default systemd-resolved configuration..."
    cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=${ROUTER_IP}
Domains=~.
LLMNR=yes
MulticastDNS=yes
DNSSEC=no
DNSOverTLS=no
Cache=yes
DNSStubListener=yes
ReadEtcHosts=yes
EOF
fi

# Create specific DNS settings for .local domains
mkdir -p /etc/systemd/resolved.conf.d/

cat > /etc/systemd/resolved.conf.d/local-domain.conf << EOF
[Resolve]
Domains=~local
LLMNR=yes
MulticastDNS=yes
EOF

# Check for restored nsswitch.conf
RESTORED_NSSWITCH=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_NSSWITCH_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/nsswitch.conf"
        "${GENERAL_CONFIGS_PATH}/nsswitch.conf"
    )
    
    for path in "${POSSIBLE_NSSWITCH_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_NSSWITCH="${path}"
            echo "Found restored nsswitch.conf at ${RESTORED_NSSWITCH}"
            break
        fi
    done
fi

# Configure NSS to use mDNS for hostname resolution
if [[ -n "${RESTORED_NSSWITCH}" ]]; then
    echo "Using restored nsswitch.conf configuration..."
    cp "${RESTORED_NSSWITCH}" /etc/nsswitch.conf
else
    echo "Updating nsswitch.conf for mDNS resolution..."
    # Make backup of current nsswitch.conf
    cp /etc/nsswitch.conf /etc/nsswitch.conf.backup
    # Update the hosts line to include mdns4_minimal
    sed -i '/^hosts:/s/files dns/files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf
fi

# Check for restored avahi config
RESTORED_AVAHI=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_AVAHI_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/avahi/avahi-daemon.conf"
        "${GENERAL_CONFIGS_PATH}/avahi/avahi-daemon.conf"
    )
    
    for path in "${POSSIBLE_AVAHI_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_AVAHI="${path}"
            echo "Found restored avahi-daemon.conf at ${RESTORED_AVAHI}"
            break
        fi
    done
fi

# Configure Avahi to discover and resolve local hostnames
if [[ -n "${RESTORED_AVAHI}" ]]; then
    echo "Using restored Avahi configuration..."
    cp "${RESTORED_AVAHI}" /etc/avahi/avahi-daemon.conf
else
    echo "Creating default Avahi configuration..."
    cat > /etc/avahi/avahi-daemon.conf << EOF
[server]
use-ipv4=yes
use-ipv6=yes
allow-interfaces=*
enable-dbus=yes
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
publish-resolv-conf-dns-servers=yes
publish-aaaa-on-ipv4=yes
publish-a-on-ipv6=yes

[reflector]
enable-reflector=yes
reflect-ipv=yes

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
EOF
fi

# Restore hosts entries if available
if [[ -n "${RESTORED_HOSTS}" ]]; then
    echo "Adding entries from restored hosts file..."
    # Extract non-localhost entries from the restored hosts file
    grep -v "^127.0.0.1\|^::1\|^#" "${RESTORED_HOSTS}" >> /etc/hosts
fi

# Restart systemd-resolved and avahi to apply settings
systemctl restart systemd-resolved
systemctl restart avahi-daemon
systemctl enable avahi-daemon

# Set up NetworkManager to use systemd-resolved
cat > /etc/NetworkManager/conf.d/dns-systemd-resolved.conf << EOF
[main]
dns=systemd-resolved
EOF

# Create a script to discover and add local hosts
cat > /usr/local/bin/discover-local-hosts << 'EOF'
#!/bin/bash

# discover-local-hosts: Tool to find and add local network hosts to /etc/hosts

echo "Discovering local network hosts..."
echo

# Scan local network for mDNS hosts
echo "mDNS hosts on the network:"
avahi-browse -at | grep -v 'IPv6' | grep 'local' | sort

echo
echo "Local hosts from /etc/hosts:"
grep -v '^#\|^127\.\|^::1' /etc/hosts

echo
echo "Would you like to add hosts to /etc/hosts for direct access without .local suffix?"
read -p "Add hosts to /etc/hosts? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "No changes made to /etc/hosts"
    exit 0
fi

# Function to add a host
add_host() {
    echo
    read -p "Enter hostname (without .local): " hostname
    read -p "Enter IP address: " ip_address
    
    # Validate IP address format
    if [[ ! $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid IP address format."
        return
    fi
    
    # Check if hostname already exists in hosts file
    if grep -q "^[0-9].*[[:space:]]$hostname\([[:space:]]\|$\)" /etc/hosts; then
        echo "Hostname $hostname already exists in /etc/hosts"
        read -p "Update it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        # Remove existing entry
        sed -i "/^[0-9].*[[:space:]]$hostname\([[:space:]]\|$\)/d" /etc/hosts
    fi
    
    # Add new entry
    echo "$ip_address $hostname" >> /etc/hosts
    echo "Added $hostname ($ip_address) to /etc/hosts"
}

# Add multiple hosts
while true; do
    add_host
    echo
    read -p "Add another host? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        break
    fi
done

echo "Current /etc/hosts entries:"
grep -v '^#\|^127\.\|^::1' /etc/hosts

echo
echo "Done! You should now be able to access hosts without the .local suffix."
echo "Example: ping hostname"
EOF

chmod +x /usr/local/bin/discover-local-hosts

# Create a script to check DNS resolution
cat > /usr/local/bin/check-dns << 'EOF'
#!/bin/bash

# check-dns: Tool to verify DNS resolution

echo "Testing DNS resolution..."
echo

echo "Router DNS resolution test:"
host google.com
echo

echo "Local hostname resolution test:"
echo "Available local hosts:"
avahi-browse -at | grep -v 'IPv6' | grep 'local' | sort
echo

# Try to find at least one local host to test
LOCAL_HOST=$(avahi-browse -at | grep -v 'IPv6' | grep 'local' | head -1 | awk -F' ' '{print $4}' 2>/dev/null)
if [[ -n "${LOCAL_HOST}" ]]; then
    echo "Testing local host resolution for: ${LOCAL_HOST}"
    ping -c 1 "${LOCAL_HOST}" 2>/dev/null || echo "Could not resolve ${LOCAL_HOST}"
    
    # Try without .local suffix if hostname has it
    if [[ "${LOCAL_HOST}" == *".local" ]]; then
        HOST_NO_SUFFIX=${LOCAL_HOST%".local"}
        echo "Testing without .local suffix: ${HOST_NO_SUFFIX}"
        ping -c 1 "${HOST_NO_SUFFIX}" 2>/dev/null || echo "Could not resolve ${HOST_NO_SUFFIX}"
    fi
else
    echo "No local hosts found for testing"
fi

echo
echo "DNS server being used:"
systemd-resolve --status | grep "DNS Servers" -A2
EOF

chmod +x /usr/local/bin/check-dns

echo "✓ DNS configuration completed"
echo "  - Router (${ROUTER_IP}) set as primary DNS server"
echo "  - Configured mDNS for direct hostname resolution without .local suffix"
echo "  - Added discover-local-hosts utility to find and add local network hosts"
echo "  - You can test DNS resolution with the check-dns command"

# ======================================================================
# 3. Browser Safe Search Configuration (with Incognito allowed)
# ======================================================================
section "Setting Up Browser Safe Search (with Incognito allowed)"

echo "Configuring enforced safe search for browsers (allowing incognito mode)..."

# Check for restored browser policies
RESTORED_BROWSER_POLICIES=false
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    BROWSER_POLICY_DIRS=(
        "chrome/policies"
        "edge/policies"
        "firefox/distribution"
        "brave/policies"
    )
    
    for dir in "${BROWSER_POLICY_DIRS[@]}"; do
        if [[ -d "${GENERAL_CONFIGS_PATH}/etc/opt/${dir}" ]] || [[ -d "${GENERAL_CONFIGS_PATH}/opt/${dir}" ]]; then
            RESTORED_BROWSER_POLICIES=true
            echo "Found restored browser policies in ${dir}"
        fi
    done
fi

# Create directory for browser policies
mkdir -p /etc/opt/chrome/policies/managed
mkdir -p /etc/opt/edge/policies/managed
mkdir -p /usr/lib/firefox/distribution
mkdir -p /etc/brave/policies/managed

# Apply restored browser policies or use defaults
if [[ "${RESTORED_BROWSER_POLICIES}" = true ]]; then
    echo "Using restored browser policies from backup..."
    
    # Chrome
    if [[ -d "${GENERAL_CONFIGS_PATH}/etc/opt/chrome/policies/managed" ]]; then
        cp -r "${GENERAL_CONFIGS_PATH}/etc/opt/chrome/policies/managed/"* /etc/opt/chrome/policies/managed/
    fi
    
    # Edge
    if [[ -d "${GENERAL_CONFIGS_PATH}/etc/opt/edge/policies/managed" ]]; then
        cp -r "${GENERAL_CONFIGS_PATH}/etc/opt/edge/policies/managed/"* /etc/opt/edge/policies/managed/
    fi
    
    # Firefox
    if [[ -f "${GENERAL_CONFIGS_PATH}/usr/lib/firefox/distribution/policies.json" ]]; then
        cp "${GENERAL_CONFIGS_PATH}/usr/lib/firefox/distribution/policies.json" /usr/lib/firefox/distribution/
    fi
    
    # Brave
    if [[ -d "${GENERAL_CONFIGS_PATH}/etc/brave/policies/managed" ]]; then
        cp -r "${GENERAL_CONFIGS_PATH}/etc/brave/policies/managed/"* /etc/brave/policies/managed/
    fi
else
    echo "Creating default browser policies..."
    
    # Google Chrome/Chromium policy
    cat > /etc/opt/chrome/policies/managed/safesearch.json << EOF
{
  "ForceGoogleSafeSearch": true,
  "ForceYouTubeRestrict": "Strict",
  "URLBlocklist": [
    "chrome://settings/content/contentSettings"
  ],
  "BrowserSwitcherEnabled": false,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Kagi",
  "DefaultSearchProviderSearchURL": "https://kagi.com/search?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://kagi.com/api/autosuggest?q={searchTerms}",
  "DefaultSearchProviderIconURL": "https://kagi.com/favicon.ico",
  "DefaultSearchProviderKeyword": "kagi",
  "DefaultSearchProviderAlternateURLs": ["https://kagi.com/search?q={searchTerms}"],
  "DefaultSearchProviderEncodings": ["UTF-8"],
  "DefaultSearchProviderImageURL": "https://kagi.com/image?q={searchTerms}",
  "DefaultSearchProviderImageURLPostParams": "",
  "DefaultSearchProviderNewTabURL": "https://kagi.com",
  "SearchSuggestEnabled": true,
  "HideWebStoreIcon": false,
  "DeveloperToolsAvailability": 1,
  "OverrideSecurityRestrictionsOnInsecureOrigin": false,
  "ShowFullUrlsInAddressBar": true,
  "AlternateErrorPagesEnabled": true,
  "HomepageLocation": "https://kagi.com",
  "HomepageIsNewTabPage": false,
  "NewTabPageLocation": "https://kagi.com",
  "RestoreOnStartup": 5,
  "RestoreOnStartupURLs": ["https://kagi.com"]
}
EOF

    # Microsoft Edge policy
    cat > /etc/opt/edge/policies/managed/safesearch.json << EOF
{
  "ForceGoogleSafeSearch": true,
  "ForceYouTubeRestrict": "Strict",
  "URLBlocklist": [
    "edge://settings/content/contentSettings"
  ],
  "BrowserSwitcherEnabled": false,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Kagi",
  "DefaultSearchProviderSearchURL": "https://kagi.com/search?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://kagi.com/api/autosuggest?q={searchTerms}",
  "DefaultSearchProviderIconURL": "https://kagi.com/favicon.ico",
  "DefaultSearchProviderKeyword": "kagi",
  "DefaultSearchProviderAlternateURLs": ["https://kagi.com/search?q={searchTerms}"],
  "DefaultSearchProviderEncodings": ["UTF-8"],
  "DefaultSearchProviderImageURL": "https://kagi.com/image?q={searchTerms}",
  "DefaultSearchProviderImageURLPostParams": "",
  "DefaultSearchProviderNewTabURL": "https://kagi.com",
  "SearchSuggestEnabled": true,
  "HideWebStoreIcon": false,
  "DeveloperToolsAvailability": 1,
  "OverrideSecurityRestrictionsOnInsecureOrigin": false,
  "ShowFullUrlsInAddressBar": true,
  "AlternateErrorPagesEnabled": true,
  "HomepageLocation": "https://kagi.com",
  "HomepageIsNewTabPage": false,
  "NewTabPageLocation": "https://kagi.com",
  "RestoreOnStartup": 5,
  "RestoreOnStartupURLs": ["https://kagi.com"]
}
EOF

    # Firefox policy (allowing incognito/private browsing)
    cat > /usr/lib/firefox/distribution/policies.json << EOF
{
  "policies": {
    "SearchEngineRestriction": {
      "LockSafeSearch": true
    },
    "OfferToSaveLogins": false,
    "BlockAboutConfig": true,
    "WebsiteFilter": {
      "Block": ["https://www.youtube.com/watch?*&safety_mode=false", "https://www.youtube.com/watch?*?safety_mode=false"]
    },
    "SearchEngines": {
      "Default": "Kagi",
      "PreventInstalls": true,
      "Add": [
        {
          "Name": "Kagi",
          "URLTemplate": "https://kagi.com/search?q={searchTerms}",
          "Method": "GET",
          "IconURL": "https://kagi.com/favicon.ico",
          "SuggestURLTemplate": "https://kagi.com/api/autosuggest?q={searchTerms}",
          "Alias": "kagi"
        }
      ],
      "Remove": ["Google", "Bing", "Amazon.com", "eBay", "Twitter", "Wikipedia"]
    },
    "OverrideFirstRunPage": "https://kagi.com",
    "OverridePostUpdatePage": "https://kagi.com",
    "Homepage": {
      "URL": "https://kagi.com",
      "Locked": true
    },
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "NoDefaultBookmarks": true,
    "DisplayBookmarksToolbar": true,
    "DontCheckDefaultBrowser": true
  }
}
EOF

    # Brave Browser policy
    cat > /etc/brave/policies/managed/safesearch.json << EOF
{
  "ForceGoogleSafeSearch": true,
  "ForceYouTubeRestrict": "Strict",
  "URLBlocklist": [
    "brave://settings/content/contentSettings"
  ],
  "BrowserSwitcherEnabled": false,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "Kagi",
  "DefaultSearchProviderSearchURL": "https://kagi.com/search?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://kagi.com/api/autosuggest?q={searchTerms}",
  "DefaultSearchProviderIconURL": "https://kagi.com/favicon.ico",
  "DefaultSearchProviderKeyword": "kagi",
  "DefaultSearchProviderAlternateURLs": ["https://kagi.com/search?q={searchTerms}"],
  "DefaultSearchProviderEncodings": ["UTF-8"],
  "DefaultSearchProviderImageURL": "https://kagi.com/image?q={searchTerms}",
  "DefaultSearchProviderImageURLPostParams": "",
  "DefaultSearchProviderNewTabURL": "https://kagi.com",
  "SearchSuggestEnabled": true,
  "HideWebStoreIcon": false,
  "DeveloperToolsAvailability": 1,
  "OverrideSecurityRestrictionsOnInsecureOrigin": false,
  "ShowFullUrlsInAddressBar": true,
  "AlternateErrorPagesEnabled": true,
  "HomepageLocation": "https://kagi.com",
  "HomepageIsNewTabPage": false,
  "NewTabPageLocation": "https://kagi.com",
  "RestoreOnStartup": 5,
  "RestoreOnStartupURLs": ["https://kagi.com"]
}
EOF
fi

echo "✓ Browser safe search configuration completed"
echo "  - Google SafeSearch enforced for Chrome, Edge, Firefox, and Brave"
echo "  - YouTube restricted mode enforced"
echo "  - Incognito/Private browsing allowed for troubleshooting cache and cookie issues"
echo "  - Kagi set as default search engine for all browsers"
echo "  - Browser warnings about non-default search engines overridden"

# ======================================================================
# 4. Network Performance Optimizations
# ======================================================================
section "Applying Network Performance Optimizations"

echo "Configuring network performance settings..."

# Check for restored network optimization scripts
RESTORED_NETWORK_OPTIMIZER=""
if [[ "${RESTORED_CONFIGS_AVAILABLE}" = true ]] && [[ -n "${GENERAL_CONFIGS_PATH}" ]]; then
    POSSIBLE_NETWORK_PATHS=(
        "${GENERAL_CONFIGS_PATH}/etc/NetworkManager/dispatcher.d/optimize-connection"
        "${GENERAL_CONFIGS_PATH}/NetworkManager/dispatcher.d/optimize-connection"
        "${GENERAL_CONFIGS_PATH}/etc/NetworkManager/dispatcher.d/01-optimize-connection"
    )
    
    for path in "${POSSIBLE_NETWORK_PATHS[@]}"; do
        if [[ -f "${path}" ]]; then
            RESTORED_NETWORK_OPTIMIZER="${path}"
            echo "Found restored network optimization script at ${RESTORED_NETWORK_OPTIMIZER}"
            break
        fi
    done
fi

# Create NetworkManager dispatcher script to optimize network on connection
mkdir -p /etc/NetworkManager/dispatcher.d/

if [[ -n "${RESTORED_NETWORK_OPTIMIZER}" ]]; then
    echo "Using restored network optimization script..."
    cp "${RESTORED_NETWORK_OPTIMIZER}" /etc/NetworkManager/dispatcher.d/01-optimize-connection
    chmod 755 /etc/NetworkManager/dispatcher.d/01-optimize-connection
else
    echo "Creating default network optimization script..."
    cat > /etc/NetworkManager/dispatcher.d/01-optimize-connection << 'EOF'
#!/bin/bash

# This script optimizes network settings when a connection is established

INTERFACE="$1"
STATUS="$2"

if [[ "${STATUS}" = "up" ]]; then
    # Get the type of connection (wifi or ethernet)
    CONN_TYPE=$(nmcli -g GENERAL.TYPE device show "${INTERFACE}")
    
    # Apply specific optimizations based on connection type
    if [[ "${CONN_TYPE}" = "ethernet" ]]; then
        # Ethernet optimizations
        
        # Increase interface transmit queue length
        ip link set "${INTERFACE}" txqueuelen 10000
        
        # Optimize TCP for wired connection
        sysctl -w net.ipv4.tcp_moderate_rcvbuf=1
        sysctl -w net.core.rmem_max=16777216
        sysctl -w net.core.wmem_max=16777216
        sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
        sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
        sysctl -w net.ipv4.tcp_window_scaling=1
        
    elif [[ "${CONN_TYPE}" = "wifi" ]]; then
        # WiFi optimizations
        
        # Lower txqueue for WiFi to reduce latency
        ip link set "${INTERFACE}" txqueuelen 2000
        
        # Different TCP settings for WiFi
        sysctl -w net.ipv4.tcp_moderate_rcvbuf=1
        sysctl -w net.core.rmem_max=12582912
        sysctl -w net.core.wmem_max=12582912
        sysctl -w net.ipv4.tcp_rmem="4096 87380 12582912"
        sysctl -w net.ipv4.tcp_wmem="4096 65536 12582912"
    fi
    
    # Common optimizations for all connection types
    
    # Set TCP congestion control algorithm
    if grep -q 'bbr' /proc/sys/net/ipv4/tcp_available_congestion_control; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr
    elif grep -q 'cubic' /proc/sys/net/ipv4/tcp_available_congestion_control; then
        sysctl -w net.ipv4.tcp_congestion_control=cubic
    fi
    
    # Disable TCP slow start after idle
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0
    
    # Log the optimizations
    logger "Network optimizations applied for ${INTERFACE} (${CONN_TYPE})"
fi

exit 0
EOF
fi

chmod 755 /etc/NetworkManager/dispatcher.d/01-optimize-connection
