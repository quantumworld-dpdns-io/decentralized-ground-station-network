"""Quantum circuit builder utility using Qiskit."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister
from qiskit.circuit import ParameterVector, Parameter
from qiskit.circuit.library import (
    RXXGate,
    RYYGate,
    RZZGate,
    RXGate,
    RYGate,
    RZGate,
    CXGate,
    CZGate,
    HGate,
    SGate,
    TGate,
    XGate,
    YGate,
    ZGate,
    PhaseGate,
    CRXGate,
    CRYGate,
    CRZGate,
)


@dataclass
class CircuitParams:
    num_qubits: int = 4
    num_classical: int = 4
    depth: int = 3
    entanglement: str = "linear"
    measurement: bool = True
    barrier: bool = False
    global_phase: float = 0.0

    def __post_init__(self):
        if self.num_qubits < 1:
            raise ValueError("num_qubits must be at least 1")
        if self.num_classical < 1:
            self.num_classical = self.num_qubits
        if self.entanglement not in ("linear", "circular", "full"):
            raise ValueError(f"unknown entanglement type: {self.entanglement}")


class QuantumCircuitBuilder:
    """Builder for constructing parameterized quantum circuits."""

    def __init__(self, params: Optional[CircuitParams] = None):
        self.params = params or CircuitParams()
        self.qr = QuantumRegister(self.params.num_qubits, "q")
        self.cr = ClassicalRegister(
            self.params.num_classical, "c"
        )
        self.circuit = QuantumCircuit(self.qr, self.cr)

        if self.params.global_phase != 0.0:
            self.circuit.global_phase = self.params.global_phase

    def add_hadamard_layer(self) -> "QuantumCircuitBuilder":
        for i in range(self.params.num_qubits):
            self.circuit.h(self.qr[i])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_pauli_layer(self) -> "QuantumCircuitBuilder":
        gates = [XGate(), YGate(), ZGate()]
        for i in range(self.params.num_qubits):
            gate = gates[i % len(gates)]
            self.circuit.append(gate, [self.qr[i]])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_ry_layer(self, params_vector: Optional[ParameterVector] = None) -> "QuantumCircuitBuilder":
        if params_vector is None:
            params_vector = ParameterVector("theta", self.params.num_qubits)
        for i in range(self.params.num_qubits):
            self.circuit.ry(params_vector[i], self.qr[i])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_rz_layer(self, params_vector: Optional[ParameterVector] = None) -> "QuantumCircuitBuilder":
        if params_vector is None:
            params_vector = ParameterVector("phi", self.params.num_qubits)
        for i in range(self.params.num_qubits):
            self.circuit.rz(params_vector[i], self.qr[i])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_entangling_layer(self) -> "QuantumCircuitBuilder":
        if self.params.entanglement == "linear":
            for i in range(self.params.num_qubits - 1):
                self.circuit.cx(self.qr[i], self.qr[i + 1])
        elif self.params.entanglement == "circular":
            for i in range(self.params.num_qubits):
                self.circuit.cx(self.qr[i], self.qr[(i + 1) % self.params.num_qubits])
        elif self.params.entanglement == "full":
            for i in range(self.params.num_qubits):
                for j in range(i + 1, self.params.num_qubits):
                    self.circuit.cx(self.qr[i], self.qr[j])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_xx_layer(self, params_vector: Optional[ParameterVector] = None) -> "QuantumCircuitBuilder":
        if params_vector is None:
            params_vector = ParameterVector("alpha", self.params.num_qubits)
        for i in range(self.params.num_qubits - 1):
            self.circuit.append(RXXGate(params_vector[i]), [self.qr[i], self.qr[i + 1]])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_zz_layer(self, params_vector: Optional[ParameterVector] = None) -> "QuantumCircuitBuilder":
        if params_vector is None:
            params_vector = ParameterVector("gamma", self.params.num_qubits)
        for i in range(self.params.num_qubits - 1):
            self.circuit.append(RZZGate(params_vector[i]), [self.qr[i], self.qr[i + 1]])
        if self.params.barrier:
            self.circuit.barrier()
        return self

    def add_measurement(self) -> "QuantumCircuitBuilder":
        self.circuit.measure(self.qr, self.cr)
        return self

    def build_qaoa(self, num_layers: int = 1) -> QuantumCircuit:
        gamma_params = ParameterVector("gamma", num_layers)
        beta_params = ParameterVector("beta", num_layers)
        p = num_layers

        self.add_hadamard_layer()

        for layer in range(p):
            for i in range(self.params.num_qubits - 1):
                self.circuit.append(
                    RZZGate(2 * gamma_params[layer]),
                    [self.qr[i], self.qr[i + 1]],
                )
            for i in range(self.params.num_qubits):
                self.circuit.append(RXGate(2 * beta_params[layer]), [self.qr[i]])
            if self.params.barrier:
                self.circuit.barrier()

        if self.params.measurement:
            self.circuit.measure(self.qr, self.cr)

        return self.circuit

    def build_vqe(self, num_layers: int = 1) -> QuantumCircuit:
        theta_params = ParameterVector("theta", self.params.num_qubits * num_layers * 2)
        idx = 0

        for layer in range(num_layers):
            for i in range(self.params.num_qubits):
                self.circuit.ry(theta_params[idx], self.qr[i])
                idx += 1
            for i in range(self.params.num_qubits):
                self.circuit.rz(theta_params[idx], self.qr[i])
                idx += 1
            if layer < num_layers - 1:
                for i in range(self.params.num_qubits - 1):
                    self.circuit.cx(self.qr[i], self.qr[i + 1])
                if self.params.entanglement == "circular":
                    self.circuit.cx(self.qr[-1], self.qr[0])
                if self.params.barrier:
                    self.circuit.barrier()

        if self.params.measurement:
            self.circuit.measure(self.qr, self.cr)

        return self.circuit

    def build_qft(self, swap: bool = True) -> QuantumCircuit:
        for i in range(self.params.num_qubits):
            self.circuit.h(self.qr[i])
            for j in range(i + 1, self.params.num_qubits):
                angle = np.pi / (2 ** (j - i))
                self.circuit.cp(angle, self.qr[j], self.qr[i])
            if self.params.barrier:
                self.circuit.barrier()

        if swap:
            for i in range(self.params.num_qubits // 2):
                self.circuit.swap(self.qr[i], self.qr[self.params.num_qubits - i - 1])

        if self.params.measurement:
            self.circuit.measure(self.qr, self.cr)

        return self.circuit

    def build_ghz(self) -> QuantumCircuit:
        self.circuit.h(self.qr[0])
        for i in range(self.params.num_qubits - 1):
            self.circuit.cx(self.qr[i], self.qr[i + 1])
        if self.params.measurement:
            self.circuit.measure(self.qr, self.cr)
        return self.circuit

    def build_grover_oracle(self, marked_state: int) -> QuantumCircuit:
        for i in range(self.params.num_qubits):
            if not (marked_state >> i) & 1:
                self.circuit.x(self.qr[i])
        self.circuit.h(self.qr[self.params.num_qubits - 1])
        self.circuit.mcx(list(range(self.params.num_qubits - 1)), self.qr[self.params.num_qubits - 1])
        self.circuit.h(self.qr[self.params.num_qubits - 1])
        for i in range(self.params.num_qubits):
            if not (marked_state >> i) & 1:
                self.circuit.x(self.qr[i])
        return self.circuit

    def build_w_state(self) -> QuantumCircuit:
        self.circuit.ry(np.arccos(1 / np.sqrt(self.params.num_qubits)), self.qr[0])
        for i in range(1, self.params.num_qubits):
            self.circuit.cx(self.qr[0], self.qr[i])
        for i in range(1, self.params.num_qubits - 1):
            angle = np.arccos(1 / np.sqrt(self.params.num_qubits - i))
            self.circuit.ry(angle, self.qr[i]).c_if(self.cr, 0)
        if self.params.measurement:
            self.circuit.measure(self.qr, self.cr)
        return self.circuit

    def append_circuit(self, other: QuantumCircuit) -> "QuantumCircuitBuilder":
        self.circuit.compose(other, inplace=True)
        return self

    def get_circuit(self) -> QuantumCircuit:
        return self.circuit

    def bind_parameters(self, param_dict: dict) -> QuantumCircuit:
        return self.circuit.assign_parameters(param_dict)

    def depth(self) -> int:
        return self.circuit.depth()

    def num_operations(self) -> int:
        return self.circuit.size()

    def num_parameters(self) -> int:
        return self.circuit.num_parameters

    def __repr__(self) -> str:
        return (
            f"QuantumCircuitBuilder(num_qubits={self.params.num_qubits}, "
            f"depth={self.depth()}, params={self.num_parameters()})"
        )
