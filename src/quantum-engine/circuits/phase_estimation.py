"""Quantum phase estimation for frequency analysis."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister
from qiskit.circuit.library import QFT


class PhaseEstimationCircuit:
    def __init__(
        self,
        num_evaluation_qubits: int = 4,
        num_target_qubits: int = 3,
    ):
        self.num_eval = num_evaluation_qubits
        self.num_target = num_target_qubits
        self.num_qubits = num_evaluation_qubits + num_target_qubits

    def build_qpe(self, unitary_matrix: np.ndarray) -> QuantumCircuit:
        n_eval = self.num_eval
        n_target = self.num_target
        qr_eval = QuantumRegister(n_eval, "eval")
        qr_target = QuantumRegister(n_target, "target")
        cr = ClassicalRegister(n_eval, "c")
        qc = QuantumCircuit(qr_eval, qr_target, cr)

        qc.h(qr_eval)
        for i in range(n_target):
            qc.x(qr_target[i])

        for i in range(n_eval):
            power = 2**i
            for _ in range(power):
                qc.unitary(unitary_matrix, qr_target, label=f"U^{power}", qubits=qr_eval[i])

        inverse_qft = QFT(n_eval, inverse=True)
        qc.compose(inverse_qft, qubits=qr_eval, inplace=True)

        qc.measure(qr_eval, cr)
        return qc

    def build_iterative_qpe(self, unitary_gate, target_qubit: int) -> QuantumCircuit:
        n_eval = self.num_eval
        qr = QuantumRegister(n_eval + 1, "q")
        cr = ClassicalRegister(n_eval, "c")
        qc = QuantumCircuit(qr, cr)

        for i in range(n_eval):
            qc.reset(qr[i])
            qc.h(qr[i])
            for _ in range(2**i):
                qc.append(unitary_gate, [qr[i], qr[target_qubit]])

            for j in range(i):
                angle = -np.pi / (2 ** (i - j))
                if cr[j] is not None:
                    qc.p(angle, qr[i]).c_if(cr[j], 1)

            qc.h(qr[i])
            qc.measure(qr[i], cr[i])

        return qc

    def estimate_phase_from_counts(self, counts: dict[str, int]) -> float:
        n = self.num_eval
        total = sum(counts.values())
        phase = 0.0
        for bitstring, count in counts.items():
            if len(bitstring) >= n:
                idx = int(bitstring[:n], 2)
                phase += (count / total) * (idx / (2**n))
        return phase

    def __repr__(self) -> str:
        return f"PhaseEstimationCircuit(eval={self.num_eval}, target={self.num_target})"


class FrequencyEstimator:
    def __init__(
        self,
        num_evaluation_qubits: int = 6,
        num_signal_qubits: int = 4,
        sampling_rate: float = 1.0,
    ):
        self.num_eval = num_evaluation_qubits
        self.num_signal = num_signal_qubits
        self.sampling_rate = sampling_rate
        self.pe_circuit = PhaseEstimationCircuit(num_evaluation_qubits, num_signal_qubits)

    def build_frequency_estimation_circuit(self, frequencies: list[float]) -> QuantumCircuit:
        n_total = self.num_eval + self.num_signal
        qr = QuantumRegister(n_total, "q")
        cr = ClassicalRegister(self.num_eval, "c")
        qc = QuantumCircuit(qr, cr)

        for i in range(self.num_eval):
            qc.h(qr[i])

        for i in range(self.num_signal):
            qc.x(qr[self.num_eval + i])

        for freq in frequencies:
            omega = 2 * np.pi * freq / self.sampling_rate
            for i in range(self.num_eval):
                for _ in range(2**i):
                    for j in range(self.num_signal):
                        qc.cp(omega, qr[i], qr[self.num_eval + j])

        inverse_qft = QFT(self.num_eval, inverse=True)
        qc.compose(inverse_qft, qubits=qr[:self.num_eval], inplace=True)
        qc.measure(qr[:self.num_eval], cr)
        return qc

    def extract_frequencies(
        self, counts: dict[str, int]
    ) -> list[tuple[float, float]]:
        n = self.num_eval
        total = sum(counts.values())
        freq_bins = {}

        for bitstring, count in counts.items():
            if len(bitstring) >= n:
                idx = int(bitstring[:n], 2)
                freq = (idx / (2**n)) * self.sampling_rate
                prob = count / total
                freq_bins[freq] = prob

        sorted_freqs = sorted(freq_bins.items(), key=lambda x: x[1], reverse=True)
        return sorted_freqs[:5]

    def __repr__(self) -> str:
        return f"FrequencyEstimator(eval={self.num_eval}, signal={self.num_signal})"
