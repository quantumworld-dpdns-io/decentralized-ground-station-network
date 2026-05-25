// QAOA circuit for ground station scheduling optimization
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// Problem: 4 stations x 6 time slots = 24 qubits
// Each qubit encodes assignment of station i to time slot j
qubit[24] q;
bit[24] c;

// Define problem parameters
const int stations = 4;
const int slots = 6;
const int p = 2;  // QAOA depth

// QAOA parameters for p=2
input array[float64, 2] betas;
input array[float64, 2] gammas;

// Initialize superposition
for int i in [0:23] {
    h q[i];
}

// QAOA layer 1
// Cost Hamiltonian: -gamma1 * sum(sigma_z_i) + gamma1 * sum(sigma_z_i * sigma_z_j) for conflicts
for int i in [0:23] {
    rz(-2.0 * gammas[0]) q[i];
}

// Conflict terms: station i and station j cannot be assigned same slot
// Conflicts: station 0<->1, 0<->2, 2<->3
// For each conflicting pair, add RZZ gate for each time slot
for int t in [0:5] {
    // Station 0 vs Station 1 conflict at slot t
    rz(4.0 * gammas[0]) q[t];
    cx q[t], q[t + 6];
    rz(-4.0 * gammas[0]) q[t + 6];
    cx q[t], q[t + 6];

    // Station 0 vs Station 2 conflict at slot t
    rz(4.0 * gammas[0]) q[t];
    cx q[t], q[t + 12];
    rz(-4.0 * gammas[0]) q[t + 12];
    cx q[t], q[t + 12];

    // Station 2 vs Station 3 conflict at slot t
    rz(4.0 * gammas[0]) q[t + 12];
    cx q[t + 12], q[t + 18];
    rz(-4.0 * gammas[0]) q[t + 18];
    cx q[t + 12], q[t + 18];
}

// Mixer Hamiltonian: sum(sigma_x_i)
for int i in [0:23] {
    rx(2.0 * betas[0]) q[i];
}

// QAOA layer 2
for int i in [0:23] {
    rz(-2.0 * gammas[1]) q[i];
}

// Same conflict terms for layer 2
for int t in [0:5] {
    rz(4.0 * gammas[1]) q[t];
    cx q[t], q[t + 6];
    rz(-4.0 * gammas[1]) q[t + 6];
    cx q[t], q[t + 6];

    rz(4.0 * gammas[1]) q[t];
    cx q[t], q[t + 12];
    rz(-4.0 * gammas[1]) q[t + 12];
    cx q[t], q[t + 12];

    rz(4.0 * gammas[1]) q[t + 12];
    cx q[t + 12], q[t + 18];
    rz(-4.0 * gammas[1]) q[t + 18];
    cx q[t + 12], q[t + 18];
}

for int i in [0:23] {
    rx(2.0 * betas[1]) q[i];
}

// Measure all qubits
for int i in [0:23] {
    measure q[i] -> c[i];
}
