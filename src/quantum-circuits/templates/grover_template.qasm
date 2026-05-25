// Grover search template for database search
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// 4-qubit Grover search (search space of 16 items)
qubit[4] q;
qubit[1] aux;
bit[4] c;

// Oracle marking: marked state = |1010> (decimal 10)
int marked_state = 10;

// Initialize aux in |->
x aux[0];
h aux[0];

// Initialize data qubits in |+>
for int i in [0:3] {
    h q[i];
}

// Grover iteration (repeat ~2 times for 4 qubits)
for int iter in [0:1] {
    // Oracle: phase flip on marked state
    // Apply X on qubits that are 0 in marked state
    if ((marked_state >> 0) & 1) == 0 { x q[0]; }
    if ((marked_state >> 1) & 1) == 0 { x q[1]; }
    if ((marked_state >> 2) & 1) == 0 { x q[2]; }
    if ((marked_state >> 3) & 1) == 0 { x q[3]; }

    // Multi-controlled Toffoli for phase flip
    h q[3];
    ccx q[0], q[1], aux[0];
    ccx q[2], aux[0], q[3];
    ccx q[0], q[1], aux[0];
    h q[3];

    // Uncompute X gates
    if ((marked_state >> 0) & 1) == 0 { x q[0]; }
    if ((marked_state >> 1) & 1) == 0 { x q[1]; }
    if ((marked_state >> 2) & 1) == 0 { x q[2]; }
    if ((marked_state >> 3) & 1) == 0 { x q[3]; }
    barrier q;

    // Diffusion operator
    for int i in [0:3] {
        h q[i];
    }
    for int i in [0:3] {
        x q[i];
    }
    h q[3];
    ccx q[0], q[1], aux[0];
    ccx q[2], aux[0], q[3];
    ccx q[0], q[1], aux[0];
    h q[3];
    for int i in [0:3] {
        x q[i];
    }
    for int i in [0:3] {
        h q[i];
    }
    barrier q;
}

// Measure data qubits
for int i in [0:3] {
    measure q[i] -> c[i];
}
