# Fixing KDE Network Detection After Ubuntu Server Installation

## Overview
When installing KDE (Kubuntu/Ubuntu Studio) on top of Ubuntu Server, the desktop environment may fail to properly detect network connections despite the network actually functioning (e.g., web browsing works but Discover shows no network).

## When to Apply These Fixes
Apply these fixes after:
1. Installing Ubuntu Server
2. Adding Kubuntu or Ubuntu Studio desktop packages
3. Booting into the graphical KDE environment for the first time

## Solution Steps

### 1. Verify NetworkManager Service Status
```bash
sudo systemctl status NetworkManager
```

If not running or enabled:
```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
```

### 2. Install KDE Network Management Widgets
```bash
sudo apt update
sudo apt install plasma-nm
```

### 3. Configure NetworkManager as Primary Network Manager
```bash
sudo nano /etc/NetworkManager/NetworkManager.conf
```

Ensure it contains:
```
[main]
managed=true
```

If you edited the file, restart NetworkManager:
```bash
sudo systemctl restart NetworkManager
```

### 4. Check for Competing Network Services
Systemd-networkd might be controlling your network instead:
```bash
sudo systemctl status systemd-networkd
```

If active and you want NetworkManager to handle connections:
```bash
sudo systemctl stop systemd-networkd
sudo systemctl disable systemd-networkd
```

### 5. Restart Plasma Shell to Apply Changes
```bash
killall plasmashell
plasmashell &
```

### 6. Additional Troubleshooting (if needed)

If Discover still can't connect:
```bash
# Restart the packagekit service
sudo systemctl restart packagekit

# Check if plasma-discover service is running
systemctl --user status plasma-discover
```

You may need to log out and log back in (or restart) for all changes to take effect.

## Common Issues
- If using a wired connection, ensure ifupdown isn't managing it instead of NetworkManager
- Check `/etc/netplan/*.yaml` files if they're configuring your network to use a different renderer

If problems persist, temporary workaround for updating:
```bash
sudo apt update && sudo apt upgrade
```
