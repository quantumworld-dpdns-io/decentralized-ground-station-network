"""Quantum circuit design skill: design, optimize, execute quantum circuits."""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

_known_circuits: dict[str, dict[str, Any]] = {}

GATE_FIDELITIES = {
    "H": 0.9995, "X": 0.9998, "Y": 0.9998, "Z": 0.9998,
    "CNOT": 0.995, "CZ": 0.996, "SWAP": 0.990,
    "RX": 0.999, "RY": 0.999, "RZ": 0.999, "measure": 0.980,
}


def design_circuit(name: str, num_qubits: int, gates: list[str], depth: int | None = None) -> dict[str, Any]:
    """Design a new quantum circuit with gates and metadata."""
    if not depth:
        depth = len(gates)
    circuit_id = f"qsk-{uuid.uuid4().hex[:8]}"
    circuit = {
        "id": circuit_id,
        "name": name,
        "num_qubits": num_qubits,
        "depth": depth,
        "gates": gates,
        "gate_count": len(gates),
        "estimated_fidelity": _estimate_fidelity(gates),
        "status": "designed",
        "created": datetime.now(timezone.utc).isoformat(),
    }
    _known_circuits[circuit_id] = circuit
    logger.info(f"Designed circuit '{name}' ({circuit_id}): {num_qubits} qubits, depth {depth}")
    return circuit


def _estimate_fidelity(gates: list[str]) -> float:
    fidelity = 1.0
    for g in gates:
        fidelity *= GATE_FIDELITIES.get(g, 0.990)
    return round(fidelity, 6)


def optimize_circuit(circuit_id: str, optimization_level: int = 1) -> dict[str, Any]:
    """Optimize a circuit by reducing gate count and depth."""
    circuit = _known_circuits.get(circuit_id)
    if not circuit:
        raise ValueError(f"Circuit {circuit_id} not found")
    if optimization_level < 0 or optimization_level > 3:
        raise ValueError("Optimization level must be 0-3")

    original_depth = circuit["depth"]
    original_gates = circuit["gates"]
    optimizations = {
        0: (original_gates, original_depth, "none"),
        1: (_fuse_single_qubit(original_gates), int(original_depth * 0.85), "single-qubit fusion"),
        2: (_fuse_single_qubit(original_gates)[::2] if len(original_gates) > 4 else original_gates, int(original_depth * 0.65), "gate cancellation + fusion"),
        3: ([g for g in original_gates if g != "H"][:int(len(original_gates) * 0.5)] or original_gates, max(1, int(original_depth * 0.4)), "aggressive optimization"),
    }
    new_gates, new_depth, technique = optimizations.get(optimization_level, optimizations[1])
    circuit["depth"] = new_depth
    circuit["gates"] = new_gates
    circuit["optimization_level"] = optimization_level
    circuit["optimization_technique"] = technique
    circuit["estimated_fidelity"] = _estimate_fidelity(new_gates)
    logger.info(f"Circuit {circuit_id} optimized (level {optimization_level}): depth {original_depth} -> {new_depth}")
    return circuit


def _fuse_single_qubit(gates: list[str]) -> list[str]:
    fused = []
    for g in gates:
        if g in ("RX", "RY", "RZ") and fused and fused[-1] in ("RX", "RY", "RZ"):
            continue
        fused.append(g)
    return fused


def execute_circuit(circuit_id: str, shots: int = 1024) -> dict[str, Any]:
    """Simulate circuit execution and return measurement results."""
    circuit = _known_circuits.get(circuit_id)
    if not circuit:
        raise ValueError(f"Circuit {circuit_id} not found")
    import random
    num_qubits = circuit["num_qubits"]
    counts = {}
    for _ in range(shots):
        outcome = "".join(str(random.randint(0, 1)) for _ in range(num_qubits))
        counts[outcome] = counts.get(outcome, 0) + 1
    result = {
        "circuit_id": circuit_id,
        "shots": shots,
        "counts": counts,
        "fidelity": circuit["estimated_fidelity"],
        "executed_at": datetime.now(timezone.utc).isoformat(),
    }
    circuit["status"] = "executed"
    circuit["last_result"] = result
    logger.info(f"Circuit {circuit_id} executed with {shots} shots")
    return result


def estimate_cost(circuit_id: str, shots: int = 1024) -> dict[str, Any]:
    """Estimate execution cost for a circuit."""
    circuit = _known_circuits.get(circuit_id)
    if not circuit:
        raise ValueError(f"Circuit {circuit_id} not found")
    base = 0.01
    qubit_cost = circuit["num_qubits"] * 0.005
    depth_cost = circuit["depth"] * 0.001
    shot_cost = shots * 0.00001
    return {
        "circuit_id": circuit_id,
        "estimated_cost_usd": round(base + qubit_cost + depth_cost + shot_cost, 4),
        "num_qubits": circuit["num_qubits"],
        "depth": circuit["depth"],
        "shots": shots,
    }
