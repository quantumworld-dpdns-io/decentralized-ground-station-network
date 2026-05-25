// QFT circuit for signal frequency analysis
// OPENQASM 3.0 specification
OPENQASM 3.0;
include "stdgates.inc";

// 8 qubit QFT for signal processing
qubit[8] q;
bit[8] c;

// State preparation: encode signal amplitude into quantum state
input array[float64, 8] signal_amplitudes;

// Encode signal: Ry rotations proportional to amplitude
for int i in [0:7] {
    ry(2.0 * arcsin(sqrt(abs(signal_amplitudes[i]) / 2.0))) q[i];
}

// Quantum Fourier Transform
// Apply Hadamard and controlled phase rotations
h q[0];
for int j in [1:7] {
    float64 angle = pi / 2^(1);
    cp(angle) q[0], q[j];
}
barrier q;

h q[1];
for int j in [2:7] {
    float64 angle = pi / 2^(j - 1);
    cp(angle) q[1], q[j];
}
barrier q;

h q[2];
for int j in [3:7] {
    float64 angle = pi / 2^(j - 2);
    cp(angle) q[2], q[j];
}
barrier q;

h q[3];
for int j in [4:7] {
    float64 angle = pi / 2^(j - 3);
    cp(angle) q[3], q[j];
}
barrier q;

h q[4];
for int j in [5:7] {
    float64 angle = pi / 2^(j - 4);
    cp(angle) q[4], q[j];
}
barrier q;

h q[5];
for int j in [6:7] {
    float64 angle = pi / 2^(j - 5);
    cp(angle) q[5], q[j];
}
barrier q;

h q[6];
for int j in [7:7] {
    float64 angle = pi / 2^(j - 6);
    cp(angle) q[6], q[j];
}
barrier q;

h q[7];
barrier q;

// Swap qubits for correct output order
swap q[0], q[7];
swap q[1], q[6];
swap q[2], q[5];
swap q[3], q[4];

// Measure frequency bins
for int i in [0:7] {
    measure q[i] -> c[i];
}
