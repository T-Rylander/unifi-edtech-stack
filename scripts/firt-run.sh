#!/bin/bash

# OS Version Check
check_os_version() {
    . /etc/os-release
    if [[ ! "$ID" =~ ^(raspbian|debian)$ ]]; then
        echo "Error: This script requires Raspbian or Debian OS"
        return 1
    fi
    
    if [[ ! "$VERSION_ID" =~ ^(12|13)$ ]]; then
        echo "Warning: Unsupported OS version $VERSION_ID ($PRETTY_NAME)"
        echo "This script is tested on Raspbian/Debian 12 (Bookworm) or 13 (Trixie)"
        echo "Continue anyway? (y/n)"
        read -r choice
        [[ "$choice" == "y" ]] || return 1
    fi
    return 0
}

if ! check_os_version; then
    exit 1
fi

# Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "Unsupported architecture: $ARCH. Please use aarch64."
    exit 1
fi

# Temperature Check
check_temperature() {
    local temp_warn=60.0
    local temp_crit=70.0
    local temp

    if ! command -v vcgencmd >/dev/null 2>&1; then
        echo "Warning: vcgencmd not found - temperature check skipped"
        return 0
    fi

    if ! temp=$(vcgencmd measure_temp | grep -oP '\d+\.\d+'); then
        echo "Warning: Failed to read temperature"
        return 0
    fi

    echo "CPU Temperature: ${temp}°C"

    if (( $(echo "$temp > $temp_crit" | bc -l) )); then
        echo "Error: Temperature is critically high (${temp}°C > ${temp_crit}°C)"
        echo "Please ensure proper cooling before continuing"
        return 1
    fi

    if (( $(echo "$temp > $temp_warn" | bc -l) )); then
        echo "Warning: Temperature is high (${temp}°C > ${temp_warn}°C)"
        echo "Continue anyway? (y/n)"
        read -r choice
        [[ "$choice" == "y" ]] || return 1
    fi

    return 0
}

if ! check_temperature; then
    exit 1
fi

# Internet Connectivity Check
check_internet() {
    local timeout=2
    local hosts=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")
    local success=false

    echo "Checking internet connectivity..."
    
    for host in "${hosts[@]}"; do
        echo -n "Testing connection to $host... "
        if ping -c 1 -W "$timeout" "$host" > /dev/null 2>&1; then
            echo "OK"
            success=true
            break
        else
            echo "Failed"
        fi
    done

    if ! $success; then
        echo "ERROR: No internet connectivity detected"
        echo "Please check:"
        echo "  - Network cable/WiFi connection"
        echo "  - Router/gateway configuration"
        echo "  - DNS settings"
        echo "  - Firewall rules"
        
        echo -n "Would you like to:"
        echo "  1) Retry check"
        echo "  2) Continue anyway (not recommended)"
        echo "  3) Exit"
        read -r -p "Choose (1-3): " choice
        
        case $choice in
            1) return 2 ;; # Retry
            2) return 0 ;; # Continue
            *) return 1 ;; # Exit
        esac
    fi

    return 0
}

while true; do
    if check_internet; then
        break
    elif [ $? -eq 2 ]; then
        echo "Retrying internet check..."
        continue
    else
        exit 1
    fi
done

# Storage Check
check_storage() {
    local warn_threshold=80
    local crit_threshold=90
    local min_free_gb=50

    # Get storage metrics
    local total_gb=$(df -B 1G / | awk 'NR==2 {print $2}')
    local free_gb=$(df -B 1G / | awk 'NR==2 {print $4}')
    local used_gb=$((total_gb - free_gb))
    local used_percent=$((used_gb * 100 / total_gb))
    
    # Get inode metrics
    local inodes_total=$(df -i / | awk 'NR==2 {print $2}')
    local inodes_free=$(df -i / | awk 'NR==2 {print $4}')
    local inodes_used=$((inodes_total - inodes_free))
    local inodes_percent=$((inodes_used * 100 / inodes_total))

    # Calculate Docker/UniFi estimated space needs
    local docker_estimate=20
    local unifi_estimate=10
    local total_needed=$((docker_estimate + unifi_estimate))
    
    # Pretty print results
    printf "\nStorage Analysis:\n"
    printf "════════════════════════════════════════\n"
    printf "Disk Space:\n"
    printf "  Total:      %5d GB\n" "$total_gb"
    printf "  Used:       %5d GB (%d%%)\n" "$used_gb" "$used_percent"
    printf "  Free:       %5d GB\n" "$free_gb"
    printf "  Required:   %5d GB (Docker: %dGB, UniFi: %dGB)\n" "$total_needed" "$docker_estimate" "$unifi_estimate"
    
    printf "\nInodes:\n"
    printf "  Total:      %'d\n" "$inodes_total"
    printf "  Used:       %'d (%d%%)\n" "$inodes_used" "$inodes_percent"
    printf "  Free:       %'d\n" "$inodes_free"
    printf "════════════════════════════════════════\n"

    # Check conditions
    local errors=()
    local warnings=()

    if [ "$free_gb" -lt "$min_free_gb" ]; then
        errors+=("Insufficient free space: ${free_gb}GB < ${min_free_gb}GB required")
    fi

    if [ "$used_percent" -gt "$crit_threshold" ]; then
        errors+=("Critical: Storage usage at ${used_percent}% (threshold: ${crit_threshold}%)")
    elif [ "$used_percent" -gt "$warn_threshold" ]; then
        warnings+=("Warning: Storage usage at ${used_percent}% (threshold: ${warn_threshold}%)")
    fi

    if [ "$inodes_percent" -gt "$crit_threshold" ]; then
        errors+=("Critical: Inode usage at ${inodes_percent}% (threshold: ${crit_threshold}%)")
    elif [ "$inodes_percent" -gt "$warn_threshold" ]; then
        warnings+=("Warning: Inode usage at ${inodes_percent}% (threshold: ${warn_threshold}%)")
    fi

    if [ "$free_gb" -lt "$total_needed" ]; then
        errors+=("Insufficient space for Docker+UniFi: need ${total_needed}GB, have ${free_gb}GB free")
    fi

    # Report issues
    if [ ${#errors[@]} -gt 0 ]; then
        printf "\nErrors:\n"
        printf "  • %s\n" "${errors[@]}"
        return 1
    fi

    if [ ${#warnings[@]} -gt 0 ]; then
        printf "\nWarnings:\n"
        printf "  • %s\n" "${warnings[@]}"
        echo -n "Continue despite warnings? (y/n) "
        read -r choice
        [[ "$choice" == "y" ]] || return 1
    fi

    return 0
}

if ! check_storage; then
    exit 1
fi

if ! check_storage; then
    exit 1
fi

# Docker Setup
# (Script continues here, but it appears to be truncated in the original file)