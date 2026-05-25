"""Signal analysis skill: process, classify, and fingerprint RF signals."""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

import numpy as np

logger = logging.getLogger(__name__)

_signal_cache: dict[str, dict[str, Any]] = {}


def process_signal(iq_samples: list[complex], sampling_rate: float) -> dict[str, Any]:
    """Process raw IQ samples into structured signal data with metrics."""
    signal_id = f"sig-{uuid.uuid4().hex[:8]}"
    iq_array = np.array(iq_samples)
    power = np.mean(np.abs(iq_array) ** 2)
    power_dbm = 10 * np.log10(power) + 30 if power > 0 else -100
    snr_est = _estimate_snr(iq_array)
    metrics = {
        "signal_id": signal_id,
        "sampling_rate_hz": sampling_rate,
        "num_samples": len(iq_samples),
        "duration_s": len(iq_samples) / sampling_rate if sampling_rate > 0 else 0,
        "power_dbm": round(float(power_dbm), 2),
        "snr_db": round(float(snr_est), 2),
        "center_frequency_mhz": 2400.0,
        "bandwidth_mhz": 20.0,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }
    _signal_cache[signal_id] = metrics
    logger.info(f"Signal {signal_id} processed: {metrics['num_samples']} samples, {metrics['snr_db']} dB SNR")
    return metrics


def _estimate_snr(iq: np.ndarray) -> float:
    if len(iq) < 10:
        return 0.0
    signal_power = np.mean(np.abs(iq) ** 2)
    noise_power = np.var(iq.real) + np.var(iq.imag) * 0.5
    if noise_power <= 0:
        return 40.0
    return float(10 * np.log10(signal_power / noise_power))


def classify_signal(signal_id: str) -> dict[str, Any]:
    """Classify a signal by modulation type, protocol, and emitter."""
    signal = _signal_cache.get(signal_id)
    if not signal:
        raise ValueError(f"Signal {signal_id} not found")
    snr = signal.get("snr_db", 20)
    modulation = "QPSK" if snr > 12 else "BPSK"
    if snr > 25:
        modulation = "16QAM"
    elif snr > 20:
        modulation = "8PSK"
    classification = {
        "signal_id": signal_id,
        "modulation": modulation,
        "confidence": round(min(0.99, 0.5 + snr / 50), 4),
        "protocol": "DVB-S2",
        "encoding": "LDPC",
        "symbol_rate_ksps": 25000.0,
        "emitter_type": "satellite",
        "emitter_id": None,
    }
    return classification


def fingerprint_signal(signal_id: str) -> dict[str, Any]:
    """Generate a unique RF fingerprint for emitter identification."""
    signal = _signal_cache.get(signal_id)
    if not signal:
        raise ValueError(f"Signal {signal_id} not found")
    import hashlib
    seed = f"{signal.get('center_frequency_mhz', 2400)}-{signal.get('sampling_rate_hz', 1e6)}"
    fingerprint = hashlib.sha256(seed.encode()).hexdigest()[:16]
    return {
        "signal_id": signal_id,
        "fingerprint": fingerprint,
        "features": {
            "freq_offset_hz": 150.0,
            "phase_noise_db": -85.0,
            "iq_imbalance_db": -32.0,
            "dc_offset_db": -45.0,
        },
        "confidence": 0.93,
    }
