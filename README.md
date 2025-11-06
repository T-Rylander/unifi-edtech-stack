# 📦 unifi-edtech-stack# 📦 unifi-edtech-stack



A secure, modular, and scalable on-prem edtech stack built with **Raspberry Pi 5 (8GB)**, **Docker**, **UniFi**, and **AI integration**.A secure, modular, and scalable on-prem edtech stack built with **Raspberry Pi 5 (8GB)**, **Docker**, **UniFi**, and **AI integration**.



## 🎯 Project Goals## 🎯 Project Goals



- **Secure**: Hardened Pi with AppArmor, Fail2Ban, and SSH key-only access.- **Secure**: Hardened Pi with AppArmor, Fail2Ban, and SSH key-only access.

- **Modular**: Docker-based services for easy deployment and scaling.- **Modular**: Docker-based services for easy deployment and scaling.

- **Scalable**: WireGuard tunneling for cross-subnet connectivity.- **Scalable**: WireGuard tunneling for cross-subnet connectivity.

- **Documented**: Git-versioned playbooks and scripts for reproducibility.- **Documented**: Git-versioned playbooks and scripts for reproducibility.

- **AI-Ready**: Ollama/Llama integration for ops insights and anomaly detection.- **AI-Ready**: Ollama/Llama integration for ops insights and anomaly detection.



## 🚀 Quick Start## 🚀 Quick Start



1. **Clone the repo**:1. **Clone the repo**:

   ```bash   ```bash

   git clone https://github.com/T-Rylander/unifi-edtech-stack.git   git clone https://github.com/T-Rylander/unifi-edtech-stack.git

   cd unifi-edtech-stack   cd unifi-edtech-stack
   ```

2. **Run first-run script** (on Raspberry Pi 5):
   ```bash
   cd scripts
   sudo bash first-run.sh --auto-detect
   ```

3. **Deploy stack**:
   ```bash
   cd ../docker
   docker compose up -d
   ```

4. **Access UniFi Controller**:
   - Web UI: `https://<pi-ip>:8443`
   - Default: Setup wizard on first access

5. **(Optional) Enable AI**:
   ```bash
   docker compose --profile ai up -d
   ```

---

## 📚 Documentation

### 📖 Core Guides
- **[PROJECT-STATUS.md](docs/PROJECT-STATUS.md)** - Current repo health, 85% goal coverage, component status
- **[PHASED-ROADMAP.md](docs/PHASED-ROADMAP.md)** - Implementation phases: Immediate → Mid-Term → Long-Term
- **[FIRST-RUN.md](docs/FIRST-RUN.md)** - Detailed Pi provisioning and post-boot workflows
- **[DOCKER-SWARM.md](docs/DOCKER-SWARM.md)** - Multi-node cluster setup and scaling
- **[AI-ROADMAP.md](docs/AI-ROADMAP.md)** - Ollama integration, fine-tuning, and edtech AI flows
- **[SECURITY.md](docs/SECURITY.md)** - Hardening guidelines and threat model
- **[MONITORING.md](docs/MONITORING.md)** - Observability stack (Prometheus + Grafana)
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

### 🔧 Technical References
- **[docker/README.md](docker/README.md)** - Compose stack usage, healthchecks, Leo's hardening
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and git workflow

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Raspberry Pi 5 (8GB)                    │
├─────────────────────────────────────────────────────────────┤
│  Docker Compose Stack (unifi-net network)                   │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  WireGuard   │───▶│    UniFi     │───▶│   Ollama     │  │
│  │   Tunnel     │    │  Controller  │    │  (AI, opt)   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         ▲                    ▲                    ▲          │
│         │                    │                    │          │
│         └────────────────────┴────────────────────┘          │
│              Config: /etc/unifi-edtech/config.env           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  edtech-api (planned)                                │   │
│  │  - VLAN automation                                   │   │
│  │  - RADIUS correlation                                │   │
│  │  - Ollama query bridge                               │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Current Status (November 2025)

**Overall Health**: 85% goal coverage ✅  
**Branch**: main (clean, no WIP)  
**Last Push**: Recent (commit 7f2a9e4)  
**Phase**: Immediate (Test & Doc Parity)

### ✅ What's Complete
- **first-run.sh**: Production-ready Pi provisioning (flock-locked, auto-detect, retries)
- **docker-compose.yml**: Hardened orchestration (health-chained, logging limits, profiles)
- **Config Management**: Centralized `/etc/unifi-edtech/config.env` generation
- **Security**: AppArmor, Fail2Ban, SSH key-only defaults
- **AI Foundation**: Ollama service containerized and profile-gated

### 🟡 In Progress
- **FIRST-RUN.md**: Expanding post-boot workflows and troubleshooting
- **swarm-init.sh**: Drafting multi-node Swarm setup script
- **edtech-api**: VLAN automation API (stubbed in compose)
- **AI Fine-Tuning**: Custom `edtech-assist` model on UniFi logs

### ⚪ Planned
- **Multi-Pi Testing**: 3+ node Swarm validation
- **RADIUS Integration**: Student auth correlation for VLAN grouping
- **Monitoring**: Prometheus + Grafana dashboards
- **Classroom Pilot**: Real-world testing with 10+ student devices

See **[PROJECT-STATUS.md](docs/PROJECT-STATUS.md)** for detailed breakdown.

---

## 🤖 AI Philosophy

**Core Principle**: AI as augmentation tool, not autonomous overlord.

- ✅ **AI Suggests**: VLAN groupings, device troubleshooting, anomaly detection
- 🤝 **Humans Decide**: Teachers review and approve all network changes
- 📊 **Transparency**: All AI suggestions logged with confidence scores
- 🔒 **Privacy**: Local inference only (no cloud APIs)
- 🎯 **Empathy**: Designed for classroom chaos (flaky devices, on-prem constraints)

**Example Flow**:
```
Student connects → edtech-api captures event → Ollama: "Suggest VLAN for lab-101"
→ AI returns: "VLAN 101, confidence: 0.87, reasoning: grouped with similar SSIDs"
→ Teacher reviews → Approves or overrides → VLAN assigned
```

See **[AI-ROADMAP.md](docs/AI-ROADMAP.md)** for implementation details.

---

## 📊 Tech Stack

| Component         | Technology                          | Purpose                          |
|-------------------|-------------------------------------|----------------------------------|
| **Hardware**      | Raspberry Pi 5 (8GB)                | On-prem compute, classroom-ready |
| **OS**            | Raspberry Pi OS Lite (64-bit)       | Minimal footprint, aarch64       |
| **Orchestration** | Docker Compose v2.24+               | Service deployment, health chains|
| **Network**       | UniFi Network Application           | AP management, device adoption   |
| **Tunneling**     | WireGuard                           | Secure cross-subnet connectivity |
| **AI**            | Ollama + LLaMA3                     | Local LLM inference              |
| **API**           | Flask (planned)                     | VLAN automation, event listener  |
| **Monitoring**    | Prometheus + Grafana (planned)      | Metrics, alerts, dashboards      |
| **Auth**          | FreeRADIUS (planned)                | Student login correlation        |

---

## 🛠️ Requirements

### Hardware
- **Raspberry Pi 5** (8GB RAM recommended)
- **64GB+ microSD** or NVMe SSD (for log persistence)
- **Power supply** (official Pi5 27W recommended)
- **Active cooling** (fan or heatsink for sustained workloads)
- **Network**: Ethernet preferred (Gigabit)

### Software
- **Raspberry Pi OS Lite (64-bit)** - Bookworm (Debian 12) or Trixie (Debian 13)
- **Docker** (installed by first-run.sh)
- **Docker Compose v2.24+** (for env validation)

### Optional
- **UniFi APs** (for real network testing)
- **Additional Pi5 units** (for Swarm multi-node)
- **RADIUS server** (for student auth)

---

## 🚦 Workflow

1. **Bootstrap**: `first-run.sh` provisions Pi (security, Docker, WireGuard keys)
2. **Deploy**: `docker compose up -d` starts services (WireGuard → UniFi → Ollama)
3. **Configure**: UniFi web UI setup (adopt APs, create networks)
4. **Iterate**: Monitor logs, tweak `config.env`, redeploy
5. **Scale**: Run `swarm-init.sh` for multi-node clusters
6. **AI Layer**: Enable Ollama profile, query for insights
7. **Automate**: Wire edtech-api for VLAN automation (Phase 2)

---

## 🧪 Testing

**Single-Node Validation** (Phase 1):
```bash
# After first-run.sh and compose up
docker compose ps  # All services healthy?
curl -k https://localhost:8443  # UniFi UI reachable?
docker exec unifi-wg-tunnel wg show  # WireGuard interface up?
curl http://localhost:11434/api/tags  # Ollama responding? (if --profile ai)
```

**Multi-Node Swarm** (Phase 3):
```bash
# On manager node
bash scripts/swarm-init.sh
docker stack deploy -c docker-compose.yml unifi-stack

# On worker nodes
docker swarm join --token <worker-token> <manager-ip>:2377

# Verify
docker node ls  # All nodes ready?
docker stack ps unifi-stack  # Services distributed?
```

---

## 🤝 Contributing

Contributions welcome! This project values:
- **Pragmatism**: Solutions over perfect abstractions
- **Documentation**: If it's not versioned, it didn't happen
- **Empathy**: Design for classroom constraints (flaky devices, on-prem limits)
- **AI Balance**: Augment humans, don't replace them

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for guidelines.

---

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🌟 Acknowledgments

- **Leo (AI)**: Docker compose hardening (healthchecks, logging, security)
- **Grok (AI)**: Project assessment and phased roadmap guidance
- **GitHub Copilot**: Code generation and documentation assistance
- **Community**: Edtech educators sharing classroom realities

---

## 📞 Contact

**Maintainer**: Travis Rylander (@T-Rylander)  
**Repository**: [github.com/T-Rylander/unifi-edtech-stack](https://github.com/T-Rylander/unifi-edtech-stack)  
**Issues**: File bugs, feature requests, or classroom pilot feedback

---

**Philosophy**: "Because nothing says 'classroom ready' like a Pi that doesn't melt under 30 Chromebooks." 🍓🔥
