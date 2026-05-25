"""Bell states, GHZ, W-states, cluster states."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister


class BellStateCircuit:
    def __init__(self):
        self.num_qubits = 2

    def build(self, bell_state: int = 0) -> QuantumCircuit:
        qr = QuantumRegister(2, "q")
        cr = ClassicalRegister(2, "c")
        qc = QuantumCircuit(qr, cr)
        qc.h(0)
        qc.cx(0, 1)
        if bell_state == 1:
            qc.x(0)
        elif bell_state == 2:
            qc.z(0)
        elif bell_state == 3:
            qc.x(0)
            qc.z(0)
        qc.measure(qr, cr)
        return qc

    def build_all(self) -> list[QuantumCircuit]:
        return [self.build(i) for i in range(4)]

    def measure_bell_basis(self) -> QuantumCircuit:
        qr = QuantumRegister(2, "q")
        cr = ClassicalRegister(2, "c")
        qc = QuantumCircuit(qr, cr)
        qc.cx(0, 1)
        qc.h(0)
        qc.measure(qr, cr)
        return qc

    def __repr__(self) -> str:
        return "BellStateCircuit()"


class GHZCircuit:
    def __init__(self, num_qubits: int = 4):
        self.num_qubits = num_qubits

    def build(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        qc.h(0)
        for i in range(self.num_qubits - 1):
            qc.cx(i, i + 1)
        qc.measure(qr, cr)
        return qc

    def build_ancilla(self, num_ancilla: int = 1) -> QuantumCircuit:
        total = self.num_qubits + num_ancilla
        qr = QuantumRegister(total, "q")
        cr = ClassicalRegister(total, "c")
        qc = QuantumCircuit(qr, cr)
        qc.h(0)
        for i in range(self.num_qubits - 1):
            qc.cx(i, i + 1)
        for i in range(num_ancilla):
            qc.cx(i, self.num_qubits + i)
        qc.measure(qr, cr)
        return qc

    def __repr__(self) -> str:
        return f"GHZCircuit(qubits={self.num_qubits})"


class WStateCircuit:
    def __init__(self, num_qubits: int = 4):
        self.num_qubits = num_qubits

    def build(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        qc.ry(2 * np.arccos(1 / np.sqrt(self.num_qubits)), 0)
        for i in range(1, self.num_qubits):
            qc.cx(0, i)
        for i in range(1, self.num_qubits):
            qc.cx(0, i)
            qc.ry(2 * np.arccos(1 / np.sqrt(self.num_qubits)), i)
            qc.cx(0, i)
        qc.measure(qr, cr)
        return qc

    def __repr__(self) -> str:
        return f"WStateCircuit(qubits={self.num_qubits})"


class ClusterStateCircuit:
    def __init__(self, num_qubits: int = 4, topology: str = "linear"):
        self.num_qubits = num_qubits
        self.topology = topology

    def build(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        qc.h(range(self.num_qubits))
        if self.topology == "linear":
            for i in range(self.num_qubits - 1):
                qc.cz(i, i + 1)
        elif self.topology == "grid_2d":
            side = int(np.sqrt(self.num_qubits))
            for row in range(side):
                for col in range(side):
                    idx = row * side + col
                    if col < side - 1:
                        qc.cz(idx, idx + 1)
                    if row < side - 1:
                        qc.cz(idx, idx + side)
        elif self.topology == "circular":
            for i in range(self.num_qubits):
                qc.cz(i, (i + 1) % self.num_qubits)
        elif self.topology == "full":
            for i in range(self.num_qubits):
                for j in range(i + 1, self.num_qubits):
                    qc.cz(i, j)
        qc.measure(qr, cr)
        return qc

    def __repr__(self) -> str:
        return f"ClusterStateCircuit(qubits={self.num_qubits}, topology={self.topology})"
