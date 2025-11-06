# 🔐 Security Policy

This document outlines the **security hardening steps**, **vulnerability disclosure process**, and **privacy protections** for the **UniFi Edtech Stack** project.

---

## 📢 Supported Versions

We actively maintain security updates for the following versions:

| Version | Supported          | Notes |
|---------|--------------------|-------|
| 0.2.x   | :white_check_mark: | Current development |
| 0.1.x   | :white_check_mark: | Baseline release |
| < 0.1   | :x:                | Pre-release, unsupported |

---

## 🚨 Reporting a Vulnerability

**We take security seriously.** If you discover a vulnerability, please report it responsibly.

### Reporting Process

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. **Email security concerns to**: [Your email or security@yourdomain.com]
3. **Include the following details**:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected versions/components
   - Potential impact (confidentiality, integrity, availability)
   - Any suggested mitigations

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Patch development**: Varies by severity (1-30 days)
- **Public disclosure**: After patch is released and users have time to update

### Coordinated Disclosure

We follow a **90-day coordinated disclosure** policy:
- Security fixes are released as soon as possible
- Public disclosure occurs 90 days after initial report, or when 95% of users have patched (whichever is sooner)
- Reporters are credited (unless anonymity is requested)

---

## 🔒 Pi Security Hardening

These controls are **automatically applied** by `scripts/first-run.sh`:

### SSH Hardening

| Control | Status | Implementation |
|---------|--------|----------------|
| **Key-only auth** | ✅ Auto-applied | `PasswordAuthentication no` in `/etc/ssh/sshd_config` |
| **Root login disabled** | ✅ Auto-applied | `PermitRootLogin no` |
| **Port 22 filtered** | ✅ Auto-applied | UFW rule: `limit 22/tcp from 192.168.2.0/24` |

**Validation**:
```bash
# Verify SSH hardening
sudo grep "PasswordAuthentication no" /etc/ssh/sshd_config
sudo grep "PermitRootLogin no" /etc/ssh/sshd_config
sudo ufw status | grep 22
```

### Fail2Ban Configuration

| Control | Status | Configuration |
|---------|--------|---------------|
| **Fail2Ban enabled** | ✅ Auto-applied | Monitors SSH, UniFi ports |
| **Ban threshold** | 5 attempts | `/etc/fail2ban/jail.local` |
| **Ban duration** | 1 hour | Increases on repeat offenses |

**UniFi-specific jail**:
```ini
# /etc/fail2ban/jail.d/unifi.conf
[unifi-controller]
enabled = true
port = 8080,8443,8843,8880
filter = unifi
logpath = /mnt/hdd/unifi-data/logs/server.log
maxretry = 5
bantime = 3600
findtime = 600
```

**UniFi filter**:
```ini
# /etc/fail2ban/filter.d/unifi.conf
[Definition]
failregex = ^.*Failed password for .* from <HOST>.*$
            ^.*authentication failure.*rhost=<HOST>.*$
ignoreregex =
```

**Apply manually** (auto-applied by first-run.sh):
```bash
sudo fail2ban-client reload
sudo fail2ban-client status unifi-controller
```

### AppArmor Profiles

| Container | Profile | Status |
|-----------|---------|--------|
| **unifi-controller** | `docker-unifi` | ✅ Enabled |
| **wireguard** | `docker-wireguard` | ✅ Enabled |
| **ollama** | `docker-default` | ✅ Enabled |

**UniFi Controller Profile**:
```apparmor
# /etc/apparmor.d/docker-unifi
#include <tunables/global>

profile docker-unifi flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Network access
  network inet stream,
  network inet6 stream,
  network inet dgram,
  network inet6 dgram,

  # File access
  /mnt/hdd/unifi-data/** rw,
  /tmp/** rw,
  /var/log/unifi/** w,

  # Deny sensitive paths
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /etc/ssh/** w,
  deny /root/** r,

  # Java execution
  /usr/lib/jvm/** ix,
  /usr/bin/java rix,
}
```

**WireGuard Profile**:
```apparmor
# /etc/apparmor.d/docker-wireguard
#include <tunables/global>

profile docker-wireguard flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Network access (required for VPN)
  capability net_admin,
  capability net_raw,
  network inet stream,
  network inet6 stream,
  network netlink raw,

  # WireGuard config
  /config/** rw,
  /etc/wireguard/** rw,

  # Deny sensitive paths
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /root/.ssh/** r,
}
```

**Enable profiles**:
```bash
sudo apparmor_parser -r /etc/apparmor.d/docker-unifi
sudo apparmor_parser -r /etc/apparmor.d/docker-wireguard

# Verify status
sudo aa-status | grep docker
```

### Firewall Rules (UFW)

**Default policy**: Deny all incoming, allow all outgoing

| Service | Port | Source | Rule |
|---------|------|--------|------|
| **SSH** | 22/tcp | LAN only | `limit 22/tcp from 192.168.2.0/24` |
| **UniFi Web** | 8443/tcp | LAN only | `allow 8443/tcp from 192.168.2.0/24` |
| **UniFi Inform** | 8080/tcp | LAN only | `allow 8080/tcp from 192.168.2.0/24` |
| **UniFi Discovery** | 10001/udp | LAN only | `allow 10001/udp from 192.168.2.0/24` |
| **WireGuard** | 51820/udp | LAN only | `allow 51820/udp from 192.168.2.0/24` |
| **Ollama API** | 11434/tcp | Localhost | `deny 11434/tcp from any` (Docker internal only) |

**Apply rules** (auto-applied by first-run.sh):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp from 192.168.2.0/24
sudo ufw allow 8080/tcp from 192.168.2.0/24
sudo ufw allow 8443/tcp from 192.168.2.0/24
sudo ufw allow 10001/udp from 192.168.2.0/24
sudo ufw allow 51820/udp from 192.168.2.0/24
sudo ufw enable
```

**Note**: Ollama port 11434 is **not exposed** to host network—only accessible via Docker internal networking.

---

## 🔒 WireGuard Security

### Cryptographic Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Key exchange** | Curve25519 | Elliptic-curve Diffie-Hellman |
| **Encryption** | ChaCha20 | Symmetric encryption |
| **Authentication** | Poly1305 | MAC authentication |
| **Key rotation** | Manual | Rotate keys every 90 days |

### Tunnel Configuration

```ini
# /config/wg0.conf (inside container)
[Interface]
Address = 10.13.13.1/24
ListenPort = 51820
PrivateKey = <AUTO_GENERATED>

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.13.13.2/32
PersistentKeepalive = 25
```

**Security checklist**:
- [ ] Private keys never committed to Git
- [ ] Keys generated on Pi (not shared across nodes)
- [ ] Peer connections limited by `AllowedIPs`
- [ ] UFW restricts WireGuard to LAN only

**Key rotation procedure** (every 90 days):
```bash
# Generate new keys
docker exec wireguard wg genkey | tee privatekey | wg pubkey > publickey

# Update config.env
sudo nano /etc/unifi-edtech/config.env
# Set: WG_PRIVATEKEY=<new_private_key>

# Restart WireGuard
cd docker
docker compose restart wireguard

# Distribute new client configs
docker exec wireguard cat /config/peer1/peer1.conf
```

---

## 🔒 Docker Security

### Container Hardening

| Control | Status | Implementation |
|---------|--------|----------------|
| **Non-root user** | ✅ | `PUID=1000`, `PGID=1000` for linuxserver.io images |
| **Read-only filesystem** | ⚠️ Partial | Where possible (not UniFi due to DB writes) |
| **No privileged mode** | ✅ | Except WireGuard (requires `NET_ADMIN`) |
| **Capabilities dropped** | ✅ | Default Docker capability set |
| **Secrets via env** | ✅ | `/etc/unifi-edtech/config.env` |
| **Logging limits** | ✅ | 10MB × 3 files max |

**Dockerfile security scan** (future work):
```bash
# Scan for vulnerabilities (requires Docker Scout or Trivy)
docker scout cves linuxserver/wireguard:latest
docker scout cves jacobalberty/unifi:latest
docker scout cves ollama/ollama:latest
```

### Image Verification

**Always use pinned tags** (not `latest`):
```yaml
# Good
image: linuxserver/wireguard:1.0.20210914

# Bad
image: linuxserver/wireguard:latest
```

**Verify image signatures** (optional, requires Docker Content Trust):
```bash
export DOCKER_CONTENT_TRUST=1
docker pull linuxserver/wireguard:1.0.20210914
```

### Dependabot Alerts

We use **GitHub Dependabot** to track vulnerabilities in dependencies:

[![Dependabot Status](https://img.shields.io/badge/Dependabot-enabled-brightgreen.svg)](https://github.com/T-Rylander/unifi-edtech-stack/security/dependabot)

**Auto-created PRs** for:
- GitHub Actions versions
- Python package vulnerabilities (requirements.txt)
- Docker base image updates

---

## 🔒 Data Privacy & PII Protection

**Critical for educational environments**: Student data must be protected.

### PII Categories

| Category | Examples | Handling |
|----------|----------|----------|
| **Direct PII** | Names, email, student ID | **Never log**, hash if needed |
| **Network identifiers** | MAC address, IP | Hash before AI training |
| **Usage metadata** | Connection times, bandwidth | Aggregate only, no individual tracking |

### Log Sanitization

**Before committing logs or training AI models**, sanitize PII:

**Bash sanitization** (in `first-run.sh`):
```bash
# Hash MAC addresses
sanitize_mac() {
    local mac=$1
    echo "device-$(echo -n "$mac" | sha256sum | cut -c1-8)"
}

# Example usage
echo "Device AA:BB:CC:DD:EE:FF connected" | sed -E 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/[MAC_HASHED]/g'
# Output: Device [MAC_HASHED] connected
```

**Python sanitization** (in `edtech-api`):
```python
import hashlib
import re

def sanitize_mac(mac: str) -> str:
    """Convert MAC address to hashed device ID"""
    return f"device-{hashlib.sha256(mac.encode()).hexdigest()[:8]}"

def sanitize_log_line(log: str) -> str:
    """Remove PII from log line"""
    # Hash MACs
    log = re.sub(
        r'([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}',
        lambda m: sanitize_mac(m.group(0)),
        log
    )
    # Mask IPs
    log = re.sub(
        r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
        '[IP_MASKED]',
        log
    )
    return log

# Example
log = "Device AA:BB:CC:DD:EE:FF at 192.168.2.50 connected"
print(sanitize_log_line(log))
# Output: Device device-a1b2c3d4 at [IP_MASKED] connected
```

### Ollama Training Data

**Before fine-tuning Ollama** on UniFi logs:

1. **Export logs**:
   ```bash
   docker exec unifi-controller cat /var/log/unifi/server.log > raw_logs.txt
   ```

2. **Sanitize**:
   ```bash
   python3 scripts/sanitize_logs.py raw_logs.txt > sanitized_logs.txt
   ```

3. **Review manually** (human veto required):
   ```bash
   grep -i "student\|name\|email" sanitized_logs.txt
   # Should return no results
   ```

4. **Train model** (see [AI-ROADMAP.md](AI-ROADMAP.md)):
   ```bash
   docker exec ollama ollama create unifi-model -f Modelfile
   ```

### Audit Trail

**All AI suggestions are logged** with human decision:

```json
// ~/unifi-logs/ai-decisions.log
{
  "timestamp": "2025-01-19T14:23:45Z",
  "query": "Balance 15 devices by signal strength",
  "ai_suggestion": {
    "vlan": "lab-101",
    "devices": ["device-a1b2c3d4", "device-e5f6g7h8"],
    "confidence": 0.87
  },
  "human_decision": "approved",
  "actioned_by": "teacher@school.edu",
  "notes": "Moved devices to reduce congestion"
}
```

**Retention policy**:
- Logs kept for **90 days**
- Sanitized logs retained indefinitely for training
- Raw logs with PII deleted after 90 days

---

## 🔍 Security Monitoring

### Automated Checks (CI/CD)

Our GitHub Actions workflow includes:

| Check | Tool | Frequency |
|-------|------|-----------|
| **Shellcheck** | shellcheck | Every push |
| **YAML lint** | yamllint | Every push |
| **Markdown lint** | markdownlint | Every push |
| **Link check** | markdown-link-check | Every push |
| **Compose validation** | docker compose config | Every push |

### Manual Audits

**Quarterly security review** (every 90 days):

- [ ] Rotate WireGuard keys
- [ ] Review UFW rules (`sudo ufw status numbered`)
- [ ] Check Fail2Ban logs (`sudo fail2ban-client status`)
- [ ] Scan Docker images for CVEs (`docker scout cves`)
- [ ] Review AppArmor denials (`sudo aa-status`, `dmesg | grep apparmor`)
- [ ] Audit AI decision logs (`~/unifi-logs/ai-decisions.log`)
- [ ] Update dependencies (`docker compose pull`, `pip install -U`)

### Incident Response

**If a security breach occurs**:

1. **Isolate**: Disconnect Pi from network
2. **Assess**: Review logs (`~/unifi-logs/`, `docker compose logs`)
3. **Contain**: Stop compromised services (`docker compose down`)
4. **Eradicate**: Patch vulnerability, rotate keys
5. **Recover**: Restore from backup if needed
6. **Lessons learned**: Document in post-mortem, update this doc

---

## 🏆 Security Best Practices

### For Operators

- **Principle of least privilege**: Grant only necessary permissions
- **Defense in depth**: Multiple layers of security (UFW, Fail2Ban, AppArmor)
- **Audit trail**: All changes logged and reviewable
- **Human oversight**: AI never makes autonomous network changes
- **Secrets management**: Never commit sensitive data to Git
- **Regular updates**: Keep OS, Docker, and images patched

### For Developers

- **Sanitize inputs**: Validate all API parameters
- **Rate limiting**: Prevent API abuse (future: add middleware)
- **PII handling**: Hash/mask before logging
- **Secure defaults**: Fail closed, not open
- **Code review**: All PRs reviewed by maintainer
- **Test security**: Include security tests in pytest suite

---

## 📚 References

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [WireGuard Security Model](https://www.wireguard.com/papers/wireguard.pdf)
- [AppArmor Documentation](https://gitlab.com/apparmor/apparmor/-/wikis/Documentation)
- [Fail2Ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)

---

## 🔗 Related Documentation

- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Security-related issues
- [AI-ROADMAP.md](AI-ROADMAP.md) - PII sanitization for AI training
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Reporting vulnerabilities

---

**Security is a journey, not a destination.** Review this document quarterly and update as threats evolve.