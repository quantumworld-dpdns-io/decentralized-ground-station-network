"""DGSN Quantum Engine - Quantum computing integration for ground station optimization."""

__version__ = "0.1.0"
__author__ = "DGSN Contributors"
__license__ = "MIT"

from . import circuits
from . import qiskit_wrapper
from . import cudaq_wrapper

__all__ = [
    "__version__",
    "circuits",
    "qiskit_wrapper",
    "cudaq_wrapper",
]
