'use client';

import { useState } from 'react';

interface Agent {
  id: string;
  name: string;
  description: string;
  status: 'active' | 'paused' | 'error';
  model: string;
  capabilities: string[];
  lastActive: string;
  tasksCompleted: number;
}

const agents: Agent[] = [
  {
    id: 'agent-001',
    name: 'Station Monitor',
    description: 'Monitors all ground stations for anomalies and performance degradation',
    status: 'active',
    model: 'gpt-4',
    capabilities: ['station-monitoring', 'anomaly-detection', 'alerting'],
    lastActive: 'Just now',
    tasksCompleted: 1423,
  },
  {
    id: 'agent-002',
    name: 'Signal Optimizer',
    description: 'Optimizes signal processing parameters in real-time',
    status: 'active',
    model: 'gpt-4',
    capabilities: ['signal-processing', 'parameter-tuning', 'noise-reduction'],
    lastActive: '2m ago',
    tasksCompleted: 891,
  },
  {
    id: 'agent-003',
    name: 'Scheduler',
    description: 'Intelligently schedules satellite passes across the network',
    status: 'active',
    model: 'gpt-3.5',
    capabilities: ['scheduling', 'conflict-resolution', 'optimization'],
    lastActive: '5m ago',
    tasksCompleted: 2456,
  },
  {
    id: 'agent-004',
    name: 'Quantum Analyst',
    description: 'Analyzes quantum circuit outputs and suggests optimizations',
    status: 'paused',
    model: 'claude-3',
    capabilities: ['quantum-analysis', 'circuit-optimization', 'error-mitigation'],
    lastActive: '1h ago',
    tasksCompleted: 567,
  },
  {
    id: 'agent-005',
    name: 'Chain Verifier',
    description: 'Verifies blockchain receipts and monitors on-chain activity',
    status: 'active',
    model: 'gpt-4',
    capabilities: ['blockchain', 'verification', 'monitoring'],
    lastActive: '30s ago',
    tasksCompleted: 3789,
  },
  {
    id: 'agent-006',
    name: 'Report Generator',
    description: 'Generates automated network performance reports',
    status: 'error',
    model: 'gpt-3.5',
    capabilities: ['reporting', 'analytics', 'visualization'],
    lastActive: '3h ago',
    tasksCompleted: 234,
  },
];

const statusConfig: Record<string, { color: string; bg: string }> = {
  active: { color: 'text-green-400', bg: 'bg-green-500/10' },
  paused: { color: 'text-yellow-400', bg: 'bg-yellow-500/10' },
  error: { color: 'text-red-400', bg: 'bg-red-500/10' },
};

export default function AgentsPage() {
  const [filter, setFilter] = useState<string>('all');

  const filtered = agents.filter((a) => filter === 'all' || a.status === filter);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">AI Agents</h1>
          <p className="text-surface-400 mt-1">
            Manage autonomous AI agents for network operations
          </p>
        </div>
        <button className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium text-sm transition-all">
          Deploy Agent
        </button>
      </div>

      <div className="glass rounded-xl p-4">
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="all">All Agents</option>
          <option value="active">Active</option>
          <option value="paused">Paused</option>
          <option value="error">Error</option>
        </select>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((agent) => {
          const cfg = statusConfig[agent.status];
          return (
            <div key={agent.id} className="glass rounded-xl p-5 glass-hover">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-white text-sm">
                  {agent.name}
                </h3>
                <span
                  className={`px-2 py-0.5 text-xs rounded-full ${cfg.bg} ${cfg.color}`}
                >
                  {agent.status.charAt(0).toUpperCase() + agent.status.slice(1)}
                </span>
              </div>
              <p className="text-xs text-surface-400 mb-3 leading-relaxed">
                {agent.description}
              </p>
              <div className="flex flex-wrap gap-1 mb-3">
                {agent.capabilities.map((cap) => (
                  <span
                    key={cap}
                    className="px-2 py-0.5 text-[10px] rounded-full bg-primary-500/10 text-primary-400"
                  >
                    {cap.replace(/-/g, ' ')}
                  </span>
                ))}
              </div>
              <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <span className="text-surface-500">Model:</span>
                  <span className="text-white font-mono">{agent.model}</span>
                </div>
                <div className="text-surface-500">
                  {agent.tasksCompleted} tasks
                </div>
              </div>
              <div className="mt-2 text-xs text-surface-500">
                Last active: {agent.lastActive}
              </div>
            </div>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-12 text-surface-500">
          No agents found.
        </div>
      )}
    </div>
  );
}
