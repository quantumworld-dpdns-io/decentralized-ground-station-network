"""Aer simulator wrapper with configurable noise models."""

from dataclasses import dataclass, field
from typing import Optional, Callable

import numpy as np
from qiskit import QuantumCircuit
from qiskit_aer import AerSimulator
from qiskit_aer.noise import (
    NoiseModel,
    depolarizing_error,
    thermal_relaxation_error,
    ReadoutError,
    amplitude_damping_error,
    phase_damping_error,
    pauli_error,
    NoiseModel as _NoiseModel,
)
from qiskit.result import Result


@dataclass
class NoiseModelConfig:
    depolarizing_error_rate: float = 0.001
    gate_error_1q: float = 0.0001
    gate_error_2q: float = 0.001
    readout_error_prob0: float = 0.01
    readout_error_prob1: float = 0.02
    t1: float = 100e-6
    t2: float = 50e-6
    gate_time_1q: float = 50e-9
    gate_time_2q: float = 300e-9
    reset_after_measurement: bool = True
    seed: Optional[int] = None

    def build_noise_model(self) -> NoiseModel:
        noise_model = NoiseModel()

        if self.depolarizing_error_rate > 0:
            depol_error_1q = depolarizing_error(self.depolarizing_error_rate, 1)
            depol_error_2q = depolarizing_error(self.depolarizing_error_rate, 2)
            noise_model.add_all_qubit_quantum_error(depol_error_1q, ["u1", "u2", "u3", "h", "s", "t", "x", "y", "z"])
            noise_model.add_all_qubit_quantum_error(depol_error_2q, ["cx", "cz", "swap", "rzz", "rxx"])

        if self.gate_error_1q > 0:
            error_1q = depolarizing_error(self.gate_error_1q, 1)
            noise_model.add_all_qubit_quantum_error(error_1q, ["u1", "u2", "u3"])

        if self.gate_error_2q > 0:
            error_2q = depolarizing_error(self.gate_error_2q, 2)
            noise_model.add_all_qubit_quantum_error(error_2q, ["cx"])

        if self.readout_error_prob0 > 0 or self.readout_error_prob1 > 0:
            readout = ReadoutError(self.readout_error_prob0, self.readout_error_prob1)
            noise_model.add_all_qubit_readout_error(readout)

        return noise_model


@dataclass
class SimulatorConfig:
    method: str = "automatic"
    device: str = "CPU"
    precision: str = "double"
    shots: int = 1024
    memory: bool = False
    max_parallel_threads: int = 0
    max_parallel_experiments: int = 0
    fusion_enable: bool = True
    fusion_max_qubits: int = 5
    fusion_threshold: int = 14
    noise_model_config: Optional[NoiseModelConfig] = None


class AerSimulatorWrapper:
    """Wrapper around Qiskit AerSimulator with noise modeling support."""

    def __init__(self, config: Optional[SimulatorConfig] = None):
        self.config = config or SimulatorConfig()
        self._simulator: Optional[AerSimulator] = None
        self._initialize()

    def _initialize(self) -> None:
        sim_kwargs = {
            "method": self.config.method,
            "shots": self.config.shots,
            "memory": self.config.memory,
            "max_parallel_threads": self.config.max_parallel_threads or None,
            "max_parallel_experiments": self.config.max_parallel_experiments or None,
            "fusion_enable": self.config.fusion_enable,
            "fusion_max_qubits": self.config.fusion_max_qubits,
            "fusion_threshold": self.config.fusion_threshold,
        }

        if self.config.noise_model_config:
            noise_model = self.config.noise_model_config.build_noise_model()
            sim_kwargs["noise_model"] = noise_model

        if self.config.seed is not None:
            sim_kwargs["seed_simulator"] = self.config.seed

        self._simulator = AerSimulator(**sim_kwargs)

    def run(self, circuit: QuantumCircuit, shots: Optional[int] = None) -> Result:
        run_shots = shots or self.config.shots
        return self._simulator.run(circuit, shots=run_shots).result()

    def run_batch(self, circuits: list[QuantumCircuit], shots: Optional[int] = None) -> list[Result]:
        run_shots = shots or self.config.shots
        result = self._simulator.run(circuits, shots=run_shots).result()
        return [result] if isinstance(result, Result) else result

    def get_counts(self, circuit: QuantumCircuit, shots: Optional[int] = None) -> dict[str, int]:
        result = self.run(circuit, shots)
        return result.get_counts()

    def get_statevector(self, circuit: QuantumCircuit) -> np.ndarray:
        state_circuit = circuit.copy()
        try:
            state_circuit.remove_final_measurements()
        except Exception:
            pass
        sim = AerSimulator(method="statevector")
        result = sim.run(state_circuit).result()
        return result.get_statevector().data

    def get_expectation_value(
        self, circuit: QuantumCircuit, observable: np.ndarray, shots: Optional[int] = None
    ) -> float:
        result = self.run(circuit, shots)
        counts = result.get_counts()
        num_qubits = circuit.num_qubits
        total_shots = sum(counts.values())
        expectation = 0.0

        for bitstring, count in counts.items():
            basis_state = np.zeros(2**num_qubits, dtype=complex)
            basis_state[int(bitstring, 2)] = 1.0
            expectation += count * (basis_state.conj().T @ observable @ basis_state).real

        return expectation / total_shots

    def reconfigure(self, **kwargs) -> None:
        for key, value in kwargs.items():
            if hasattr(self.config, key):
                setattr(self.config, key, value)
        self._initialize()

    @property
    def simulator(self) -> AerSimulator:
        return self._simulator

    def __repr__(self) -> str:
        return (
            f"AerSimulatorWrapper(method={self.config.method}, "
            f"shots={self.config.shots}, "
            f"noise={'yes' if self.config.noise_model_config else 'no'})"
        )
