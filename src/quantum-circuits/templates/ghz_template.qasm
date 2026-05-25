// GHZ state preparation template for entanglement benchmarking
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// Parametric GHZ circuit
const int n = 8;  // Number of qubits
qubit[n] q;
bit[n] c;

// Step 1: Apply Hadamard to first qubit
h q[0];

// Step 2: Cascade CNOT gates to create entanglement
for int i in [0:n-2] {
    cx q[i], q[i + 1];
}

// Barrier for measurement separation
barrier q;

// Step 3: Measure all qubits in Z basis
for int i in [0:n-1] {
    measure q[i] -> c[i];
}
