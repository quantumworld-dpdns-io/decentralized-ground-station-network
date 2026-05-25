"""Dynamical decoupling sequences (CPMG, XY4, KDD)."""

from dataclasses import dataclass, field
from typing import Optional
from abc import ABC, abstractmethod

import numpy as np


class DynamicalDecoupling(ABC):
    def __init__(self, num_qubits: int, num_pulses: int = 4):
        self.num_qubits = num_qubits
        self.num_pulses = num_pulses

    @abstractmethod
    def build_sequence(self) -> list[tuple[str, list[int], Optional[float]]]:
        pass

    def apply_to_circuit(self, circuit, idle_qubits: Optional[list[int]] = None):
        from qiskit import QuantumCircuit
        qubits = idle_qubits or list(range(self.num_qubits))
        seq = self.build_sequence()
        qc = QuantumCircuit(self.num_qubits)
        for gate_name, targets, angle in seq:
            valid_targets = [t for t in targets if t in qubits]
            if not valid_targets:
                continue
            if gate_name == "x":
                for t in valid_targets:
                    qc.x(t)
            elif gate_name == "y":
                for t in valid_targets:
                    qc.y(t)
            elif gate_name == "rx" and angle is not None:
                for t in valid_targets:
                    qc.rx(angle, t)
            elif gate_name == "ry" and angle is not None:
                for t in valid_targets:
                    qc.ry(angle, t)
            elif gate_name == "id":
                for t in valid_targets:
                    qc.id(t)
        return circuit.compose(qc)

    def insert_idle_times(self, circuit, idle_qubits: list[int], delay: float = 1.0):
        n_repeats = max(1, int(delay * self.num_pulses))
        qc = circuit.copy()
        for _ in range(n_repeats):
            seq = self.build_sequence()
            for gate_name, targets, angle in seq:
                valid = [t for t in targets if t in idle_qubits]
                if not valid:
                    continue
                if gate_name == "x":
                    for t in valid:
                        qc.x(t)
                elif gate_name == "y":
                    for t in valid:
                        qc.y(t)
                elif gate_name == "rx" and angle is not None:
                    for t in valid:
                        qc.rx(angle, t)
                elif gate_name == "ry" and angle is not None:
                    for t in valid:
                        qc.ry(angle, t)
        return qc


class CPMGSequence(DynamicalDecoupling):
    def build_sequence(self) -> list[tuple[str, list[int], Optional[float]]]:
        seq = []
        tau = np.pi / (self.num_pulses + 1)
        for i in range(self.num_pulses):
            seq.append(("id", list(range(self.num_qubits)), None))
            seq.append(("rx", list(range(self.num_qubits)), np.pi))
            seq.append(("id", list(range(self.num_qubits)), None))
        return seq

    def __repr__(self) -> str:
        return f"CPMGSequence(pulses={self.num_pulses})"


class XY4Sequence(DynamicalDecoupling):
    def build_sequence(self) -> list[tuple[str, list[int], Optional[float]]]:
        seq = []
        for _ in range(self.num_pulses // 4 + 1):
            seq.append(("x", list(range(self.num_qubits)), None))
            seq.append(("y", list(range(self.num_qubits)), None))
            seq.append(("x", list(range(self.num_qubits)), None))
            seq.append(("y", list(range(self.num_qubits)), None))
        return seq[:self.num_pulses]

    def __repr__(self) -> str:
        return f"XY4Sequence(pulses={self.num_pulses})"


class KDDSequence(DynamicalDecoupling):
    def build_sequence(self) -> list[tuple[str, list[int], Optional[float]]]:
        seq = []
        phi1 = np.pi / 6
        phi2 = np.pi / 3
        phi3 = np.pi / 2
        for _ in range(self.num_pulses // 4 + 1):
            seq.append(("rx", list(range(self.num_qubits)), np.pi))
            seq.append(("ry", list(range(self.num_qubits)), np.pi))
            seq.append(("rx", list(range(self.num_qubits)), np.pi + phi1))
            seq.append(("ry", list(range(self.num_qubits)), np.pi + phi2))
            seq.append(("rx", list(range(self.num_qubits)), np.pi + phi3))
        return seq[:self.num_pulses]

    def __repr__(self) -> str:
        return f"KDDSequence(pulses={self.num_pulses})"
