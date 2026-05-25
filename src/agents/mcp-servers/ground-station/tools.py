"""MCP tools for ground station operations."""
import json
import logging
from datetime import datetime, timezone
from typing import Any

from mcp.server.fastmcp import FastMCP

logger = logging.getLogger(__name__)

_stations = {
    "gs-1": {"id": "gs-1", "name": "McMurdo Ground Station", "lat": -77.85, "lon": 166.67, "status": "online", "capabilities": ["s-band", "x-band", "ka-band"], "antennas": ["AM-1", "AM-2"]},
    "gs-2": {"id": "gs-2", "name": "Svalbard Satellite Station", "lat": 78.23, "lon": 15.39, "status": "online", "capabilities": ["s-band", "x-band"], "antennas": ["SV-1", "SV-2", "SV-3"]},
    "gs-3": {"id": "gs-3", "name": "Kourou Ground Station", "lat": 5.16, "lon": -52.65, "status": "maintenance", "capabilities": ["s-band", "x-band", "ka-band", "optical"], "antennas": ["KR-1", "KR-2"]},
}

_schedules = {}

def register_tools(mcp: FastMCP):
    @mcp.tool()
    async def get_station(station_id: str) -> str:
        """Get details for a specific ground station by ID."""
        station = _stations.get(station_id)
        if not station:
            return json.dumps({"error": f"Station {station_id} not found"})
        return json.dumps(station, indent=2)

    @mcp.tool()
    async def list_stations(status: str = "") -> str:
        """List all ground stations, optionally filtered by status."""
        if status:
            filtered = [s for s in _stations.values() if s["status"] == status]
        else:
            filtered = list(_stations.values())
        return json.dumps(filtered, indent=2)

    @mcp.tool()
    async def update_status(station_id: str, new_status: str) -> str:
        """Update the operational status of a ground station."""
        if station_id not in _stations:
            return json.dumps({"error": f"Station {station_id} not found"})
        valid = ["online", "offline", "maintenance", "degraded"]
        if new_status not in valid:
            return json.dumps({"error": f"Invalid status. Must be one of {valid}"})
        _stations[station_id]["status"] = new_status
        logger.info(f"Station {station_id} status updated to {new_status}")
        return json.dumps({"success": True, "station_id": station_id, "new_status": new_status})

    @mcp.tool()
    async def get_schedule(station_id: str, date: str = "") -> str:
        """Get schedule for a ground station on a given date (YYYY-MM-DD)."""
        if station_id not in _stations:
            return json.dumps({"error": f"Station {station_id} not found"})
        if not date:
            date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        schedule = _schedules.get(station_id, {}).get(date, [])
        return json.dumps({"station_id": station_id, "date": date, "passes": schedule}, indent=2)
