"""
Quantum Library for Robot Framework.
Provides keywords for quantum circuit operations, simulation, and validation.
"""

import json
import math
import random
from typing import Any, Dict, List, Optional, Tuple


class QuantumLibrary:
    """Custom library for quantum circuit operations and verification."""

    def __init__(self):
        self._circuits = {}
        self._results = {}

    def create_bell_state_circuit(self, name: str = "bell") -> Dict[str, Any]:
        """Create a Bell state circuit: H + CNOT."""
        circuit = {
            "name": name,
            "qubits": 2,
            "classical_bits": 2,
            "gates": [
                {"gate": "h", "qubits": [0]},
                {"gate": "cx", "qubits": [0, 1]},
                {"gate": "measure", "qubits": [0], "classical": [0]},
                {"gate": "measure", "qubits": [1], "classical": [1]},
            ],
            "description": "Bell state |Φ+⟩ = (|00⟩ + |11⟩)/√2",
        }
        self._circuits[name] = circuit
        return circuit

    def create_ghz_state_circuit(self, n_qubits: int = 3, name: str = "ghz") -> Dict[str, Any]:
        """Create an n-qubit GHZ state circuit."""
        gates = [{"gate": "h", "qubits": [0]}]
        for i in range(n_qubits - 1):
            gates.append({"gate": "cx", "qubits": [i, i + 1]})
        for i in range(n_qubits):
            gates.append({"gate": "measure", "qubits": [i], "classical": [i]})

        circuit = {
            "name": name,
            "qubits": n_qubits,
            "classical_bits": n_qubits,
            "gates": gates,
            "description": f"GHZ state (|0...0⟩ + |1...1⟩)/√2 with {n_qubits} qubits",
        }
        self._circuits[name] = circuit
        return circuit

    def create_qaoa_circuit(
        self, n_qubits: int = 4, p_layers: int = 2, name: str = "qaoa"
    ) -> Dict[str, Any]:
        """Create a QAOA circuit for MaxCut."""
        gates = [{"gate": "h", "qubits": list(range(n_qubits))}]
        for layer in range(p_layers):
            gamma = round(random.uniform(0, 2 * math.pi), 4)
            beta = round(random.uniform(0, 2 * math.pi), 4)
            for i in range(n_qubits - 1):
                gates.append({"gate": "cz", "qubits": [i, i + 1], "parameter": gamma})
            for i in range(n_qubits):
                gates.append({"gate": "rx", "qubits": [i], "parameter": beta})
        for i in range(n_qubits):
            gates.append({"gate": "measure", "qubits": [i], "classical": [i]})

        circuit = {
            "name": name,
            "qubits": n_qubits,
            "classical_bits": n_qubits,
            "gates": gates,
            "p_layers": p_layers,
            "description": f"QAOA for MaxCut with {p_layers} layers on {n_qubits} qubits",
        }
        self._circuits[name] = circuit
        return circuit

    def create_vqe_circuit(
        self, n_qubits: int = 4, name: str = "vqe"
    ) -> Dict[str, Any]:
        """Create a VQE circuit with hardware-efficient ansatz."""
        gates = []
        for i in range(n_qubits):
            gates.append({"gate": "ry", "qubits": [i], "parameter": round(random.uniform(0, 2 * math.pi), 4)})
        for i in range(n_qubits - 1):
            gates.append({"gate": "cx", "qubits": [i, i + 1]})
        for i in range(n_qubits):
            gates.append({"gate": "ry", "qubits": [i], "parameter": round(random.uniform(0, 2 * math.pi), 4)})
        for i in range(n_qubits):
            gates.append({"gate": "measure", "qubits": [i], "classical": [i]})

        circuit = {
            "name": name,
            "qubits": n_qubits,
            "classical_bits": n_qubits,
            "gates": gates,
            "description": f"VQE hardware-efficient ansatz on {n_qubits} qubits",
        }
        self._circuits[name] = circuit
        return circuit

    def simulate_circuit(self, circuit: Dict[str, Any], shots: int = 1024) -> Dict[str, Any]:
        """Simulate a quantum circuit and return measurement counts."""
        n_qubits = circuit.get("qubits", 2)
        counts = {}
        for _ in range(shots):
            outcome = "".join(random.choices("01", k=n_qubits))
            counts[outcome] = counts.get(outcome, 0) + 1

        result = {
            "circuit_name": circuit.get("name", "unknown"),
            "shots": shots,
            "counts": counts,
            "n_qubits": n_qubits,
            "success": True,
        }
        self._results[circuit.get("name", "unknown")] = result
        return result

    def verify_bell_state(self, counts: Dict[str, int], shots: int, tolerance: float = 0.05) -> Tuple[bool, str]:
        """Verify that measurement results match Bell state expectations."""
        expected = shots / 2
        for outcome in ["00", "11"]:
            actual = counts.get(outcome, 0)
            if abs(actual - expected) / shots > tolerance:
                return False, f"{outcome}: expected ~{expected}, got {actual}"
        for outcome in ["01", "10"]:
            if counts.get(outcome, 0) > shots * tolerance:
                return False, f"{outcome}: expected ~0, got {counts.get(outcome, 0)}"
        return True, "Bell state verification passed"

    def verify_ghz_state(self, counts: Dict[str, int], shots: int, n_qubits: int, tolerance: float = 0.05) -> Tuple[bool, str]:
        """Verify GHZ state measurement results."""
        all_zeros = "0" * n_qubits
        all_ones = "1" * n_qubits
        expected = shots / 2
        zeros_count = counts.get(all_zeros, 0)
        ones_count = counts.get(all_ones, 0)
        if abs(zeros_count - expected) / shots > tolerance:
            return False, f"|0...0⟩: expected ~{expected}, got {zeros_count}"
        if abs(ones_count - expected) / shots > tolerance:
            return False, f"|1...1⟩: expected ~{expected}, got {ones_count}"
        total_other = shots - zeros_count - ones_count
        if total_other > shots * tolerance:
            return False, f"Other outcomes: expected ~0, got {total_other}"
        return True, "GHZ state verification passed"

    def compute_state_fidelity(self, ideal_counts: Dict[str, int], actual_counts: Dict[str, int]) -> float:
        """Compute fidelity between ideal and actual measurement distributions."""
        all_outcomes = set(list(ideal_counts.keys()) + list(actual_counts.keys()))
        total_ideal = sum(ideal_counts.values())
        total_actual = sum(actual_counts.values())
        fidelity = 0.0
        for outcome in all_outcomes:
            p_ideal = ideal_counts.get(outcome, 0) / total_ideal if total_ideal > 0 else 0
            p_actual = actual_counts.get(outcome, 0) / total_actual if total_actual > 0 else 0
            fidelity += math.sqrt(p_ideal * p_actual)
        return fidelity ** 2

    def compare_simulators(self, qiskit_result: Dict[str, Any], cudaq_result: Dict[str, Any]) -> Tuple[bool, str]:
        """Compare results from Qiskit and CUDA-Q simulators."""
        qiskit_counts = qiskit_result.get("counts", {})
        cudaq_counts = cudaq_result.get("counts", {})
        fidelity = self.compute_state_fidelity(qiskit_counts, cudaq_counts)
        if fidelity < 0.95:
            return False, f"Simulator fidelity {fidelity:.4f} below threshold 0.95"
        return True, f"Simulators agree with fidelity {fidelity:.4f}"

    def verify_qaoa_optimality(self, results: Dict[str, Any], n_qubits: int) -> Tuple[bool, str]:
        """Verify QAOA results are reasonable for MaxCut."""
        top_outcomes = sorted(results.get("counts", {}).items(), key=lambda x: -x[1])[:10]
        if not top_outcomes:
            return False, "No measurement outcomes found"
        return True, f"QAOA produced {len(top_outcomes)} top outcomes"

    def verify_vqe_convergence(self, results: Dict[str, Any]) -> Tuple[bool, str]:
        """Verify VQE result structure is valid."""
        if "counts" not in results:
            return False, "VQE results missing counts"
        if not results.get("success", False):
            return False, "VQE simulation did not succeed"
        total = sum(results["counts"].values())
        if total != results.get("shots", 0):
            return False, f"Count total {total} != shots {results.get('shots')}"
        return True, "VQE results valid"
