"""
UniFi Edtech Stack - Integration Tests
Tests for Docker Compose stack health and service availability
"""

import pytest
import requests
import subprocess
import time
from typing import Dict, List


class TestDockerComposeHealth:
    """Test suite for Docker Compose services health checks"""

    @pytest.fixture(scope="class")
    def compose_services(self) -> List[str]:
        """Get list of running compose services"""
        result = subprocess.run(
            ["docker", "compose", "ps", "--services"],
            cwd="../docker",
            capture_output=True,
            text=True
        )
        return result.stdout.strip().split("\n")

    def test_docker_is_running(self):
        """Verify Docker daemon is accessible"""
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, "Docker daemon not accessible"

    def test_compose_services_up(self, compose_services):
        """Verify all expected services are running"""
        expected_services = ["wireguard", "unifi-controller"]
        
        for service in expected_services:
            assert service in compose_services, f"Service {service} not found in running services"

    def test_wireguard_healthy(self):
        """Test WireGuard container health"""
        result = subprocess.run(
            ["docker", "exec", "unifi-wg-tunnel", "wg", "show"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, "WireGuard interface not accessible"
        assert "interface:" in result.stdout.lower(), "WireGuard interface not configured"

    def test_unifi_controller_reachable(self):
        """Test UniFi Controller HTTPS endpoint"""
        try:
            # Allow self-signed cert
            response = requests.get(
                "https://localhost:8443",
                verify=False,
                timeout=10
            )
            # UniFi returns various status codes on initial setup
            assert response.status_code in [200, 302, 400], \
                f"Unexpected status code: {response.status_code}"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Cannot reach UniFi Controller: {e}")

    @pytest.mark.skipif("ollama" not in subprocess.run(
        ["docker", "compose", "ps", "--services"],
        cwd="../docker",
        capture_output=True,
        text=True
    ).stdout, reason="Ollama profile not enabled")
    def test_ollama_api_available(self):
        """Test Ollama API endpoint (if AI profile enabled)"""
        try:
            response = requests.get(
                "http://localhost:11434/api/tags",
                timeout=10
            )
            assert response.status_code == 200, "Ollama API not responding"
            data = response.json()
            assert "models" in data, "Ollama API response malformed"
        except requests.exceptions.RequestException as e:
            pytest.fail(f"Cannot reach Ollama API: {e}")


class TestConfigurationFiles:
    """Test suite for configuration file validity"""

    def test_config_env_exists(self):
        """Verify /etc/unifi-edtech/config.env exists"""
        import os
        config_path = "/etc/unifi-edtech/config.env"
        
        # Skip if not on Pi (e.g., CI environment)
        if not os.path.exists(config_path):
            pytest.skip(f"Config file not found: {config_path} (not on Pi?)")
        
        assert os.path.isfile(config_path), "Config file is not a regular file"

    def test_required_env_variables(self):
        """Check that required variables are set in config.env"""
        import os
        
        config_path = "/etc/unifi-edtech/config.env"
        if not os.path.exists(config_path):
            pytest.skip("Config file not found (not on Pi?)")
        
        required_vars = [
            "HOSTNAME",
            "IP",
            "ROUTER",
            "DNS",
            "DOCKER_NETWORK",
            "WG_PORT"
        ]
        
        with open(config_path, 'r') as f:
            config_content = f.read()
        
        for var in required_vars:
            assert f"{var}=" in config_content, f"Required variable {var} not found in config"


class TestSecurityPosture:
    """Test suite for security configuration"""

    def test_apparmor_enabled(self):
        """Verify AppArmor is enabled"""
        result = subprocess.run(
            ["aa-status", "--enabled"],
            capture_output=True,
            text=True
        )
        # Skip if AppArmor not installed (e.g., non-Pi system)
        if result.returncode == 127:
            pytest.skip("AppArmor not installed")
        
        assert result.returncode == 0, "AppArmor is not enabled"

    def test_fail2ban_running(self):
        """Verify Fail2Ban service is active"""
        result = subprocess.run(
            ["systemctl", "is-active", "fail2ban"],
            capture_output=True,
            text=True
        )
        # Skip if Fail2Ban not installed
        if "not-found" in result.stdout:
            pytest.skip("Fail2Ban not installed")
        
        assert result.stdout.strip() == "active", "Fail2Ban is not running"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
