// Surface code error correction for quantum memory
// OPENQASM 3.0 specification
// 5x5 surface code lattice (25 data qubits + 24 ancilla)
OPENQASM 3.0;
include "stdgates.inc";

// Surface code layout:
// Data qubits: even positions (0,2,4,...)
// Ancilla qubits: odd positions (1,3,5,...)
const int lattice_size = 5;
const int num_data = 13;
const int num_ancilla = 12;
const int total = num_data + num_ancilla;

qubit[total] q;
bit[total] c;

// Initialize data qubits in |0>
// Initialize ancilla qubits in |+>
for int i in [0:num_ancilla-1] {
    h q[2 * i + 1];
}
barrier q;

// Syndrome measurement round 1:
// X-stabilizers (plaquette): measure product of Z around each plaquette
// Z-stabilizers (vertex): measure product of X around each vertex
// Round 1: X-stabilizer measurements
// Plaquette at center (data qubits: 0,2,4,6 with ancilla 1,3,5,7)
cx q[0], q[1];
cx q[2], q[1];
cx q[4], q[3];
cx q[6], q[3];
cx q[0], q[5];
cx q[2], q[7];
cx q[4], q[5];
cx q[6], q[7];
barrier q;

// Measure ancilla qubits for X-stabilizers
measure q[1] -> c[1];
measure q[3] -> c[3];
measure q[5] -> c[5];
measure q[7] -> c[7];
barrier q;

// Reset ancilla qubits
for int i in [1, 3, 5, 7] {
    reset q[i];
}
barrier q;

// Initialize ancilla for Z-stabilizers
for int i in [1, 3, 5, 7] {
    h q[i];
}
barrier q;

// Round 2: Z-stabilizer measurements
// Vertex stabilizers: measure product of X around each vertex
h q[0];
h q[2];
h q[4];
h q[6];
cx q[0], q[1];
cx q[2], q[1];
cx q[4], q[3];
cx q[6], q[3];
cx q[0], q[5];
cx q[2], q[7];
cx q[4], q[5];
cx q[6], q[7];
h q[0];
h q[2];
h q[4];
h q[6];
barrier q;

// Measure ancilla qubits for Z-stabilizers
measure q[1] -> c[1];
measure q[3] -> c[3];
measure q[5] -> c[5];
measure q[7] -> c[7];
barrier q;

// Logical qubit readout: measure data qubits
for int i in [0, 2, 4, 6, 8] {
    measure q[i] -> c[i];
}
