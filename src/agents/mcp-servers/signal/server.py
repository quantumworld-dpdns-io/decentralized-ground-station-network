"""MCP server for signal analysis operations."""
import asyncio
import logging

from mcp.server.fastmcp import FastMCP

from .tools import register_tools

logger = logging.getLogger(__name__)

mcp = FastMCP("signal", "Signal Analysis & Processing Hub")

register_tools(mcp)

async def main():
    logger.info("Starting signal analysis MCP server...")
    async with mcp.run_stdio_async():
        pass

if __name__ == "__main__":
    asyncio.run(main())
