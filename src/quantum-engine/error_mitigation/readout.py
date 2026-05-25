"""Readout error mitigation with calibration matrices."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


@dataclass
class CalibrationMatrix:
    matrix: np.ndarray
    num_qubits: int

    def __post_init__(self):
        if self.matrix.shape != (2**self.num_qubits, 2**self.num_qubits):
            raise ValueError(f"Calibration matrix must be {2**self.num_qubits}x{2**self.num_qubits}")

    def apply_inverse(self, counts: dict[str, int], shots: int) -> dict[str, float]:
        n = self.num_qubits
        dim = 2**n
        noisy_vector = np.zeros(dim)
        for bitstring, count in counts.items():
            idx = int(bitstring, 2) if len(bitstring) <= n else int(bitstring[:n], 2)
            noisy_vector[idx] = count / shots

        try:
            calib_inv = np.linalg.inv(self.matrix)
            corrected = calib_inv @ noisy_vector
            corrected = np.clip(corrected, 0, 1)
            corrected /= corrected.sum()
        except np.linalg.LinAlgError:
            corrected = noisy_vector

        result = {}
        for i in range(dim):
            if corrected[i] > 1e-10:
                bitstring = format(i, f'0{n}b')
                result[bitstring] = corrected[i]
        return result


class ReadoutMitigation:
    def __init__(self, num_qubits: int):
        self.num_qubits = num_qubits
        self._calibration_matrix: Optional[CalibrationMatrix] = None

    def build_calibration_circuits(self) -> tuple:
        from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister
        n = self.num_qubits
        prep_circuits = []
        for state in range(2**n):
            qr = QuantumRegister(n, "q")
            cr = ClassicalRegister(n, "c")
            qc = QuantumCircuit(qr, cr)
            bitstring = format(state, f'0{n}b')
            for i, bit in enumerate(bitstring):
                if bit == "1":
                    qc.x(i)
            qc.measure(qr, cr)
            prep_circuits.append(qc)
        return prep_circuits

    def compute_calibration(self, results: list[dict[str, int]], shots: int) -> CalibrationMatrix:
        n = self.num_qubits
        dim = 2**n
        matrix = np.zeros((dim, dim), dtype=float)

        for prepared_state in range(dim):
            counts = results[prepared_state]
            total = sum(counts.values())
            for bitstring, count in counts.items():
                measured_state = int(bitstring, 2) if len(bitstring) <= n else int(bitstring[:n], 2)
                matrix[measured_state, prepared_state] = count / total

        for j in range(dim):
            col_sum = matrix[:, j].sum()
            if col_sum > 0:
                matrix[:, j] /= col_sum

        self._calibration_matrix = CalibrationMatrix(matrix, n)
        return self._calibration_matrix

    def mitigate(self, counts: dict[str, int], shots: int) -> dict[str, float]:
        if self._calibration_matrix is None:
            raise RuntimeError("Calibration matrix not computed. Call compute_calibration first.")
        return self._calibration_matrix.apply_inverse(counts, shots)

    def build_tensored_calibration(self, sub_calibrations: list[CalibrationMatrix]) -> CalibrationMatrix:
        total_qubits = sum(c.num_qubits for c in sub_calibrations)
        total_dim = 2**total_qubits
        full_matrix = np.eye(total_dim)

        row_offset = 0
        col_offset = 0
        for cal in sub_calibrations:
            dim = 2**cal.num_qubits
            full_matrix[
                row_offset : row_offset + dim,
                col_offset : col_offset + dim,
            ] = cal.matrix
            row_offset += dim
            col_offset += dim

        return CalibrationMatrix(full_matrix, total_qubits)

    def __repr__(self) -> str:
        return f"ReadoutMitigation(qubits={self.num_qubits}, calibrated={self._calibration_matrix is not None})"
