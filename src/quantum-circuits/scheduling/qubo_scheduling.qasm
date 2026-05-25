// QUBO formulation circuit for ground station scheduling
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// QUBO scheduling: 3 stations, 4 time slots = 12 binary variables
qubit[12] q;
bit[12] c;

// QUBO Hamiltonian parameters (pre-computed)
input array[float64, 12] qubo_weights;
input array[float64, 12, 12] qubo_couplings;

// Initialize in equal superposition
for int i in [0:11] {
    h q[i];
}

// Apply QUBO phase separation
// Linear terms: exp(-i * gamma * w_i * Z_i)
for int i in [0:11] {
    rz(-2.0 * qubo_weights[i]) q[i];
}

// Quadratic terms: exp(-i * gamma * J_ij * Z_i * Z_j)
for int i in [0:10] {
    for int j in [i+1:11] {
        float64 coupling = qubo_couplings[i][j];
        if abs(coupling) > 1e-6 {
            rz(2.0 * coupling) q[i];
            cx q[i], q[j];
            rz(-2.0 * coupling) q[j];
            cx q[i], q[j];
        }
    }
}

// Mixer: uniform X rotations
float64 beta = 0.5;
for int i in [0:11] {
    rx(2.0 * beta) q[i];
}

// Measure
for int i in [0:11] {
    measure q[i] -> c[i];
}
