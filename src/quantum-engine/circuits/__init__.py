"""Quantum circuit module for various application-specific circuits."""

from .error_correction import SurfaceCodeCircuit, RepetitionCodeCircuit
from .entanglement import (
    BellStateCircuit,
    GHZCircuit,
    WStateCircuit,
    ClusterStateCircuit,
)
from .arithmetic import QuantumAdder, QuantumComparator
from .phase_estimation import PhaseEstimationCircuit, FrequencyEstimator

__all__ = [
    "SurfaceCodeCircuit",
    "RepetitionCodeCircuit",
    "BellStateCircuit",
    "GHZCircuit",
    "WStateCircuit",
    "ClusterStateCircuit",
    "QuantumAdder",
    "QuantumComparator",
    "PhaseEstimationCircuit",
    "FrequencyEstimator",
]
