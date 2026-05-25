// VQE circuit for resource allocation optimization
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// 6 resources x 4 nodes = 24 qubits for allocation optimization
qubit[24] q;
bit[24] c;

// VQE parameters: 2 layers of Ry-Rz rotations
// Each layer has 48 parameters (24 Ry + 24 Rz)
const int num_layers = 2;
input array[float64, 96] thetas;
const int num_qubits = 24;

// Layer 1
for int i in [0:23] {
    ry(thetas[i]) q[i];
}
for int i in [0:23] {
    rz(thetas[i + 24]) q[i];
}

// Entangling layer 1: linear CNOT chain
for int i in [0:22] {
    cx q[i], q[i + 1];
}

// Layer 2
for int i in [0:23] {
    ry(thetas[i + 48]) q[i];
}
for int i in [0:23] {
    rz(thetas[i + 72]) q[i];
}

// Entangling layer 2
for int i in [0:22] {
    cx q[i], q[i + 1];
}

// Measure all qubits
for int i in [0:23] {
    measure q[i] -> c[i];
}
