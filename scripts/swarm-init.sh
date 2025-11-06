#!/bin/bash
#
# UniFi Edtech Stack - Docker Swarm Initialization
# Idempotent wrapper for multi-node cluster setup
#
# Usage: 
#   ./swarm-init.sh [--dry-run] [--manager-only]
#
# Security: Set strict mode and error handling
set -euo pipefail
umask 022

# Script configuration
readonly VERSION="0.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="/etc/unifi-edtech/config.env"
readonly LOGFILE="${HOME}/unifi-logs/swarm-init.log"
readonly TOKEN_DIR="/etc/unifi-edtech"
readonly MANAGER_TOKEN_FILE="${TOKEN_DIR}/swarm-manager-token"
readonly WORKER_TOKEN_FILE="${TOKEN_DIR}/swarm-worker-token"

# Parse command line arguments
DRY_RUN=0
MANAGER_ONLY=0

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --manager-only)
            MANAGER_ONLY=1
            shift
            ;;
        --help)
            cat << 'EOF'
Usage: ./swarm-init.sh [OPTIONS]

Initialize Docker Swarm for multi-node UniFi Edtech Stack deployment.

OPTIONS:
  --dry-run        Validate configuration without making changes
  --manager-only   Initialize manager node only (skip token export)
  --help           Show this help message

EXAMPLES:
  # Initialize Swarm on manager node
  sudo bash swarm-init.sh

  # Test configuration without changes
  sudo bash swarm-init.sh --dry-run

  # Initialize without exporting join tokens (for single-node testing)
  sudo bash swarm-init.sh --manager-only

NOTES:
  - Requires /etc/unifi-edtech/config.env with IP variable
  - Idempotent: safe to run multiple times
  - Join tokens written to /etc/unifi-edtech/ with 600 perms
  - For worker nodes, use: docker swarm join --token <token> <manager-ip>:2377

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Try './swarm-init.sh --help' for more information." >&2
            exit 1
            ;;
    esac
done

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

# Logging function
log() {
    local level=$1
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOGFILE"
}

log "INFO" "=== UniFi Edtech Stack - Swarm Init v${VERSION} ==="
log "INFO" "Mode: $([ $DRY_RUN -eq 1 ] && echo 'DRY-RUN' || echo 'LIVE')"

# Validate prerequisites
if ! command -v docker >/dev/null 2>&1; then
    log "ERROR" "Docker not found. Please run first-run.sh first."
    exit 1
fi

# Source config file
if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR" "Configuration file not found: $CONFIG_FILE"
    log "INFO" "Please run scripts/first-run.sh to generate config."
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate required variables
if [ -z "${IP:-}" ]; then
    log "ERROR" "IP variable not set in $CONFIG_FILE"
    exit 1
fi

# Extract IP without CIDR notation
ADVERTISE_IP="${IP%/*}"
log "INFO" "Advertise address: $ADVERTISE_IP"

# Check if Swarm is already initialized
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    log "INFO" "Docker Swarm already initialized on this node"
    
    # Check if this is a manager node
    if docker node ls >/dev/null 2>&1; then
        log "INFO" "This node is a Swarm manager"
        
        if [ $DRY_RUN -eq 1 ]; then
            log "INFO" "[DRY-RUN] Would refresh join tokens"
        else
            # Refresh tokens if not in manager-only mode
            if [ $MANAGER_ONLY -eq 0 ]; then
                log "INFO" "Refreshing join tokens..."
                
                # Get manager token
                MANAGER_TOKEN=$(docker swarm join-token manager -q)
                echo "$MANAGER_TOKEN" | sudo tee "$MANAGER_TOKEN_FILE" > /dev/null
                sudo chmod 600 "$MANAGER_TOKEN_FILE"
                log "INFO" "Manager token updated: $MANAGER_TOKEN_FILE"
                
                # Get worker token
                WORKER_TOKEN=$(docker swarm join-token worker -q)
                echo "$WORKER_TOKEN" | sudo tee "$WORKER_TOKEN_FILE" > /dev/null
                sudo chmod 600 "$WORKER_TOKEN_FILE"
                log "INFO" "Worker token updated: $WORKER_TOKEN_FILE"
                
                # Display join commands
                cat << EOF

=== Swarm Join Commands ===

To add a manager node, run on the new Pi:
  docker swarm join --token $MANAGER_TOKEN $ADVERTISE_IP:2377

To add a worker node, run on the new Pi:
  docker swarm join --token $WORKER_TOKEN $ADVERTISE_IP:2377

Tokens saved to:
  - Manager: $MANAGER_TOKEN_FILE
  - Worker: $WORKER_TOKEN_FILE

EOF
            fi
        fi
    else
        log "INFO" "This node is a Swarm worker (not manager)"
        log "WARN" "Worker nodes cannot initialize Swarm. Run this script on a manager node."
        exit 1
    fi
    
    # Show current node status
    log "INFO" "Current Swarm nodes:"
    docker node ls 2>&1 | tee -a "$LOGFILE"
    
    exit 0
fi

# Initialize Swarm (not yet initialized)
log "INFO" "Docker Swarm not initialized. Starting initialization..."

if [ $DRY_RUN -eq 1 ]; then
    log "INFO" "[DRY-RUN] Would run: docker swarm init --advertise-addr $ADVERTISE_IP"
    log "INFO" "[DRY-RUN] Would write tokens to $TOKEN_DIR"
    log "INFO" "[DRY-RUN] Configuration valid. Ready for live initialization."
    exit 0
fi

# Live initialization
log "INFO" "Initializing Docker Swarm with advertise address: $ADVERTISE_IP"
if ! docker swarm init --advertise-addr "$ADVERTISE_IP" >> "$LOGFILE" 2>&1; then
    log "ERROR" "Failed to initialize Docker Swarm"
    log "ERROR" "Check log file: $LOGFILE"
    exit 1
fi

log "INFO" "Docker Swarm initialized successfully"

# Verify manager status
if ! docker node ls >/dev/null 2>&1; then
    log "ERROR" "Swarm initialized but manager status check failed"
    exit 1
fi

# Export join tokens (unless manager-only mode)
if [ $MANAGER_ONLY -eq 0 ]; then
    log "INFO" "Exporting Swarm join tokens..."
    
    # Ensure token directory exists with correct permissions
    if ! sudo mkdir -p "$TOKEN_DIR" 2>/dev/null; then
        log "ERROR" "Failed to create token directory: $TOKEN_DIR"
        exit 1
    fi
    
    # Get manager token
    log "INFO" "Retrieving manager join token..."
    MANAGER_TOKEN=$(docker swarm join-token manager -q)
    if [ -z "$MANAGER_TOKEN" ]; then
        log "ERROR" "Failed to retrieve manager token"
        exit 1
    fi
    echo "$MANAGER_TOKEN" | sudo tee "$MANAGER_TOKEN_FILE" > /dev/null
    sudo chmod 600 "$MANAGER_TOKEN_FILE"
    log "INFO" "Manager token saved: $MANAGER_TOKEN_FILE"
    
    # Get worker token
    log "INFO" "Retrieving worker join token..."
    WORKER_TOKEN=$(docker swarm join-token worker -q)
    if [ -z "$WORKER_TOKEN" ]; then
        log "ERROR" "Failed to retrieve worker token"
        exit 1
    fi
    echo "$WORKER_TOKEN" | sudo tee "$WORKER_TOKEN_FILE" > /dev/null
    sudo chmod 600 "$WORKER_TOKEN_FILE"
    log "INFO" "Worker token saved: $WORKER_TOKEN_FILE"
    
    # Display join commands
    cat << EOF | tee -a "$LOGFILE"

=== Swarm Initialized Successfully ===

This node is now a Swarm manager at: $ADVERTISE_IP

To add additional nodes to the cluster:

  1. Manager Node (run on new Pi):
     docker swarm join --token $MANAGER_TOKEN $ADVERTISE_IP:2377

  2. Worker Node (run on new Pi):
     docker swarm join --token $WORKER_TOKEN $ADVERTISE_IP:2377

Tokens securely stored at:
  - Manager: $MANAGER_TOKEN_FILE
  - Worker: $WORKER_TOKEN_FILE

Next Steps:
  1. Deploy stack: docker stack deploy -c docker/docker-compose.yml unifi-stack
  2. Monitor services: docker stack ps unifi-stack
  3. View logs: docker service logs unifi-stack_unifi-controller

For documentation, see: docs/DOCKER-SWARM.md

EOF
else
    log "INFO" "Manager-only mode: skipping token export"
fi

# Show initial node status
log "INFO" "Current Swarm nodes:"
docker node ls 2>&1 | tee -a "$LOGFILE"

# Log final status
log "INFO" "Swarm initialization complete. Check $LOGFILE for full details."

exit 0
