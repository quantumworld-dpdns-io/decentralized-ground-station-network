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
    sampling: bool = False


class CudaqKernelBuilder:
    """Builder for creating CUDA-Q quantum kernels."""

    def __init__(self, params: Optional[KernelParams] = None):
        self.params = params or KernelParams()

    def _make_kernel_header(self, name: str = "kernel", args: str = "") -> str:
        return f"auto {name} = []({args}) __qpu__ {{"

    def _make_kernel_footer(self, name: str = "kernel") -> str:
        return "};"

    def kernel_source_qaoa(self, betas: list[float], gammas: list[float]) -> str:
        p = len(betas)
        n = self.params.num_qubits

        lines = [
            self._make_kernel_header("kernel", "std::vector<double> betas, std::vector<double> gammas"),
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
            if self.params.sampling:
                lines.append("  auto result = mz(q);")
            else:
                lines.append("  mz(q);")

        lines.append(self._make_kernel_footer())

        return "\n".join(lines)

    def kernel_source_vqe(self, thetas: list[float]) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel", "std::vector<double> thetas"),
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

        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_qft(self) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
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

        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_ghz(self) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n});",
            f"  h(q[0]);",
        ]

        for i in range(n - 1):
            lines.append(f"  x<cudaq::ctrl>(q[{i}], q[{i + 1}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_w_state(self) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n});",
        ]

        lines.append(f"  ry({2 * np.arccos(1 / np.sqrt(n))}, q[0]);")
        for i in range(1, n):
            lines.append(f"  x<cudaq::ctrl>(q[0], q[{i}]);")

        if self.params.measurement:
            lines.append("  mz(q);")

        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_bell_state(self) -> str:
        lines = [
            self._make_kernel_header("kernel"),
            "  cudaq::qvector q(2);",
            "  h(q[0]);",
            "  x<cudaq::ctrl>(q[0], q[1]);",
        ]
        if self.params.measurement:
            lines.append("  mz(q);")
        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_qpe(self, num_eval_qubits: int = 4) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n});",
        ]
        lines.append("  h(q[0]);")
        for i in range(1, min(num_eval_qubits + 1, n)):
            lines.append(f"  h(q[{i}]);")
        for i in range(min(num_eval_qubits, n - 1)):
            for _ in range(2**i):
                lines.append(f"  x<cudaq::ctrl>(q[{i + 1}], q[0]);")
        if self.params.measurement:
            lines.append("  mz(q);")
        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_grover(self, marked_state: int = 0) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n});",
        ]
        for i in range(n):
            lines.append(f"  h(q[{i}]);")
        for i in range(n):
            if not (marked_state >> i) & 1:
                lines.append(f"  x(q[{i}]);")
        lines.append(f"  h(q[{n - 1}]);")
        lines.append(f"  x<cudaq::ctrl>(q[{0}], q[{n - 1}]);")
        lines.append(f"  h(q[{n - 1}]);")
        for i in range(n):
            if not (marked_state >> i) & 1:
                lines.append(f"  x(q[{i}]);")
        for i in range(n):
            lines.append(f"  h(q[{i}]);")
        for i in range(n):
            lines.append(f"  x(q[{i}]);")
        lines.append(f"  x<cudaq::ctrl>(q[{0}], q[{n - 1}]);")
        for i in range(n):
            lines.append(f"  x(q[{i}]);")
        for i in range(n):
            lines.append(f"  h(q[{i}]);")
        if self.params.measurement:
            lines.append("  mz(q);")
        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_parametric(self, param_count: int = 8) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel", "std::vector<double> params"),
            f"  cudaq::qvector q({n});",
        ]
        for layer in range(self.params.num_layers):
            for i in range(n):
                idx = (layer * 2 * n + i) % max(param_count, 1)
                lines.append(f"  ry(params[{idx}], q[{i}]);")
            for i in range(n):
                idx = (layer * 2 * n + n + i) % max(param_count, 1)
                lines.append(f"  rz(params[{idx}], q[{i}]);")
            for i in range(n - 1):
                lines.append(f"  x<cudaq::ctrl>(q[{i}], q[{i + 1}]);")
        if self.params.measurement:
            lines.append("  mz(q);")
        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_amplitude_estimation(self, num_oracle_qubits: int = 3) -> str:
        n = self.params.num_qubits
        m = num_oracle_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n + m});",
        ]
        for i in range(m):
            lines.append(f"  h(q[{i}]);")
        for _ in range(n):
            lines.append(f"  ry({2 * np.arcsin(1 / np.sqrt(n))}, q[0]);")
        for i in range(m):
            ctrl_qubits = ", ".join(f"q[{m + j}]" for j in range(n))
            lines.append(f"  x<cudaq::ctrl>({{{ctrl_qubits}}}, q[{i}]);")
        if self.params.measurement:
            lines.append("  mz(q);")
        lines.append(self._make_kernel_footer())
        return "\n".join(lines)

    def kernel_source_sampling(self, num_samples: int = 1024) -> str:
        n = self.params.num_qubits
        lines = [
            self._make_kernel_header("kernel"),
            f"  cudaq::qvector q({n});",
        ]
        for i in range(n):
            lines.append(f"  h(q[{i}]);")
        for i in range(n - 1):
            lines.append(f"  x<cudaq::ctrl>(q[{i}], q[{i + 1}]);")
        lines.append(f"  auto result = mz(q);")
        lines.append(self._make_kernel_footer())
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
            "bell_state": self.kernel_source_bell_state(),
            "qpe": self.kernel_source_qpe(),
            "grover": self.kernel_source_grover(),
            "parametric": self.kernel_source_parametric(),
        }
