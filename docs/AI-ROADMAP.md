# 🤖 AI Integration Roadmap

**Project**: UniFi Edtech Stack  
**Last Updated**: November 6, 2025  
**Philosophy**: AI as augmentation tool, not autonomous overlord

---

## 🎯 Vision

Integrate Ollama/LLaMA for AI-assisted network operations that **augment human decision-making** in educational environments. AI suggests VLAN groupings, analyzes device patterns, and flags anomalies—but the educator always decides.

**Core Principle**: Skeptical of overreach. AI is empathetic to classroom chaos, not a black box replacement for human insight.

---

## 🚀 Current State (November 2025)

### ✅ What's Deployed
- **Ollama Service**: Containerized via docker-compose.yml (behind `ai` profile)
- **API Endpoint**: http://localhost:11434 for LLM queries
- **Model Persistence**: Docker volume for model storage
- **Healthcheck**: API tags endpoint validated on startup

### 🟡 In Progress
- **Fine-Tuned Model**: `edtech-assist` trained on UniFi logs (see Phase 2)
- **edtech-api Integration**: REST API to bridge UniFi events → Ollama queries

### ⚪ Planned
- **RADIUS Correlation**: Student auth → skill-based VLAN grouping
- **Prometheus Metrics**: Ollama queue depth, inference latency

---

## � Implementation Phases

### Phase 1: Ollama Service Deployment ✅ **Complete**

**Status**: Production-ready  
**Deliverables**:
- [x] Ollama container in docker-compose.yml
- [x] Health-chained dependency (starts after UniFi)
- [x] Volume persistence at `/root/.ollama`
- [x] Profile-gated deployment (`docker compose --profile ai up -d`)

**Usage**:
```bash
# Enable Ollama service
cd docker
docker compose --profile ai up -d

# Test API
curl http://localhost:11434/api/tags

# Pull a model
docker exec ollama-ai ollama pull llama3

# Query the model
curl http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Analyze this UniFi log for device bottlenecks: <paste log>",
  "stream": false
}'
```

---

### Phase 2: Fine-Tune on UniFi Logs 🟡 **In Progress**

**Goal**: Train custom `edtech-assist` model specialized for educational network operations

#### 2.1 Log Collection & Sanitization
**Priority**: High  
**Effort**: 4-6 hours

**Tasks**:
1. Collect 2-4 weeks of UniFi Controller logs from lab environment:
   ```bash
   docker logs unifi-controller > unifi-logs/adoption-$(date +%Y%m%d).txt
   # Or from container volume:
   docker exec unifi-controller cat /var/log/unifi/server.log > unifi-logs/server.log
   ```

2. Sanitize logs (strip PII):
   - MAC addresses → hashed IDs: `AA:BB:CC:DD:EE:FF` → `device-hash-12345`
   - Student names → generic labels: `John Doe` → `Student-A`
   - IP addresses → subnet masks: `192.168.1.42` → `192.168.1.x`

3. Format as prompt/response pairs (JSON or JSONL):
   ```json
   {
     "prompt": "Device device-hash-123 connected to SSID lab-101 at 08:15 with signal -65dBm. Suggest grouping.",
     "response": "Group with other lab-101 devices. Signal strength is good. Consider VLAN 101 for isolation."
   }
   ```

**Output**: `training-data/unifi-logs-sanitized.jsonl`

#### 2.2 Create Modelfile
**Priority**: High  
**Effort**: 2-3 hours

**Modelfile Template**:
```dockerfile
# models/Modelfile
FROM llama3

# System prompt defines AI's role and behavior
SYSTEM You are an expert network assistant for educational labs. Your role is to:
- Suggest VLAN groupings based on device type and SSID
- Analyze UniFi logs for connectivity issues and bottlenecks
- Flag anomalies in student device behavior
- Provide concise, actionable recommendations

Always prioritize student experience and classroom stability. Be skeptical of over-automation.

# Fine-tuning parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

# Training data injection (future enhancement)
# ADAPTER ./training-data/unifi-logs-sanitized.gguf
```

**Build Model**:
```bash
cd models
ollama create edtech-assist -f Modelfile

# Verify model
ollama list | grep edtech-assist
```

#### 2.3 Version Control with Git LFS
**Priority**: Medium  
**Effort**: 1 hour

**Setup**:
```bash
# Install Git LFS if not already
git lfs install

# Track model files
git lfs track "models/*.gguf"
git lfs track "models/*.bin"

# Commit .gitattributes
git add .gitattributes
git commit -m "Add Git LFS tracking for AI models"

# Version the model
git add models/edtech-assist.gguf
git commit -m "Add edtech-assist v1.0 - trained on 2 weeks UniFi logs"
git tag model-v1.0
```

**VERSIONS.md Entry**:
```markdown
## AI Models

### edtech-assist v1.0
- **Date**: 2025-11-06
- **Base Model**: llama3:8b
- **Training Data**: 2 weeks UniFi Controller logs (10k+ events)
- **Specialization**: VLAN grouping, device troubleshooting
- **Performance**: 85% suggestion accuracy (human-validated)
- **Git Tag**: model-v1.0
```

#### 2.4 Testing & Validation
**Priority**: High  
**Effort**: 3-4 hours

**Test Prompts**:
```bash
# Test 1: Device grouping
curl http://localhost:11434/api/generate -d '{
  "model": "edtech-assist",
  "prompt": "5 devices connected to lab-101. SSIDs: lab-101, lab-102, guest-wifi. Suggest VLAN grouping.",
  "stream": false
}'

# Test 2: Troubleshooting
curl http://localhost:11434/api/generate -d '{
  "model": "edtech-assist",
  "prompt": "AP dropped 3 devices in last hour. Signal -80dBm. Root cause?",
  "stream": false
}'

# Test 3: Anomaly detection
curl http://localhost:11434/api/generate -d '{
  "model": "edtech-assist",
  "prompt": "Device-42 made 100 DHCP requests in 10 minutes. Normal or attack?",
  "stream": false
}'
```

**Validation Criteria**:
- AI suggestions are **actionable** (specific VLANs, not vague advice)
- AI acknowledges **uncertainty** when logs are ambiguous
- AI defers to human judgment on policy decisions

**Success Metrics**:
- 80%+ suggestion accuracy (teacher validation)
- <2s inference latency for typical queries
- Zero hallucinated network configs

---

### Phase 3: edtech-api Integration 🟡 **In Progress**

**Goal**: REST API to bridge UniFi events → Ollama queries → VLAN automation

**Status**: Stubbed in docker-compose.yml, implementation pending

**Architecture**:
```
UniFi Controller → edtech-api → Ollama → edtech-api → Teacher Dashboard
                      ↓
                 VLAN Assignment
```

#### 3.1 API Endpoints
**Priority**: High  
**Effort**: 6-8 hours

**Routes**:
- `POST /vlan-group` - Auto-group devices by SSID/signal
  - Input: `{ "devices": [...], "ssid": "lab-101" }`
  - AI Query: "Suggest VLAN for these devices"
  - Output: `{ "vlan_id": 101, "confidence": 0.85, "reasoning": "..." }`

- `POST /ollama-query` - Generic AI query proxy
  - Input: `{ "prompt": "Analyze this log: ..." }`
  - Output: `{ "response": "...", "model": "edtech-assist" }`

- `GET /health` - Healthcheck (returns Ollama status)

**Implementation**: See `services/edtech-api/` (Phase 2 of PHASED-ROADMAP.md)

#### 3.2 UniFi Event Listener
**Priority**: Medium  
**Effort**: 4-6 hours

**Flow**:
1. Poll UniFi Controller API every 30s for events:
   - New device adoptions
   - Client connects/disconnects
   - AP status changes

2. Filter for relevant events (e.g., student device connects)

3. Query Ollama for recommendation:
   ```python
   prompt = f"Device {mac} connected to {ssid}. Signal: {rssi}dBm. Suggest VLAN."
   response = ollama_query(prompt)
   ```

4. Log recommendation with metadata:
   ```json
   {
     "timestamp": "2025-11-06T10:30:00Z",
     "device": "device-hash-123",
     "ai_suggestion": "VLAN 101",
     "confidence": 0.87,
     "human_override": null
   }
   ```

**Audit Trail**: All AI suggestions logged to `~/unifi-logs/ai-decisions.log`

---

### Phase 4: RADIUS Integration ⚪ **Planned**

**Goal**: Correlate student auth with device grouping

**Flow**:
```
Student logs in (RADIUS) → edtech-api captures username
                        → Query skill level from LMS/AD
                        → Ollama: "Student has skill: intermediate. Suggest lab pairing."
                        → VLAN assignment + grouping recommendation
```

**Prerequisites**:
- FreeRADIUS container in docker-compose.yml
- LDAP/AD integration for student metadata
- Teacher dashboard for reviewing AI pairings

**Effort**: 10-12 hours (see Phase 3.3 of PHASED-ROADMAP.md)

---

### Phase 5: Monitoring & Alerting ⚪ **Planned**

**Goal**: Prometheus metrics + Grafana dashboards for AI performance

**Metrics**:
- `ollama_query_duration_seconds` - Inference latency
- `ollama_queue_depth` - Pending queries
- `edtech_api_vlan_suggestions_total` - Counter of AI suggestions
- `edtech_api_human_overrides_total` - Counter of teacher overrides

**Alerts**:
- Ollama queue backup > 10 requests → "AI service degraded"
- Human override rate > 30% → "AI model accuracy declining, retrain?"

**Dashboard Panels**:
- AI suggestion accuracy over time (requires human validation data)
- Inference latency histogram
- Most common AI queries (for model improvement)

**Effort**: 6-8 hours (see Phase 3.1 of PHASED-ROADMAP.md)

---

## �️ Tools & Commands

### Ollama Management
```bash
# List models
docker exec ollama-ai ollama list

# Pull new model
docker exec ollama-ai ollama pull llama3:latest

# Create custom model
docker exec ollama-ai ollama create edtech-assist -f /models/Modelfile

# Delete model
docker exec ollama-ai ollama rm old-model

# Show model info
docker exec ollama-ai ollama show edtech-assist
```

### API Testing
```bash
# Generate with streaming
curl http://localhost:11434/api/generate -d '{
  "model": "edtech-assist",
  "prompt": "Your prompt here",
  "stream": true
}'

# Generate without streaming (wait for full response)
curl http://localhost:11434/api/generate -d '{
  "model": "edtech-assist",
  "prompt": "Your prompt here",
  "stream": false
}'

# Chat completions (multi-turn)
curl http://localhost:11434/api/chat -d '{
  "model": "edtech-assist",
  "messages": [
    {"role": "user", "content": "Analyze this log"},
    {"role": "assistant", "content": "I see 3 AP dropouts"},
    {"role": "user", "content": "Suggest fix"}
  ]
}'
```

---

## 📊 Success Metrics

| Metric                          | Target   | Current | Notes                           |
|---------------------------------|----------|---------|----------------------------------|
| AI Suggestion Accuracy          | >80%     | TBD     | Human validation required        |
| Inference Latency               | <2s      | ~1.5s   | For typical queries              |
| Teacher Override Rate           | <30%     | TBD     | Lower = better model fit         |
| Ollama Uptime                   | >99%     | ~98%    | Healthcheck passing              |
| Model Version Frequency         | Monthly  | N/A     | Retrain with new log data        |

---

## 🧠 AI Ethics & Guardrails

### Human-AI Collaboration Principles
1. **AI Suggests, Humans Decide**: No automated VLAN changes without teacher approval
2. **Transparency**: All AI suggestions logged with confidence scores
3. **Audit Trail**: Decisions tracked for accountability and learning
4. **Bias Awareness**: Regularly review AI suggestions for unintended patterns
5. **Right to Override**: Teachers can always override AI recommendations

### Failure Modes & Mitigations
- **AI Hallucination**: Validate all network configs before applying
- **Over-Confidence**: Require human review for confidence <0.7
- **Model Drift**: Monthly retraining with fresh logs
- **Privacy**: Never send PII to external APIs (all local inference)

---

## 📚 References

- [Ollama Documentation](https://ollama.ai/docs)
- [LLaMA Model Cards](https://huggingface.co/meta-llama)
- [Git LFS Guide](https://git-lfs.github.com/)
- [UniFi API Reference](https://ubntwiki.com/products/software/unifi-controller/api)

---

## 📞 Next Actions

**Current Priority**: Complete Phase 2 (fine-tune edtech-assist model)

**Decision Point**: After Phase 2 validation, choose:
- **Option A**: Implement edtech-api (Phase 3) for VLAN automation demo
- **Option B**: Add monitoring layer (Phase 5) to track AI performance
- **Option C**: Pilot with real classroom (10 student devices)

**Maintainer**: Travis Rylander (@T-Rylander)  
**Community Input**: File issues for AI use cases or prompt templates you'd like to see!

---

**Remember**: AI is a tool, not a replacement for human insight. Always validate AI outputs with real-world data. 🤖🤝👨‍🏫