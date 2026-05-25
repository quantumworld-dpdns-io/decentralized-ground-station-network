'use client';

import { useState } from 'react';
import Link from 'next/link';

interface Receipt {
  id: string;
  blockNumber: number;
  stationId: string;
  stationName: string;
  satellite: string;
  timestamp: string;
  frequency: string;
  dataSize: string;
  status: 'verified' | 'pending' | 'failed';
  txHash: string;
}

const receipts: Receipt[] = [
  { id: '0x7a3f...b9e2', blockNumber: 18457234, stationId: 'st-001', stationName: 'Station Alpha', satellite: 'NOAA-19', timestamp: '2024-01-15 14:32:15', frequency: '137.100 MHz', dataSize: '2.4 MB', status: 'verified', txHash: '0x8f3c...a1b2' },
  { id: '0x4c8e...f1a7', blockNumber: 18457198, stationId: 'st-002', stationName: 'Station Beta', satellite: 'ISS', timestamp: '2024-01-15 14:28:00', frequency: '145.800 MHz', dataSize: '1.8 MB', status: 'pending', txHash: '' },
  { id: '0x9b2d...e4c1', blockNumber: 18457165, stationId: 'st-003', stationName: 'Station Gamma', satellite: 'GOES-16', timestamp: '2024-01-15 14:22:45', frequency: '1694.100 MHz', dataSize: '5.2 MB', status: 'verified', txHash: '0x2a7e...c3d4' },
  { id: '0x3f6a...d8b4', blockNumber: 18457132, stationId: 'st-004', stationName: 'Station Delta', satellite: 'Fengyun-3', timestamp: '2024-01-15 14:15:30', frequency: '137.950 MHz', dataSize: '3.1 MB', status: 'failed', txHash: '' },
  { id: '0xe5c2...a7f9', blockNumber: 18457101, stationId: 'st-001', stationName: 'Station Alpha', satellite: 'Meteor-M2', timestamp: '2024-01-15 14:08:20', frequency: '137.900 MHz', dataSize: '4.7 MB', status: 'verified', txHash: '0x5b6d...e8f0' },
  { id: '0x1d8a...b3e6', blockNumber: 18457078, stationId: 'st-005', stationName: 'Station Epsilon', satellite: 'NOAA-18', timestamp: '2024-01-15 14:02:10', frequency: '137.9125 MHz', dataSize: '2.1 MB', status: 'pending', txHash: '' },
];

const statusConfig: Record<string, { color: string; bg: string; label: string }> = {
  verified: { color: 'text-green-400', bg: 'bg-green-500/10', label: 'Verified' },
  pending: { color: 'text-yellow-400', bg: 'bg-yellow-500/10', label: 'Pending' },
  failed: { color: 'text-red-400', bg: 'bg-red-500/10', label: 'Failed' },
};

export default function ReceiptsPage() {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  const filteredReceipts = receipts.filter((r) => {
    const matchSearch = r.id.toLowerCase().includes(search.toLowerCase()) ||
      r.satellite.toLowerCase().includes(search.toLowerCase()) ||
      r.stationName.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'all' || r.status === statusFilter;
    return matchSearch && matchStatus;
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Receipts</h1>
        <p className="text-surface-400 mt-1">
          Blockchain-verified data transmission receipts
        </p>
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by ID, satellite, or station..."
              className="w-full px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all text-sm"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Status</option>
            <option value="verified">Verified</option>
            <option value="pending">Pending</option>
            <option value="failed">Failed</option>
          </select>
        </div>
      </div>

      <div className="glass rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-surface-800">
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">ID</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Block</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Station</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Satellite</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Time</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Frequency</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Size</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Status</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-surface-400">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredReceipts.map((receipt) => {
                const cfg = statusConfig[receipt.status];
                return (
                  <tr key={receipt.id} className="border-b border-surface-800/50 hover:bg-surface-800/30 transition-colors">
                    <td className="px-4 py-3">
                      <Link
                        href={`/dashboard/receipts/${receipt.id}`}
                        className="text-primary-400 font-mono text-sm hover:text-primary-300 transition-colors"
                      >
                        {receipt.id}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300 font-mono">
                      {receipt.blockNumber.toLocaleString()}
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300">
                      {receipt.stationName}
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300">
                      {receipt.satellite}
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300">
                      {receipt.timestamp}
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300 font-mono">
                      {receipt.frequency}
                    </td>
                    <td className="px-4 py-3 text-sm text-surface-300">
                      {receipt.dataSize}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${cfg.bg} ${cfg.color}`}>
                        {cfg.label}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Link
                        href={`/dashboard/receipts/${receipt.id}`}
                        className="text-sm text-primary-400 hover:text-primary-300 transition-colors"
                      >
                        View
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {filteredReceipts.length === 0 && (
          <div className="text-center py-12 text-surface-500">
            No receipts found.
          </div>
        )}
      </div>

      <div className="flex items-center justify-between text-sm text-surface-400">
        <div>
          Showing {filteredReceipts.length} of {receipts.length} receipts
        </div>
        <div className="flex gap-2">
          <button className="px-3 py-1 rounded border border-surface-700 hover:border-surface-500 transition-colors">
            Previous
          </button>
          <button className="px-3 py-1 rounded bg-primary-600 text-white">
            1
          </button>
          <button className="px-3 py-1 rounded border border-surface-700 hover:border-surface-500 transition-colors">
            2
          </button>
          <button className="px-3 py-1 rounded border border-surface-700 hover:border-surface-500 transition-colors">
            3
          </button>
          <button className="px-3 py-1 rounded border border-surface-700 hover:border-surface-500 transition-colors">
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
