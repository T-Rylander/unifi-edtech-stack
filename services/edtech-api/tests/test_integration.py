#!/usr/bin/env python3
"""
Integration tests for edtech-api

Tests end-to-end workflows with real Ollama service.
These tests require Ollama to be running (skip if not available).
"""

import pytest
import requests
import os

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
API_HOST = os.getenv("API_HOST", "http://localhost:5000")
API_KEY = os.getenv("API_KEY", "test-api-key-123")


def is_ollama_available():
    """Check if Ollama is reachable"""
    try:
        response = requests.get(f"{OLLAMA_HOST}/api/version", timeout=5)
        return response.status_code == 200
    except Exception:
        return False


def is_api_available():
    """Check if edtech-api is reachable"""
    try:
        response = requests.get(f"{API_HOST}/health", timeout=5)
        return response.status_code == 200
    except Exception:
        return False


@pytest.mark.skipif(not is_ollama_available(), reason="Ollama not available")
class TestOllamaIntegration:
    """Integration tests with real Ollama service"""

    def test_ollama_health(self):
        """Test Ollama health check"""
        response = requests.get(f"{OLLAMA_HOST}/api/version", timeout=5)
        assert response.status_code == 200

        data = response.json()
        assert "version" in data

    def test_ollama_query(self):
        """Test direct Ollama query"""
        payload = {
            "model": "llama3:8b",
            "prompt": "What is 2+2? Reply with only the number.",
            "stream": False,
        }

        response = requests.post(
            f"{OLLAMA_HOST}/api/generate", json=payload, timeout=30
        )

        assert response.status_code == 200
        data = response.json()
        assert "response" in data


@pytest.mark.skipif(not is_api_available(), reason="edtech-api not available")
class TestAPIIntegration:
    """Integration tests with running edtech-api"""

    def test_api_health(self):
        """Test API health check"""
        response = requests.get(f"{API_HOST}/health", timeout=5)
        assert response.status_code == 200

        data = response.json()
        assert "status" in data
        assert data["status"] in ["healthy", "degraded"]

    def test_api_version(self):
        """Test API version endpoint"""
        response = requests.get(f"{API_HOST}/api/version", timeout=5)
        assert response.status_code == 200

        data = response.json()
        assert "api_version" in data
        assert "ollama_version" in data

    @pytest.mark.skipif(not is_ollama_available(), reason="Ollama not available")
    def test_vlan_grouping_e2e(self):
        """Test end-to-end VLAN grouping with real Ollama"""
        payload = {
            "ssids": ["lab-101", "quiet-corner"],
            "devices": [
                {
                    "mac": "AA:BB:CC:DD:EE:FF",
                    "signal": -45,
                    "hostname": "student-chromebook-12",
                },
                {
                    "mac": "11:22:33:44:55:66",
                    "signal": -72,
                    "hostname": "ipad-08",
                },
            ],
        }

        response = requests.post(
            f"{API_HOST}/vlan-group",
            json=payload,
            headers={"X-API-Key": API_KEY},
            timeout=60,  # Ollama queries can be slow
        )

        # May fail if API_KEY is not set correctly
        if response.status_code == 401:
            pytest.skip("API key authentication failed")

        assert response.status_code == 200
        data = response.json()

        # Validate response structure
        assert "suggestion" in data
        assert "confidence" in data
        assert "reasoning" in data
        assert data["human_review_required"] is True


@pytest.mark.skipif(
    not (is_api_available() and is_ollama_available()),
    reason="Full stack not available",
)
class TestFullStackIntegration:
    """Tests requiring both API and Ollama"""

    def test_health_check_reports_ollama_status(self):
        """Test that health endpoint correctly reports Ollama status"""
        response = requests.get(f"{API_HOST}/health", timeout=5)
        data = response.json()

        assert data["ollama_reachable"] is True
        assert data["status"] == "healthy"

    def test_feedback_workflow(self):
        """Test full workflow: suggestion + feedback"""
        # Step 1: Get AI suggestion
        payload = {
            "ssids": ["lab-101"],
            "devices": [
                {"mac": "AA:BB:CC:DD:EE:FF", "signal": -50, "hostname": "device-1"}
            ],
        }

        response = requests.post(
            f"{API_HOST}/vlan-group",
            json=payload,
            headers={"X-API-Key": API_KEY},
            timeout=60,
        )

        if response.status_code == 401:
            pytest.skip("API key authentication failed")

        assert response.status_code == 200
        suggestion_data = response.json()
        timestamp = suggestion_data["timestamp"]

        # Step 2: Record feedback
        feedback_payload = {
            "timestamp": timestamp,
            "decision": "approved",
            "notes": "Integration test feedback",
        }

        feedback_response = requests.post(
            f"{API_HOST}/feedback",
            json=feedback_payload,
            headers={"X-API-Key": API_KEY},
            timeout=10,
        )

        assert feedback_response.status_code == 200
        feedback_data = feedback_response.json()
        assert feedback_data["status"] == "feedback recorded"


if __name__ == "__main__":
    # Print environment info
    print(f"\nOllama Host: {OLLAMA_HOST}")
    print(f"API Host: {API_HOST}")
    print(f"Ollama available: {is_ollama_available()}")
    print(f"API available: {is_api_available()}\n")

    # Run tests
    pytest.main([__file__, "-v", "-s"])
