"""MCP server for quantum operations."""
import asyncio
import logging

from mcp.server.fastmcp import FastMCP

from .tools import register_tools

logger = logging.getLogger(__name__)

mcp = FastMCP("quantum", "Quantum Circuit Design & Execution Hub")

register_tools(mcp)

async def main():
    logger.info("Starting quantum MCP server...")
    async with mcp.run_stdio_async():
        pass

if __name__ == "__main__":
    asyncio.run(main())
