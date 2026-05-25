"""QAOA circuit for ground station scheduling optimization."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit import ParameterVector
from qiskit.circuit.library import RZZGate, RXGate, RYGate, RZGate

from ..qiskit_wrapper import QuantumCircuitBuilder, CircuitParams


@dataclass
class StationSchedulingProblem:
    num_stations: int = 4
    num_time_slots: int = 6
    station_capacities: Optional[list[int]] = None
    time_slot_weights: Optional[list[float]] = None
    conflict_matrix: Optional[list[list[bool]]] = None

    def __post_init__(self):
        if self.station_capacities is None:
            self.station_capacities = [1] * self.num_stations
        if self.time_slot_weights is None:
            self.time_slot_weights = [1.0] * self.num_time_slots
        if self.conflict_matrix is None:
            self.conflict_matrix = [[False] * self.num_stations for _ in range(self.num_stations)]


class QaoaSchedulingCircuit:
    """QAOA-based circuit for solving ground station scheduling problems."""

    def __init__(self, problem: StationSchedulingProblem):
        self.problem = problem
        self.num_qubits = problem.num_stations * problem.num_time_slots

    def build_cost_hamiltonian_circuit(self, gamma: float) -> QuantumCircuit:
        n = self.num_qubits
        circuit = QuantumCircuit(n)

        for i in range(n):
            circuit.rz(-2 * gamma, i)

        for i in range(self.problem.num_stations):
            for j in range(i + 1, self.problem.num_stations):
                if self.problem.conflict_matrix[i][j]:
                    for t in range(self.problem.num_time_slots):
                        q1 = i * self.problem.num_time_slots + t
                        q2 = j * self.problem.num_time_slots + t
                        circuit.append(RZZGate(2 * gamma), [q1, q2])

        return circuit

    def build_mixer_hamiltonian_circuit(self, beta: float) -> QuantumCircuit:
        n = self.num_qubits
        circuit = QuantumCircuit(n)

        for i in range(n):
            circuit.append(RXGate(2 * beta), [i])

        return circuit

    def build_qaoa_circuit(self, betas: list[float], gammas: list[float]) -> QuantumCircuit:
        p = len(betas)
        n = self.num_qubits

        builder = QuantumCircuitBuilder(CircuitParams(
            num_qubits=n,
            num_classical=n,
            measurement=True,
        ))

        for i in range(n):
            builder.circuit.h(i)

        for layer in range(p):
            cost_circuit = self.build_cost_hamiltonian_circuit(gammas[layer])
            builder.circuit.compose(cost_circuit, inplace=True)
            mixer_circuit = self.build_mixer_hamiltonian_circuit(betas[layer])
            builder.circuit.compose(mixer_circuit, inplace=True)

        builder.circuit.measure_all()

        return builder.circuit

    def build_parameterized_qaoa(self, num_layers: int = 1) -> QuantumCircuit:
        n = self.num_qubits
        betas = ParameterVector("beta", num_layers)
        gammas = ParameterVector("gamma", num_layers)

        builder = QuantumCircuitBuilder(CircuitParams(
            num_qubits=n,
            num_classical=n,
            measurement=True,
        ))

        for i in range(n):
            builder.circuit.h(i)

        for layer in range(num_layers):
            for i in range(n):
                builder.circuit.rz(-2 * gammas[layer], i)

            for i in range(self.problem.num_stations):
                for j in range(i + 1, self.problem.num_stations):
                    if self.problem.conflict_matrix[i][j]:
                        for t in range(self.problem.num_time_slots):
                            q1 = i * self.problem.num_time_slots + t
                            q2 = j * self.problem.num_time_slots + t
                            builder.circuit.append(RZZGate(2 * gammas[layer]), [q1, q2])

            for i in range(n):
                builder.circuit.append(RXGate(2 * betas[layer]), [i])

        builder.circuit.measure_all()

        return builder.circuit

    def interpret_schedule(self, bitstring: str) -> list[tuple[int, int]]:
        schedule = []
        n_stations = self.problem.num_stations
        n_slots = self.problem.num_time_slots

        for i in range(n_stations):
            for t in range(n_slots):
                idx = i * n_slots + t
                if idx < len(bitstring) and bitstring[idx] == "1":
                    schedule.append((i, t))

        return schedule

    def evaluate_schedule(self, bitstring: str) -> float:
        schedule = self.interpret_schedule(bitstring)
        score = 0.0
        station_usage = [0] * self.problem.num_stations
        slot_usage = [0] * self.problem.num_time_slots

        for station, time_slot in schedule:
            station_usage[station] += 1
            slot_usage[time_slot] += 1
            score += self.problem.time_slot_weights[time_slot]

        for station, time_slot in schedule:
            for other_station, other_slot in schedule:
                if station != other_station and time_slot == other_slot:
                    if self.problem.conflict_matrix[station][other_station]:
                        score -= 100.0

        for i, usage in enumerate(station_usage):
            if usage > self.problem.station_capacities[i]:
                score -= 50.0 * (usage - self.problem.station_capacities[i])

        return score

    def __repr__(self) -> str:
        return (
            f"QaoaSchedulingCircuit(stations={self.problem.num_stations}, "
            f"slots={self.problem.num_time_slots}, "
            f"qubits={self.num_qubits})"
        )
