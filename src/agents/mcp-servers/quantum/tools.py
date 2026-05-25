"""MCP tools for quantum circuit operations."""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from mcp.server.fastmcp import FastMCP

logger = logging.getLogger(__name__)

_circuits = {}

def register_tools(mcp: FastMCP):
    @mcp.tool()
    async def submit_circuit(name: str, num_qubits: int, depth: int, gates: list[str]) -> str:
        """Submit a new quantum circuit for execution."""
        circuit_id = f"qc-{uuid.uuid4().hex[:8]}"
        _circuits[circuit_id] = {
            "id": circuit_id,
            "name": name,
            "num_qubits": num_qubits,
            "depth": depth,
            "gates": gates,
            "status": "submitted",
            "created": datetime.now(timezone.utc).isoformat(),
            "result": None,
        }
        logger.info(f"Circuit {circuit_id} submitted: {name} ({num_qubits} qubits, depth {depth})")
        return json.dumps({"circuit_id": circuit_id, "status": "submitted", "estimated_depth": depth}, indent=2)

    @mcp.tool()
    async def get_circuit_result(circuit_id: str) -> str:
        """Get the result of a previously submitted quantum circuit."""
        circuit = _circuits.get(circuit_id)
        if not circuit:
            return json.dumps({"error": f"Circuit {circuit_id} not found"})
        if circuit["status"] == "submitted":
            circuit["status"] = "completed"
            circuit["result"] = {"counts": {"000": 512, "001": 128, "010": 96, "100": 64}, "shots": 1024}
        return json.dumps(circuit, indent=2)

    @mcp.tool()
    async def estimate_cost(num_qubits: int, depth: int, shots: int = 1024) -> str:
        """Estimate the cost of running a quantum circuit."""
        base_cost = 0.01
        cost = base_cost * num_qubits * (depth / 10) * (shots / 1024)
        return json.dumps({
            "estimated_cost_usd": round(cost, 4),
            "num_qubits": num_qubits,
            "depth": depth,
            "shots": shots,
            "currency": "USD",
        }, indent=2)

    @mcp.tool()
    async def list_circuits(status: str = "") -> str:
        """List all quantum circuits, optionally filtered by status."""
        if status:
            filtered = [c for c in _circuits.values() if c["status"] == status]
        else:
            filtered = list(_circuits.values())
        return json.dumps(filtered, indent=2)
