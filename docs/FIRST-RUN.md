# 📌 FIRST-RUN.md — Raspberry Pi 5 Boot and Hardening Checklist

This document provides a step-by-step checklist for booting and hardening your **Raspberry Pi 5 (8GB)** with a **SA400S37/120G HDD** via **USB-to-SATA**.

---

## 🧰 Step-by-Step Checklist

| Step | Action | Command | Notes |
|------|--------|---------|-------|
| 1 | Set Hostname | `sudo raspi-config nonint do_hostname unifi-pi` | Sets the Pi's hostname |
| 2 | Set Timezone | `sudo raspi-config nonint do_change_timezone (UTC-6:00) Central Time (US & Canada)` | Sets the correct timezone |
| 3 | Enable SSH and Disable Password Auth | `sudo raspi-config nonint do_ssh 1`<br>`sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config`<br>`sudo systemctl restart ssh` | Ensures secure SSH access |
| 4 | Set Static IP | `sudo raspi-config nonint do_network_set_static_ip 192.168.1.52 192.168.1.1 255.255.255.0` | Sets a static IP for the Pi |
| 5 | Update and Upgrade | `sudo apt update && sudo apt full-upgrade -y` | Installs latest OS patches |
| 6 | Reboot | `sudo reboot` | Applies all changes |
| 7 | Mount HDD | `sudo blkid | grep "EDTECH-HDD" | cut -d '"' -f2 | xargs -I {} sudo mount {} /mnt/hdd`<br>`echo "UUID=YOUR_HDD_UUID /mnt/hdd auto defaults,nofail 0 2" | sudo tee -a /etc/fstab` | Mounts the SA400S37/120G HDD |
| 8 | Set Up Cron for Backups | `crontab -l 2>/dev/null; echo "0 2 * * * rsync -a /home/pi/unifi-cloudkey /mnt/hdd/backups/" | crontab -` | Sets up daily backups |
| 9 | Enable Security Hardening | `sudo apt install -y fail2ban apparmor`<br>`sudo systemctl enable fail2ban`<br>`sudo systemctl start fail2ban`<br>`sudo aa-enforce /etc/apparmor.d/docker` | Adds security layers |
| 10 | Initialize Git Repo | `cd /home/pi && git clone https://github.com/T-Rylander/unifi-edtech-stack.git`<br>`cd unifi-edtech-stack && git add . && git commit -m "Initial setup: Pi5 + HDD"` | Initializes and commits the repo |
