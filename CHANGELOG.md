# Changelog

All notable changes to the UniFi Edtech Stack project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive FIRST-RUN.md with post-boot validation, troubleshooting, and AI onboarding workflows
- swarm-init.sh v0.1.0 - Idempotent Docker Swarm initialization script with --dry-run support
- Mermaid diagram in FIRST-RUN.md showing first-run.sh boot sequence
- Human-AI onboarding section with Ollama prompt examples for VLAN grouping and troubleshooting
- Extended troubleshooting guide covering common deployment issues

### Changed
- README.md expanded with full quickstart, architecture diagram, and documentation index
- AI-ROADMAP.md restructured with 5-phase implementation plan and ethics/guardrails section
- PROJECT-STATUS.md added with 85% goal coverage metrics and testing status table
- PHASED-ROADMAP.md created with three-phase implementation strategy

### Fixed
- Docker compose env validation now requires Compose v2.24+ (documented)
- WireGuard healthcheck improved with explicit exit codes

## [0.1.0] - 2025-11-06

### Added
- Initial project structure with docs/, scripts/, and docker/ directories
- first-run.sh v1.0.0 - Pi5 provisioning script with auto-detect, validation, and hardening
- docker-compose.yml with hardened services (WireGuard, UniFi Controller, Ollama)
- Configuration management via /etc/unifi-edtech/config.env
- WireGuard key generation (idempotent)
- Docker network creation (unifi-net)
- Security defaults: AppArmor, Fail2Ban, SSH key-only
- Ollama service behind optional 'ai' profile
- Logging with 10MB × 3 file rotation

### Documentation
- README.md with project goals and quickstart
- AI-ROADMAP.md with AI integration phases
- DOCKER-SWARM.md with multi-node setup guidance
- SECURITY.md with hardening recommendations
- MONITORING.md with observability guidelines
- TROUBLESHOOTING.md with common issues

### Infrastructure
- Git repository initialized with .gitignore for logs and secrets
- Backup management with max 10 backups (auto-cleanup)
- QR code generation for documentation handoff (optional)

## Version History

- **v0.1.0** (2025-11-06): Initial release with core provisioning and orchestration
- **Unreleased**: Phase 1 enhancements (expanded docs, swarm-init, CI/CD)

---

## How to Contribute

When making changes:

1. **Update Unreleased section** with your changes under appropriate category:
   - **Added**: New features
   - **Changed**: Changes to existing functionality
   - **Deprecated**: Soon-to-be removed features
   - **Removed**: Removed features
   - **Fixed**: Bug fixes
   - **Security**: Vulnerability fixes

2. **Use conventional commits** for git messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `refactor:` for code refactoring
   - `test:` for test additions
   - `chore:` for maintenance tasks

3. **Tag releases** using semantic versioning:
   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0: Phase 1 completion"
   git push origin v0.2.0
   ```

4. **Move Unreleased to versioned section** when releasing:
   - Update `## [Unreleased]` → `## [0.2.0] - YYYY-MM-DD`
   - Add new empty `## [Unreleased]` section at top

---

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
