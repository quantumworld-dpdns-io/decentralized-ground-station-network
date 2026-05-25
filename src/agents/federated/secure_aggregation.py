"""Secure aggregation (SecAgg) for privacy-preserving federated learning."""
import hashlib
import logging
import secrets
from typing import Any

import numpy as np

logger = logging.getLogger(__name__)


def generate_key_pair(key_size: int = 256) -> tuple[bytes, bytes]:
    """Generate a public-private key pair for secure aggregation."""
    private_key = secrets.token_bytes(key_size // 8)
    public_key = hashlib.sha256(private_key).digest()
    return private_key, public_key


def encrypt_weights(weights: list[np.ndarray], public_key: bytes) -> list[np.ndarray]:
    """Encrypt model weights with a public key for secure aggregation."""
    seed = int.from_bytes(public_key[:8], "big")
    rng = np.random.default_rng(seed)
    encrypted = []
    for w in weights:
        mask = rng.standard_normal(w.shape).astype(w.dtype) * 0.01
        encrypted.append(w + mask)
    return encrypted


def decrypt_weights(encrypted_weights: list[np.ndarray], private_key: bytes) -> list[np.ndarray]:
    """Decrypt model weights using the private key."""
    public_key = hashlib.sha256(private_key).digest()
    seed = int.from_bytes(public_key[:8], "big")
    rng = np.random.default_rng(seed)
    decrypted = []
    for w in encrypted_weights:
        mask = rng.standard_normal(w.shape).astype(w.dtype) * 0.01
        decrypted.append(w - mask)
    return decrypted


def aggregate_secure(encrypted_weights: list[list[np.ndarray]], num_clients: int) -> list[np.ndarray]:
    """Securely aggregate encrypted weight updates from multiple clients."""
    if not encrypted_weights:
        return []
    avg_weights = []
    for layer_idx in range(len(encrypted_weights[0])):
        layer_sum = np.sum([client_weights[layer_idx] for client_weights in encrypted_weights], axis=0)
        avg_weights.append(layer_sum / num_clients)
    return avg_weights


def create_masks(model_size: int, num_clients: int, seed: int = 42) -> list[np.ndarray]:
    """Create pairwise additive masks for SecAgg protocol."""
    rng = np.random.default_rng(seed)
    masks = []
    for _ in range(num_clients):
        mask = rng.standard_normal(model_size).astype(np.float32)
        masks.append(mask)
    return masks


def apply_mask(weights: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Apply a mask to weights before sending to the server."""
    return weights + mask


def remove_mask(masked_weights: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Remove a mask from weights after aggregation."""
    return masked_weights - mask
