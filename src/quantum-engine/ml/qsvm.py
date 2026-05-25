"""Quantum kernel SVM for station clustering."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


class QuantumKernelSVM:
    def __init__(
        self,
        num_qubits: int = 4,
        num_layers: int = 2,
        C: float = 1.0,
        kernel_regularization: float = 1e-6,
        seed: Optional[int] = None,
    ):
        self.num_qubits = num_qubits
        self.num_layers = num_layers
        self.C = C
        self.kernel_regularization = kernel_regularization
        self.rng = np.random.default_rng(seed)
        self.kernel_params = self.rng.uniform(-np.pi, np.pi, num_qubits * num_layers)
        self.support_vectors: Optional[np.ndarray] = None
        self.support_labels: Optional[np.ndarray] = None
        self.alphas: Optional[np.ndarray] = None
        self.bias: float = 0.0
        self.trained = False

    def _quantum_kernel(self, x1: np.ndarray, x2: np.ndarray) -> float:
        n = min(len(x1), len(x2), self.num_qubits)
        kernel_val = 0.0
        for layer in range(self.num_layers):
            for i in range(n):
                theta = self.kernel_params[layer * self.num_qubits + i]
                kernel_val += np.cos(theta * (x1[i] - x2[i]))
        return np.tanh(kernel_val / self.num_layers)

    def compute_kernel_matrix(self, X1: np.ndarray, X2: np.ndarray) -> np.ndarray:
        n1, n2 = len(X1), len(X2)
        K = np.zeros((n1, n2))
        for i in range(n1):
            for j in range(n2):
                K[i, j] = self._quantum_kernel(X1[i], X2[j])
        return K

    def fit(self, X: np.ndarray, y: np.ndarray):
        n = len(X)
        K = self.compute_kernel_matrix(X, X)
        K_reg = K + self.kernel_regularization * np.eye(n)

        y_vec = 2 * y - 1
        P = np.outer(y_vec, y_vec) * K_reg
        q_vec = -np.ones(n)

        from scipy.optimize import minimize

        bounds = [(0, self.C) for _ in range(n)]
        constraints = [{"type": "eq", "fun": lambda a: np.dot(a, y_vec)}]

        def objective(alpha):
            return 0.5 * alpha @ P @ alpha + q_vec @ alpha

        alpha0 = np.zeros(n)
        result = minimize(
            objective,
            alpha0,
            bounds=bounds,
            constraints=constraints,
            method="SLSQP",
            options={"maxiter": 200},
        )

        self.alphas = result.x
        sv_mask = self.alphas > 1e-6
        self.support_vectors = X[sv_mask]
        self.support_labels = y[sv_mask]
        self.alphas = self.alphas[sv_mask]

        sv_idx = np.where(sv_mask)[0]
        if len(sv_idx) > 0:
            bias_sum = 0.0
            for idx in sv_idx[:10]:
                bias_sum += y_vec[idx] - np.sum(
                    self.alphas * y_vec[sv_mask] * K[idx, sv_mask]
                )
            self.bias = bias_sum / min(10, len(sv_idx))

        self.trained = True

    def decision_function(self, X: np.ndarray) -> np.ndarray:
        if not self.trained:
            raise RuntimeError("Model not trained yet.")
        K_test = self.compute_kernel_matrix(X, self.support_vectors)
        y_sv = 2 * self.support_labels - 1
        return K_test @ (self.alphas * y_sv) + self.bias

    def predict(self, X: np.ndarray) -> np.ndarray:
        return (self.decision_function(X) > 0).astype(int)

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        scores = self.decision_function(X)
        return 1.0 / (1.0 + np.exp(-scores))

    def fit_predict(self, X: np.ndarray, y: np.ndarray, X_test: np.ndarray) -> np.ndarray:
        self.fit(X, y)
        return self.predict(X_test)

    def score(self, X: np.ndarray, y: np.ndarray) -> float:
        preds = self.predict(X)
        return np.mean(preds == y)

    def __repr__(self) -> str:
        return f"QuantumKernelSVM(qubits={self.num_qubits}, C={self.C})"
