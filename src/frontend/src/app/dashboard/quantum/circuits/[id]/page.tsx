'use client';

import { useState } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

const histData = [
  { state: '|000⟩', count: 482 },
  { state: '|001⟩', count: 51 },
  { state: '|010⟩', count: 23 },
  { state: '|011⟩', count: 15 },
  { state: '|100⟩', count: 28 },
  { state: '|101⟩', count: 12 },
  { state: '|110⟩', count: 19 },
  { state: '|111⟩', count: 370 },
];

const circuitGates = [
  { step: 1, gate: 'H', qubit: 0 },
  { step: 2, gate: 'H', qubit: 1 },
  { step: 2, gate: 'H', qubit: 2 },
  { step: 3, gate: 'CX', qubit: 0, target: 1 },
  { step: 4, gate: 'CX', qubit: 1, target: 2 },
  { step: 5, gate: 'M', qubit: 0 },
  { step: 5, gate: 'M', qubit: 1 },
  { step: 5, gate: 'M', qubit: 2 },
];

export default function CircuitDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const circuitName =
    params.id === 'qc-001'
      ? "Grover's Search 3q"
      : params.id === 'qc-002'
        ? 'QFT 4-Qubit'
        : `Circuit ${params.id}`;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{circuitName}</h1>
          <p className="text-surface-400 mt-1 font-mono text-sm">
            {params.id}
          </p>
        </div>
        <div className="flex gap-2">
          <button className="px-4 py-2 rounded-lg bg-surface-800 text-surface-300 hover:text-white text-sm transition-colors">
            Edit
          </button>
          <button className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium text-sm transition-all">
            Execute
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Qubits', value: '3' },
          { label: 'Depth', value: '5' },
          { label: 'Total Gates', value: '8' },
          { label: 'Executions', value: '1,000' },
        ].map((stat) => (
          <div key={stat.label} className="glass rounded-xl p-4">
            <div className="text-sm text-surface-400 mb-1">{stat.label}</div>
            <div className="text-2xl font-bold text-white">{stat.value}</div>
          </div>
        ))}
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">
          Circuit Diagram
        </h3>
        <div className="overflow-x-auto">
          <div className="min-w-[600px]">
            <div className="grid grid-cols-[60px_repeat(5,80px)] gap-1">
              <div className="text-xs text-surface-500" />
              {[1, 2, 3, 4, 5].map((s) => (
                <div key={s} className="text-xs text-surface-500 text-center py-2">
                  {s}
                </div>
              ))}

              {[0, 1, 2].map((q) => (
                <div key={q} className="contents">
                  <div className="text-xs text-surface-400 font-mono py-2">
                    q[{q}]
                  </div>
                  {[1, 2, 3, 4, 5].map((s) => {
                    const g = circuitGates.find(
                      (g) => g.step === s && g.qubit === q,
                    );
                    const isTarget = circuitGates.find(
                      (g) => g.step === s && g.target === q,
                    );
                    return (
                      <div
                        key={s}
                        className="h-10 flex items-center justify-center"
                      >
                        {g && (
                          <div className="w-8 h-8 rounded bg-primary-500/20 border border-primary-500/40 flex items-center justify-center text-xs font-mono text-primary-300 font-bold">
                            {g.gate}
                          </div>
                        )}
                        {isTarget && !g && (
                          <div className="w-3 h-3 rounded-full bg-quantum-500/40 border border-quantum-500/60" />
                        )}
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">
          Measurement Results
        </h3>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={histData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis dataKey="state" stroke="#64748b" fontSize={12} />
            <YAxis stroke="#64748b" fontSize={12} />
            <Tooltip
              contentStyle={{
                background: '#1e293b',
                border: '1px solid #334155',
                borderRadius: '8px',
              }}
            />
            <Bar dataKey="count" fill="#6366f1" radius={[4, 4, 0, 0]}>
              {histData.map((entry, index) => (
                <rect key={index} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">
          OpenQASM 3.0
        </h3>
        <pre className="bg-surface-950 rounded-lg p-4 text-sm text-surface-300 font-mono overflow-x-auto">
          <code>{`OPENQASM 3.0;
include "stdgates.inc";

qubit[3] q;
bit[3] c;

h q[0];
h q[1];
h q[2];
cx q[0], q[1];
cx q[1], q[2];
c[0] = measure q[0];
c[1] = measure q[1];
c[2] = measure q[2];`}</code>
        </pre>
      </div>
    </div>
  );
}
