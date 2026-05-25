"""CUDA-Q kernel definition helper for GPU-accelerated quantum circuits."""

from dataclasses import dataclass, field
from typing import Optional, Callable
from enum import Enum

import numpy as np


class EntanglementStrategy(Enum):
    LINEAR = "linear"
    CIRCULAR = "circular"
    FULL = "full"


@dataclass
class KernelParams:
    num_qubits: int = 4
    num_layers: int = 1
    entanglement: EntanglementStrategy = EntanglementStrategy.LINEAR
    measurement: bool = True
    cudaq_target: str = "nvidia"


class CudaqKernelBuilder:
    """Builder for creating CUDA-Q quantum kernels."""

    def __init__(self, params: Optional[KernelParams] = None):
        self.params = params or KernelParams()

    def kernel_source_qaoa(self, betas: list[float], gammas: list[float]) -> str:
        p = len(betas)
        n = self.params.num_qubits

        lines = [
            f"auto kernel = [](std::vector<double> betas, std::vector<double> gammas) __qpu__ {{",
            f"  cudaq::qvector q({n});",
        ]

        for i in range(n):
            lines.append(f"  h(q[{i}]);")

        for layer in range(p):
            beta = betas[layer]
            gamma = gammas[layer]
            for i in range(n - 1):
                lines.append(f"  exp_pauli({2 * gamma}, q, \"ZZ\", q[{i}], q[{i + 1}]);")
            for i in range(n):
                lines.append(f"  rx({2 * beta}, q[{i}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append("};")

        return "\n".join(lines)

    def kernel_source_vqe(self, thetas: list[float]) -> str:
        n = self.params.num_qubits
        lines = [
            f"auto kernel = [](std::vector<double> thetas) __qpu__ {{",
            f"  cudaq::qvector q({n});",
        ]

        idx = 0
        for layer in range(self.params.num_layers):
            for i in range(n):
                lines.append(f"  ry(thetas[{idx}], q[{i}]);")
                idx += 1
            for i in range(n):
                lines.append(f"  rz(thetas[{idx}], q[{i}]);")
                idx += 1
            if layer < self.params.num_layers - 1:
                for i in range(n - 1):
                    lines.append(f"  x<cudaq::ctrl>(q[{i}], q[{i + 1}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append("};")
        return "\n".join(lines)

    def kernel_source_qft(self) -> str:
        n = self.params.num_qubits
        lines = [
            f"auto kernel = []() __qpu__ {{",
            f"  cudaq::qvector q({n});",
        ]

        for i in range(n):
            lines.append(f"  h(q[{i}]);")
            for j in range(i + 1, n):
                angle = np.pi / (2 ** (j - i))
                lines.append(f"  r1({angle}, q[{j}], q[{i}]);")

        for i in range(n // 2):
            lines.append(f"  swap(q[{i}], q[{n - i - 1}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append("};")
        return "\n".join(lines)

    def kernel_source_ghz(self) -> str:
        n = self.params.num_qubits
        lines = [
            f"auto kernel = []() __qpu__ {{",
            f"  cudaq::qvector q({n});",
            f"  h(q[0]);",
        ]

        for i in range(n - 1):
            lines.append(f"  x<cudaq::ctrl>(q[{i}], q[{i + 1}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append("};")
        return "\n".join(lines)

    def kernel_source_w_state(self) -> str:
        n = self.params.num_qubits
        lines = [
            f"auto kernel = []() __qpu__ {{",
            f"  cudaq::qvector q({n});",
        ]

        lines.append(f"  ry({2 * np.arccos(1 / np.sqrt(n))}, q[0]);")
        for i in range(1, n):
            lines.append(f"  x<cudaq::ctrl>(q[0], q[{i}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append("};")
        return "\n".join(lines)

    def create_circuit_from_source(self, source: str, target: Optional[str] = None):
        target = target or self.params.cudaq_target
        return source

    def generate_all_kernels(self, betas: list[float], gammas: list[float], thetas: list[float]) -> dict[str, str]:
        return {
            "qaoa": self.kernel_source_qaoa(betas, gammas),
            "vqe": self.kernel_source_vqe(thetas),
            "qft": self.kernel_source_qft(),
            "ghz": self.kernel_source_ghz(),
            "w_state": self.kernel_source_w_state(),
        }
