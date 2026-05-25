'use client';

import { useState } from 'react';
import Link from 'next/link';

interface Circuit {
  id: string;
  name: string;
  qubits: number;
  depth: number;
  gates: number;
  createdAt: string;
  lastRun: string;
  runs: number;
  tags: string[];
}

const circuits: Circuit[] = [
  { id: 'qc-001', name: 'Grover's Search 3q', qubits: 3, depth: 12, gates: 24, createdAt: '2024-01-14', lastRun: '2024-01-15 14:30', runs: 45, tags: ['search', 'algorithm'] },
  { id: 'qc-002', name: 'QFT 4-Qubit', qubits: 4, depth: 8, gates: 16, createdAt: '2024-01-13', lastRun: '2024-01-15 12:15', runs: 32, tags: ['fourier', 'transform'] },
  { id: 'qc-003', name: 'Bell State Prep', qubits: 2, depth: 3, gates: 4, createdAt: '2024-01-12', lastRun: '2024-01-15 10:00', runs: 128, tags: ['entanglement', 'basic'] },
  { id: 'qc-004', name: 'Quantum Teleportation', qubits: 3, depth: 7, gates: 12, createdAt: '2024-01-11', lastRun: '2024-01-14 22:45', runs: 67, tags: ['teleportation', 'protocol'] },
  { id: 'qc-005', name: 'Shor's 15', qubits: 8, depth: 42, gates: 156, createdAt: '2024-01-10', lastRun: '2024-01-14 18:30', runs: 12, tags: ['factorization', 'shor'] },
  { id: 'qc-006', name: 'VQE Ansatz', qubits: 4, depth: 15, gates: 38, createdAt: '2024-01-09', lastRun: '2024-01-14 15:00', runs: 89, tags: ['vqe', 'variational'] },
];

export default function CircuitsPage() {
  const [search, setSearch] = useState('');
  const [tagFilter, setTagFilter] = useState('all');

  const allTags = Array.from(new Set(circuits.flatMap((c) => c.tags)));

  const filtered = circuits.filter((c) => {
    const matchSearch =
      c.name.toLowerCase().includes(search.toLowerCase()) ||
      c.id.toLowerCase().includes(search.toLowerCase());
    const matchTag = tagFilter === 'all' || c.tags.includes(tagFilter);
    return matchSearch && matchTag;
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Circuit Library</h1>
          <p className="text-surface-400 mt-1">
            Browse and manage quantum circuits
          </p>
        </div>
        <Link
          href="/dashboard/quantum"
          className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium text-sm transition-all"
        >
          New Circuit
        </Link>
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search circuits..."
              className="w-full px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all text-sm"
            />
          </div>
          <select
            value={tagFilter}
            onChange={(e) => setTagFilter(e.target.value)}
            className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Tags</option>
            {allTags.map((tag) => (
              <option key={tag} value={tag}>
                {tag.charAt(0).toUpperCase() + tag.slice(1)}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((circuit) => (
          <Link
            key={circuit.id}
            href={`/dashboard/quantum/circuits/${circuit.id}`}
            className="glass rounded-xl p-5 glass-hover block"
          >
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-semibold text-white text-sm">
                {circuit.name}
              </h3>
              <div className="text-xs text-surface-500 font-mono">
                {circuit.id}
              </div>
            </div>
            <div className="flex gap-4 mb-3">
              <div>
                <div className="text-xs text-surface-400">Qubits</div>
                <div className="text-sm text-white font-mono">
                  {circuit.qubits}
                </div>
              </div>
              <div>
                <div className="text-xs text-surface-400">Depth</div>
                <div className="text-sm text-white font-mono">
                  {circuit.depth}
                </div>
              </div>
              <div>
                <div className="text-xs text-surface-400">Gates</div>
                <div className="text-sm text-white font-mono">
                  {circuit.gates}
                </div>
              </div>
              <div>
                <div className="text-xs text-surface-400">Runs</div>
                <div className="text-sm text-white font-mono">
                  {circuit.runs}
                </div>
              </div>
            </div>
            <div className="flex flex-wrap gap-1">
              {circuit.tags.map((tag) => (
                <span
                  key={tag}
                  className="px-2 py-0.5 text-[10px] rounded-full bg-quantum-500/10 text-quantum-400"
                >
                  {tag}
                </span>
              ))}
            </div>
            <div className="mt-3 text-xs text-surface-500">
              Last run: {circuit.lastRun}
            </div>
          </Link>
        ))}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-12 text-surface-500">
          No circuits found.
        </div>
      )}
    </div>
  );
}
