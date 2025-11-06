#!/usr/bin/env python3
"""
Ollama Client - Wrapper for Ollama API interactions

Handles queries to Ollama for AI-powered network suggestions.
"""

import logging
import requests
from typing import Optional

logger = logging.getLogger(__name__)


class OllamaClient:
    """Client for interacting with Ollama API"""

    def __init__(self, host: str, model: str = "llama3:8b", timeout: int = 30):
        """
        Initialize Ollama client.

        Args:
            host: Ollama API URL (e.g., "http://ollama:11434")
            model: Model to use for queries (default: llama3:8b)
            timeout: Request timeout in seconds
        """
        self.host = host.rstrip("/")
        self.model = model
        self.timeout = timeout
        logger.info(f"Initialized OllamaClient for {self.host} with model {self.model}")

    def is_healthy(self) -> bool:
        """
        Check if Ollama is reachable and healthy.

        Returns:
            True if healthy, False otherwise
        """
        try:
            response = requests.get(f"{self.host}/api/version", timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Ollama health check failed: {e}")
            return False

    def get_version(self) -> str:
        """
        Get Ollama version.

        Returns:
            Version string or "unknown" if unavailable
        """
        try:
            response = requests.get(f"{self.host}/api/version", timeout=5)
            if response.status_code == 200:
                version_data = response.json()
                return version_data.get("version", "unknown")
        except Exception as e:
            logger.error(f"Failed to get Ollama version: {e}")
        return "unknown"

    def query(self, prompt: str, system: Optional[str] = None) -> str:
        """
        Send a query to Ollama and return the response.

        Args:
            prompt: User prompt to send to the model
            system: Optional system prompt to set context

        Returns:
            Model's response as string

        Raises:
            Exception: If request fails or times out
        """
        try:
            payload = {
                "model": self.model,
                "prompt": prompt,
                "stream": False,  # Get full response at once
            }

            if system:
                payload["system"] = system

            logger.info(f"Querying Ollama model '{self.model}'")
            logger.debug(f"Prompt: {prompt[:100]}...")  # Log first 100 chars

            response = requests.post(
                f"{self.host}/api/generate",
                json=payload,
                timeout=self.timeout,
            )

            if response.status_code != 200:
                error_msg = f"Ollama API returned {response.status_code}: {response.text}"
                logger.error(error_msg)
                raise Exception(error_msg)

            response_data = response.json()
            answer = response_data.get("response", "")

            logger.info(f"Ollama response received ({len(answer)} chars)")
            logger.debug(f"Response: {answer[:100]}...")

            return answer

        except requests.exceptions.Timeout:
            error_msg = f"Ollama request timed out after {self.timeout}s"
            logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.ConnectionError as e:
            error_msg = f"Failed to connect to Ollama at {self.host}: {e}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            logger.error(f"Unexpected error querying Ollama: {e}")
            raise

    def list_models(self) -> list:
        """
        List available models in Ollama.

        Returns:
            List of model names
        """
        try:
            response = requests.get(f"{self.host}/api/tags", timeout=10)
            if response.status_code == 200:
                data = response.json()
                models = [model["name"] for model in data.get("models", [])]
                logger.info(f"Available Ollama models: {models}")
                return models
        except Exception as e:
            logger.error(f"Failed to list Ollama models: {e}")
        return []

    def pull_model(self, model: str) -> bool:
        """
        Pull a model from Ollama registry.

        Args:
            model: Model name to pull (e.g., "llama3:8b")

        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info(f"Pulling Ollama model '{model}'...")
            response = requests.post(
                f"{self.host}/api/pull",
                json={"name": model},
                timeout=300,  # 5 minutes for large downloads
            )
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Failed to pull model '{model}': {e}")
            return False


# === TEST CODE ===

if __name__ == "__main__":
    # Test Ollama client locally
    import os

    logging.basicConfig(level=logging.DEBUG)

    ollama_host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    client = OllamaClient(ollama_host)

    # Test health check
    print(f"\nHealth check: {client.is_healthy()}")
    print(f"Version: {client.get_version()}")

    # Test model listing
    print(f"Models: {client.list_models()}")

    # Test query
    if client.is_healthy():
        response = client.query(
            prompt="What is 2+2? Respond with only the number.",
            system="You are a helpful math assistant.",
        )
        print(f"\nQuery response: {response}")
