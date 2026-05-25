"""Probabilistic error cancellation."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


class ProbabilisticErrorCancellation:
    def __init__(self, num_qubits: int, seed: Optional[int] = None):
        self.num_qubits = num_qubits
        self.rng = np.random.default_rng(seed)
        self._noise_channel: Optional[np.ndarray] = None
        self._inverse_channel: Optional[np.ndarray] = None
        self._quasi_probability: Optional[dict[str, float]] = None

    def learn_noise_channel(self, tomographic_data: list) -> np.ndarray:
        dim = 2**self.num_qubits
        channel = np.zeros((dim, dim), dtype=complex)
        for prep, meas, prob in tomographic_data:
            rho_in = np.zeros((dim, dim), dtype=complex)
            rho_in[prep, prep] = 1.0
            e_out = np.zeros((dim, dim), dtype=complex)
            e_out[meas, meas] = prob
            channel += e_out @ rho_in.T
        self._noise_channel = channel
        return channel

    def compute_inverse_channel(self, regularization: float = 1e-6) -> np.ndarray:
        if self._noise_channel is None:
            raise RuntimeError("Noise channel not learned yet.")
        n = self._noise_channel.shape[0]
        A = self._noise_channel
        I = np.eye(n)
        A_reg = A.conj().T @ A + regularization * I
        inv_reg = np.linalg.inv(A_reg)
        self._inverse_channel = inv_reg @ A.conj().T
        return self._inverse_channel

    def compute_quasi_probabilities(self, num_samples: int = 1000) -> dict[str, float]:
        if self._inverse_channel is None:
            self.compute_inverse_channel()
        dim = 2**self.num_qubits
        quasi = {}
        for i in range(dim):
            for j in range(dim):
                prob = abs(self._inverse_channel[i, j])
                if prob > 1e-10:
                    key = f"{i:0{self.num_qubits}b}_{j:0{self.num_qubits}b}"
                    quasi[key] = prob
        total = sum(quasi.values())
        if total > 0:
            for k in quasi:
                quasi[k] /= total
        self._quasi_probability = quasi
        return quasi

    def sample_gate_sequence(self, operation: str) -> list[tuple[str, list[int]]]:
        if self._quasi_probability is None:
            self.compute_quasi_probabilities()
        keys = list(self._quasi_probability.keys())
        probs = [self._quasi_probability[k] for k in keys]
        if not keys:
            return [(operation, list(range(self.num_qubits)))]
        chosen = self.rng.choice(keys, p=probs)
        parts = chosen.split("_")
        gates = [(operation, list(range(self.num_qubits)))]
        if parts[0] != "0" * self.num_qubits:
            for i, bit in enumerate(parts[0]):
                if bit == "1":
                    gates.append(("x", [i]))
        return gates

    def mitigate_expectation(
        self,
        raw_counts: dict[str, int],
        shots: int,
        num_samples: int = 100,
    ) -> float:
        n = self.num_qubits
        dim = 2**n
        noisy_expectation = 0.0
        total = sum(raw_counts.values())
        for bitstring, count in raw_counts.items():
            parity = sum(1 for b in bitstring if b == "1") % 2
            noisy_expectation += (2 * (0.5 - parity)) * (count / total)

        if self._inverse_channel is None:
            self.compute_inverse_channel()

        mitigated = 0.0
        for _ in range(num_samples):
            sample_expectation = 0.0
            for bitstring, count in raw_counts.items():
                idx = int(bitstring[:n], 2)
                prob = count / shots
                correction = 0.0
                for j in range(dim):
                    correction += abs(self._inverse_channel[idx, j])
                sample_expectation += prob * correction
            mitigated += sample_expectation / num_samples

        return mitigated * np.sign(noisy_expectation) if noisy_expectation != 0 else 0.0

    def __repr__(self) -> str:
        return f"ProbabilisticErrorCancellation(qubits={self.num_qubits})"
