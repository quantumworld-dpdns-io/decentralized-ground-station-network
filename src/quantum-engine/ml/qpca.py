"""Quantum PCA for signal dimensionality reduction."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


class QuantumPCA:
    def __init__(
        self,
        num_components: int = 2,
        num_qubits: int = 4,
        num_layers: int = 3,
        seed: Optional[int] = None,
    ):
        self.num_components = num_components
        self.num_qubits = num_qubits
        self.num_layers = num_layers
        self.rng = np.random.default_rng(seed)
        self.components: Optional[np.ndarray] = None
        self.explained_variance: Optional[np.ndarray] = None
        self.mean: Optional[np.ndarray] = None
        self._circuit_params = self.rng.uniform(-np.pi, np.pi, num_qubits * num_layers)

    def _quantum_encoding(self, x: np.ndarray) -> np.ndarray:
        n = min(len(x), self.num_qubits)
        encoded = np.zeros(self.num_qubits)
        encoded[:n] = x[:n] / (np.linalg.norm(x[:n]) + 1e-10)
        return encoded

    def _quantum_circuit_transform(self, x: np.ndarray) -> np.ndarray:
        encoded = self._quantum_encoding(x)
        result = np.zeros(self.num_components)
        for c in range(self.num_components):
            val = 0.0
            for layer in range(self.num_layers):
                for i in range(self.num_qubits):
                    theta = self._circuit_params[layer * self.num_qubits + i]
                    val += np.sin(theta * encoded[i])
            result[c] = val
        return result

    def fit(self, X: np.ndarray):
        self.mean = np.mean(X, axis=0)
        X_centered = X - self.mean
        cov = np.cov(X_centered.T)
        eigenvalues, eigenvectors = np.linalg.eigh(cov)
        idx = np.argsort(eigenvalues)[::-1]
        eigenvalues = eigenvalues[idx]
        eigenvectors = eigenvectors[:, idx]
        self.components = eigenvectors[:, : self.num_components]
        total = np.sum(eigenvalues)
        self.explained_variance = eigenvalues[: self.num_components] / total if total > 0 else eigenvalues[: self.num_components]

    def transform(self, X: np.ndarray) -> np.ndarray:
        if self.components is not None:
            X_centered = X - self.mean
            return X_centered @ self.components
        n, p = X.shape
        result = np.zeros((n, self.num_components))
        for i in range(n):
            result[i] = self._quantum_circuit_transform(X[i])
        return result

    def fit_transform(self, X: np.ndarray) -> np.ndarray:
        self.fit(X)
        return self.transform(X)

    def inverse_transform(self, X_transformed: np.ndarray) -> np.ndarray:
        if self.components is None:
            raise RuntimeError("Model not fitted yet.")
        return X_transformed @ self.components.T + self.mean

    def explained_variance_ratio(self) -> np.ndarray:
        if self.explained_variance is None:
            raise RuntimeError("Model not fitted yet.")
        return self.explained_variance

    def quantum_variance_ratio(self, X: np.ndarray) -> np.ndarray:
        transformed = self.transform(X)
        variances = np.var(transformed, axis=0)
        total = np.sum(variances)
        return variances / total if total > 0 else variances

    def __repr__(self) -> str:
        return f"QuantumPCA(components={self.num_components}, qubits={self.num_qubits})"
