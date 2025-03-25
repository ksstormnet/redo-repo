#!/bin/bash
# ============================================================================
# ui_utils.sh
# ----------------------------------------------------------------------------
# User interface utilities for installer scripts
# Provides functions for user interaction, prompts, progress bars, etc.
# ============================================================================

# Define color variables if not already defined
: "${COLOR_GREEN:=\033[0;32m}"
: "${COLOR_RED:=\033[0;31m}"
: "${COLOR_CYAN:=\033[0;36m}"
: "${COLOR_RESET:=\033[0m}"
: "${USE_COLOR:=true}"

# Ask user for confirmation (yes/no)
function prompt_yes_no() {
    local question="$1"
    local default="${2:-y}"
    local response
    
    # Default options text
    local options="[Y/n]"
    if [[ "${default,,}" == "n" ]]; then
        options="[y/N]"
    fi
    
    # Loop until we get a valid response
    while true; do
        read -r -p "${question} ${options} " response
        
        # Handle empty response (use default)
        if [[ -z "${response}" ]]; then
            response="${default}"
        fi
        
        # Check response
        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer with yes (y) or no (n)."
                ;;
        esac
    done
}

# Ask user to select from a list of options
function prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected
    
    echo "${prompt}"
    select selected in "${options[@]}"; do
        if [[ -n "${selected}" ]]; then
            echo "${selected}"
            return 0
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Ask user to enter a value with validation
function prompt_with_validation() {
    local prompt="$1"
    local validation_func="$2"
    local default="${3:-}"
    local value
    
    # Add default to prompt if provided
    if [[ -n "${default}" ]]; then
        prompt="${prompt} [${default}]"
    fi
    
    # Loop until we get a valid response
    while true; do
        read -r -p "${prompt}: " value
        
        # Use default if input is empty
        if [[ -z "${value}" && -n "${default}" ]]; then
            value="${default}"
        fi
        
        # Validate the input - avoid masking return value
        local validation_result
        if [[ -n "${validation_func}" ]]; then
            validation_result=$(${validation_func} "${value}") || true
        else
            validation_result="true"
        fi
        
        if [[ "${validation_result}" == "true" ]]; then
            echo "${value}"
            return 0
        else
            echo "Invalid input. Please try again."
        fi
    done
}

# Show a spinner while a command is running
function show_spinner() {
    local message="$1"
    local command="$2"
    local pid
    local spin='-\|/'
    local i=0
    
    # Start the command in background
    ${command} &
    pid=$!
    
    # Display spinner while command is running
    echo -n "${message} "
    while ps -p "${pid}" > /dev/null; do
        echo -ne "\b${spin:i++%4:1}"
        sleep 0.1
    done
    echo -ne "\bDone\n"
    
    # Wait for command to finish and return its exit code
    wait "${pid}"
    return $?
}

# Display a progress bar
function show_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local title="${4:-}"
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    
    # Display title if provided
    if [[ -n "${title}" ]]; then
        echo -n "${title}: "
    fi
    
    # Display progress bar
    echo -n "["
    for ((i=0; i<width; i++)); do
        if [[ ${i} -lt ${completed} ]]; then
            echo -n "="
        else
            echo -n " "
        fi
    done
    echo -n "] ${percent}%"
    
    # Move to next line if complete
    if [[ ${current} -eq ${total} ]]; then
        echo
    else
        echo -ne "\r"
    fi
}

# Create a spinner animation
function start_spinner() {
    local message="$1"
    local delay=0.1
    local spin='-\|/'
    
    # Save cursor position
    tput sc
    
    # Function to update spinner
    update_spinner() {
        local i=0
        while true; do
            tput rc  # Restore cursor position
            echo -n "${message} [${spin:i++%4:1}]"
            sleep "${delay}"
        done
    }
    
    # Start spinner in background
    update_spinner &
    echo $! > /tmp/spinner_pid
}

# Stop the spinner animation
function stop_spinner() {
    local success=${1:-true}
    
    # Kill the spinner process
    if [[ -f /tmp/spinner_pid ]]; then
        # Read PID from file to avoid word splitting
        local spinner_pid
        spinner_pid=$(cat /tmp/spinner_pid) || true
        
        if [[ -n "${spinner_pid}" ]]; then
            kill "${spinner_pid}" &> /dev/null
        fi
        rm -f /tmp/spinner_pid
    fi
    
    # Clear the line
    tput rc  # Restore cursor position
    tput el  # Clear to end of line
    
    # Show final status
    if [[ "${success}" == "true" ]]; then
        echo -e "${COLOR_GREEN}✓${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}✗${COLOR_RESET}"
    fi
}

# Display a countdown timer
function countdown_timer() {
    local seconds="$1"
    local message="${2:-"Starting in"}"
    
    for ((i=seconds; i>0; i--)); do
        echo -ne "\r${message} ${i} seconds..."
        sleep 1
    done
    echo -e "\r${message} 0 seconds...Done\n"
}

# Display a simple menu and get user selection
function display_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selection
    
    echo "${title}"
    echo "----------------------------------------"
    
    # Display menu items
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[${i}]}"
    done
    
    echo "----------------------------------------"
    read -r -p "Enter selection (1-${#options[@]}): " selection
    
    # Validate selection
    if [[ "${selection}" =~ ^[0-9]+$ && "${selection}" -ge 1 && "${selection}" -le "${#options[@]}" ]]; then
        return $((selection-1))
    else
        echo "Invalid selection"
        return 255
    fi
}

# Create a selection checklist
function selection_checklist() {
    local title="$1"
    shift
    local options=("$@")
    local selected=()
    local choice
    
    echo "${title}"
    echo "----------------------------------------"
    
    # Display options
    for i in "${!options[@]}"; do
        echo "  $((i+1)). [ ] ${options[${i}]}"
    done
    
    echo "----------------------------------------"
    echo "Enter numbers to toggle selection (comma or space separated)"
    echo "or 'a' for all, 'n' for none, 'd' for done"
    
    # Initialize checklist
    local checked=()
    for i in "${!options[@]}"; do
        checked[i]=false
    done
    
    # Process selections
    while true; do
        read -r -p "Selection: " choice
        
        case "${choice}" in
            a|A)
                # Select all
                for i in "${!options[@]}"; do
                    checked[i]=true
                done
                ;;
            n|N)
                # Select none
                for i in "${!options[@]}"; do
                    checked[i]=false
                done
                ;;
            d|D)
                # Done with selection
                break
                ;;
            *)
                # Toggle selected items
                IFS=' ' read -r -a numbers <<< "${choice}"
                for num in "${numbers[@]}"; do
                    if [[ "${num}" =~ ^[0-9]+$ && "${num}" -ge 1 && "${num}" -le "${#options[@]}" ]]; then
                        # Toggle checked state - use array index directly
                        local idx=$((num-1))
                        if [[ "${checked[idx]}" == "true" ]]; then
                            checked[idx]=false
                        else
                            checked[idx]=true
                        fi
                    fi
                done
                ;;
        esac
        
        # Re-display the options with current state
        echo "----------------------------------------"
        for i in "${!options[@]}"; do
            if [[ "${checked[${i}]}" == "true" ]]; then
                echo "  $((i+1)). [X] ${options[${i}]}"
            else
                echo "  $((i+1)). [ ] ${options[${i}]}"
            fi
        done
        echo "----------------------------------------"
    done
    
    # Build array of selected options
    for i in "${!options[@]}"; do
        if [[ "${checked[${i}]}" == "true" ]]; then
            selected+=("${options[${i}]}")
        fi
    done
    
    # Return the selected options
    for item in "${selected[@]}"; do
        echo "${item}"
    done
}

# Display message wrapped to terminal width
function wrap_message() {
    local message="$1"
    local width="${2:-$(tput cols)}"
    
    # Avoid masking return value
    local folded_message
    folded_message=$(fold -s -w "${width}" <<< "${message}") || true
    echo "${folded_message}"
}

# Print a centered text
function print_centered() {
    local message="$1"
    local width="${2:-$(tput cols)}"
    local padding=$(( (width - ${#message}) / 2 ))
    
    printf "%${padding}s%s%${padding}s\n" "" "${message}" ""
}

# Print a boxed message
function print_box() {
    local title="$1"
    local message="$2"
    local width="${3:-$(tput cols)}"
    local width=$((width-4))  # Account for borders
    
    # Print top border
    printf "┌%${width}s┐\n" | tr ' ' '─'
    
    # Print title if provided
    if [[ -n "${title}" ]]; then
        printf "│ %-${width}s │\n" "${title}"
        printf "├%${width}s┤\n" | tr ' ' '─'
    fi
    
    # Print message
    # Avoid masking return value in pipeline
    local folded_message
    folded_message=$(fold -s -w "${width}" <<< "${message}") || true
    
    while read -r line; do
        printf "│ %-${width}s │\n" "${line}"
    done <<< "${folded_message}"
    
    # Print bottom border
    printf "└%${width}s┘\n" | tr ' ' '─'
}

# Clear screen and display program header
function display_header() {
    local title="$1"
    local version="${2:-}"
    
    clear
    
    if [[ -n "${title}" ]]; then
        if [[ "${USE_COLOR}" == "true" ]]; then
            echo -e "${COLOR_CYAN}=============================================${COLOR_RESET}"
            echo -e "${COLOR_CYAN}  ${title} ${version:+ v${version}}${COLOR_RESET}"
            echo -e "${COLOR_CYAN}=============================================${COLOR_RESET}"
        else
            echo "============================================="
            echo "  ${title} ${version:+ v${version}}"
            echo "============================================="
        fi
        echo
    fi
}

# Wait for user to press any key
function press_any_key() {
    local message="${1:-"Press any key to continue..."}"
    
    echo
    echo "${message}"
    read -r -n 1 -s
    echo
}

# Wait for Enter key
function press_enter() {
    local message="${1:-"Press Enter to continue..."}"
    
    echo
    echo "${message}"
    read -r
    echo
}
