#!/usr/bin/env python3
"""
VLAN Listener - UniFi Event Polling (Optional)

Polls UniFi Controller for device events and triggers AI suggestions.
This is a stub for future Phase 2 implementation.
"""

import logging
import time
from typing import Optional

logger = logging.getLogger(__name__)


class VLANListener:
    """
    Listens for UniFi events and triggers AI suggestions.

    TODO: Implement in Phase 2
    - WebSocket connection to UniFi Controller
    - Event filtering (device connect/disconnect)
    - Trigger AI suggestions on threshold (e.g., 5+ new devices)
    """

    def __init__(self, unifi_host: str, unifi_username: str, unifi_password: str):
        """
        Initialize VLAN listener.

        Args:
            unifi_host: UniFi Controller URL
            unifi_username: UniFi admin username
            unifi_password: UniFi admin password
        """
        self.unifi_host = unifi_host
        self.unifi_username = unifi_username
        self.unifi_password = unifi_password
        logger.info(f"Initialized VLANListener for {unifi_host}")

    def start_polling(self, interval: int = 30):
        """
        Start polling UniFi Controller for events.

        Args:
            interval: Polling interval in seconds
        """
        logger.info(f"Starting UniFi event polling (every {interval}s)")
        while True:
            try:
                # TODO: Poll UniFi API for new device events
                # Example: GET /api/s/default/stat/sta
                logger.debug("Polling UniFi for device events...")

                # Simulate polling
                time.sleep(interval)

            except KeyboardInterrupt:
                logger.info("Stopping UniFi event polling")
                break
            except Exception as e:
                logger.error(f"Error polling UniFi: {e}")
                time.sleep(interval)

    def get_connected_devices(self) -> list:
        """
        Get list of currently connected devices.

        Returns:
            List of device dictionaries with mac, signal, hostname

        TODO: Implement UniFi API call
        """
        logger.warning("get_connected_devices() is a stub - returning empty list")
        return []


# === TEST CODE ===

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)

    listener = VLANListener(
        unifi_host="https://unifi-controller:8443",
        unifi_username="admin",
        unifi_password="password",
    )

    # In production, this would run as a background thread
    # For now, it's just a stub
    logger.info("VLANListener is a Phase 2 stub - not polling")
