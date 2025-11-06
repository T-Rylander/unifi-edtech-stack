#!/bin/bash

# first-run.sh: Pi Priming for UniFi Edtech Stack (Merged: Checks + Scaffold)
# Run as sudo on fresh Bookworm/Trixie. Idempotent where possible.
#
# === Running Modes ===
# Default: Non-interactive mode (recommended for reliable automation)
#   ./first-run.sh
#   # or explicitly:
#   NONINTERACTIVE=1 ./first-run.sh
#
# Optional: Interactive mode with dialog prompts (requires dialog package)
#   NONINTERACTIVE=0 ./first-run.sh
#
# Note: Non-interactive mode uses safe defaults and logs all decisions.
#       Check ~/unifi-logs/setup.log for detailed output.

# Script configuration
NONINTERACTIVE=${NONINTERACTIVE:-1}  # Set to 1 for non-interactive mode
DEFAULT_ANSWER=${DEFAULT_ANSWER:-"n"} # Default answer for prompts in non-interactive mode
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30} # Timeout for user input
LOGFILE="$HOME/unifi-logs/setup.log"  # Persistent log (old script nod)

# Early log dir & tee setup (fail-fast if can't write)
mkdir -p ~/unifi-logs
exec > >(tee -a "$LOGFILE") 2>&1  # Log everything, everywhere all at once

# Check if dialog is installed (new script base)
if ! command -v dialog >/dev/null 2>&1; then
    echo "$(date): Installing dialog for interactive prompts..." | tee -a "$LOGFILE"
    sudo apt-get update
    sudo apt-get install -y dialog
fi

# Helper function for getting user input with dialog (new)
get_user_input() {
    local prompt="$1"
    local default=${2:-"n"}
    local timeout=${3:-$TIMEOUT_SECONDS}

    if [ "$NONINTERACTIVE" = "1" ]; then
        echo "$(date): $prompt (non-interactive mode, using default: $default)" | tee -a "$LOGFILE"
        if [[ "$default" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi

    # If not attached to a terminal, fall back to default
    if [ ! -t 0 ]; then
        echo "$(date): $prompt (no TTY, using default: $default)" | tee -a "$LOGFILE"
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

# Helper function for info messages (new)
show_info() {
    local title="$1"
    local message="$2"
    if [ "$NONINTERACTIVE" = "0" ] && [ -t 0 ]; then
        dialog --infobox "$message" 10 60
        sleep 2
    else
        echo "$(date): INFO [$title]: $message" | tee -a "$LOGFILE"
    fi
}

# Helper function for error messages (new)
show_error() {
    local title="$1"
    local message="$2"
    if [ "$NONINTERACTIVE" = "0" ] && [ -t 0 ]; then
        dialog --msgbox "$message" 15 60
    else
        echo "$(date): ERROR [$title]: $message" | tee -a "$LOGFILE"
    fi
}

# Helper function for menu selection (new)
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    if [ "$NONINTERACTIVE" = "0" ] && [ -t 0 ]; then
        # dialog writes the tag to stderr by default; capture and echo it so callers can use command substitution
        local dlg_out
        dlg_out=$(dialog --menu "$title" 15 60 10 "${options[@]}" 2>&1 >/dev/tty) || true
        echo "$dlg_out"
    else
        echo "$(date): MENU [$title]: Non-interactive fallback to default" | tee -a "$LOGFILE"
        echo "1"  # Default to first option in headless
    fi
}

set -euo pipefail  # Fail fast, no loose ends (old)

echo "$(date): === first-run.sh Started: Edtech Pi Bootstrap ===" | tee -a "$LOGFILE"

# === Phase 0: Pre-Flight Checks (New Script Core) ===
show_info "OS Check" "Verifying Raspbian/Debian..."

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
    show_info "OS Check" "✓ $PRETTY_NAME ($VERSION_ID) - Good to go."
    return 0
}

if ! check_os_version; then
    echo "$(date): OS check failed - Exiting." | tee -a "$LOGFILE"
    clear
    exit 1
fi

# Architecture Check (new)
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    show_error "Architecture Check Failed" "Unsupported architecture: $ARCH\n\nPlease use aarch64."
    echo "$(date): Arch mismatch - Exiting." | tee -a "$LOGFILE"
    clear
    exit 1
fi
show_info "Arch Check" "✓ aarch64 confirmed - ARM64 party."

# Temperature Check (new, with bc install if needed)
check_temperature() {
    local temp_warn=60.0
    local temp_crit=70.0
    local temp

    # Install bc if missing (old script pulls it later, but front-load for math)
    if ! command -v bc >/dev/null 2>&1; then
        echo "$(date): Installing bc for temp math..." | tee -a "$LOGFILE"
        sudo apt-get install -y bc
    fi

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
    echo "$(date): Temp check failed - Exiting." | tee -a "$LOGFILE"
    clear
    exit 1
fi

# Internet Connectivity Check (new, with loop)
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

        # Use dialog/menu for retry options; show_menu itself handles dialog capture
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

    show_info "Internet Check" "Internet connectivity verified!"
    return 0
}

while true; do
    if check_internet; then
        break
    elif [ $? -eq 2 ]; then
        continue
    else
        echo "$(date): Internet check failed - Exiting." | tee -a "$LOGFILE"
        clear
        exit 1
    fi
done

# Storage Check (old Phase 1 snippet, idempotent)
echo "$(date): === Phase 1: Storage Prereqs ===" | tee -a "$LOGFILE"
FREE_GB=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
if (( $(echo "$FREE_GB < 98" | bc -l) )); then
    show_error "Storage Check Failed" "Need 98GB+ free on /. Got ${FREE_GB}GB. Bail."
    exit 1
fi
show_info "Storage Check" "✓ ${FREE_GB}GB free - SSD green-lit."

# === Phase 2: System Update & Packages (Old, with dialog skip) ===
echo "$(date): === Phase 2: System Update & Packages ===" | tee -a "$LOGFILE"
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release ufw nmap htop bc  # bc already handled
show_info "Packages" "Core utils installed - hardening the nest."

# Docker GPG/Repo setup (old guide exact)
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin iptables-persistent netfilter-persistent
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker "$USER"  # For mtrvs or whoever's SSH'd in
show_info "Docker Install" "✓ Docker: $(docker --version). Re-login for group perms."

# === Phase 3: Static IP & Hostname Lock (Old) ===
echo "$(date): === Phase 3: Static IP & Hostname ===" | tee -a "$LOGFILE"
HOSTNAME="unifi-pi"
IP="192.168.1.52/24"  # Tweakable—edtech LAN default
ROUTER="192.168.1.1"
DNS="192.168.1.1 8.8.8.8"
sudo hostnamectl set-hostname "$HOSTNAME"
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak  # Safety net
cat >> /etc/dhcpcd.conf << EOF
interface eth0
static ip_address=$IP
static routers=$ROUTER
static domain_name_servers=$DNS
EOF
sudo systemctl restart dhcpcd
sleep 5  # Let it settle
if ! ip addr show eth0 | grep -q "$IP"; then
    show_error "IP Assignment Failed" "Static IP not bound. Check cabling/router."
    exit 1
fi
show_info "Network Lock" "✓ $HOSTNAME @ $IP. Ping your router to confirm."

# === Phase 4: Firewall Basics (Old) ===
echo "$(date): === Phase 4: Firewall Basics ===" | tee -a "$LOGFILE"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh  # Keep the door cracked for now
sudo ufw --force enable
show_info "UFW Setup" "✓ Paranoid defaults. Full UniFi rules post-deploy."

# === Phase 5: Git Clone & Scaffold (Path-Agnostic) ===
echo "$(date): === Phase 5: Repo Sync & Volumes ===" | tee -a "$LOGFILE"

# Handle custom repo path with fallbacks
REPO_PATH="${REPO_PATH:-}"  # Allow env var override
REPO_NAME="unifi-edtech-stack"
HOME_DIR=$(eval echo ~"$USER")

# Detect if script is running from a different repo path
if [ -z "$REPO_PATH" ]; then
    # Try to detect the repo path from script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        REPO_PATH="$(dirname "$SCRIPT_DIR")"
    fi
fi

show_info "Repository" "Checking repository setup..."

# Change to home directory
cd "$HOME_DIR" || exit 1

# If we have a custom repo path, create a symlink if needed
if [ -n "$REPO_PATH" ] && [ -d "$REPO_PATH" ] && [ ! -d "$REPO_NAME" ]; then
    show_info "Repository" "Creating symlink from $REPO_PATH to ~/$REPO_NAME"
    ln -sf "$REPO_PATH" "$REPO_NAME"
    echo "$(date): Created symlink from $REPO_PATH to ~/$REPO_NAME" | tee -a "$LOGFILE"
fi

# Clone or update repo
if [ ! -d "$REPO_NAME" ]; then
    show_info "Repository" "Cloning fresh repository..."
    git clone https://github.com/T-Rylander/unifi-edtech-stack.git
    cd "$REPO_NAME" || exit 1
    echo "$(date): Cloned fresh repository to ~/$REPO_NAME" | tee -a "$LOGFILE"
else
    cd "$REPO_NAME" || exit 1
    if [ -d .git ]; then
        show_info "Repository" "Updating existing repository..."
        git pull
        echo "$(date): Updated existing repository in ~/$REPO_NAME" | tee -a "$LOGFILE"
    fi
fi
mkdir -p unifi-data/{mongo,unifi/{db,logs,run,backup}}
chown -R "$USER":"$USER" unifi-data && chmod -R 755 unifi-data
show_info "Repo Scaffold" "✓ Cloned/scaffolded. Data vols prepped for Docker."

echo "$(date): === All Clear: Reboot Recommended ===" | tee -a "$LOGFILE"
show_info "Bootstrap Complete" "Run 'sudo reboot' now. Post-reboot: cd ~/unifi-edtech-stack/docker && docker compose up -d\nLogs: tail -f $LOGFILE"
clear  # Clean console exit