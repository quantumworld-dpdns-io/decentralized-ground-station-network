"""Zero-noise extrapolation (Richardson, exponential)."""

from dataclasses import dataclass, field
from typing import Optional, Callable
from abc import ABC, abstractmethod

import numpy as np


class ZneExtrapolator(ABC):
    def __init__(self, noise_factors: Optional[list[float]] = None):
        self.noise_factors = noise_factors or [1.0, 1.5, 2.0, 2.5, 3.0]

    @abstractmethod
    def extrapolate(self, noise_factors: list[float], expectation_values: list[float]) -> float:
        pass

    def fold_circuit(self, circuit, noise_factor: float):
        from qiskit import QuantumCircuit
        n = circuit.num_qubits
        folded = circuit.copy()
        extra_gates = int((noise_factor - 1.0) * circuit.size())
        if extra_gates <= 0:
            return folded
        for _ in range(extra_gates):
            for i in range(n):
                folded.h(i)
                folded.h(i)
        return folded

    def mitigate(
        self, circuit, backend, shots: int = 1024,
    ) -> tuple[float, list[float], list[float]]:
        expectation_values = []
        for nf in self.noise_factors:
            folded = self.fold_circuit(circuit, nf)
            counts = backend.get_counts(folded, shots=shots)
            exp_val = self._expectation_from_counts(counts, shots)
            expectation_values.append(exp_val)
        zero_noise = self.extrapolate(self.noise_factors, expectation_values)
        return zero_noise, self.noise_factors, expectation_values

    def _expectation_from_counts(self, counts: dict[str, int], shots: int) -> float:
        total = sum(counts.values())
        exp_val = 0.0
        for bitstring, count in counts.items():
            parity = sum(1 for b in bitstring if b == "1") % 2
            exp_val += (2 * (0.5 - parity)) * (count / total)
        return exp_val


class RichardsonExtrapolator(ZneExtrapolator):
    def extrapolate(self, noise_factors: list[float], expectation_values: list[float]) -> float:
        n = len(noise_factors)
        if n < 2:
            return expectation_values[0]
        A = np.vander(noise_factors, increasing=True)
        coeffs = np.linalg.lstsq(A, expectation_values, rcond=None)[0]
        return coeffs[0]

    def __repr__(self) -> str:
        return f"RichardsonExtrapolator(factors={self.noise_factors})"


class ExponentialExtrapolator(ZneExtrapolator):
    def __init__(self, noise_factors: Optional[list[float]] = None, eps: float = 1e-10):
        super().__init__(noise_factors)
        self.eps = eps

    def extrapolate(self, noise_factors: list[float], expectation_values: list[float]) -> float:
        n = len(noise_factors)
        if n < 2:
            return expectation_values[0]
        vals = np.array(expectation_values)
        factors = np.array(noise_factors)
        try:
            log_vals = np.log(np.abs(vals) + self.eps)
            A = np.column_stack([np.ones(n), factors])
            coeffs = np.linalg.lstsq(A, log_vals, rcond=None)[0]
            return np.exp(coeffs[0]) * np.sign(vals[0])
        except np.linalg.LinAlgError:
            A = np.vander(factors, increasing=True)
            coeffs = np.linalg.lstsq(A, vals, rcond=None)[0]
            return coeffs[0]

    def __repr__(self) -> str:
        return f"ExponentialExtrapolator(factors={self.noise_factors})"
