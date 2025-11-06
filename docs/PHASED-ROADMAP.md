# 🛤️ Phased Implementation Roadmap

**Project**: UniFi Edtech Stack  
**Maintainer**: Travis Rylander (@T-Rylander)  
**Last Updated**: November 6, 2025  
**Current Phase**: Immediate (Test & Doc Parity)

---

## Philosophy

Keep the iterative pulse—test single-node deployment in lab, validate core flows, then layer in complexity. Each phase builds on the previous, ensuring stability before scaling. The goal is a **pragmatic fortress** that empowers educators with AI-augmented network ops, not autonomous black boxes.

**Guiding Principles**:
- 🧪 **Test First**: Validate on hardware before documenting
- 📝 **Document Everything**: If it's not versioned, it didn't happen
- 🤝 **Human-AI Balance**: AI suggests, humans decide
- 🔄 **Iterate Quickly**: Small changes, frequent validation
- 🎯 **Empathy for Chaos**: Design for flaky devices and classroom realities

---

## 🚀 Phase 1: Immediate (This Week)

**Goal**: Single-node validation and documentation parity  
**Duration**: 3-5 days  
**Success Criteria**: Pi boots, services healthy, docs match reality

### Tasks

#### 1.1 Expand FIRST-RUN.md
**Priority**: High  
**Owner**: Travis  
**Effort**: 2-3 hours

**Deliverables**:
- Mirror README's quickstart flow with post-boot rituals
- Add "Post-Deployment Validation" section:
  ```bash
  # Verify services
  cd docker
  docker compose ps
  docker compose logs -f unifi-controller
  
  # Check UniFi Controller
  curl -k https://localhost:8443
  
  # Validate WireGuard
  docker exec unifi-wg-tunnel wg show
  
  # Test Ollama (if AI profile enabled)
  curl http://localhost:11434/api/tags
  ```

- Add "Troubleshoot Edtech Flows" section:
  - UniFi Controller not adopting devices → check STUN/inform ports
  - WireGuard tunnel down → verify keys in `/etc/wireguard/`
  - Ollama models not loading → check volume permissions
  
- Include Ollama prompt templates:
  ```bash
  # Example: Analyze UniFi logs for student bottlenecks
  curl http://localhost:11434/api/generate -d '{
    "model": "llama3",
    "prompt": "Analyze this UniFi log for student device bottlenecks: <paste log>",
    "stream": false
  }'
  ```

**Files to Update**:
- `docs/FIRST-RUN.md`

---

#### 1.2 Draft swarm-init.sh Script
**Priority**: Medium  
**Owner**: Travis  
**Effort**: 3-4 hours

**Deliverables**:
- Create `scripts/swarm-init.sh` as thin wrapper around `docker swarm init`
- Features:
  - Source `/etc/unifi-edtech/config.env` for `${IP}` advertise address
  - Generate Swarm join tokens (manager and worker)
  - Write tokens to `/etc/unifi-edtech/swarm-tokens.env` (600 perms)
  - Log initialization to `~/unifi-logs/swarm-init.log`
  - Idempotent: detect existing Swarm and skip init if present
  
**Script Template**:
```bash
#!/bin/bash
set -euo pipefail
source /etc/unifi-edtech/config.env

if docker info | grep -q "Swarm: active"; then
  echo "Swarm already initialized"
  exit 0
fi

docker swarm init --advertise-addr "${IP%/*}"
docker swarm join-token manager -q > /etc/unifi-edtech/swarm-manager-token
docker swarm join-token worker -q > /etc/unifi-edtech/swarm-worker-token
chmod 600 /etc/unifi-edtech/swarm-*-token

echo "Swarm initialized. Tokens written to /etc/unifi-edtech/"
```

**Testing**:
- Run on single Pi, verify `docker node ls` shows manager
- Prepare for 2-Pi cluster test in Phase 2

**Files to Create**:
- `scripts/swarm-init.sh`
- `docs/DOCKER-SWARM.md` (update with swarm-init usage)

---

#### 1.3 Single-Node Lab Validation
**Priority**: Critical  
**Owner**: Travis  
**Effort**: 4-6 hours (includes troubleshooting)

**Checklist**:
- [ ] Fresh Pi5 (8GB) with Raspberry Pi OS Lite (64-bit)
- [ ] Run `scripts/first-run.sh --auto-detect`
- [ ] Verify `/etc/unifi-edtech/config.env` generated correctly
- [ ] Run `cd docker && docker compose up -d`
- [ ] Wait 90s for UniFi Controller startup
- [ ] Access UniFi web UI: `https://<pi-ip>:8443`
- [ ] Check WireGuard: `docker exec unifi-wg-tunnel wg show`
- [ ] (Optional) Enable Ollama: `docker compose --profile ai up -d`
- [ ] Test Ollama: `curl http://localhost:11434/api/tags`
- [ ] Document any issues in `TROUBLESHOOTING.md`

**Success Criteria**:
- All services show `healthy` in `docker compose ps`
- UniFi Controller web UI accessible
- WireGuard interface shows `wg0` with keypair
- (If enabled) Ollama returns JSON list of models

**Artifacts**:
- Screenshot of UniFi Controller dashboard
- `docker compose ps` output
- `~/unifi-logs/setup.log` file

---

## 🧪 Phase 2: Mid-Term (Pilots - Edtech Hooks)

**Goal**: Implement VLAN automation and AI fine-tuning  
**Duration**: 2-3 weeks  
**Success Criteria**: edtech-api wired, custom Ollama model trained, lab prototype with 10 devices

### Tasks

#### 2.1 Implement edtech-api Service
**Priority**: High  
**Owner**: Travis + AI Assist  
**Effort**: 8-12 hours

**Deliverables**:
- Uncomment `edtech-api` stub in `docker/docker-compose.yml`
- Create `services/edtech-api/` directory structure:
  ```
  services/edtech-api/
  ├── Dockerfile          # Alpine + Python 3.12 + Flask
  ├── requirements.txt    # unifi-api, requests, flask
  ├── app.py             # Flask entrypoint
  ├── vlan_listener.py   # UniFi event poller
  └── ollama_client.py   # Query interface to Ollama
  ```

**Key Features**:
- REST API on port 5000 with routes:
  - `POST /vlan-group` - Auto-group devices by SSID/auth
  - `GET /health` - Healthcheck endpoint
  - `POST /ollama-query` - Proxy to Ollama with prompt templates
  
- UniFi Event Listener:
  - Poll UniFi Controller API every 30s for new device adoptions
  - Correlate with RADIUS auth logs (if available)
  - Push device metadata to Ollama: "Suggest VLAN for device <MAC> with SSID <lab-101>"
  
- Ollama Integration:
  - Use `requests` to query `http://ollama-ai:11434/api/generate`
  - Prompt template: "Based on these student devices, suggest lab pairing strategy"
  - Return JSON response to caller

**Testing Plan**:
- Unit tests: Mock UniFi API responses, validate VLAN grouping logic
- Integration test: Simulate 10 Chromebook devices with varied SSIDs
- Human validation: Teacher reviews AI suggestions, confirms/overrides VLANs

**Files to Create**:
- `services/edtech-api/Dockerfile`
- `services/edtech-api/app.py`
- `services/edtech-api/vlan_listener.py`
- `services/edtech-api/ollama_client.py`
- `services/edtech-api/requirements.txt`
- `services/edtech-api/README.md`

---

#### 2.2 Fine-Tune Ollama Model on UniFi Logs
**Priority**: Medium  
**Owner**: Travis  
**Effort**: 6-8 hours (mostly data prep)

**Deliverables**:
- Collect 2-4 weeks of UniFi Controller logs from lab environment
- Sanitize logs: strip PII (MAC addresses → hashed IDs, student names → generic labels)
- Format logs as prompt/response pairs:
  ```
  Prompt: "Device <hash-123> connected to SSID lab-101 at 08:15. Suggest grouping."
  Response: "Group with devices on lab-101. Check signal strength for optimal AP."
  ```
  
- Create `Modelfile` for Ollama:
  ```
  FROM llama3
  PARAMETER temperature 0.7
  PARAMETER top_p 0.9
  SYSTEM You are an expert network assistant for educational labs. Suggest VLAN groupings and troubleshoot device issues based on UniFi logs. Be concise and actionable.
  ```

- Train model: `ollama create edtech-assist -f Modelfile`
- Version in Git: `git lfs track "models/edtech-assist.gguf"`
- Update `AI-ROADMAP.md` with versioning workflow

**Testing**:
- Query model with sample logs: "Analyze this AP dropout pattern"
- Compare generic llama3 vs fine-tuned `edtech-assist` responses
- Human evaluation: does it provide actionable insights?

**Files to Create/Update**:
- `models/Modelfile`
- `docs/AI-ROADMAP.md` (add fine-tuning section)
- `docs/VERSIONS.md` (track model versions)

---

#### 2.3 Lab Prototype: 10-Device Simulation
**Priority**: High  
**Owner**: Travis  
**Effort**: 4-6 hours

**Scenario**:
- Simulate 10 student Chromebooks connecting to UniFi network
- Use mix of SSIDs: `lab-101`, `lab-102`, `guest-wifi`
- Trigger edtech-api VLAN grouping via API calls
- Observe Ollama suggestions for device pairing

**Tools**:
- Python script to spoof MAC addresses and simulate auth events
- UniFi Controller test site with isolated VLAN segments
- `curl` commands to edtech-api for manual testing

**Success Criteria**:
- edtech-api correctly groups devices by SSID
- Ollama returns sensible pairing suggestions (e.g., "Group lab-101 devices by signal strength")
- Teacher can override AI suggestions via API
- Logs show clear audit trail: device → AI suggestion → human decision

**Artifacts**:
- Video/screenshot demo of VLAN automation flow
- Log file showing device grouping decisions
- User feedback notes (simulated teacher review)

---

## 🏗️ Phase 3: Long-Term (Scale - Human-Machine Riff)

**Goal**: Multi-node Swarm, monitoring layer, production pilots  
**Duration**: 1-2 months  
**Success Criteria**: 3+ Pi cluster, Grafana dashboards, real classroom pilot

### Tasks

#### 3.1 Monitoring Layer: Prometheus + Grafana
**Priority**: Medium  
**Owner**: Travis  
**Effort**: 8-10 hours

**Deliverables**:
- Add `prometheus` and `grafana` services to `docker-compose.yml`
- Scrape metrics from:
  - UniFi Controller (via SNMP or API)
  - Docker containers (cAdvisor)
  - Ollama inference queue (custom exporter)
  - WireGuard tunnel stats
  
- Create Grafana dashboards:
  - **Network Health**: AP uptime, device count, traffic throughput
  - **AI Insights**: Ollama query latency, model load, suggestion accuracy
  - **System Resources**: Pi CPU temp, memory usage, disk I/O
  
- Alert rules:
  - Ollama queue backup > 10 requests
  - UniFi AP offline > 5 minutes
  - Pi CPU temp > 70°C

**Testing**:
- Simulate high load (20+ devices)
- Verify alerts fire correctly
- Human review: dashboards provide actionable insights?

**Files to Create/Update**:
- `docker/docker-compose.yml` (add prometheus, grafana services)
- `monitoring/prometheus.yml` (scrape config)
- `monitoring/grafana-dashboards/` (JSON dashboard exports)
- `docs/MONITORING.md` (setup and usage guide)

---

#### 3.2 Multi-Pi Swarm Testing (3+ Nodes)
**Priority**: High  
**Owner**: Travis  
**Effort**: 12-16 hours (includes hardware setup)

**Deliverables**:
- Set up 3-node Pi5 cluster:
  - 1 manager (runs UniFi Controller, Ollama)
  - 2 workers (run WireGuard tunnels, edtech-api replicas)
  
- Deploy stack with Swarm mode:
  ```bash
  docker stack deploy -c docker-compose.yml unifi-stack
  ```
  
- Test scenarios:
  - Manager node failure → worker promotes to manager
  - Rolling updates → zero-downtime service restarts
  - Load balancing → edtech-api requests distributed across workers
  
- Document findings in `docs/DOCKER-SWARM.md`

**Success Criteria**:
- Stack remains healthy during node failures
- Services auto-recover within 30s
- Logs show Swarm orchestration events

**Artifacts**:
- Network diagram of 3-node cluster
- `docker stack ps unifi-stack` output showing replicas
- Video demo of node failure + recovery

---

#### 3.3 RADIUS Integration for Student Auth
**Priority**: Low  
**Owner**: Travis + Community  
**Effort**: 10-12 hours

**Deliverables**:
- Add `freeradius` container to `docker-compose.yml`
- Configure RADIUS to accept student logins via LDAP/AD
- Wire edtech-api to correlate:
  - Device MAC → RADIUS username → Student skill level/group
  
- Example flow:
  1. Student logs in with username `student-42`
  2. RADIUS auth success → edtech-api receives event
  3. API queries Ollama: "Student 42 has skill level: intermediate. Suggest lab pairing."
  4. API returns VLAN assignment + pairing recommendation

**Testing**:
- Simulate student logins from 5 Chromebooks
- Verify edtech-api correctly maps auth events to VLANs
- Human review: does AI pairing match pedagogical goals?

**Files to Create/Update**:
- `services/freeradius/Dockerfile`
- `services/freeradius/clients.conf` (UniFi as RADIUS client)
- `services/edtech-api/radius_correlator.py`
- `docs/RADIUS-SETUP.md`

---

#### 3.4 Whimsy Detour: TTS Narration (Optional)
**Priority**: Very Low (Joy-Driven)  
**Owner**: Travis (if it sparks joy)  
**Effort**: 2-3 hours

**Concept**:
- Add `espeak-ng` container with Ollama voice mode
- On first-run completion, narrate: "Cluster healthy—ready for class."
- On error, narrate issue summary: "Warning: UniFi Controller unreachable. Check port 8443."

**Implementation**:
- Add sidecar service in `docker-compose.yml`:
  ```yaml
  tts-narration:
    image: synesthesiam/espeak-ng
    command: espeak-ng "Cluster healthy—ready for class"
    profiles: ["whimsy"]
  ```

**Usage**:
```bash
docker compose --profile whimsy up -d
```

**Note**: Only implement if it enhances user experience without adding complexity. Otherwise, defer indefinitely.

---

## 🎯 Decision Points

At each phase boundary, assess:

1. **What's Working?** - Log wins, document patterns
2. **What's Friction?** - Identify pain points, file issues
3. **Next Layer or Refine?** - Scale up or iterate current phase?
4. **Community Input** - Share demos, gather feedback

**Current Decision Point** (End of Phase 1):
- **Option A**: Dive into Phase 2 (edtech-api + AI fine-tuning)
- **Option B**: Refine Phase 1 (harden first-run, expand docs, add tests)
- **Option C**: Jump to Phase 3 (Swarm multi-node for early scalability validation)

**Travis's Call**: Review Phase 1 artifacts, choose next beat based on lab readiness and personal itch.

---

## 📊 Progress Tracking

| Phase       | Status       | Completion | Next Milestone                     |
|-------------|--------------|------------|------------------------------------|
| **Phase 1** | 🟡 In Progress | 60%        | Complete FIRST-RUN.md expansion    |
| **Phase 2** | ⚪ Not Started | 0%         | Uncomment edtech-api, build Docker |
| **Phase 3** | ⚪ Not Started | 0%         | Procure 2 additional Pi5 units     |

---

## 🧠 AI-Human Collaboration Notes

**Philosophy**: AI (Grok, Copilot, Ollama) assists with code generation, log analysis, and prompt suggestions. Humans validate outputs, make architectural decisions, and ensure classroom empathy.

**Examples**:
- ✅ **Good Use**: "Analyze this UniFi log for AP dropout patterns" → AI highlights anomalies → Human investigates root cause
- ❌ **Bad Use**: "Auto-deploy VLAN changes without teacher review" → AI makes unsupervised network changes → Chaos ensues

**Audit Trail**: All AI suggestions logged to `~/unifi-logs/ai-decisions.log` for transparency and learning.

---

## 📞 Maintainer Notes

**From Grok's Assessment**:
> "The stack's not just wired for UniFi orchestration; it's primed for those human-machine edtech rhythms we chew on—AI suggesting VLAN tweaks based on student traffic patterns, without the hubris of full autonomy. Skeptical of overreach? Absolutely; the API stub's a tool, not a takeover."

**Travis's Intent**:
- Keep iterating—small changes, frequent validation
- Document everything for reproducibility
- Empathy for classroom constraints (flaky devices, on-prem limits)
- AI augments, humans decide

**Community Contributions Welcome**:
- File issues for friction points
- PRs for doc improvements, test cases, or whimsy features
- Share classroom pilot results (anonymized)

---

**Let's Riff**: Ready to layer Phase 2, or refine Phase 1 first? Your lead shapes the next beat. 🎸
