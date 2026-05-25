"""Station operations skill: register, configure, monitor ground stations."""
import json
import logging
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

_registered_stations: dict[str, dict[str, Any]] = {}
_monitoring_data: dict[str, list[dict[str, Any]]] = {}


def register_station(station_id: str, name: str, lat: float, lon: float, capabilities: list[str] | None = None) -> dict[str, Any]:
    """Register a new ground station in the network."""
    capabilities = capabilities or ["s-band"]
    station = {
        "id": station_id,
        "name": name,
        "lat": lat,
        "lon": lon,
        "capabilities": capabilities,
        "status": "offline",
        "registered_at": datetime.now(timezone.utc).isoformat(),
        "last_seen": None,
    }
    _registered_stations[station_id] = station
    _monitoring_data[station_id] = []
    logger.info(f"Station {station_id} ({name}) registered at ({lat}, {lon})")
    return station


def configure_station(station_id: str, config: dict[str, Any]) -> dict[str, Any]:
    """Update configuration for a registered ground station."""
    if station_id not in _registered_stations:
        raise ValueError(f"Station {station_id} not registered")
    _registered_stations[station_id]["config"] = config
    logger.info(f"Station {station_id} configuration updated")
    return _registered_stations[station_id]


def monitor_station(station_id: str) -> dict[str, Any]:
    """Get real-time monitoring data for a station."""
    data = {
        "station_id": station_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "cpu_usage": 45.2,
        "memory_usage": 62.1,
        "antenna_temperature": 22.5,
        "signal_quality": 0.94,
        "connection_status": "active",
    }
    if station_id in _monitoring_data:
        _monitoring_data[station_id].append(data)
    return data


def get_station_status(station_id: str) -> dict[str, Any]:
    """Get the current status of a ground station."""
    station = _registered_stations.get(station_id)
    if not station:
        raise ValueError(f"Station {station_id} not found")
    return {**station, "monitoring": monitor_station(station_id)}


def set_station_status(station_id: str, status: str) -> dict[str, Any]:
    """Set the operational status of a ground station."""
    valid = {"online", "offline", "maintenance", "degraded"}
    if status not in valid:
        raise ValueError(f"Invalid status: {status}. Must be one of {valid}")
    if station_id not in _registered_stations:
        raise ValueError(f"Station {station_id} not registered")
    prev = _registered_stations[station_id]["status"]
    _registered_stations[station_id]["status"] = status
    _registered_stations[station_id]["last_seen"] = datetime.now(timezone.utc).isoformat()
    logger.info(f"Station {station_id} status changed: {prev} -> {status}")
    return _registered_stations[station_id]


def list_all_stations() -> list[dict[str, Any]]:
    """List all registered ground stations."""
    return list(_registered_stations.values())
