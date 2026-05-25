"""QFT-based signal analysis circuits for ground station signal processing."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit
from qiskit.circuit.library import QFT, PhaseEstimation
from qiskit.circuit import ParameterVector

from ..qiskit_wrapper import QuantumCircuitBuilder, CircuitParams


@dataclass
class SignalProcessingConfig:
    num_signal_qubits: int = 8
    num_phase_qubits: int = 4
    num_ancilla: int = 2
    sampling_rate_mhz: float = 2.5
    frequency_resolution_hz: float = 1000.0
    use_noise_mitigation: bool = True
    num_measurement_cycles: int = 3


class SignalProcessingCircuits:
    """Quantum signal processing circuits for RF signal analysis."""

    def __init__(self, config: Optional[SignalProcessingConfig] = None):
        self.config = config or SignalProcessingConfig()
        self.num_qubits = self.config.num_signal_qubits + self.config.num_phase_qubits + self.config.num_ancilla

    def build_qft_analyzer(self) -> QuantumCircuit:
        n = self.config.num_signal_qubits
        builder = QuantumCircuitBuilder(CircuitParams(
            num_qubits=n,
            num_classical=n,
            measurement=True,
        ))
        circuit = builder.build_qft(swap=True)
        return circuit

    def build_iqft_circuit(self) -> QuantumCircuit:
        n = self.config.num_signal_qubits
        circuit = QuantumCircuit(n)

        for i in range(n // 2):
            circuit.swap(i, n - i - 1)

        for i in reversed(range(n)):
            circuit.h(i)
            for j in range(i):
                angle = -np.pi / (2 ** (i - j))
                circuit.cp(angle, i, j)
            circuit.barrier()

        circuit.measure_all()
        return circuit

    def build_phase_estimation_circuit(self, unitary_matrix: np.ndarray) -> QuantumCircuit:
        signal_qubits = self.config.num_signal_qubits
        phase_qubits = self.config.num_phase_qubits
        total = signal_qubits + phase_qubits

        pe = PhaseEstimation(
            num_evaluation_qubits=phase_qubits,
            unitary=QuantumCircuit(signal_qubits).unitary(unitary_matrix, list(range(signal_qubits))),
        )

        circuit = QuantumCircuit(total)
        circuit.compose(pe, inplace=True)
        circuit.measure_all()

        return circuit

    def build_frequency_estimation_circuit(self, frequencies: list[float]) -> QuantumCircuit:
        n = self.config.num_signal_qubits
        circuit = QuantumCircuit(n)

        for freq in frequencies:
            angle = 2 * np.pi * freq / self.config.sampling_rate_mhz
            for i in range(n):
                circuit.rz(angle * (2**i), i)
            circuit.barrier()

        circuit.compose(QFT(n, inverse=False), inplace=True)
        circuit.measure_all()

        return circuit

    def build_amplitude_estimation_circuit(self, oracle_qubits: int = 3) -> QuantumCircuit:
        n = self.config.num_signal_qubits
        m = oracle_qubits
        total = n + m + self.config.num_ancilla

        circuit = QuantumCircuit(total)

        for i in range(m):
            circuit.h(i)

        circuit.barrier()

        for i in range(n):
            circuit.ry(2 * np.arcsin(1 / np.sqrt(n)), m + i)

        circuit.barrier()

        for i in range(m):
            controlled_qubits = list(range(m, m + n))
            circuit.mcx(controlled_qubits, i)

        circuit.barrier()

        qft = QFT(m, inverse=False)
        circuit.compose(qft, qubits=list(range(m)), inplace=True)

        circuit.measure_all()

        return circuit

    def build_noise_mitigation_circuit(self) -> QuantumCircuit:
        n = self.config.num_signal_qubits
        circuit = QuantumCircuit(n, n)

        for _ in range(self.config.num_measurement_cycles):
            for i in range(n):
                circuit.h(i)
            for i in range(n):
                circuit.measure(i, i)

        return circuit

    def build_signal_correlation_circuit(self, num_signals: int = 2) -> QuantumCircuit:
        n_per_signal = self.config.num_signal_qubits // num_signals
        total = n_per_signal * num_signals
        circuit = QuantumCircuit(total)

        for s in range(num_signals):
            offset = s * n_per_signal
            for i in range(n_per_signal):
                circuit.h(offset + i)

        for s in range(num_signals - 1):
            offset1 = s * n_per_signal
            offset2 = (s + 1) * n_per_signal
            for i in range(min(n_per_signal, self.config.num_phase_qubits)):
                circuit.cx(offset1 + i, offset2 + i)

        qft = QFT(total, inverse=True)
        circuit.compose(qft, inplace=True)

        circuit.measure_all()

        return circuit

    def analyze_spectrum(self, counts: dict[str, int]) -> dict:
        n = self.config.num_signal_qubits
        total_shots = sum(counts.values())
        spectrum = np.zeros(n)

        for bitstring, count in counts.items():
            freq_bin = int(bitstring[:n], 2) if len(bitstring) >= n else 0
            spectrum[freq_bin % n] += count / total_shots

        peak_indices = np.argsort(spectrum)[-5:][::-1]
        frequencies = [
            idx * self.config.frequency_resolution_hz
            for idx in peak_indices
        ]

        return {
            "spectrum": spectrum.tolist(),
            "peak_indices": peak_indices.tolist(),
            "peak_frequencies_hz": frequencies,
            "frequency_resolution_hz": self.config.frequency_resolution_hz,
            "num_qubits": n,
        }

    def __repr__(self) -> str:
        return (
            f"SignalProcessingCircuits(signal_qubits={self.config.num_signal_qubits}, "
            f"phase_qubits={self.config.num_phase_qubits}, "
            f"total_qubits={self.num_qubits})"
        )
