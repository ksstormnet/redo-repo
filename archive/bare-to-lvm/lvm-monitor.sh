#!/bin/bash
#
# lvm-monitor.sh - Comprehensive LVM space usage monitor
# Displays information about physical volumes, volume groups, logical volumes,
# and mount points in a visually organized and human-readable format.
#

# Color definitions
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
# MAGENTA="\033[35m" # Removed unused variable
CYAN="\033[36m"
RESET="\033[0m"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${RESET}"
    echo "Please run with sudo: sudo $0"
    exit 1
fi

# Banner function for section headers
banner() {
    local text="$1"
    local length=${#text}
    local padding=$(( (60 - length) / 2 ))
    
    echo
    echo -e "${BOLD}${BLUE}┌$( printf '─%.0s' $(seq 60) )┐${RESET}"
    echo -e "${BOLD}${BLUE}│$( printf ' %.0s' $(seq $padding) )${CYAN}$text$( printf ' %.0s' $(seq $(( 60 - length - padding )) ) )${BLUE}│${RESET}"
    echo -e "${BOLD}${BLUE}└$( printf '─%.0s' $(seq 60) )┘${RESET}"
    echo
}

# Check if lvm2 is installed
if ! command -v pvs &> /dev/null; then
    echo -e "${RED}Error: LVM tools not found.${RESET}"
    echo "Please install lvm2 package: sudo apt install lvm2"
    exit 1
fi

# Main banner
banner "LVM SPACE USAGE MONITOR"
echo -e "${BOLD}Date:${RESET} $(date)"
echo -e "${BOLD}Hostname:${RESET} $(hostname)"
echo

# Physical Volumes Section
banner "PHYSICAL VOLUMES"
if pvs &> /dev/null; then
    # Header
    echo -e "${BOLD}${YELLOW}PV NAME\tSIZE\tUSED\tFREE\tUSED%\tATTRIBUTES${RESET}"
    
    # Get physical volumes info with human-readable sizes
    pvs --units h --nosuffix --noheadings -o pv_name,pv_size,pv_used,pv_free,pv_attr | while read -r pv_name pv_size pv_used pv_free pv_attr; do
        # Calculate percentage used
        if [ "$(echo "$pv_size > 0" | bc)" -eq 1 ]; then
            pv_used_percent=$(printf "%.1f" "$(echo "scale=1; $pv_used * 100 / $pv_size" | bc)")
        else
            pv_used_percent="N/A"
        fi
        
        # Color based on usage percentage
        if [ "$(echo "$pv_used_percent > 90" | bc)" -eq 1 ]; then
            color="${RED}"
        elif [ "$(echo "$pv_used_percent > 75" | bc)" -eq 1 ]; then
            color="${YELLOW}"
        else
            color="${GREEN}"
        fi
        
        # Format and display
        echo -e "$pv_name\t$(numfmt --to=iec --format="%.1f" "${pv_size}B")\t$(numfmt --to=iec --format="%.1f" "${pv_used}B")\t$(numfmt --to=iec --format="%.1f" "${pv_free}B")\t${color}${pv_used_percent}%${RESET}\t$pv_attr"
    done
else
    echo -e "${YELLOW}No physical volumes found.${RESET}"
fi

# Volume Groups Section
banner "VOLUME GROUPS"
if vgs &> /dev/null; then
    # Header
    echo -e "${BOLD}${YELLOW}VG NAME\tSIZE\tFREE\tFREE%\tATTRIBUTES${RESET}"
    
    # Get volume groups info with human-readable sizes
    vgs --units h --nosuffix --noheadings -o vg_name,vg_size,vg_free,vg_attr | while read -r vg_name vg_size vg_free vg_attr; do
        # Calculate percentage free
        if [ "$(echo "$vg_size > 0" | bc)" -eq 1 ]; then
            vg_free_percent=$(printf "%.1f" "$(echo "scale=1; $vg_free * 100 / $vg_size" | bc)")
        else
            vg_free_percent="N/A"
        fi
        
        # Color based on free percentage
        if [ "$(echo "$vg_free_percent < 10" | bc)" -eq 1 ]; then
            color="${RED}"
        elif [ "$(echo "$vg_free_percent < 25" | bc)" -eq 1 ]; then
            color="${YELLOW}"
        else
            color="${GREEN}"
        fi
        
        # Format and display
        echo -e "$vg_name\t$(numfmt --to=iec --format="%.1f" "${vg_size}B")\t$(numfmt --to=iec --format="%.1f" "${vg_free}B")\t${color}${vg_free_percent}%${RESET}\t$vg_attr"
    done
else
    echo -e "${YELLOW}No volume groups found.${RESET}"
fi

# Logical Volumes Section
banner "LOGICAL VOLUMES"
if lvs &> /dev/null; then
    # Header
    echo -e "${BOLD}${YELLOW}LV NAME\tVG NAME\tSIZE\tATTRIBUTES\tSYNC%\tDEVICES${RESET}"
    
    # Get logical volumes info with human-readable sizes
    lvs --units h --nosuffix --noheadings -o lv_name,vg_name,lv_size,lv_attr,copy_percent,devices | while read -r lv_name vg_name lv_size lv_attr copy_percent devices; do
        # Clean up the devices output
        devices=${devices//\([^)]*\)/}
        
        # Format and display
        echo -e "$lv_name\t$vg_name\t$(numfmt --to=iec --format="%.1f" "${lv_size}B")\t$lv_attr\t$copy_percent\t$devices"
    done
else
    echo -e "${YELLOW}No logical volumes found.${RESET}"
fi

# Mount Points Section
banner "MOUNT POINTS"
echo -e "${BOLD}${YELLOW}MOUNT POINT\tDEVICE\tSIZE\tUSED\tAVAIL\tUSED%\tFILE SYSTEM${RESET}"

# Get LVM mount points with df
df -h | grep "/dev/mapper" | sort | while read -r device size used avail usedp mount; do
    # Color based on usage percentage
    usedp_num=$(echo "$usedp" | tr -d '%')
    if [ "$usedp_num" -gt 90 ]; then
        color="${RED}"
    elif [ "$usedp_num" -gt 75 ]; then
        color="${YELLOW}"
    else
        color="${GREEN}"
    fi
    
    # Get filesystem type
    fs_type=$(df -T | grep "$device" | awk '{print $2}')
    
    # Format and display
    echo -e "$mount\t$device\t$size\t$used\t$avail\t${color}$usedp${RESET}\t$fs_type"
done

# Summary
banner "SUMMARY"
echo -e "${BOLD}Total Physical Volumes:${RESET} $(pvs --noheadings | wc -l)"
echo -e "${BOLD}Total Volume Groups:${RESET} $(vgs --noheadings | wc -l)"
echo -e "${BOLD}Total Logical Volumes:${RESET} $(lvs --noheadings | wc -l)"

# LVM snapshot information if any exist
if lvs --noheadings -o lv_name,lv_attr | grep -q "^\s*.*s"; then
    banner "LVM SNAPSHOTS"
    echo -e "${BOLD}${YELLOW}SNAPSHOT\tORIGIN\tSIZE\tDATA%\tAGE${RESET}"
    
    # Get snapshot info
    lvs --noheadings -o lv_name,origin,lv_size,data_percent,time --units h --nosuffix | grep -v "^\s*$" | while read -r lv_name origin lv_size data_percent time; do
        if [ -n "$origin" ]; then
            # Color based on data percentage
            if [ "$(echo "$data_percent > 80" | bc)" -eq 1 ]; then
                color="${RED}"
            elif [ "$(echo "$data_percent > 50" | bc)" -eq 1 ]; then
                color="${YELLOW}"
            else
                color="${GREEN}"
            fi
            
            # Format and display
            echo -e "$lv_name\t$origin\t$(numfmt --to=iec --format="%.1f" "${lv_size}B")\t${color}${data_percent}%${RESET}\t$time"
        fi
    done
fi

# End of script
echo
echo -e "${BOLD}${GREEN}✓ Scan completed successfully${RESET}"
echo

exit 0
