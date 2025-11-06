#!/bin/bash
#
# UniFi Edtech Stack First Run Script
# Configures a Raspberry Pi for UniFi Controller deployment
# 
# Usage: ./first-run.sh [--non-interactive] [--force-warn]
#
# Security: Set strict mode and error handling
set -euo pipefail
umask 022

# Script configuration (must be before trap)
readonly VERSION="1.0.0"
readonly NONINTERACTIVE=${NONINTERACTIVE:-1}
readonly DEFAULT_ANSWER=${DEFAULT_ANSWER:-"n"}
readonly AUTO_DETECT_ON_FRESH=${AUTO_DETECT_ON_FRESH:-1}
readonly TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30}
readonly MAX_BACKUPS=10  # Cap number of backups to prevent menu overload
readonly LOGFILE="${HOME}/unifi-logs/setup.log"
readonly CONFIG_FILE="/etc/unifi-edtech/config.env"
readonly CONFIG_DIR="$(dirname "$CONFIG_FILE")"

# Parse command line arguments
AUTO_DETECT=0
for arg in "$@"; do
    case $arg in
        --auto-detect)
            AUTO_DETECT=1
            ;;
        --help)
            echo "Usage: $0 [--non-interactive] [--auto-detect] [--force-warn]"
            echo "  --non-interactive  Run without user prompts"
            echo "  --auto-detect     Auto-detect network settings"
            echo "  --force-warn      Continue despite warnings"
            exit 0
            ;;
    esac
done

# Helper function to detect and validate network settings
detect_network_settings() {
    local detected_ip default_route default_dns iface dns dns_valid

    log "INFO" "Detecting network settings..."

    # Find primary network interface (excluding docker/veth/lo)
    iface=$(ip -o link show | awk -F': ' '$2 !~ /^(docker|veth|lo)/ {print $2}' | head -n1)
    if [ -z "$iface" ]; then
        log "ERROR" "No suitable network interface found"
        return 1
    fi
    log "DEBUG" "Primary interface detected: $iface"

    # Get primary IP with validation
    detected_ip=$(ip -o -4 addr show dev "$iface" | awk '{print $4}' | head -n1 || true)
    if [ -z "$detected_ip" ]; then
        log "WARN" "No IPv4 address detected on $iface, using fallback"
        detected_ip="192.168.1.52/24"
    else
        if ! [[ "$detected_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            log "WARN" "Invalid IP format detected ($detected_ip), using fallback"
            detected_ip="192.168.1.52/24"
        fi
    fi
    log "DEBUG" "IP detected: $detected_ip"

    # Get default gateway with validation
    default_route=$(ip route show default | awk '{print $3}' | head -n1 || true)
    if [ -z "$default_route" ] || ! ping -c 1 -W 2 "$default_route" >/dev/null 2>&1; then
        log "WARN" "Default gateway not responding or missing, using fallback"
        default_route="192.168.1.1"
    fi
    log "DEBUG" "Router detected: $default_route"

    # Get DNS servers with validation
    if [ -f /etc/resolv.conf ]; then
        default_dns=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | paste -sd ' ' || true)
        dns_valid=1
        for dns in $default_dns; do
            if ! ping -c 1 -W 2 "$dns" >/dev/null 2>&1; then
                dns_valid=0
                break
            fi
        done
        if [ "$dns_valid" -ne 1 ]; then
            log "WARN" "DNS servers not responding, using fallback"
            default_dns="8.8.8.8 1.1.1.1"
        fi
    else
        log "WARN" "resolv.conf not found, using fallback DNS"
        default_dns="8.8.8.8 1.1.1.1"
    fi
    log "DEBUG" "DNS servers detected: $default_dns"

    # Return detected and validated values
    echo "IP=${detected_ip}"
    echo "ROUTER=${default_route}"
    echo "DNS=${default_dns}"

    log "INFO" "Network detection complete"
    return 0
}
readonly ERROR_LOGFILE="${HOME}/unifi-logs/error.log"
readonly LOCKFILE="/tmp/unifi-setup.lock"

# Source OS release early so PRETTY_NAME and ID are available
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    PRETTY_NAME=${PRETTY_NAME:-$NAME}
else
    PRETTY_NAME="Unknown OS"
fi

# Dependency check (ensure required commands exist)
check_dependencies() {
    local required_cmds=(
        "bash" "curl" "sudo" "tee" "find" "awk" "grep" "sed" "ping" "mkdir" "chmod" "flock"
    )
    local optional_cmds=(
        "dialog" "docker" "vcgencmd" "bc" "wg" "ollama"
    )

    local missing=()
    for cmd in "${required_cmds[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Missing required commands: ${missing[*]}" >&2
        return 1
    fi

    for cmd in "${optional_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "WARN: Optional command not found: $cmd" >&2
        fi
    done

    return 0
}

# Acquire a lock using flock to prevent concurrent runs
acquire_lock() {
    local lf="$LOCKFILE"
    # Ensure lock directory exists
    local lockdir
    lockdir=$(dirname "$lf")
    if [ ! -d "$lockdir" ]; then
        if ! sudo mkdir -p "$lockdir" 2>/dev/null; then
            echo "ERROR: Cannot create lock directory $lockdir" >&2
            exit 1
        fi
    fi

    # Open file descriptor 200 for locking
    exec 200>"$lf" || {
        echo "ERROR: Cannot open lockfile $lf" >&2
        exit 1
    }

    if ! flock -n 200; then
        echo "ERROR: Another instance is running (lock: $lf)" >&2
        exit 1
    fi

    # Write PID for diagnostics (kept on FD 200)
    # Record current PID (simplified)
    echo "$$" 1>&200 || true

    # Ensure unlock and remove on exit
    trap 'flock -u 200; rm -f "$lf" 2>/dev/null || true' EXIT
}

# Ensure directories exist
mkdir -p "$(dirname "$LOGFILE")" "$(dirname "${ERROR_LOGFILE}")"

# Check for required external commands
if ! check_dependencies; then
    show_error "Startup" "Missing required dependencies. Please install them and retry."
    exit 1
fi

# Create config directory with error handling
if ! sudo mkdir -p "$CONFIG_DIR" 2>/dev/null; then
    show_error "Startup" "Failed to create config directory: $CONFIG_DIR (try running with sudo)"
    exit 1
fi

# Acquire a lock to avoid concurrent runs
acquire_lock

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    log "INFO" "Creating default configuration file..."
    # Enable auto-detect by default for fresh installations
    AUTO_DETECT=1
    sudo tee "$CONFIG_FILE" > /dev/null << 'EOF'
# UniFi Edtech Stack Configuration
HOSTNAME="unifi-pi"
IP="192.168.1.52/24"
ROUTER="192.168.1.1"
DNS="192.168.1.1 8.8.8.8"
TZ="America/Chicago"

# Auto-detect behavior for fresh installs
AUTO_DETECT_ON_FRESH=1

# Optional QR artifact creation (0/1)
ENABLE_QR=1

# Security Settings
ENABLE_APPARMOR=1
ENABLE_FAIL2BAN=1
SSH_KEY_ONLY=1

# Docker Settings
DOCKER_NETWORK="unifi-net"
DOCKER_SUBNET="172.20.0.0/16"

# UniFi Controller Settings
UNIFI_HTTPS_PORT=8443
UNIFI_HTTP_PORT=8080
UNIFI_STUN_PORT=3478
JVM_MAX_HEAP_SIZE=512M

# WireGuard Settings
WG_PORT=51820
WG_NETWORK="10.10.0.0/24"
WG_PEERS=1
SERVERURL="auto"
PEERDNS="auto"

# AI Settings
ENABLE_OLLAMA=1

# Edtech API Settings
LOG_LEVEL="INFO"
RATE_LIMIT="10/minute"
# API key for securing edtech-api requests (set a strong value!)
API_KEY=""
EOF
    sudo chmod 600 "$CONFIG_FILE"
fi

# Source config file with validation
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    show_error "Config" "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Logging function (must be before trap)
log() {
    local level=$1
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOGFILE"
}

# Cleanup function (must be before trap)
cleanup() {
    local exit_code=$?
    log "INFO" "Cleaning up..."
    
    # Rotate logs if they get too large (10MB) with a 3-file cap: .1, .2, .3
    for logfile in "$LOGFILE" "$ERROR_LOGFILE"; do
        if [ -f "$logfile" ]; then
            local size
            size=$(wc -c < "$logfile" 2>/dev/null || echo 0)
            if [ "$size" -gt 10485760 ]; then
                # Prune oldest if present
                if [ -f "${logfile}.3" ]; then
                    rm -f "${logfile}.3" || true
                fi
                # Shift 2->3, 1->2
                if [ -f "${logfile}.2" ]; then
                    mv "${logfile}.2" "${logfile}.3" 2>/dev/null || true
                fi
                if [ -f "${logfile}.1" ]; then
                    mv "${logfile}.1" "${logfile}.2" 2>/dev/null || true
                fi
                # Move current to .1 and create new empty log
                mv "$logfile" "${logfile}.1" 2>/dev/null || true
                : > "$logfile"
            fi
        fi
    done

    # Clean up any temporary files
    if [ -d "/tmp/unifi_setup" ]; then
        rm -rf "/tmp/unifi_setup"
        log "DEBUG" "Removed temporary directory"
    fi
    
    # Restore terminal settings if needed
    if [ "$NONINTERACTIVE" = "0" ]; then
        clear
    fi
    
    # Log final status
    if [ $exit_code -eq 0 ]; then
        log "INFO" "Script completed successfully"
    else
        log "ERROR" "Script failed with exit code $exit_code"
    fi
}

# Trap errors and cleanup
trap 'log "ERROR" "Error on line $LINENO. Exit code: $?"' ERR
trap cleanup EXIT

# Check if dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    log "INFO" "Installing dialog package..."
    sudo apt-get update
    sudo apt-get install -y dialog
fi

# Helper function for getting user input with dialog
get_user_input() {
    local prompt="$1"
    local default=${2:-"n"}
    local timeout=${3:-$TIMEOUT_SECONDS}

    if [ "$NONINTERACTIVE" = "1" ]; then
        log "DEBUG" "Non-interactive mode: $prompt (default: $default)"
        if [[ "$default" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi

    # If not attached to a terminal, fall back to default
    if [ ! -t 0 ]; then
        log "WARN" "No TTY available: $prompt (default: $default)"
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

# Helper function for info messages with error handling
show_info() {
    local title="$1"
    local message="$2"
    
    log "INFO" "[$title] $message"
    
    if [ "$NONINTERACTIVE" = "1" ] || [ ! -t 0 ]; then
        return 0
    fi
    
    if command -v dialog >/dev/null 2>&1; then
        if ! dialog --infobox "$message" 10 60 2>/dev/null; then
            log "WARN" "Failed to show dialog info box"
            echo "[$title] $message"
        fi
        sleep 2
    else
        # Fallback to echo if dialog unavailable
        echo "[$title] $message"
    fi
}

# Helper function for error messages with enhanced handling
show_error() {
    local title="$1"
    local message="$2"
    
    log "ERROR" "[$title] $message"
    
    # Also log to error file
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] [$title] $message" >> "$ERROR_LOGFILE"
    
    if [ "$NONINTERACTIVE" = "1" ] || [ ! -t 0 ]; then
        return 0
    fi
    
    if command -v dialog >/dev/null 2>&1; then
        if ! dialog --title "ERROR: $title" --msgbox "$message" 15 60 2>/dev/null; then
            log "WARN" "Failed to show dialog error box"
            echo "ERROR: [$title] $message" >&2
        fi
    else
        # Fallback to echo if dialog unavailable
        echo "ERROR: [$title] $message" >&2
    fi
}

# Helper function for menu selection
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    if [ "$NONINTERACTIVE" = "1" ]; then
        log "DEBUG" "$title (non-interactive mode, using default: 1)"
        echo "1"
        return
    fi
    
    dialog --menu "$title" 15 60 10 "${options[@]}"
}

# Backup configuration function
backup_config() {
    local backup_dir="$HOME/unifi-backups/$(date '+%Y-%m-%d_%H%M%S')"
    mkdir -p "$backup_dir"
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$backup_dir/config.env"
        log "INFO" "Configuration backed up to $backup_dir/config.env"
        return 0
    else
        log "ERROR" "No configuration file found to backup"
        return 1
    fi
}

# Restore configuration function
restore_config() {
    if [ "$NONINTERACTIVE" = "1" ]; then
        log "INFO" "Skipping config restore in non-interactive mode"
        return 0
    fi

    if ! get_user_input "Would you like to restore a configuration?" "n"; then
        return 0
    fi

    local backup_dir="$HOME/unifi-backups"
    if [ ! -d "$backup_dir" ]; then
        show_error "Config" "No backup directory found at $backup_dir"
        return 1
    fi

    local -a backup_files
    while IFS= read -r -d '' file; do
        backup_files+=("$file")
    done < <(find "$backup_dir" -type f -name "config.env" -print0 | sort -rz)

    if [ ${#backup_files[@]} -eq 0 ]; then
        show_error "Config" "No backup files found in $backup_dir"
        return 1
    fi

    local options=()
    for file in "${backup_files[@]}"; do
        local timestamp=$(basename "$(dirname "$file")")
        options+=("$timestamp" "Backup from $timestamp")
    done

    local choice
    choice=$(show_menu "Select Backup to Restore" "${options[@]}")
    if [ -n "$choice" ]; then
        local selected_file
        selected_file=$(find "$backup_dir" -type f -path "*/$choice/config.env")
        if [ -f "$selected_file" ]; then
            # Backup current config before restore
            backup_config
            
            sudo cp "$selected_file" "$CONFIG_FILE"
            sudo chmod 600 "$CONFIG_FILE"
            log "INFO" "Configuration restored from $selected_file"
            return 0
        fi
    fi

    show_error "Config" "Failed to restore configuration"
    return 1
}

# Validate user input with retries
validate_input() {
    local prompt="$1"
    local value="$2"
    local validator="$3"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ -n "$value" ] && eval "$validator \"\$value\""; then
            echo "$value"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            value=$(dialog --inputbox "$prompt (attempt $attempt of $max_attempts)" 10 60 "$value" 2>&1 >/dev/tty) || true
        fi
        
        ((attempt++))
    done
    
    return 1
}

# IP CIDR format validator
validate_cidr() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
    
    local IFS='.' read -r -a octets <<< "${ip%/*}"
    local mask="${ip#*/}"
    
    # Validate octets
    for octet in "${octets[@]}"; do
        (( octet >= 0 && octet <= 255 )) || return 1
    done
    
    # Validate mask
    (( mask >= 0 && mask <= 32 )) || return 1
    return 0
}

# Configuration wizard function
config_wizard() {
    if [ "$NONINTERACTIVE" = "1" ]; then
        return 0
    fi

    if ! get_user_input "Would you like to configure settings interactively?" "n"; then
        return 0
    fi

    log "INFO" "Starting configuration wizard..."
    
    # Network Configuration
    local new_hostname
    new_hostname=$(dialog --inputbox "Enter hostname:" 10 60 "$HOSTNAME" 2>&1 >/dev/tty) || true
    if [ -n "$new_hostname" ]; then
        HOSTNAME="$new_hostname"
    fi

    # Validate IP with retries
    local new_ip
    new_ip=$(validate_input "Enter IP address (CIDR format, e.g., 192.168.1.52/24)" "$IP" validate_cidr)
    if [ -n "$new_ip" ]; then
        IP="$new_ip"
    else
        show_error "Config" "Failed to validate IP after multiple attempts"
        return 1
    fi

    # Security Configuration
    if dialog --yesno "Enable AppArmor?" 10 60; then
        ENABLE_APPARMOR=1
    else
        ENABLE_APPARMOR=0
    fi

    if dialog --yesno "Enable Fail2Ban?" 10 60; then
        ENABLE_FAIL2BAN=1
    else
        ENABLE_FAIL2BAN=0
    fi

    # Save changes
    backup_config
    save_config
    log "INFO" "Configuration updated through wizard and persisted"
    return 0
}

# Status reporting function
show_status() {
    local status=(
        "System: $PRETTY_NAME"
        "Architecture: $ARCH"
        "Hostname: $HOSTNAME"
        "IP: $IP"
        "Docker: $(docker --version 2>/dev/null || echo 'Not installed')"
        "Security: $(aa-status --enabled 2>/dev/null && echo 'AppArmor enabled' || echo 'AppArmor disabled')"
        "AI Ready: $(command -v ollama >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
        "WireGuard: $(command -v wg >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    )
    
    log "INFO" "Status Report:"
    printf '%s\n' "${status[@]}" | tee -a "$LOGFILE"
}

# Persist current in-memory configuration back to CONFIG_FILE safely
save_config() {
    if [ -z "${CONFIG_FILE:-}" ]; then
        log "ERROR" "CONFIG_FILE variable unset; cannot persist configuration"
        return 1
    fi
    local tmp_file
    tmp_file="/tmp/config.$$"
    cat > "$tmp_file" <<EOF
# UniFi Edtech Stack Configuration (generated by wizard)
HOSTNAME="${HOSTNAME}"
IP="${IP}"
ROUTER="${ROUTER}"
DNS="${DNS}"
TZ="${TZ:-America/Chicago}"
AUTO_DETECT_ON_FRESH="${AUTO_DETECT_ON_FRESH}"
ENABLE_QR="${ENABLE_QR:-1}"
ENABLE_APPARMOR="${ENABLE_APPARMOR:-1}"
ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN:-1}"
SSH_KEY_ONLY="${SSH_KEY_ONLY:-1}"
DOCKER_NETWORK="${DOCKER_NETWORK}"
DOCKER_SUBNET="${DOCKER_SUBNET}"
UNIFI_HTTPS_PORT="${UNIFI_HTTPS_PORT:-8443}"
UNIFI_HTTP_PORT="${UNIFI_HTTP_PORT:-8080}"
UNIFI_STUN_PORT="${UNIFI_STUN_PORT:-3478}"
JVM_MAX_HEAP_SIZE="${JVM_MAX_HEAP_SIZE:-512M}"
WG_PORT="${WG_PORT}"
WG_NETWORK="${WG_NETWORK}"
WG_PEERS="${WG_PEERS:-1}"
SERVERURL="${SERVERURL:-auto}"
PEERDNS="${PEERDNS:-auto}"
ENABLE_OLLAMA="${ENABLE_OLLAMA:-1}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
RATE_LIMIT="${RATE_LIMIT:-10/minute}"
API_KEY="${API_KEY:-}"
EOF
    if sudo cp "$tmp_file" "$CONFIG_FILE" 2>/dev/null; then
        sudo chmod 600 "$CONFIG_FILE"
        log "INFO" "Configuration persisted to $CONFIG_FILE"
    else
        log "ERROR" "Failed to persist configuration to $CONFIG_FILE"
        rm -f "$tmp_file" || true
        return 1
    fi
    rm -f "$tmp_file" || true
    return 0
}

# Configuration validation with extended checks
validate_config() {
    local required_vars=(
        "HOSTNAME"
        "IP"
        "ROUTER"
        "DNS"
        "DOCKER_NETWORK"
        "DOCKER_SUBNET"
        "WG_PORT"
        "WG_NETWORK"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            show_error "Config" "Missing required variable: $var"
            return 1
        fi
    done
    
    # Validate IP formats
    local ip_vars=("IP" "DOCKER_SUBNET" "WG_NETWORK")
    for var in "${ip_vars[@]}"; do
        if ! [[ "${!var}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            show_error "Config" "Invalid network format for $var: ${!var}"
            return 1
        fi
    done
    
    # Validate port number
    if ! [[ "$WG_PORT" =~ ^[0-9]+$ ]] || (( WG_PORT < 1 || WG_PORT > 65535 )); then
        show_error "Config" "Invalid port number for WG_PORT: $WG_PORT"
        return 1
    fi
    
    # Validate boolean settings
    local bool_vars=("ENABLE_APPARMOR" "ENABLE_FAIL2BAN" "SSH_KEY_ONLY" "ENABLE_OLLAMA")
    for var in "${bool_vars[@]}"; do
        if ! [[ "${!var:-0}" =~ ^[01]$ ]]; then
            show_error "Config" "Invalid boolean value for $var: ${!var}"
            return 1
        fi
    done
    
    return 0
}

# Security check function
check_security() {
    local issues=()
    
    log "INFO" "Performing security checks..."
    
    # Check SSH key-only access
    if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
        issues+=("SSH password authentication is enabled")
    fi
    
    # Check if AppArmor is enabled
    if ! command -v aa-status >/dev/null 2>&1 || ! aa-status --enabled; then
        issues+=("AppArmor is not enabled")
    fi
    
    # Check if Fail2Ban is installed
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        issues+=("Fail2Ban is not installed")
    fi
    
    if (( ${#issues[@]} > 0 )); then
        show_error "Security Check" "Security issues found:\n • ${issues[*]/#/\n • }"
        if [ "$NONINTERACTIVE" = "1" ]; then
            log "WARN" "Continuing despite security issues in non-interactive mode"
            return 0
        fi
        return 1
    fi
    return 0
}

# Validate configuration before proceeding
if ! validate_config; then
    log "ERROR" "Configuration validation failed"
    exit 1
fi

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

# Helper function for lazy package installation with retries
install_package() {
    local package="$1"
    local desc="${2:-$package}"
    local max_retries=3
    local retry_count=0
    
    # Use dpkg -s to accurately detect install status
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        show_info "Dependencies" "Installing $desc..."
        
        while (( retry_count < max_retries )); do
            if ! sudo apt-get update >/dev/null 2>&1; then
                log "WARN" "Failed to update package lists (attempt $((retry_count + 1)))"
            fi
            
            if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >>"$LOGFILE" 2>&1; then
                log "INFO" "Successfully installed $desc"
                return 0
            else
                (( retry_count++ ))
                if (( retry_count < max_retries )); then
                    log "WARN" "Failed to install $desc (attempt $retry_count/$max_retries) - retrying in 5s..."
                    sleep 5
                else
                    log "ERROR" "Failed to install $desc after $max_retries attempts"
                    return 1
                fi
            fi
        done
    else
        log "DEBUG" "Package $desc already installed"
    fi
    return 0
}

# Temperature Check
check_temperature() {
    local temp_warn=60.0
    local temp_crit=70.0
    local temp

    if ! command -v vcgencmd >/dev/null 2>&1; then
        show_info "Temperature Check" "Warning: vcgencmd not found - temperature check skipped"
        return 0
    fi

    # Ensure bc is available for float comparison
    if ! command -v bc >/dev/null 2>&1; then
        if ! install_package bc "bc (required for temperature check)"; then
            show_info "Temperature Check" "Warning: Could not install bc - temperature check skipped"
            return 0
        fi
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

# Internet Connectivity Check with retry mechanism (returns 0 success, 1 fail/exit, 2 retry)
check_internet() {
    local timeout=2
    local hosts=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")
    local max_retries=3
    local success=false
    local retry_count=0

    log "INFO" "Checking internet connectivity..."
    show_info "Internet Check" "Checking internet connectivity...\nPlease wait..."

    while (( retry_count < max_retries )); do
        for host in "${hosts[@]}"; do
            log "DEBUG" "Trying to reach $host..."
            if ping -c 1 -W "$timeout" "$host" > /dev/null 2>&1; then
                success=true
                log "INFO" "Successfully connected to $host"
                break 2
            fi
        done
        (( retry_count++ ))
        if ! $success && (( retry_count < max_retries )); then
            log "WARN" "Attempt $retry_count failed, retrying in 2 seconds..."
            sleep 2
        fi
    done

    if ! $success; then
        local error_msg="No internet connectivity detected after $retry_count attempts.\n\nPlease check:\n"
        error_msg+="  • Network cable/WiFi connection\n"
        error_msg+="  • Router/gateway configuration\n"
        error_msg+="  • DNS settings\n"
        error_msg+="  • Firewall rules"
        show_error "Internet Connection Failed" "$error_msg"
        log "ERROR" "Internet connectivity check failed"
        if [ "$NONINTERACTIVE" = "1" ]; then
            return 1
        fi
        local choice
        choice=$(show_menu "Internet Connectivity" \
            1 "Retry check" \
            2 "Continue anyway (not recommended)" \
            3 "Exit")
        case ${choice:-3} in
            1) return 2 ;; # Retry
            2) return 0 ;; # Continue
            *) return 1 ;; # Exit
        esac
    fi

    # Optional: Warn if Docker Hub unreachable (non-fatal unless user aborts)
    if ! curl -fIs https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
        log "WARN" "Docker Hub unreachable - container pulls may fail"
        if [ "$NONINTERACTIVE" = "0" ]; then
            if ! get_user_input "Continue without Docker Hub access?" "y"; then
                return 2
            fi
        fi
    fi

    log "INFO" "Internet connectivity verified"
    show_info "Internet Check" "✓ Internet connectivity verified!"
    return 0
}

# Try internet connectivity check
while true; do
    if check_internet; then
        break
    elif [ $? -eq 2 ]; then
        log "INFO" "Retrying internet check..."
        continue
    else
        log "ERROR" "Internet check failed - exiting"
        exit 1
    fi
done

# Setup core components
log "INFO" "=== Starting Core Components Setup ==="

# Docker setup function with comprehensive validation
setup_docker() {
    local compose_version
    local max_retries=3
    local retry_count=0
    
    log "INFO" "Setting up Docker environment..."
    
    # Install Docker if needed
    if ! command -v docker >/dev/null 2>&1; then
        show_info "Docker" "Installing Docker..."
        while (( retry_count < max_retries )); do
            if curl -fsSL https://get.docker.com | sh >>"$LOGFILE" 2>&1; then
                break
            else
                (( retry_count++ ))
                if (( retry_count < max_retries )); then
                    log "WARN" "Docker installation failed (attempt $retry_count/$max_retries) - retrying in 10s..."
                    sleep 10
                else
                    show_error "Docker" "Failed to install Docker engine after $max_retries attempts"
                    return 1
                fi
            fi
        done
    fi
    
    # Comprehensive Docker validation
    log "INFO" "Validating Docker installation..."
    
    # Check Docker daemon
    if ! sudo systemctl is-active --quiet docker; then
        log "WARN" "Docker daemon not running, attempting to start..."
        sudo systemctl start docker
        sleep 5
    fi
    
    # Validate Docker installation with hello-world
    retry_count=0
    while (( retry_count < max_retries )); do
        if docker run --rm hello-world >>"$LOGFILE" 2>&1; then
            log "INFO" "Docker engine validated successfully"
            break
        else
            (( retry_count++ ))
            if (( retry_count < max_retries )); then
                log "WARN" "Docker validation failed (attempt $retry_count/$max_retries) - retrying in 5s..."
                sleep 5
            else
                show_error "Docker" "Docker validation failed after $max_retries attempts"
                return 1
            fi
        fi
    done
    
    # Verify Docker API access
    if ! docker info >/dev/null 2>&1; then
        show_error "Docker" "Cannot access Docker API - check permissions"
        return 1
    fi
    
    # Verify container networking
    if ! docker run --rm alpine ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        show_error "Docker" "Container networking validation failed"
        return 1
    fi
    
    log "INFO" "Docker validation complete - all checks passed"
    
    # Setup Docker compose
    if ! compose_version=$(docker compose version 2>/dev/null); then
        show_info "Docker" "Installing Docker Compose..."
        sudo apt-get install -y docker-compose-plugin
    fi
    
    # Create Docker network for stack
    if ! docker network inspect unifi-net >/dev/null 2>&1; then
        docker network create unifi-net
    fi
    
    # Add current user to docker group
    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        log "WARN" "Added $USER to docker group - please log out and back in"
    fi
    
    return 0
}

# WireGuard setup function
setup_wireguard() {
    log "INFO" "Setting up WireGuard..."
    
    if ! command -v wg >/dev/null 2>&1; then
        show_info "Network" "Installing WireGuard..."
        sudo apt-get install -y wireguard
    fi
    # Ensure key directory and keys exist (idempotent)
    if [ ! -f /etc/wireguard/private.key ]; then
        sudo mkdir -p /etc/wireguard
        sudo sh -c 'wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key'
        sudo chmod 600 /etc/wireguard/private.key
        log "INFO" "WireGuard keys generated"
    fi
    
    return 0
}

# AI components setup function
setup_ai_components() {
    log "INFO" "Setting up AI components..."
    
    # Check for Ollama
    if ! command -v ollama >/dev/null 2>&1; then
        show_info "AI" "Installing Ollama..."
        curl https://ollama.ai/install.sh | sh
    fi
    
    return 0
}

# Run setups in sequence
if ! setup_docker; then
    show_error "Setup" "Docker setup failed"
    exit 1
fi

if ! setup_wireguard; then
    show_error "Setup" "WireGuard setup failed"
    exit 1
fi

if ! setup_ai_components; then
    log "WARN" "AI components setup failed - continuing anyway"
fi

# Run security checks
if ! check_security; then
    if [ "$NONINTERACTIVE" = "1" ]; then
        log "WARN" "Security checks failed but continuing in non-interactive mode"
    else
        show_error "Security" "Please address security issues before continuing"
        exit 1
    fi
fi

# Final configuration and status steps
backup_config

# Cleanup old backups (keep only MAX_BACKUPS most recent)
cleanup_old_backups() {
    local backup_dir="$HOME/unifi-backups"
    if [ -d "$backup_dir" ]; then
        local count
        count=$(find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$count" -gt "$MAX_BACKUPS" ]; then
            log "INFO" "Cleaning up old backups (keeping $MAX_BACKUPS most recent)..."
            find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | sort | head -n -"$MAX_BACKUPS" | xargs rm -rf
        fi
    fi
}
cleanup_old_backups

## Show final status and next steps
log "INFO" "=== Setup Complete ==="

# Create setup completion flag and optional QR code (controlled by ENABLE_QR)
# The flag and QR are created under $CONFIG_DIR so they don't require hard-coded /etc paths.
if [ "${ENABLE_QR:-1}" -eq 1 ]; then
    sudo mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    if command -v qrencode >/dev/null 2>&1; then
        sudo qrencode -o "$CONFIG_DIR/setup-complete.png" "$(pwd)/docs/FIRST-RUN.md" 2>/dev/null || true
    else
        # Try lazy install; if it fails (offline), skip gracefully and log a warning
        if install_package qrencode "qrencode (QR code generator)"; then
            sudo qrencode -o "$CONFIG_DIR/setup-complete.png" "$(pwd)/docs/FIRST-RUN.md" 2>/dev/null || true
        else
            log "WARN" "qrencode unavailable - skipping QR artifact"
        fi
    fi
fi

# Touch a setup-complete flag for automation/monitoring
sudo mkdir -p "$CONFIG_DIR" 2>/dev/null || true
sudo touch "$CONFIG_DIR/setup-complete.flag" 2>/dev/null || true

# Add orchestration handoff note to the logfile
cat << 'EOT' >> "$LOGFILE"
=== Next Steps for Docker Orchestration ===
1. Review docker-compose.yml for:
   - UniFi Controller service (ports 8443)
   - Ollama AI service configuration
   - WireGuard networking setup
2. Check Docker volumes for persistence
3. Validate service health checks
4. Consider Swarm setup for scaling

For more details, see: docs/FIRST-RUN.md
EOT
show_status

show_info "Complete" "Setup completed successfully!\n\nNext steps:\n1. Check logs at $LOGFILE\n2. Review config at $CONFIG_FILE\n3. Log out and back in for Docker permissions"

if [ "$NONINTERACTIVE" = "0" ]; then
    if get_user_input "Would you like to view the full status report?" "y"; then
        clear
        show_status
        read -n 1 -s -r -p "Press any key to continue..."
    fi
fi