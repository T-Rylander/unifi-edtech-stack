#!/bin/bash

# Script configuration
NONINTERACTIVE=${NONINTERACTIVE:-0}  # Set to 1 for non-interactive mode
DEFAULT_ANSWER=${DEFAULT_ANSWER:-"n"} # Default answer for prompts in non-interactive mode
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30} # Timeout for user input

# Check if dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Installing dialog package..."
    sudo apt-get update
    sudo apt-get install -y dialog
fi

# Helper function for getting user input with dialog
get_user_input() {
    local prompt="$1"
    local default=${2:-"n"}
    local timeout=${3:-$TIMEOUT_SECONDS}

    if [ "$NONINTERACTIVE" = "1" ]; then
        echo "$prompt (non-interactive mode, using default: $default)"
        if [[ "$default" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi

    # If not attached to a terminal, fall back to default
    if [ ! -t 0 ]; then
        echo "$prompt (no TTY, using default: $default)"
        if [[ "$default" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi

    # Use dialog for yes/no prompt
    if dialog --yesno "$prompt" 10 60; then
        return 0
    else
        return 1
    fi
}

# Helper function for info messages
show_info() {
    local title="$1"
    local message="$2"
    dialog --infobox "$message" 10 60
    sleep 2
}

# Helper function for error messages
show_error() {
    local title="$1"
    local message="$2"
    dialog --msgbox "$message" 15 60
}

# Helper function for menu selection
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    dialog --menu "$title" 15 60 10 "${options[@]}"
}

# OS Version Check
check_os_version() {
    . /etc/os-release
    if [[ ! "$ID" =~ ^(raspbian|debian)$ ]]; then
        show_error "OS Check Failed" "Error: This script requires Raspbian or Debian OS\n\nDetected: $PRETTY_NAME"
        return 1
    fi
    
    if [[ ! "$VERSION_ID" =~ ^(12|13)$ ]]; then
        show_error "OS Version Warning" "Unsupported OS version $VERSION_ID\n\n$PRETTY_NAME\n\nThis script is tested on Raspbian/Debian 12 (Bookworm) or 13 (Trixie)"
        if ! get_user_input "Continue anyway?" "n" ; then
            return 1
        fi
    fi
    return 0
}

if ! check_os_version; then
    clear
    exit 1
fi

# Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    show_error "Architecture Check Failed" "Unsupported architecture: $ARCH\n\nPlease use aarch64."
    clear
    exit 1
fi

# Temperature Check
check_temperature() {
    local temp_warn=60.0
    local temp_crit=70.0
    local temp

    if ! command -v vcgencmd >/dev/null 2>&1; then
        show_info "Temperature Check" "Warning: vcgencmd not found - temperature check skipped"
        return 0
    fi

    if ! temp=$(vcgencmd measure_temp | grep -oP '\d+\.\d+'); then
        show_info "Temperature Check" "Warning: Failed to read temperature"
        return 0
    fi

    show_info "Temperature Check" "CPU Temperature: ${temp}°C"

    if (( $(echo "$temp > $temp_crit" | bc -l) )); then
        show_error "Temperature Critical" "Temperature is critically high (${temp}°C > ${temp_crit}°C)\n\nPlease ensure proper cooling before continuing"
        return 1
    fi

    if (( $(echo "$temp > $temp_warn" | bc -l) )); then
        show_error "Temperature Warning" "Temperature is high (${temp}°C > ${temp_warn}°C)"
        if ! get_user_input "Continue anyway?" "n"; then
            return 1
        fi
    fi

    return 0
}

if ! check_temperature; then
    clear
    exit 1
fi

# Internet Connectivity Check
check_internet() {
    local timeout=2
    local hosts=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")
    local success=false

    show_info "Internet Check" "Checking internet connectivity...\nPlease wait..."
    
    for host in "${hosts[@]}"; do
        if ping -c 1 -W "$timeout" "$host" > /dev/null 2>&1; then
            success=true
            break
        fi
    done

    if ! $success; then
        show_error "Internet Connection Failed" "No internet connectivity detected.\n\nPlease check:\n  • Network cable/WiFi connection\n  • Router/gateway configuration\n  • DNS settings\n  • Firewall rules"
        
        if [ "$NONINTERACTIVE" = "1" ]; then
            return 1
        fi

        # Use dialog menu for retry options
        choice=$(show_menu "Internet Connectivity" \
            1 "Retry check" \
            2 "Continue anyway (not recommended)" \
            3 "Exit" 2>&1 >/dev/tty)

        case ${choice:-3} in
            1) return 2 ;; # Retry
            2) return 0 ;; # Continue
            *) return 1 ;; # Exit
        esac
    fi

    show_info "Internet Check" "Internet connectivity verified!"
    return 0
}

while true; do
    if check_internet; then
        break
    elif [ $? -eq 2 ]; then
        continue
    else
        clear
        exit 1
    fi
done

#