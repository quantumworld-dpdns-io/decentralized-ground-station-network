"""QAOA implementation for scheduling optimization."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit import ParameterVector
from qiskit.circuit.library import RZZGate, RXGate
from scipy.optimize import minimize


@dataclass
class QaoaResult:
    optimal_betas: np.ndarray
    optimal_gammas: np.ndarray
    optimal_value: float
    circuit: QuantumCircuit
    history: list[float]
    num_iterations: int
    convergence: bool


class CostHamiltonian:
    def __init__(self, num_qubits: int, weights: np.ndarray, interactions: np.ndarray):
        self.num_qubits = num_qubits
        self.weights = weights
        self.interactions = interactions

    def build_circuit(self, gamma: float) -> QuantumCircuit:
        qc = QuantumCircuit(self.num_qubits)
        for i in range(self.num_qubits):
            if self.weights[i] != 0:
                qc.rz(-2 * gamma * self.weights[i], i)
        for i in range(self.num_qubits):
            for j in range(i + 1, self.num_qubits):
                if self.interactions[i, j] != 0:
                    qc.append(RZZGate(2 * gamma * self.interactions[i, j]), [i, j])
        return qc

    def evaluate(self, bitstring: str) -> float:
        energy = 0.0
        for i in range(self.num_qubits):
            if i < len(bitstring):
                zi = 1 if bitstring[i] == "0" else -1
                energy += self.weights[i] * zi
        for i in range(self.num_qubits):
            for j in range(i + 1, self.num_qubits):
                if j < len(bitstring):
                    zi = 1 if bitstring[i] == "0" else -1
                    zj = 1 if bitstring[j] == "0" else -1
                    energy += self.interactions[i, j] * zi * zj
        return energy


class MixerHamiltonian:
    def __init__(self, num_qubits: int):
        self.num_qubits = num_qubits

    def build_circuit(self, beta: float) -> QuantumCircuit:
        qc = QuantumCircuit(self.num_qubits)
        for i in range(self.num_qubits):
            qc.append(RXGate(2 * beta), [i])
        return qc


class QaoaOptimizer:
    def __init__(
        self,
        num_qubits: int,
        cost_hamiltonian: CostHamiltonian,
        mixer_hamiltonian: MixerHamiltonian,
        num_layers: int = 1,
        seed: Optional[int] = None,
    ):
        self.num_qubits = num_qubits
        self.cost = cost_hamiltonian
        self.mixer = mixer_hamiltonian
        self.p = num_layers
        self.rng = np.random.default_rng(seed)

    def build_qaoa_circuit(self, betas: np.ndarray, gammas: np.ndarray) -> QuantumCircuit:
        qc = QuantumCircuit(self.num_qubits, self.num_qubits)
        qc.h(range(self.num_qubits))
        for layer in range(self.p):
            cost_qc = self.cost.build_circuit(gammas[layer])
            mixer_qc = self.mixer.build_circuit(betas[layer])
            qc.compose(cost_qc, inplace=True)
            qc.compose(mixer_qc, inplace=True)
        qc.measure_all()
        return qc

    def objective(self, params: np.ndarray, backend, shots: int = 1024) -> float:
        betas = params[:self.p]
        gammas = params[self.p:]
        circuit = self.build_qaoa_circuit(betas, gammas)
        counts = backend.get_counts(circuit, shots=shots)
        energy = 0.0
        total = sum(counts.values())
        for bitstring, count in counts.items():
            energy += count * self.cost.evaluate(bitstring)
        return energy / total

    def optimize(
        self,
        backend,
        shots: int = 1024,
        max_iter: int = 200,
        callback: Optional[callable] = None,
    ) -> QaoaResult:
        x0 = np.concatenate([
            self.rng.uniform(0, np.pi, self.p),
            self.rng.uniform(0, np.pi, self.p),
        ])
        bounds = [(0, np.pi)] * (2 * self.p)
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
            method="COBYLA",
            bounds=bounds,
            options={"maxiter": max_iter, "rhobeg": 0.5},
        )

        optimal = result.x
        betas = optimal[:self.p]
        gammas = optimal[self.p:]
        circuit = self.build_qaoa_circuit(betas, gammas)

        return QaoaResult(
            optimal_betas=betas,
            optimal_gammas=gammas,
            optimal_value=result.fun,
            circuit=circuit,
            history=history,
            num_iterations=result.nfev,
            convergence=result.success,
        )

    def __repr__(self) -> str:
        return f"QaoaOptimizer(qubits={self.num_qubits}, layers={self.p})"
