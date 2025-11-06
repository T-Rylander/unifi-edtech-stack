#!/usr/bin/env python3
"""
Edtech API - AI-Augmented VLAN Management

Flask API that bridges UniFi Controller events with Ollama AI suggestions
for classroom network management.
"""

import hashlib
import json
import logging
import os
from datetime import datetime

from flask import Flask, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from ollama_client import OllamaClient

# Configuration
API_VERSION = "0.1.0"
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
API_KEY = os.getenv("API_KEY", "")
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://ollama:11434")
UNIFI_HOST = os.getenv("UNIFI_HOST", "https://unifi-controller:8443")
RATE_LIMIT = os.getenv("RATE_LIMIT", "10/minute")
AI_DECISION_LOG = os.getenv("AI_DECISION_LOG", "/logs/ai-decisions.log")

# Logging setup
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper()),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Flask app
app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False

# Rate limiter
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=[RATE_LIMIT],
    storage_uri="memory://",
)

# Ollama client
ollama = OllamaClient(OLLAMA_HOST)


# === UTILITIES ===


def sanitize_mac(mac: str) -> str:
    """Convert MAC address to hashed device ID for PII protection"""
    return f"device-{hashlib.sha256(mac.encode()).hexdigest()[:8]}"


def require_api_key(func):
    """Decorator to enforce API key authentication"""

    def wrapper(*args, **kwargs):
        provided_key = request.headers.get("X-API-Key", "")
        if not API_KEY:
            logger.warning("API_KEY not set in environment - authentication disabled")
        elif provided_key != API_KEY:
            logger.warning(f"Invalid API key from {get_remote_address()}")
            return jsonify({"error": "Invalid or missing API key"}), 401
        return func(*args, **kwargs)

    wrapper.__name__ = func.__name__
    return wrapper


def log_ai_decision(query: str, suggestion: dict, human_decision: str, notes: str):
    """
    Log AI suggestion and human decision to audit trail.

    Args:
        query: Original query to Ollama
        suggestion: AI's suggested grouping
        human_decision: "approved", "rejected", or "pending"
        notes: Optional human notes
    """
    entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "query": query,
        "ai_suggestion": suggestion,
        "human_decision": human_decision,
        "notes": notes,
    }
    try:
        with open(AI_DECISION_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
        logger.info(f"AI decision logged: {human_decision}")
    except Exception as e:
        logger.error(f"Failed to log AI decision: {e}")


# === ROUTES ===


@app.route("/health", methods=["GET"])
def health():
    """Health check for Docker Compose"""
    ollama_healthy = ollama.is_healthy()
    unifi_healthy = True  # TODO: Implement UniFi health check

    status = "healthy" if (ollama_healthy and unifi_healthy) else "degraded"

    return jsonify(
        {
            "status": status,
            "ollama_reachable": ollama_healthy,
            "unifi_reachable": unifi_healthy,
            "api_version": API_VERSION,
        }
    )


@app.route("/api/version", methods=["GET"])
def version():
    """API version information"""
    ollama_version = ollama.get_version()
    return jsonify({"api_version": API_VERSION, "ollama_version": ollama_version})


@app.route("/vlan-group", methods=["POST"])
@require_api_key
@limiter.limit(RATE_LIMIT)
def suggest_vlan_grouping():
    """
    Suggest VLAN grouping based on device metadata.

    Request JSON:
    {
      "ssids": ["lab-101", "quiet-corner"],
      "devices": [
        {"mac": "AA:BB:CC:DD:EE:FF", "signal": -45, "hostname": "device-1"},
        {"mac": "11:22:33:44:55:66", "signal": -72, "hostname": "device-2"}
      ]
    }

    Response JSON:
    {
      "suggestion": {
        "lab-101": ["device-a1b2c3d4"],
        "quiet-corner": ["device-11223344"]
      },
      "confidence": 0.87,
      "reasoning": "Strong signal devices to lab-101...",
      "human_review_required": true
    }
    """
    try:
        data = request.get_json()

        # Validate input
        if not data or "ssids" not in data or "devices" not in data:
            return jsonify({"error": "Missing 'ssids' or 'devices' in request"}), 400

        ssids = data["ssids"]
        devices = data["devices"]

        if not isinstance(ssids, list) or not isinstance(devices, list):
            return jsonify({"error": "'ssids' and 'devices' must be arrays"}), 400

        # Sanitize MAC addresses for PII protection
        sanitized_devices = []
        mac_to_sanitized = {}
        for device in devices:
            if "mac" not in device:
                continue
            mac = device["mac"]
            sanitized_mac = sanitize_mac(mac)
            mac_to_sanitized[mac] = sanitized_mac
            sanitized_devices.append(
                {
                    "device_id": sanitized_mac,
                    "signal": device.get("signal", 0),
                    "hostname": device.get("hostname", "unknown"),
                }
            )

        # Build prompt for Ollama
        prompt = f"""
You are a network assistant for a classroom environment. Analyze the following devices and suggest how to group them across SSIDs for optimal performance.

Available SSIDs: {', '.join(ssids)}

Devices:
{json.dumps(sanitized_devices, indent=2)}

Consider:
1. Signal strength (prefer devices with strong signals on primary SSID)
2. Load balancing (distribute devices evenly)
3. Device type (if hostname indicates purpose)

Respond with JSON only in this format:
{{
  "suggestion": {{
    "lab-101": ["device-a1b2c3d4", "device-e5f6g7h8"],
    "quiet-corner": ["device-11223344"]
  }},
  "confidence": 0.87,
  "reasoning": "Strong signal devices to lab-101 for bandwidth-heavy tasks, weaker signals to quiet-corner."
}}
"""

        # Query Ollama
        logger.info(f"Querying Ollama for VLAN grouping ({len(devices)} devices)")
        ollama_response = ollama.query(prompt)

        # Parse Ollama response (expecting JSON)
        try:
            suggestion = json.loads(ollama_response)
        except json.JSONDecodeError:
            logger.warning(f"Ollama returned non-JSON response: {ollama_response}")
            suggestion = {
                "suggestion": {},
                "confidence": 0.0,
                "reasoning": "Ollama returned invalid response format",
            }

        # Add metadata
        suggestion["human_review_required"] = True
        suggestion["timestamp"] = datetime.utcnow().isoformat() + "Z"

        # Log AI decision (pending human review)
        log_ai_decision(
            query=f"Group {len(devices)} devices across {len(ssids)} SSIDs",
            suggestion=suggestion,
            human_decision="pending",
            notes="AI suggestion generated",
        )

        return jsonify(suggestion), 200

    except Exception as e:
        logger.error(f"Error in vlan-group endpoint: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/feedback", methods=["POST"])
@require_api_key
def record_feedback():
    """
    Record human feedback on AI suggestion.

    Request JSON:
    {
      "timestamp": "2025-01-19T14:23:45Z",
      "decision": "approved",
      "notes": "Moved devices to reduce congestion"
    }
    """
    try:
        data = request.get_json()

        if not data or "timestamp" not in data or "decision" not in data:
            return jsonify({"error": "Missing 'timestamp' or 'decision'"}), 400

        timestamp = data["timestamp"]
        decision = data["decision"]
        notes = data.get("notes", "")

        # Update AI decision log (find matching timestamp and update)
        logger.info(f"Recording feedback: {decision} for {timestamp}")

        # For now, just log as new entry (TODO: Update existing entry)
        log_ai_decision(
            query=f"Feedback for {timestamp}",
            suggestion={},
            human_decision=decision,
            notes=notes,
        )

        return jsonify({"status": "feedback recorded"}), 200

    except Exception as e:
        logger.error(f"Error in feedback endpoint: {e}")
        return jsonify({"error": str(e)}), 500


@app.errorhandler(429)
def ratelimit_handler(e):
    """Handle rate limit errors"""
    logger.warning(f"Rate limit exceeded from {get_remote_address()}")
    return jsonify({"error": "Rate limit exceeded. Try again later."}), 429


@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(e):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {e}")
    return jsonify({"error": "Internal server error"}), 500


# === MAIN ===

if __name__ == "__main__":
    # Validate required environment variables
    if not API_KEY:
        logger.warning("API_KEY not set - authentication disabled (INSECURE)")

    logger.info(f"Starting Edtech API v{API_VERSION}")
    logger.info(f"Ollama host: {OLLAMA_HOST}")
    logger.info(f"Rate limit: {RATE_LIMIT}")

    # Run Flask app
    app.run(host="0.0.0.0", port=5000, debug=(LOG_LEVEL == "DEBUG"))
