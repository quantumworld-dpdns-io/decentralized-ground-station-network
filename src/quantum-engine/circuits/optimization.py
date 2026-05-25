"""VQE circuits for resource optimization in ground station network."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit import ParameterVector, Parameter
from qiskit.circuit.library import (
    RXXGate,
    RYYGate,
    RZZGate,
    RXGate,
    RYGate,
    RZGate,
    EfficientSU2,
    TwoLocal,
    RealAmplitudes,
)

from ..qiskit_wrapper import QuantumCircuitBuilder, CircuitParams


@dataclass
class ResourceOptimizationProblem:
    num_resources: int = 6
    num_nodes: int = 4
    coupling_map: Optional[list[tuple[int, int]]] = None
    node_weights: Optional[list[float]] = None
    resource_costs: Optional[list[float]] = None

    def __post_init__(self):
        if self.coupling_map is None:
            self.coupling_map = [(i, i + 1) for i in range(self.num_nodes - 1)]
        if self.node_weights is None:
            self.node_weights = [1.0] * self.num_nodes
        if self.resource_costs is None:
            self.resource_costs = [1.0] * self.num_resources


class VqeOptimizationCircuit:
    """VQE-based circuits for resource allocation optimization."""

    def __init__(self, problem: ResourceOptimizationProblem):
        self.problem = problem
        self.num_qubits = problem.num_resources * problem.num_nodes

    def build_ry_rz_ansatz(self, num_layers: int = 2) -> QuantumCircuit:
        n = self.num_qubits
        params = ParameterVector("theta", 2 * n * num_layers)
        circuit = QuantumCircuit(n)
        idx = 0

        for layer in range(num_layers):
            for i in range(n):
                circuit.ry(params[idx], i)
                idx += 1
            for i in range(n):
                circuit.rz(params[idx], i)
                idx += 1
            if layer < num_layers - 1:
                for i in range(n - 1):
                    circuit.cx(i, i + 1)

        circuit.measure_all()
        return circuit

    def build_efficient_su2_ansatz(self, reps: int = 2) -> QuantumCircuit:
        n = self.num_qubits
        ansatz = EfficientSU2(
            num_qubits=n,
            reps=reps,
            entanglement="linear",
            skip_unentangled_qubits=False,
            skip_final_ry=True,
        )
        ansatz.measure_all()
        return ansatz

    def build_two_local_ansatz(self, reps: int = 2) -> QuantumCircuit:
        n = self.num_qubits
        ansatz = TwoLocal(
            num_qubits=n,
            rotation_blocks=["ry", "rz"],
            entanglement_blocks=["cx"],
            entanglement="linear",
            reps=reps,
            skip_final_rotation_layer=False,
        )
        ansatz.measure_all()
        return ansatz

    def build_real_amplitudes_ansatz(self, reps: int = 2) -> QuantumCircuit:
        n = self.num_qubits
        ansatz = RealAmplitudes(
            num_qubits=n,
            reps=reps,
            entanglement="linear",
        )
        ansatz.measure_all()
        return ansatz

    def build_cost_hamiltonian(self) -> tuple[QuantumCircuit, list[str], list[float]]:
        n = self.num_qubits
        circuit = QuantumCircuit(n)

        paulis = []
        coeffs = []

        for i in range(self.problem.num_resources):
            for j in range(self.problem.num_nodes):
                idx = i * self.problem.num_nodes + j
                cost = self.problem.resource_costs[i] * self.problem.node_weights[j]
                paulis.append(f"Z{idx}")
                coeffs.append(-cost)

        for i in range(self.problem.num_resources):
            for j1 in range(self.problem.num_nodes):
                for j2 in range(j1 + 1, self.problem.num_nodes):
                    idx1 = i * self.problem.num_nodes + j1
                    idx2 = i * self.problem.num_nodes + j2
                    paulis.append(f"Z{idx1}Z{idx2}")
                    coeffs.append(10.0)

        return circuit, paulis, coeffs

    def cost_function(self, counts: dict[str, int], shots: int = 1024) -> float:
        _, paulis, coeffs = self.build_cost_hamiltonian()
        energy = 0.0

        for bitstring, count in counts.items():
            prob = count / shots
            term_energy = 0.0
            for pauli, coeff in zip(paulis, coeffs):
                expectation = 1.0
                terms = pauli.split("Z")
                for term in terms[1:]:
                    if term:
                        idx = int(term)
                        if idx < len(bitstring):
                            expectation *= -1 if bitstring[idx] == "1" else 1
                term_energy += coeff * expectation
            energy += prob * term_energy

        return energy

    def interpret_allocation(self, bitstring: str) -> dict[int, int]:
        allocation = {}
        for i in range(self.problem.num_resources):
            for j in range(self.problem.num_nodes):
                idx = i * self.problem.num_nodes + j
                if idx < len(bitstring) and bitstring[idx] == "1":
                    allocation[i] = j
        return allocation

    def __repr__(self) -> str:
        return (
            f"VqeOptimizationCircuit(resources={self.problem.num_resources}, "
            f"nodes={self.problem.num_nodes}, qubits={self.num_qubits})"
        )
