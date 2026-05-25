'use client';

import { useState, useCallback } from 'react';

interface Gate {
  id: string;
  type: string;
  qubits: number[];
  params?: Record<string, number>;
}

interface CircuitStep {
  gates: (Gate | null)[];
}

export default function QuantumDashboardPage() {
  const [circuit, setCircuit] = useState<CircuitStep[]>([]);
  const [numQubits, setNumQubits] = useState(3);
  const [draggedGate, setDraggedGate] = useState<string | null>(null);
  const [circuitName, setCircuitName] = useState('Untitled Circuit');
  const [saving, setSaving] = useState(false);

  const availableGates = [
    { id: 'h', label: 'H', description: 'Hadamard' },
    { id: 'x', label: 'X', description: 'Pauli-X' },
    { id: 'y', label: 'Y', description: 'Pauli-Y' },
    { id: 'z', label: 'Z', description: 'Pauli-Z' },
    { id: 's', label: 'S', description: 'Phase' },
    { id: 't', label: 'T', description: 'T Gate' },
    { id: 'cx', label: 'CX', description: 'CNOT' },
    { id: 'cz', label: 'CZ', description: 'CZ Gate' },
    { id: 'swap', label: 'SWAP', description: 'Swap' },
    { id: 'rx', label: 'Rx', description: 'Rotation X' },
    { id: 'ry', label: 'Ry', description: 'Rotation Y' },
    { id: 'rz', label: 'Rz', description: 'Rotation Z' },
    { id: 'measure', label: 'M', description: 'Measure' },
    { id: 'reset', label: 'RST', description: 'Reset' },
    { id: 'barrier', label: '▮', description: 'Barrier' },
  ];

  const handleDrop = useCallback(
    (qubitIdx: number, stepIdx: number) => {
      if (!draggedGate) return;
      setCircuit((prev) => {
        const newCircuit = [...prev];
        if (!newCircuit[stepIdx]) {
          newCircuit[stepIdx] = { gates: Array(numQubits).fill(null) };
        }
        const gate: Gate = {
          id: `${draggedGate}-${Date.now()}`,
          type: draggedGate,
          qubits: [qubitIdx],
        };
        newCircuit[stepIdx].gates[qubitIdx] = gate;
        return newCircuit;
      });
    },
    [draggedGate, numQubits],
  );

  const removeGate = (stepIdx: number, qubitIdx: number) => {
    setCircuit((prev) => {
      const newCircuit = [...prev];
      if (newCircuit[stepIdx]) {
        newCircuit[stepIdx].gates[qubitIdx] = null;
      }
      return newCircuit;
    });
  };

  const addStep = () => {
    setCircuit((prev) => [
      ...prev,
      { gates: Array(numQubits).fill(null) },
    ]);
  };

  const clearCircuit = () => {
    setCircuit([]);
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await fetch('/api/v1/quantum/circuits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: circuitName,
          numQubits,
          steps: circuit.map((step) =>
            step.gates.map((g) => (g ? { type: g.type, qubits: g.qubits } : null)),
          ),
        }),
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Quantum Computing</h1>
          <p className="text-surface-400 mt-1">
            Design and execute quantum circuits
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={clearCircuit}
            className="px-4 py-2 rounded-lg border border-surface-600 text-surface-300 hover:text-white text-sm transition-colors"
          >
            Clear
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium text-sm transition-all disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save Circuit'}
          </button>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <div className="flex items-center gap-4 mb-6">
          <input
            type="text"
            value={circuitName}
            onChange={(e) => setCircuitName(e.target.value)}
            className="px-3 py-1.5 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
          <div className="flex items-center gap-2">
            <span className="text-sm text-surface-400">Qubits:</span>
            <button
              onClick={() => setNumQubits((n) => Math.max(1, n - 1))}
              className="w-7 h-7 rounded bg-surface-800 text-surface-300 hover:text-white flex items-center justify-center text-sm"
            >
              -
            </button>
            <span className="text-white font-mono w-6 text-center">
              {numQubits}
            </span>
            <button
              onClick={() => setNumQubits((n) => Math.min(10, n + 1))}
              className="w-7 h-7 rounded bg-surface-800 text-surface-300 hover:text-white flex items-center justify-center text-sm"
            >
              +
            </button>
          </div>
        </div>

        <div className="flex gap-6">
          <div className="w-48 shrink-0">
            <h4 className="text-sm font-medium text-surface-400 mb-3">
              Gate Palette
            </h4>
            <div className="grid grid-cols-3 gap-2">
              {availableGates.map((gate) => (
                <button
                  key={gate.id}
                  draggable
                  onDragStart={() => setDraggedGate(gate.id)}
                  className="h-10 rounded-lg bg-surface-800 border border-surface-700 hover:border-primary-500 text-white text-sm font-mono font-bold transition-all hover:bg-surface-700"
                  title={gate.description}
                >
                  {gate.label}
                </button>
              ))}
            </div>

            <h4 className="text-sm font-medium text-surface-400 mt-6 mb-2">
              Instructions
            </h4>
            <p className="text-xs text-surface-500 leading-relaxed">
              Drag gates onto the circuit canvas. Click a placed gate to remove
              it. Add columns to build complex circuits.
            </p>
          </div>

          <div className="flex-1 overflow-x-auto">
            <div className="min-w-[400px]">
              <div className="grid grid-cols-[80px_repeat(8,60px)] gap-1">
                <div className="text-xs text-surface-500" />
                {Array.from({ length: Math.max(circuit.length, 8) }).map((_, i) => (
                  <div
                    key={i}
                    className="text-xs text-surface-500 text-center py-2"
                  >
                    {i + 1}
                  </div>
                ))}
              </div>

              {Array.from({ length: numQubits }).map((_, qubitIdx) => (
                <div
                  key={qubitIdx}
                  className="grid grid-cols-[80px_repeat(8,60px)] gap-1 items-center"
                >
                  <div className="text-xs text-surface-400 font-mono flex items-center gap-2">
                    <div
                      className={`w-2 h-2 rounded-full ${
                        qubitIdx === 0 ? 'bg-primary-500' : 'bg-surface-500'
                      }`}
                    />
                    q[{qubitIdx}]
                  </div>
                  {Array.from({ length: Math.max(circuit.length, 8) }).map(
                    (_, stepIdx) => {
                      const gate = circuit[stepIdx]?.gates[qubitIdx];
                      return (
                        <div
                          key={stepIdx}
                          onDragOver={(e) => e.preventDefault()}
                          onDrop={() => handleDrop(qubitIdx, stepIdx)}
                          onClick={() =>
                            gate && removeGate(stepIdx, qubitIdx)
                          }
                          className={`h-10 rounded border border-dashed flex items-center justify-center cursor-pointer transition-all ${
                            gate
                              ? 'bg-primary-500/20 border-primary-500/40 text-primary-300 font-mono font-bold text-sm'
                              : 'border-surface-700 hover:border-surface-500'
                          }`}
                        >
                          {gate?.type.toUpperCase() || ''}
                        </div>
                      );
                    },
                  )}
                  <button
                    onClick={addStep}
                    className="h-10 w-10 rounded border border-dashed border-surface-700 text-surface-500 hover:text-surface-300 flex items-center justify-center text-lg"
                  >
                    +
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">847</div>
          <div className="text-sm text-surface-400">Circuits Created</div>
        </div>
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">12,453</div>
          <div className="text-sm text-surface-400">Jobs Executed</div>
        </div>
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">99.2%</div>
          <div className="text-sm text-surface-400">Fidelity Avg</div>
        </div>
      </div>
    </div>
  );
}
