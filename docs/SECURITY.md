# 🔐 SECURITY.md — Hardening, WireGuard, and Access Controls

This document outlines the **security hardening steps** for your **Raspberry Pi 5**, **Docker services**, and **WireGuard tunnel**.

---

## 🔒 Pi Security Hardening Checklist

| Category | Control | Status | Notes |
|----------|---------|--------|-------|
| SSH | PasswordAuthentication no | [ ] | Ensure SSH keys only |
| Fail2Ban | Enabled | [ ] | Blocks brute-force attempts |
| AppArmor | Enabled | [ ] | Protects Docker containers |
| UFW | Enabled | [ ] | Firewalls traffic |
| HDD Mount | Nofail | [ ] | Prevents boot issues if HDD fails |

---

## 🔒 WireGuard Security

| Control | Status | Notes |
|--------|--------|-------|
| Key Exchange | Secure | [ ] | Ensure keys are generated securely |
| Tunnel IP | 10.200.0.1/24 | [ ] | Internal tunnel IP |
| Allowed IPs | 192.168.2.0/24 | [ ] | UniFi subnet |
| Endpoint | 192.168.2.100:51820 | [ ] | UniFi controller IP/port |
| UFW Rule | 51820/udp from 192.168.2.0/24 | [ ] | Allows WireGuard traffic |

---

## 🔒 Docker Security

| Control | Status | Notes |
|--------|--------|-------|
| AppArmor | Enabled | [ ] | Protects Docker containers |
| Image Tags | Pinned | [ ] | Avoid `latest` tags |
| Privileged Mode | Disabled | [ ] | Avoid running containers with `--privileged` |
| Volume Mounts | Secure | [ ] | Ensure HDD is used for persistent data |