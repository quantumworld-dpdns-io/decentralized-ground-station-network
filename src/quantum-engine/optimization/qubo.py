"""QUBO-to-Ising converter and QUBO problem builder from scheduling constraints."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


@dataclass
class QuboProblem:
    num_vars: int
    Q: np.ndarray
    offset: float = 0.0
    var_names: Optional[list[str]] = None

    def __post_init__(self):
        if self.var_names is None:
            self.var_names = [f"x_{i}" for i in range(self.num_vars)]

    def evaluate(self, x: np.ndarray) -> float:
        return x @ self.Q @ x + self.offset

    def evaluate_bitstring(self, bitstring: str) -> float:
        x = np.array([1 if b == "1" else 0 for b in bitstring], dtype=float)
        return self.evaluate(x)

    def energy(self, bitstring: str) -> float:
        return -self.evaluate_bitstring(bitstring)


class QuboConverter:
    @staticmethod
    def to_ising(Q: np.ndarray, offset: float = 0.0) -> tuple[np.ndarray, np.ndarray, float]:
        n = Q.shape[0]
        h = np.zeros(n)
        J = np.zeros((n, n))
        ising_offset = offset

        for i in range(n):
            h[i] = 0.25 * (Q[i, i] + sum(Q[i, j] + Q[j, i] for j in range(n) if j != i))
        for i in range(n):
            for j in range(i + 1, n):
                J[i, j] = 0.25 * (Q[i, j] + Q[j, i])
        for i in range(n):
            for j in range(n):
                if i != j:
                    ising_offset += 0.25 * Q[i, j]
        ising_offset += 0.25 * np.sum(np.diag(Q))
        ising_offset -= 0.5 * np.sum(h)

        return h, J, ising_offset

    @staticmethod
    def from_ising(h: np.ndarray, J: np.ndarray, offset: float = 0.0) -> tuple[np.ndarray, float]:
        n = len(h)
        Q = np.zeros((n, n))
        qubo_offset = offset

        for i in range(n):
            Q[i, i] = 4 * h[i] - 2 * sum(J[i, :]) - 2 * sum(J[:, i]) + 4 * J[i, i] if i < J.shape[0] else 4 * h[i]
        for i in range(n):
            for j in range(i + 1, n):
                if i < J.shape[0] and j < J.shape[1]:
                    Q[i, j] = 4 * J[i, j]
                    Q[j, i] = 4 * J[j, i]

        qubo_offset += offset
        for i in range(n):
            qubo_offset += -2 * h[i] + sum(J[i, :]) + sum(J[:, i]) / 2
        qubo_offset += np.sum(J) / 2

        return Q, qubo_offset

    @staticmethod
    def build_scheduling_qubo(
        num_stations: int,
        num_slots: int,
        station_weights: Optional[np.ndarray] = None,
        slot_weights: Optional[np.ndarray] = None,
        conflict_penalty: float = 100.0,
        capacity_penalty: float = 50.0,
    ) -> QuboProblem:
        n = num_stations * num_slots
        Q = np.zeros((n, n))

        if station_weights is None:
            station_weights = np.ones(num_stations)
        if slot_weights is None:
            slot_weights = np.ones(num_slots)

        def idx(station, slot):
            return station * num_slots + slot

        for s in range(num_stations):
            for t in range(num_slots):
                i = idx(s, t)
                Q[i, i] = -slot_weights[t] * station_weights[s]

        for s in range(num_stations):
            for t1 in range(num_slots):
                for t2 in range(t1 + 1, num_slots):
                    i = idx(s, t1)
                    j = idx(s, t2)
                    Q[i, j] += conflict_penalty

        for t in range(num_slots):
            for s1 in range(num_stations):
                for s2 in range(s1 + 1, num_stations):
                    i = idx(s1, t)
                    j = idx(s2, t)
                    Q[i, j] += conflict_penalty

        return QuboProblem(num_vars=n, Q=Q, var_names=[f"s{s}_t{t}" for s in range(num_stations) for t in range(num_slots)])

    @staticmethod
    def build_resource_allocation_qubo(
        num_resources: int,
        num_nodes: int,
        resource_costs: Optional[np.ndarray] = None,
        node_demands: Optional[np.ndarray] = None,
        distance_penalty: float = 10.0,
    ) -> QuboProblem:
        n = num_resources * num_nodes
        Q = np.zeros((n, n))

        if resource_costs is None:
            resource_costs = np.ones(num_resources)
        if node_demands is None:
            node_demands = np.ones(num_nodes)

        def idx(resource, node):
            return resource * num_nodes + node

        for r in range(num_resources):
            for node in range(num_nodes):
                i = idx(r, node)
                Q[i, i] = -resource_costs[r] * node_demands[node]

        for r in range(num_resources):
            for n1 in range(num_nodes):
                for n2 in range(n1 + 1, num_nodes):
                    i = idx(r, n1)
                    j = idx(r, n2)
                    Q[i, j] += distance_penalty

        return QuboProblem(num_vars=n, Q=Q, var_names=[f"r{r}_n{node}" for r in range(num_resources) for node in range(num_nodes)])

    @staticmethod
    def sample_to_bitstring(sample: dict[int, int], num_vars: int) -> str:
        return "".join(str(sample.get(i, 0)) for i in range(num_vars))

    @staticmethod
    def bitstring_to_allocation(bitstring: str, num_stations: int, num_slots: int) -> list[tuple[int, int]]:
        result = []
        for i in range(num_stations):
            for t in range(num_slots):
                idx = i * num_slots + t
                if idx < len(bitstring) and bitstring[idx] == "1":
                    result.append((i, t))
        return result

    def __repr__(self) -> str:
        return f"QuboConverter()"
