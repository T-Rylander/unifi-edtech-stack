This document lists **common issues** and their **solutions** when setting up and using the **unifi-edtech-stack**.

---

## 🚨 Common Issues

### 1. **SSH Access Fails After First Run**

- **Fix**:
  - Ensure `PasswordAuthentication no` is set in `/etc/ssh/sshd_config`.
  - Ensure SSH keys are properly configured.
  - Restart SSH: `sudo systemctl restart ssh`

### 2. **Pi Overheating**

- **Fix**:
  - Use `vcgencmd measure_temp` to check temperature.
  - Ensure proper cooling (fan, heatsink) is in place.
  - Monitor temperature with cron or alerting tools.

### 3. **Docker Volume Mounts Fail**

- **Fix**:
  - Ensure `/etc/fstab` is properly configured for HDD mounts.
  - Use `mount -a` to apply changes.
  - Ensure the HDD is mounted at `/mnt/hdd`.

### 4. **UniFi Discovery Fails**

- **Fix**:
  - Ensure the Pi is on the same network as the UniFi devices.
  - Check firewall rules (UFW) and port `10001`.
  - Ensure `set-inform` is properly configured.

### 5. **Infinite Adoption Loop**

- **Fix**:
  - Rerun `set-inform http://192.168.1.52:8080/inform` post-route.
  - Check UDP `10001` with `nmap -sU -p 10001 192.168.2.100`.

### 6. **WireGuard Tunnel Not Working**

- **Fix**:
  - Ensure WireGuard is installed and running: `sudo wg-quick up wg-edtech.conf`
  - Ensure the UFW rule is in place: `sudo ufw allow 51820/udp from 192.168.2.0/24`
  - Check the config file: `/etc/wireguard/wg-edtech.conf`

---

## 📌 Tips

- Always test scripts in a **non-production environment** first.
- Use `git log` to review changes and `git revert` to roll back if needed.
- Use `docker logs` and `journalctl` for debugging Docker and systemd services.
- Use `nmap`, `ping`, and `traceroute` to test network connectivity.
