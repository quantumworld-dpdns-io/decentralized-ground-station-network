'use client';

import { useState } from 'react';

interface QuantumJob {
  id: string;
  circuitId: string;
  circuitName: string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  shots: number;
  qubits: number;
  submitted: string;
  duration: string;
  result?: string;
}

const jobs: QuantumJob[] = [
  { id: 'qj-001', circuitId: 'qc-001', circuitName: 'Grover\'s Search 3q', status: 'completed', shots: 1024, qubits: 3, submitted: '2024-01-15 14:30:00', duration: '2.3s', result: '|000⟩: 482, |111⟩: 370' },
  { id: 'qj-002', circuitId: 'qc-003', circuitName: 'Bell State Prep', status: 'running', shots: 4096, qubits: 2, submitted: '2024-01-15 14:32:15', duration: '...' },
  { id: 'qj-003', circuitId: 'qc-005', circuitName: 'Shor\'s 15', status: 'queued', shots: 8192, qubits: 8, submitted: '2024-01-15 14:28:45', duration: '-' },
  { id: 'qj-004', circuitId: 'qc-002', circuitName: 'QFT 4-Qubit', status: 'completed', shots: 2048, qubits: 4, submitted: '2024-01-15 14:15:00', duration: '1.8s', result: '|0000⟩: 128, |1111⟩: 96' },
  { id: 'qj-005', circuitId: 'qc-004', circuitName: 'Quantum Teleportation', status: 'failed', shots: 1024, qubits: 3, submitted: '2024-01-15 14:10:30', duration: '0.5s' },
  { id: 'qj-006', circuitId: 'qc-006', circuitName: 'VQE Ansatz', status: 'queued', shots: 10000, qubits: 4, submitted: '2024-01-15 14:05:00', duration: '-' },
];

const statusConfig: Record<string, { color: string; bg: string; icon: string }> = {
  queued: { color: 'text-surface-400', bg: 'bg-surface-800', icon: '○' },
  running: { color: 'text-blue-400', bg: 'bg-blue-500/10', icon: '◌' },
  completed: { color: 'text-green-400', bg: 'bg-green-500/10', icon: '✓' },
  failed: { color: 'text-red-400', bg: 'bg-red-500/10', icon: '✗' },
};

export default function QuantumJobsPage() {
  const [statusFilter, setStatusFilter] = useState<string>('all');

  const filtered = jobs.filter(
    (j) => statusFilter === 'all' || j.status === statusFilter,
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Quantum Jobs</h1>
          <p className="text-surface-400 mt-1">
            Monitor quantum circuit execution jobs
          </p>
        </div>
        <button className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium text-sm transition-all">
          New Job
        </button>
      </div>

      <div className="glass rounded-xl p-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="all">All Status</option>
          <option value="queued">Queued</option>
          <option value="running">Running</option>
          <option value="completed">Completed</option>
          <option value="failed">Failed</option>
        </select>
      </div>

      <div className="space-y-3">
        {filtered.map((job) => {
          const cfg = statusConfig[job.status];
          return (
            <div key={job.id} className="glass rounded-xl p-5 glass-hover">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <span
                    className={`w-6 h-6 rounded-full ${cfg.bg} ${cfg.color} flex items-center justify-center text-xs`}
                  >
                    {cfg.icon}
                  </span>
                  <div>
                    <div className="font-medium text-white text-sm">
                      {job.circuitName}
                    </div>
                    <div className="text-xs text-surface-500 font-mono">
                      {job.id} · {job.circuitId}
                    </div>
                  </div>
                </div>
                <span
                  className={`px-3 py-1 text-xs font-medium rounded-full ${cfg.bg} ${cfg.color}`}
                >
                  {job.status.charAt(0).toUpperCase() + job.status.slice(1)}
                </span>
              </div>

              <div className="flex gap-6 text-sm">
                <div>
                  <span className="text-surface-400">Shots:</span>{' '}
                  <span className="text-white font-mono">
                    {job.shots.toLocaleString()}
                  </span>
                </div>
                <div>
                  <span className="text-surface-400">Qubits:</span>{' '}
                  <span className="text-white font-mono">{job.qubits}</span>
                </div>
                <div>
                  <span className="text-surface-400">Submitted:</span>{' '}
                  <span className="text-surface-300">{job.submitted}</span>
                </div>
                <div>
                  <span className="text-surface-400">Duration:</span>{' '}
                  <span className="text-surface-300">{job.duration}</span>
                </div>
              </div>

              {job.result && (
                <div className="mt-3 text-xs text-surface-400 font-mono bg-surface-950 rounded-lg p-2">
                  {job.result}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-12 text-surface-500">No jobs found.</div>
      )}
    </div>
  );
}
