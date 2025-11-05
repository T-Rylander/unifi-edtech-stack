#!/bin/bash
# first-run.sh: Pi Priming for UniFi Edtech Stack
# Run as sudo on fresh Bookworm/Trixie. Idempotent where possible.
# Because starting from scratch shouldn't feel like herding APs.

set -euo pipefail  # Fail fast, no loose ends
LOGFILE="$HOME/unifi-logs/setup.log"
exec > >(tee -a "$LOGFILE") 2>&1  # Log everything, everywhere

echo "=== Phase 1: Prereqs Check (UniFi Guide Sec 1) ==="
# Hardware/OS baseline
if ! grep -q "Raspbian GNU/Linux 12" /etc/os-release; then
    echo "WARN: Expecting 64-bit Bookworm/Trixie. Current: $(cat /etc/os-release | head -1)"
fi
FREE_GB=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
if (( $(echo "$FREE_GB < 98" | bc -l) )); then
    echo "ERROR: Need 98GB+ free on /. Got $FREE_GB GB. Bail."
    exit 1
fi
echo "✓ Storage: $FREE_GB GB green-lit. Temp check: $(vcgencmd measure_temp)"

echo "=== Phase 2: System Update & Packages (Sec 2) ==="
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release ufw nmap htop bc  # bc for math
# Docker GPG/Repo setup (guide's curl magic)
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin iptables-persistent netfilter-persistent
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker "$USER"  # For mtrvs or whoever's SSH'd in
echo "✓ Docker: $(docker --version). Re-login for group perms."

echo "=== Phase 3: Static IP & Hostname (Sec 3) ==="
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
    echo "ERROR: Static IP not bound. Check cabling/router."
    exit 1
fi
echo "✓ Locked: $HOSTNAME @ $IP. Ping your router to confirm."

echo "=== Phase 4: Firewall Basics (Sec 2 + 7 Teaser) ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh  # Keep the door cracked for now
sudo ufw --force enable
echo "✓ UFW: Paranoid defaults. Full UniFi rules post-deploy."

echo "=== Phase 5: Git Clone & Scaffold (Repo Sync) ==="
cd ~ || cd /home/"$USER"
if [ ! -d "unifi-edtech-stack" ]; then
    git clone https://github.com/T-Rylander/unifi-edtech-stack.git
else
    cd unifi-edtech-stack && git pull
fi
cd unifi-edtech-stack
mkdir -p unifi-data/{mongo,unifi/{db,logs,run,backup}}
chown -R "$USER":"$USER" unifi-data && chmod -R 755 unifi-data
echo "✓ Repo cloned/scaffolded. Data vols prepped for Docker."

echo "=== All Clear: Reboot Recommended ==="
echo "Run 'sudo reboot' now. Post-reboot: docker compose up -d in docker/."
echo "Logs: tail -f $LOGFILE for the full story."