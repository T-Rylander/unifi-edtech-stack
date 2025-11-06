# Docker Compose Stack

Production-ready orchestration for UniFi Edtech Stack on Raspberry Pi 5 (aarch64).

## Requirements

- **Docker Compose**: v2.24+ (for `env_file.required` validation)
- **Prepared by first-run.sh**:
  - `/etc/unifi-edtech/config.env` with all required variables
  - Docker network named `${DOCKER_NETWORK:-unifi-net}` created as external
  - WireGuard keys in `/etc/wireguard/`

## Services

### Core Stack
- **wireguard**: Secure tunnel via linuxserver/wireguard image
- **unifi-controller**: UniFi Network Application (jacobalberty/unifi)

### Optional (AI Profile)
- **ollama**: Local LLM inference engine (enable with `--profile ai`)

### Planned
- **edtech-api**: Custom REST API for VLAN automation (stub provided)

## Usage

### Standard Deployment
```bash
cd docker
docker compose up -d
```

### With AI (Ollama)
```bash
docker compose --profile ai up -d
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f unifi-controller
```

### Teardown
```bash
docker compose down
```

## Key Features (Leo's Hardening)

### Critical Fixes
- **Robust healthchecks**: Explicit `|| exit 1` for reliable failure detection
- **Env validation**: `required: true` ensures config.env exists before start
- **Standardized memory**: `JVM_MAX_HEAP_SIZE` for UniFi Java heap tuning

### Security & Operations
- **Log rotation**: 10MB × 3 files max per service (prevents disk exhaustion)
- **Port minimization**: Optional ports (guest portal, speed test) commented by default
- **GPU readiness**: Coral TPU/AI HAT device passthrough stub in ollama service

## Required config.env Variables

Ensure `/etc/unifi-edtech/config.env` contains:

```bash
# Timezone
TZ=America/Chicago

# Network
DOCKER_NETWORK=unifi-net
WG_PORT=51820
WG_PEERS=1
SERVERURL=auto
PEERDNS=auto

# UniFi Controller
UNIFI_HTTPS_PORT=8443
UNIFI_HTTP_PORT=8080
UNIFI_STUN_PORT=3478
JVM_MAX_HEAP_SIZE=512M
```

**Note**: `first-run.sh` creates this file automatically with sensible defaults.

## Troubleshooting

### Compose Version Check
```bash
docker compose version
# Should be >= 2.24.0 for env_file.required support
```

If using older Compose, remove `required: true` from each `env_file` block.

### Network Not Found
If you see "network unifi-net not found":
```bash
# Verify network exists
docker network ls | grep unifi-net

# Recreate if needed
docker network create unifi-net
```

### WireGuard Not Starting
Check kernel modules and keys:
```bash
# Verify WireGuard module
lsmod | grep wireguard

# Check keys exist
sudo ls -la /etc/wireguard/
```

### UniFi Controller Slow Start
First boot can take 90+ seconds. Monitor with:
```bash
docker compose logs -f unifi-controller
```

## Next Steps

1. **Validate deployment**: Access UniFi at `https://<pi-ip>:8443`
2. **Enable AI features**: Run with `--profile ai` and pull models via Ollama
3. **Add edtech-api**: Uncomment service in docker-compose.yml and build custom API
4. **Harden secrets**: Implement Docker secrets or encrypted config for sensitive data

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [UniFi Controller Image](https://github.com/jacobalberty/unifi-docker)
- [LinuxServer WireGuard](https://docs.linuxserver.io/images/docker-wireguard)
- [Ollama Documentation](https://ollama.ai/docs)
