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

interface CircuitDesignerProps {
  numQubits?: number;
  onCircuitChange?: (steps: CircuitStep[]) => void;
  readOnly?: boolean;
}

const GATE_PALETTE = [
  { id: 'h', label: 'H', color: '#6366f1' },
  { id: 'x', label: 'X', color: '#ef4444' },
  { id: 'y', label: 'Y', color: '#f97316' },
  { id: 'z', label: 'Z', color: '#22c55e' },
  { id: 's', label: 'S', color: '#14b8a6' },
  { id: 't', label: 'T', color: '#8b5cf6' },
  { id: 'cx', label: 'CX', color: '#6366f1' },
  { id: 'swap', label: 'SWAP', color: '#ec4899' },
  { id: 'rx', label: 'Rx', color: '#f97316' },
  { id: 'ry', label: 'Ry', color: '#22c55e' },
  { id: 'rz', label: 'Rz', color: '#3b82f6' },
  { id: 'measure', label: 'M', color: '#fef9c3' },
];

export function CircuitDesigner({
  numQubits: initialQubits = 3,
  onCircuitChange,
  readOnly = false,
}: CircuitDesignerProps) {
  const [numQubits] = useState(initialQubits);
  const [circuit, setCircuit] = useState<CircuitStep[]>([]);
  const [draggedGate, setDraggedGate] = useState<string | null>(null);

  const handleDrop = useCallback(
    (qubitIdx: number, stepIdx: number) => {
      if (!draggedGate || readOnly) return;
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
      onCircuitChange?.(circuit);
    },
    [draggedGate, numQubits, circuit, onCircuitChange, readOnly],
  );

  const removeGate = useCallback(
    (stepIdx: number, qubitIdx: number) => {
      if (readOnly) return;
      setCircuit((prev) => {
        const newCircuit = [...prev];
        if (newCircuit[stepIdx]) {
          newCircuit[stepIdx].gates[qubitIdx] = null;
        }
        onCircuitChange?.(newCircuit);
        return newCircuit;
      });
    },
    [onCircuitChange, readOnly],
  );

  const addStep = useCallback(() => {
    if (readOnly) return;
    setCircuit((prev) => {
      const next = [...prev, { gates: Array(numQubits).fill(null) }];
      onCircuitChange?.(next);
      return next;
    });
  }, [numQubits, onCircuitChange, readOnly]);

  const clearCircuit = useCallback(() => {
    if (readOnly) return;
    setCircuit([]);
    onCircuitChange?.([]);
  }, [onCircuitChange, readOnly]);

  const maxSteps = Math.max(circuit.length, 6);

  return (
    <div className="space-y-4">
      {!readOnly && (
        <div className="flex flex-wrap gap-2">
          {GATE_PALETTE.map((gate) => (
            <button
              key={gate.id}
              draggable
              onDragStart={() => setDraggedGate(gate.id)}
              className="w-10 h-10 rounded-lg bg-surface-800 border border-surface-700 hover:border-primary-500 text-white text-sm font-mono font-bold transition-all hover:bg-surface-700 flex items-center justify-center"
              title={gate.id}
            >
              {gate.label}
            </button>
          ))}
          <div className="flex-1" />
          <button
            onClick={clearCircuit}
            className="px-3 py-2 rounded-lg border border-surface-600 text-surface-300 hover:text-white text-xs transition-colors"
          >
            Clear
          </button>
          <button
            onClick={addStep}
            className="px-3 py-2 rounded-lg bg-primary-600 hover:bg-primary-500 text-white text-xs transition-colors"
          >
            + Step
          </button>
        </div>
      )}

      <div className="overflow-x-auto">
        <div className="min-w-[500px]">
          {Array.from({ length: numQubits }).map((_, qubitIdx) => (
            <div key={qubitIdx} className="flex items-center gap-1 mb-1">
              <div className="w-16 text-xs text-surface-400 font-mono shrink-0">
                q[{qubitIdx}]
              </div>
              {Array.from({ length: maxSteps }).map((_, stepIdx) => {
                const gate = circuit[stepIdx]?.gates[qubitIdx];
                return (
                  <div
                    key={stepIdx}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => handleDrop(qubitIdx, stepIdx)}
                    onClick={() => gate && removeGate(stepIdx, qubitIdx)}
                    className={`h-10 w-14 rounded border border-dashed flex items-center justify-center transition-all ${
                      gate
                        ? 'bg-primary-500/20 border-primary-500/40 text-primary-300 font-mono font-bold text-sm cursor-pointer'
                        : 'border-surface-700 hover:border-surface-500'
                    }`}
                  >
                    {gate?.type.toUpperCase() || ''}
                  </div>
                );
              })}
              {!readOnly && (
                <button
                  onClick={addStep}
                  className="h-10 w-8 rounded border border-dashed border-surface-700 text-surface-500 hover:text-surface-300 flex items-center justify-center text-lg"
                >
                  +
                </button>
              )}
            </div>
          ))}
        </div>
      </div>

      {circuit.length === 0 && !readOnly && (
        <div className="text-center py-8 text-surface-500 text-sm">
          Drag gates onto the circuit grid to build your circuit
        </div>
      )}
    </div>
  );
}

export type { Gate, CircuitStep };
