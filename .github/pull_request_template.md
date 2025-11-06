## Description
<!-- Brief description of your changes -->

## Type of Change
<!-- Check all that apply -->
- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change (document migration in CHANGELOG.md)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)

## Testing
<!-- Verify your changes work -->
- [ ] Tested on Raspberry Pi 5 (8GB)
- [ ] All tests pass: `pytest tests/ -v`
- [ ] Shellcheck clean: `shellcheck scripts/*.sh`
- [ ] Docker Compose validates: `docker compose config`
- [ ] Manual feature testing completed

## Human-AI Balance Check
<!-- Critical for AI features -->
- [ ] AI suggestions require human approval (no autonomous changes)
- [ ] Teacher/admin override mechanism present
- [ ] PII sanitized in logs and training data (if applicable)

## Classroom Empathy Check
<!-- Does this work in real educational environments? -->
- [ ] Handles flaky student devices gracefully
- [ ] No cloud dependencies (on-prem compatible)
- [ ] Works under Pi thermal constraints

## Checklist
<!-- Standard requirements -->
- [ ] Code follows [style guide](CONTRIBUTING.md#-style-guide)
- [ ] Documentation updated (README, relevant docs/)
- [ ] CHANGELOG.md updated under `[Unreleased]` section
- [ ] Commit messages follow [conventional commits](CONTRIBUTING.md#%EF%B8%8F-commit-message-conventions)
- [ ] No secrets or PII committed

## Related Issues
<!-- Link related issues -->
Fixes #
Addresses #
Relates to #

## Additional Context
<!-- Screenshots, logs, design decisions, etc. -->
