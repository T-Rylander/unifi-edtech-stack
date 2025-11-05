#!/bin/bash

# 📁 Variables
WG_INTERFACE="wg-edtech"
WG_CONFIG="/etc/wireguard/wg-edtech.conf"
WG_PRIVATE_KEY="/etc/wireguard/pi-private"
WG_PUBLIC_KEY="/etc/wireguard/pi-public"
UNIFI_PEER_PUBLIC="UNIFI_PEER_PUBLIC_KEY_HERE"
UNIFI_SUBNET="192.168.2.0/24"
UNIFI_ENDPOINT="192.168.2.100:51820"

# 📁 Step 1: Install WireGuard
echo "Installing WireGuard..." 
sudo apt update && sudo apt install -y wireguard

# 📁 Step 2: Generate Keys
echo "Generating WireGuard keys..."
wg genkey | tee $WG_PRIVATE_KEY
wg pubkey < $WG_PRIVATE_KEY > $WG_PUBLIC_KEY

# 📁 Step 3: Create Config File
echo "Creating WireGuard config file..."
cat <<EOF > $WG_CONFIG
[Interface]
PrivateKey = $(cat $WG_PRIVATE_KEY)
Address = 10.200.0.1/24
ListenPort = 51820
SaveConfig = true

[Peer]
PublicKey = $UNIFI_PEER_PUBLIC
AllowedIPs = $UNIFI_SUBNET
Endpoint = $UNIFI_ENDPOINT
EOF

# 📁 Step 4: Set UFW Rule
echo "Setting UFW rule for WireGuard..."
sudo ufw allow 51820/udp from $UNIFI_SUBNET

# 📁 Step 5: Start WireGuard
echo "Starting WireGuard tunnel..."
sudo wg-quick up $WG_INTERFACE

# 📁 Step 6: Test Connectivity
echo "Testing connectivity to UniFi controller..."
ping -c 4 $UNIFI_ENDPOINT | tee -a wg-setup.log

# 📁 Step 7: Log and Commit
echo "WireGuard setup complete. Check $WG_CONFIG and wg-setup.log for details."