# UniFi Edtech Stack - Test Suite

Automated tests for validating stack deployment and health.

## Structure

```
tests/
├── test_integration.py     # Docker Compose health checks
├── test_config.py          # Configuration validation (planned)
├── test_security.py        # Security posture tests (planned)
└── requirements.txt        # Python test dependencies
```

## Prerequisites

```bash
# Install test dependencies
pip install -r tests/requirements.txt
```

## Running Tests

### All Tests
```bash
cd tests
pytest -v
```

### Specific Test Class
```bash
pytest test_integration.py::TestDockerComposeHealth -v
```

### Single Test
```bash
pytest test_integration.py::TestDockerComposeHealth::test_unifi_controller_reachable -v
```

### Skip Slow Tests
```bash
pytest -v -m "not slow"
```

## Test Categories

### Integration Tests (`test_integration.py`)
- **Docker Health**: Verify daemon accessibility
- **Compose Services**: Check all services are up
- **WireGuard**: Test tunnel interface
- **UniFi Controller**: Validate HTTPS endpoint
- **Ollama**: Test API (if AI profile enabled)

### Configuration Tests (`test_config.py`) - Planned
- Validate `/etc/unifi-edtech/config.env` format
- Check required variables present
- Test IP/CIDR format validation
- Verify port ranges

### Security Tests (`test_security.py`) - Planned
- AppArmor enabled check
- Fail2Ban active check
- SSH config validation (password auth disabled)
- Docker socket permissions

## CI/CD Integration

Tests run automatically on:
- Push to `main` or `develop`
- Pull requests to `main`

See `.github/workflows/ci.yml` for workflow details.

## Writing New Tests

### Test Structure
```python
import pytest

class TestMyFeature:
    """Test suite for my feature"""
    
    def test_something(self):
        """Test description"""
        assert True, "Failure message"
```

### Fixtures
Use pytest fixtures for shared setup:
```python
@pytest.fixture(scope="class")
def my_setup(self):
    # Setup code
    yield data
    # Teardown code
```

### Skipping Tests
Skip tests conditionally:
```python
@pytest.mark.skipif(condition, reason="Why skipped")
def test_something(self):
    pass
```

## Troubleshooting

### Docker Not Found
```bash
# Ensure Docker is installed
docker --version

# Check Docker daemon
sudo systemctl status docker
```

### Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Config File Not Found
Tests skip if `/etc/unifi-edtech/config.env` doesn't exist (e.g., running on dev machine, not Pi).

## Future Enhancements

- [ ] Performance tests (load testing with simulated devices)
- [ ] Network latency tests (WireGuard tunnel overhead)
- [ ] AI response accuracy tests (Ollama prompt validation)
- [ ] Multi-node Swarm tests (manager + worker validation)
- [ ] Log parsing tests (anomaly detection)

## References

- [pytest Documentation](https://docs.pytest.org/)
- [Docker Python SDK](https://docker-py.readthedocs.io/)
- [requests Library](https://docs.python-requests.org/)
