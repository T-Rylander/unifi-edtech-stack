#!/bin/bash

# 📁 Define variables
SCRIPT_NAME="swarm-dry-run.sh"
LOG_FILE="swarm-dry-run.log"
COMMIT_MSG="Single Pi setup with UniFi on different subnet — no swarm, set-inform applied"

# 📁 Define IP addresses
PI_IP="192.168.1.52"
UNIFI_CONTROLLER_IP="192.168.2.100"  # Example IP of UniFi controller on different subnet

# 📁 Step 1: Log start of script
echo "Starting $SCRIPT_NAME at $(date)" >> $LOG_FILE

# 📁 Step 2: Initialize Docker swarm (optional, but safe for single Pi)
echo "Initializing Docker swarm (single node)..." >> $LOG_FILE
docker swarm init --advertise-addr $PI_IP >> $LOG_FILE 2>&1

# 📁 Step 3: Create a test service to validate Docker
echo "Creating a test service to validate Docker..." >> $LOG_FILE
docker service create --name test-ping alpine ping $UNIFI_CONTROLLER_IP >> $LOG_FILE 2>&1

# 📁 Step 4: List services
echo "Listing Docker services..." >> $LOG_FILE
docker service ls >> $LOG_FILE 2>&1

# 📁 Step 5: Set-inform for UniFi adoption (avoid infinite loop)
echo "Setting inform to connect to UniFi controller at $UNIFI_CONTROLLER_IP..." >> $LOG_FILE
sudo docker run --rm --network host jacobalberty/unifi:stable set-inform http://$UNIFI_CONTROLLER_IP:8080/inform >> $LOG_FILE 2>&1

# 📁 Step 6: List Docker containers
echo "Listing Docker containers..." >> $LOG_FILE
docker ps >> $LOG_FILE 2>&1

# 📁 Step 7: Log end of script
echo "Ending $SCRIPT_NAME at $(date)" >> $LOG_FILE

# 📁 Step 8: Commit changes to Git
echo "Committing changes to Git..." >> $LOG_FILE
git add . >> $LOG_FILE 2>&1
git commit -m "$COMMIT_MSG" >> $LOG_FILE 2>&1

# 📁 Step 9: Push changes (if needed)
echo "Pushing changes to remote (if configured)..." >> $LOG_FILE
git push >> $LOG_FILE 2>&1

# 📁 Step 10: Clean up (optional)
echo "Cleaning up..." >> $LOG_FILE
docker service rm test-ping >> $LOG_FILE 2>&1
docker swarm leave -f >> $LOG_FILE 2>&1

# 📁 Step 11: Final message
echo "Single Pi setup with UniFi on different subnet is configured. Check $LOG_FILE for details." >> $LOG_FILE