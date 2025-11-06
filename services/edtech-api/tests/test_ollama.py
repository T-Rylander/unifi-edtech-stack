#!/usr/bin/env python3
"""
Ollama client tests

Tests the OllamaClient wrapper for API interactions.
"""

import pytest
from unittest.mock import Mock, patch
import requests

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from ollama_client import OllamaClient


@pytest.fixture
def ollama_client():
    """Create OllamaClient for testing"""
    return OllamaClient(host="http://localhost:11434", model="llama3:8b", timeout=10)


class TestOllamaClientInit:
    """Tests for OllamaClient initialization"""

    def test_client_initialization(self):
        """Test client initializes with correct parameters"""
        client = OllamaClient("http://ollama:11434", model="llama3:4b", timeout=20)

        assert client.host == "http://ollama:11434"
        assert client.model == "llama3:4b"
        assert client.timeout == 20

    def test_host_trailing_slash_removed(self):
        """Test that trailing slash is removed from host"""
        client = OllamaClient("http://ollama:11434/")

        assert client.host == "http://ollama:11434"


class TestHealthCheck:
    """Tests for is_healthy() method"""

    @patch("requests.get")
    def test_health_check_success(self, mock_get, ollama_client):
        """Test successful health check"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_get.return_value = mock_response

        result = ollama_client.is_healthy()

        assert result is True
        mock_get.assert_called_once_with(
            "http://localhost:11434/api/version", timeout=5
        )

    @patch("requests.get")
    def test_health_check_failure(self, mock_get, ollama_client):
        """Test health check when service is down"""
        mock_get.side_effect = requests.exceptions.ConnectionError()

        result = ollama_client.is_healthy()

        assert result is False

    @patch("requests.get")
    def test_health_check_timeout(self, mock_get, ollama_client):
        """Test health check timeout"""
        mock_get.side_effect = requests.exceptions.Timeout()

        result = ollama_client.is_healthy()

        assert result is False


class TestGetVersion:
    """Tests for get_version() method"""

    @patch("requests.get")
    def test_get_version_success(self, mock_get, ollama_client):
        """Test successful version retrieval"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"version": "0.1.20"}
        mock_get.return_value = mock_response

        version = ollama_client.get_version()

        assert version == "0.1.20"

    @patch("requests.get")
    def test_get_version_failure(self, mock_get, ollama_client):
        """Test version retrieval when service is down"""
        mock_get.side_effect = requests.exceptions.ConnectionError()

        version = ollama_client.get_version()

        assert version == "unknown"


class TestQuery:
    """Tests for query() method"""

    @patch("requests.post")
    def test_query_success(self, mock_post, ollama_client):
        """Test successful query"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "response": "This is the AI response.",
            "model": "llama3:8b",
        }
        mock_post.return_value = mock_response

        result = ollama_client.query("What is 2+2?")

        assert result == "This is the AI response."
        mock_post.assert_called_once()

        # Check payload structure
        call_args = mock_post.call_args
        payload = call_args[1]["json"]
        assert payload["model"] == "llama3:8b"
        assert payload["prompt"] == "What is 2+2?"
        assert payload["stream"] is False

    @patch("requests.post")
    def test_query_with_system_prompt(self, mock_post, ollama_client):
        """Test query with system prompt"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"response": "4"}
        mock_post.return_value = mock_response

        result = ollama_client.query(
            prompt="What is 2+2?", system="You are a math assistant."
        )

        assert result == "4"

        # Check that system prompt is included
        call_args = mock_post.call_args
        payload = call_args[1]["json"]
        assert payload["system"] == "You are a math assistant."

    @patch("requests.post")
    def test_query_timeout(self, mock_post, ollama_client):
        """Test query timeout handling"""
        mock_post.side_effect = requests.exceptions.Timeout()

        with pytest.raises(Exception) as excinfo:
            ollama_client.query("Test prompt")

        assert "timed out" in str(excinfo.value).lower()

    @patch("requests.post")
    def test_query_connection_error(self, mock_post, ollama_client):
        """Test query connection error handling"""
        mock_post.side_effect = requests.exceptions.ConnectionError()

        with pytest.raises(Exception) as excinfo:
            ollama_client.query("Test prompt")

        assert "failed to connect" in str(excinfo.value).lower()

    @patch("requests.post")
    def test_query_http_error(self, mock_post, ollama_client):
        """Test query HTTP error handling"""
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"
        mock_post.return_value = mock_response

        with pytest.raises(Exception) as excinfo:
            ollama_client.query("Test prompt")

        assert "500" in str(excinfo.value)


class TestListModels:
    """Tests for list_models() method"""

    @patch("requests.get")
    def test_list_models_success(self, mock_get, ollama_client):
        """Test successful model listing"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "models": [
                {"name": "llama3:8b"},
                {"name": "llama3:4b"},
                {"name": "codellama:7b"},
            ]
        }
        mock_get.return_value = mock_response

        models = ollama_client.list_models()

        assert len(models) == 3
        assert "llama3:8b" in models
        assert "llama3:4b" in models
        assert "codellama:7b" in models

    @patch("requests.get")
    def test_list_models_empty(self, mock_get, ollama_client):
        """Test model listing when no models are available"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"models": []}
        mock_get.return_value = mock_response

        models = ollama_client.list_models()

        assert models == []

    @patch("requests.get")
    def test_list_models_failure(self, mock_get, ollama_client):
        """Test model listing when service is down"""
        mock_get.side_effect = requests.exceptions.ConnectionError()

        models = ollama_client.list_models()

        assert models == []


class TestPullModel:
    """Tests for pull_model() method"""

    @patch("requests.post")
    def test_pull_model_success(self, mock_post, ollama_client):
        """Test successful model pull"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_post.return_value = mock_response

        result = ollama_client.pull_model("llama3:4b")

        assert result is True
        mock_post.assert_called_once_with(
            "http://localhost:11434/api/pull",
            json={"name": "llama3:4b"},
            timeout=300,
        )

    @patch("requests.post")
    def test_pull_model_failure(self, mock_post, ollama_client):
        """Test model pull failure"""
        mock_post.side_effect = requests.exceptions.ConnectionError()

        result = ollama_client.pull_model("llama3:4b")

        assert result is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
