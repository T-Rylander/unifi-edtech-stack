# 📊 MONITORING.md — Temp Checks, Logs, and AI Ops Integration

This document outlines the **monitoring and logging setup** for your **Raspberry Pi 5**, **Docker services**, and **AI ops integration**.

---

## 📊 Temperature Monitoring

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Temp | >80°C | Alert via email or Slack |
| HDD Temp | >45°C | Alert via email or Slack |

**Commands**:
- `vcgencmd measure_temp` — Check Pi CPU temp
- `smartctl -t long /dev/sda` — Check HDD health
- `smartctl -a /dev/sda` — View HDD status

---

## 📊 Log Monitoring

| Service | Log File | Monitoring Tool |
|--------|----------|-----------------|
| Docker | `/var/log/docker.log` | `journalctl -u docker.service` |
| UniFi | `/var/log/unifi/*.log` | `tail -f /var/log/unifi/*.log` |
| System | `/var/log/syslog` | `journalctl -b` |

**Commands**:
- `docker logs unifi` — View UniFi logs
- `journalctl -b -1` — View logs from previous boot
- `tail -f /var/log/unifi/*.log` —
