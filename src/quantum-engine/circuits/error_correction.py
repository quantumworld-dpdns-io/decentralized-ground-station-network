"""Surface code, repetition code circuits."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister


class RepetitionCodeCircuit:
    def __init__(self, code_distance: int = 3, num_rounds: int = 1):
        self.d = code_distance
        self.num_rounds = num_rounds
        self.num_data_qubits = code_distance
        self.num_ancilla_qubits = code_distance - 1
        self.num_qubits = self.num_data_qubits + self.num_ancilla_qubits

    def build_encode_circuit(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_data_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        for i in range(self.num_data_qubits - 1):
            qc.cx(qr[i], qr[i + self.num_data_qubits])
        return qc

    def build_stabilizer_measurement(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_ancilla_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        for round_idx in range(self.num_rounds):
            for i in range(self.num_ancilla_qubits):
                qc.cx(qr[i], qr[self.num_data_qubits + i])
                qc.cx(qr[i + 1], qr[self.num_data_qubits + i])
            for i in range(self.num_ancilla_qubits):
                qc.measure(qr[self.num_data_qubits + i], cr[i])
            if round_idx < self.num_rounds - 1:
                qc.reset(qr[self.num_data_qubits : self.num_data_qubits + self.num_ancilla_qubits])
        return qc

    def build_error_detection_circuit(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        cr = ClassicalRegister(self.num_ancilla_qubits + self.num_data_qubits, "c")
        qc = QuantumCircuit(qr, cr)
        for i in range(self.num_data_qubits - 1):
            qc.cx(qr[i], qr[self.num_data_qubits + i])
            qc.cx(qr[i + 1], qr[self.num_data_qubits + i])
        for i in range(self.num_ancilla_qubits):
            qc.measure(qr[self.num_data_qubits + i], cr[i])
        for i in range(self.num_data_qubits):
            qc.measure(qr[i], cr[self.num_ancilla_qubits + i])
        return qc

    def decode_correction(self, syndrome: list[int]) -> list[int]:
        corrections = [0] * self.num_data_qubits
        for i, s in enumerate(syndrome):
            if s == 1:
                corrections[i] ^= 1
                corrections[i + 1] ^= 1
        return corrections

    def __repr__(self) -> str:
        return f"RepetitionCodeCircuit(d={self.d}, rounds={self.num_rounds})"


class SurfaceCodeCircuit:
    def __init__(self, distance: int = 3):
        self.d = distance
        self.num_qubits = 2 * distance * distance - 1

    def build_syndrome_circuit(self) -> QuantumCircuit:
        n = 2 * self.d * self.d - 1
        qr = QuantumRegister(n, "q")
        cr = ClassicalRegister(self.d * self.d - 1, "c")
        qc = QuantumCircuit(qr, cr)
        ancilla_idx = 0
        for row in range(self.d - 1):
            for col in range(self.d):
                if (row + col) % 2 == 0:
                    data_q1 = row * self.d + col
                    data_q2 = row * self.d + col + 1
                    anc = self.d * self.d + ancilla_idx
                    qc.cx(qr[data_q1], qr[anc])
                    qc.cx(qr[data_q2], qr[anc])
                    qc.measure(qr[anc], cr[ancilla_idx])
                    qc.reset(qr[anc])
                    ancilla_idx += 1
        ancilla_idx = 0
        for row in range(self.d):
            for col in range(self.d - 1):
                if (row + col) % 2 == 1:
                    data_q1 = row * self.d + col
                    data_q2 = (row + 1) * self.d + col
                    anc = self.d * self.d + self.d * (self.d - 1) // 2 + ancilla_idx
                    qc.cx(qr[data_q1], qr[anc])
                    qc.cx(qr[data_q2], qr[anc])
                    qc.measure(qr[anc], cr[self.d * (self.d - 1) // 2 + ancilla_idx])
                    qc.reset(qr[anc])
                    ancilla_idx += 1
        return qc

    def build_logical_gates(self) -> QuantumCircuit:
        qr = QuantumRegister(self.num_qubits, "q")
        qc = QuantumCircuit(qr)
        for i in range(self.d):
            qc.x(i)
        return qc

    def __repr__(self) -> str:
        return f"SurfaceCodeCircuit(d={self.d})"
