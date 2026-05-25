"""MCP server for ground station operations."""
import asyncio
import json
import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from mcp.server import Server
from mcp.server.fastmcp import FastMCP
from mcp.types import Resource, Tool, TextContent
from pydantic import BaseModel

from .tools import register_tools

logger = logging.getLogger(__name__)

mcp = FastMCP("ground-station", "Ground Station Operations Hub")

@mcp.resource("station://list")
async def list_stations_resource() -> str:
    stations = [
        {"id": "gs-1", "name": "McMurdo Ground Station", "lat": -77.85, "lon": 166.67, "status": "online"},
        {"id": "gs-2", "name": "Svalbard Satellite Station", "lat": 78.23, "lon": 15.39, "status": "online"},
        {"id": "gs-3", "name": "Kourou Ground Station", "lat": 5.16, "lon": -52.65, "status": "maintenance"},
    ]
    return json.dumps(stations, indent=2)

@mcp.resource("station://{station_id}/status")
async def station_status_resource(station_id: str) -> str:
    return json.dumps({"id": station_id, "status": "online", "uptime": 99.7, "last_contact": "2026-05-25T12:00:00Z"})

register_tools(mcp)

async def main():
    logger.info("Starting ground station MCP server...")
    async with mcp.run_stdio_async():
        pass

if __name__ == "__main__":
    asyncio.run(main())
