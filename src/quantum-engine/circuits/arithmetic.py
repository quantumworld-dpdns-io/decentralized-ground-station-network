"""Quantum adders, comparators for scheduling."""

from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister


class QuantumAdder:
    def __init__(self, num_qubits: int = 4):
        self.num_qubits = num_qubits
        self.total_qubits = 3 * num_qubits + 1

    def build_ripple_carry_adder(self) -> QuantumCircuit:
        n = self.num_qubits
        qr_a = QuantumRegister(n, "a")
        qr_b = QuantumRegister(n, "b")
        qr_cin = QuantumRegister(1, "cin")
        qr_cout = QuantumRegister(1, "cout")
        cr = ClassicalRegister(n + 1, "c")
        qr = QuantumRegister(3 * n + 2, "q")
        all_qr = [qr_a, qr_b, qr_cin, qr_cout]
        qc = QuantumCircuit(qr, cr)

        for i in range(n):
            if i == 0:
                qc.ccx(qr_a[i], qr_b[i], qr_cout[0])
                qc.cx(qr_a[i], qr_b[i])
                qc.cx(qr_cin[0], qr_b[i])
            else:
                qc.ccx(qr_a[i], qr_b[i], qr_cout[0])
                qc.cx(qr_a[i], qr_b[i])
                qc.cx(qr_cin[0], qr_b[i])
                qc.ccx(qr_b[i], qr_cout[0], qr_cin[0])

        for i in range(n):
            qc.measure(qr_b[i], cr[i])
        qc.measure(qr_cout[0], cr[n])

        return qc

    def build_adder_with_constants(
        self, constant_a: int, constant_b: int
    ) -> QuantumCircuit:
        n = self.num_qubits
        qr = QuantumRegister(n + 1, "q")
        cr = ClassicalRegister(n + 1, "c")
        qc = QuantumCircuit(qr, cr)

        a_bits = [(constant_a >> i) & 1 for i in range(n)]
        b_bits = [(constant_b >> i) & 1 for i in range(n)]

        cin = 0
        for i in range(n):
            sum_bit = a_bits[i] ^ b_bits[i] ^ cin
            cin = (a_bits[i] & b_bits[i]) | (cin & (a_bits[i] ^ b_bits[i]))
            if sum_bit:
                qc.x(qr[i])
            if cin:
                pass
            qc.cx(qr[0], qr[i])

        qc.measure(qr[:n], cr[:n])
        qc.measure(qr[n], cr[n])

        return qc

    def __repr__(self) -> str:
        return f"QuantumAdder(qubits={self.num_qubits})"


class QuantumComparator:
    def __init__(self, num_qubits: int = 4):
        self.num_qubits = num_qubits

    def build_equality_comparator(self) -> QuantumCircuit:
        n = self.num_qubits
        qr_a = QuantumRegister(n, "a")
        qr_b = QuantumRegister(n, "b")
        qr_out = QuantumRegister(1, "out")
        cr = ClassicalRegister(1, "c")
        qc = QuantumCircuit(qr_a, qr_b, qr_out, cr)

        for i in range(n):
            qc.cx(qr_a[i], qr_b[i])
            qc.x(qr_b[i])

        qc.mcx(list(range(n)), qr_out[0])

        for i in range(n - 1, -1, -1):
            qc.x(qr_b[i])
            qc.cx(qr_a[i], qr_b[i])

        qc.measure(qr_out[0], cr[0])
        return qc

    def build_greater_than_comparator(self) -> QuantumCircuit:
        n = self.num_qubits
        qr = QuantumRegister(2 * n + 2, "q")
        cr = ClassicalRegister(2, "c")
        qc = QuantumCircuit(qr, cr)

        a_bits = list(range(n))
        b_bits = list(range(n, 2 * n))
        anc = 2 * n
        gt_out = 2 * n + 1

        qc.x(qr[gt_out])
        for i in range(n):
            qc.x(qr[b_bits[i]])

        for i in range(n):
            qc.cx(qr[a_bits[i]], qr[b_bits[i]])
            qc.x(qr[b_bits[i]])

        qc.x(qr[anc])
        for i in range(n):
            qc.ccx(qr[a_bits[i]], qr[b_bits[i]], qr[anc])
        qc.cx(qr[anc], qr[gt_out])

        qc.measure(qr[gt_out], cr[0])
        return qc

    def build_less_than_constant(self, constant: int) -> QuantumCircuit:
        n = self.num_qubits
        qr = QuantumRegister(n + 1, "q")
        cr = ClassicalRegister(1, "c")
        qc = QuantumCircuit(qr, cr)

        const_bits = [(constant >> i) & 1 for i in range(n)]
        data = list(range(n))
        out = n

        for i in range(n):
            if const_bits[i]:
                qc.x(qr[data[i]])

        qc.mcx(data, qr[out])

        for i in range(n - 1, -1, -1):
            if const_bits[i]:
                qc.x(qr[data[i]])

        qc.measure(qr[out], cr[0])
        return qc

    def __repr__(self) -> str:
        return f"QuantumComparator(qubits={self.num_qubits})"
