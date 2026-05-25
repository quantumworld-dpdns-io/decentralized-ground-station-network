"""VQE implementation for resource allocation."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit import ParameterVector
from qiskit.circuit.library import RYGate, RZGate, CXGate
from scipy.optimize import minimize


@dataclass
class VqeResult:
    optimal_params: np.ndarray
    optimal_value: float
    circuit: QuantumCircuit
    history: list[float]
    num_iterations: int
    convergence: bool


class CustomAnsatz:
    def __init__(self, num_qubits: int, num_layers: int = 2, entanglement: str = "linear"):
        self.num_qubits = num_qubits
        self.num_layers = num_layers
        self.entanglement = entanglement

    @property
    def num_parameters(self) -> int:
        return 2 * self.num_qubits * self.num_layers

    def build(self, params: np.ndarray) -> QuantumCircuit:
        qc = QuantumCircuit(self.num_qubits)
        idx = 0
        for layer in range(self.num_layers):
            for i in range(self.num_qubits):
                qc.append(RYGate(params[idx]), [i])
                idx += 1
            for i in range(self.num_qubits):
                qc.append(RZGate(params[idx]), [i])
                idx += 1
            if layer < self.num_layers - 1:
                if self.entanglement == "linear":
                    for i in range(self.num_qubits - 1):
                        qc.append(CXGate(), [i, i + 1])
                elif self.entanglement == "circular":
                    for i in range(self.num_qubits):
                        qc.append(CXGate(), [i, (i + 1) % self.num_qubits])
                elif self.entanglement == "full":
                    for i in range(self.num_qubits):
                        for j in range(i + 1, self.num_qubits):
                            qc.append(CXGate(), [i, j])
        return qc


class Hamiltonian:
    def __init__(self, num_qubits: int, paulis: list[tuple[str, list[int], float]]):
        self.num_qubits = num_qubits
        self.paulis = paulis

    def evaluate_from_counts(self, counts: dict[str, int], shots: int) -> float:
        energy = 0.0
        for bitstring, count in counts.items():
            prob = count / shots
            term_energy = 0.0
            for pauli, qubits, coeff in self.paulis:
                expectation = 1.0
                for i, qbit in enumerate(qubits):
                    if qbit < len(bitstring):
                        if pauli[i] == "Z":
                            expectation *= -1 if bitstring[qbit] == "1" else 1
                        elif pauli[i] == "X":
                            expectation *= 1 - 2 * (int(bitstring[qbit]) ^ 1)
                term_energy += coeff * expectation
            energy += prob * term_energy
        return energy


class VqeOptimizer:
    def __init__(
        self,
        ansatz: CustomAnsatz,
        hamiltonian: Hamiltonian,
        seed: Optional[int] = None,
    ):
        self.ansatz = ansatz
        self.hamiltonian = hamiltonian
        self.rng = np.random.default_rng(seed)

    def objective(self, params: np.ndarray, backend, shots: int = 1024) -> float:
        circuit = self.ansatz.build(params)
        circuit.measure_all()
        counts = backend.get_counts(circuit, shots=shots)
        return self.hamiltonian.evaluate_from_counts(counts, shots)

    def optimize(
        self,
        backend,
        shots: int = 1024,
        max_iter: int = 500,
        callback: Optional[callable] = None,
    ) -> VqeResult:
        x0 = self.rng.uniform(-np.pi, np.pi, self.ansatz.num_parameters)
        history = []

        def objective_fn(params):
            val = self.objective(params, backend, shots)
            history.append(val)
            if callback:
                callback(val)
            return val

        result = minimize(
            objective_fn,
            x0,
            method="SPSA" if self.ansatz.num_parameters > 20 else "COBYLA",
            options={"maxiter": max_iter},
        )

        circuit = self.ansatz.build(result.x)
        circuit.measure_all()

        return VqeResult(
            optimal_params=result.x,
            optimal_value=result.fun,
            circuit=circuit,
            history=history,
            num_iterations=result.nfev,
            convergence=result.success,
        )

    def __repr__(self) -> str:
        return f"VqeOptimizer(ansatz_params={self.ansatz.num_parameters}, layers={self.ansatz.num_layers})"
