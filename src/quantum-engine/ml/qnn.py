"""Quantum neural network for signal classification."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


class QuantumNeuralNetwork:
    def __init__(
        self,
        num_qubits: int = 4,
        num_layers: int = 2,
        num_classes: int = 2,
        learning_rate: float = 0.01,
        seed: Optional[int] = None,
    ):
        self.num_qubits = num_qubits
        self.num_layers = num_layers
        self.num_classes = num_classes
        self.learning_rate = learning_rate
        self.rng = np.random.default_rng(seed)
        self.params = self.rng.uniform(-np.pi, np.pi, self._num_params())
        self.trained = False

    def _num_params(self) -> int:
        return 2 * self.num_qubits * self.num_layers * self.num_classes

    def encode_classical_data(self, data: np.ndarray) -> np.ndarray:
        n = min(len(data), self.num_qubits)
        angles = np.zeros(self.num_qubits)
        angles[:n] = np.arctan(data[:n])
        return angles

    def forward(self, x: np.ndarray) -> np.ndarray:
        angles = self.encode_classical_data(x)
        logits = np.zeros(self.num_classes)
        for c in range(self.num_classes):
            offset = c * 2 * self.num_qubits * self.num_layers
            for layer in range(self.num_layers):
                layer_offset = offset + layer * 2 * self.num_qubits
                for i in range(self.num_qubits):
                    theta = self.params[layer_offset + 2 * i]
                    phi = self.params[layer_offset + 2 * i + 1]
                    logits[c] += np.sin(theta * angles[i] + phi)
        return self._softmax(logits)

    def _softmax(self, x: np.ndarray) -> np.ndarray:
        exp_x = np.exp(x - np.max(x))
        return exp_x / (exp_x.sum() + 1e-10)

    def predict(self, x: np.ndarray) -> int:
        probs = self.forward(x)
        return int(np.argmax(probs))

    def predict_proba(self, x: np.ndarray) -> np.ndarray:
        return self.forward(x)

    def _categorical_crossentropy(self, y_pred: np.ndarray, y_true: int) -> float:
        eps = 1e-10
        return -np.log(y_pred[y_true] + eps)

    def _parameter_shift(
        self, x: np.ndarray, y: int, param_idx: int, shift: float = np.pi / 2
    ) -> float:
        orig = self.params[param_idx]
        self.params[param_idx] = orig + shift
        plus = self._categorical_crossentropy(self.forward(x), y)
        self.params[param_idx] = orig - shift
        minus = self._categorical_crossentropy(self.forward(x), y)
        self.params[param_idx] = orig
        return (plus - minus) / (2 * np.sin(shift))

    def fit(
        self,
        X: np.ndarray,
        y: np.ndarray,
        epochs: int = 50,
        batch_size: int = 32,
        verbose: bool = False,
    ):
        n_samples = len(X)
        for epoch in range(epochs):
            indices = self.rng.permutation(n_samples)
            epoch_loss = 0.0
            for i in range(0, n_samples, batch_size):
                batch_idx = indices[i : i + batch_size]
                batch_grad = np.zeros_like(self.params)
                for idx in batch_idx:
                    x_i = X[idx]
                    y_i = y[idx]
                    pred = self.forward(x_i)
                    loss = self._categorical_crossentropy(pred, y_i)
                    epoch_loss += loss
                    for p in range(len(self.params)):
                        batch_grad[p] += self._parameter_shift(x_i, y_i, p)
                if len(batch_idx) > 0:
                    self.params -= self.learning_rate * batch_grad / len(batch_idx)
            if verbose and (epoch + 1) % 10 == 0:
                avg_loss = epoch_loss / n_samples
                acc = self.score(X, y)
                print(f"Epoch {epoch+1}/{epochs} - loss: {avg_loss:.4f} - acc: {acc:.4f}")
        self.trained = True

    def score(self, X: np.ndarray, y: np.ndarray) -> float:
        preds = [self.predict(x) for x in X]
        return np.mean(np.array(preds) == y)

    def save_params(self, path: str):
        np.save(path, self.params)

    def load_params(self, path: str):
        self.params = np.load(path)
        self.trained = True

    def __repr__(self) -> str:
        return f"QuantumNeuralNetwork(qubits={self.num_qubits}, layers={self.num_layers}, classes={self.num_classes})"
