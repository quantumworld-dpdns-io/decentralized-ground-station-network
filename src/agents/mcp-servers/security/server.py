"""MCP server for security operations."""
import asyncio
import logging

from mcp.server.fastmcp import FastMCP

from .tools import register_tools

logger = logging.getLogger(__name__)

mcp = FastMCP("security", "Security Monitoring & Audit Hub")

register_tools(mcp)

async def main():
    logger.info("Starting security MCP server...")
    async with mcp.run_stdio_async():
        pass

if __name__ == "__main__":
    asyncio.run(main())
