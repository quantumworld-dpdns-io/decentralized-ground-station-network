'use client';

import { useState } from 'react';
import Link from 'next/link';

interface Station {
  id: string;
  name: string;
  location: string;
  status: 'online' | 'offline' | 'maintenance' | 'error';
  type: string;
  uptime: number;
  lastContact: string;
  latitude: number;
  longitude: number;
}

const stations: Station[] = [
  { id: 'st-001', name: 'Station Alpha', location: 'Fairbanks, AK', status: 'online', type: 'S-Band', uptime: 99.97, lastContact: '30s ago', latitude: 64.8378, longitude: -147.7164 },
  { id: 'st-002', name: 'Station Beta', location: 'Tromsø, Norway', status: 'online', type: 'X-Band', uptime: 99.89, lastContact: '15s ago', latitude: 69.6496, longitude: 18.9560 },
  { id: 'st-003', name: 'Station Gamma', location: 'Alice Springs, AU', status: 'maintenance', type: 'S-Band', uptime: 98.45, lastContact: '2m ago', latitude: -23.6980, longitude: 133.8807 },
  { id: 'st-004', name: 'Station Delta', location: 'Kourou, French Guiana', status: 'online', type: 'X-Band', uptime: 99.92, lastContact: '45s ago', latitude: 5.1614, longitude: -52.6494 },
  { id: 'st-005', name: 'Station Epsilon', location: 'Hartebeesthoek, ZA', status: 'error', type: 'UHF', uptime: 95.12, lastContact: '5m ago', latitude: -25.8901, longitude: 27.6865 },
  { id: 'st-006', name: 'Station Zeta', location: 'Svalbard, Norway', status: 'online', type: 'S-Band', uptime: 99.99, lastContact: '10s ago', latitude: 78.2298, longitude: 15.4069 },
];

const statusColors: Record<string, string> = {
  online: 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]',
  offline: 'bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.5)]',
  maintenance: 'bg-yellow-500 shadow-[0_0_8px_rgba(234,179,8,0.5)]',
  error: 'bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.5)] animate-pulse',
};

export default function StationsPage() {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [typeFilter, setTypeFilter] = useState<string>('all');

  const filteredStations = stations.filter((station) => {
    const matchesSearch =
      station.name.toLowerCase().includes(search.toLowerCase()) ||
      station.location.toLowerCase().includes(search.toLowerCase()) ||
      station.id.toLowerCase().includes(search.toLowerCase());
    const matchesStatus =
      statusFilter === 'all' || station.status === statusFilter;
    const matchesType =
      typeFilter === 'all' || station.type === typeFilter;
    return matchesSearch && matchesStatus && matchesType;
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Ground Stations</h1>
          <p className="text-surface-400 mt-1">
            Monitor and manage your ground station network
          </p>
        </div>
        <Link
          href="/dashboard/stations/register"
          className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white font-medium text-sm transition-all"
        >
          Register Station
        </Link>
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search stations by name, location, or ID..."
              className="w-full px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all text-sm"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Status</option>
            <option value="online">Online</option>
            <option value="offline">Offline</option>
            <option value="maintenance">Maintenance</option>
            <option value="error">Error</option>
          </select>
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Types</option>
            <option value="S-Band">S-Band</option>
            <option value="X-Band">X-Band</option>
            <option value="UHF">UHF</option>
          </select>
        </div>
      </div>

      <div className="glass rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-surface-800">
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Station
                </th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Location
                </th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Status
                </th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Type
                </th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Uptime
                </th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">
                  Last Contact
                </th>
                <th className="text-right px-4 py-3 text-sm font-medium text-surface-400">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {filteredStations.map((station) => (
                <tr
                  key={station.id}
                  className="border-b border-surface-800/50 hover:bg-surface-800/30 transition-colors"
                >
                  <td className="px-4 py-3">
                    <Link
                      href={`/dashboard/stations/${station.id}`}
                      className="text-white font-medium hover:text-primary-400 transition-colors"
                    >
                      {station.name}
                    </Link>
                    <div className="text-xs text-surface-500">{station.id}</div>
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {station.location}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div
                        className={`w-2 h-2 rounded-full ${
                          statusColors[station.status]
                        }`}
                      />
                      <span className="text-sm text-surface-300 capitalize">
                        {station.status}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {station.type}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 w-20 h-1.5 rounded-full bg-surface-800">
                        <div
                          className={`h-full rounded-full ${
                            station.uptime >= 99
                              ? 'bg-green-500'
                              : station.uptime >= 95
                                ? 'bg-yellow-500'
                                : 'bg-red-500'
                          }`}
                          style={{ width: `${station.uptime}%` }}
                        />
                      </div>
                      <span className="text-xs text-surface-400">
                        {station.uptime}%
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {station.lastContact}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <Link
                      href={`/dashboard/stations/${station.id}`}
                      className="text-sm text-primary-400 hover:text-primary-300 transition-colors"
                    >
                      View Details
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {filteredStations.length === 0 && (
          <div className="text-center py-12 text-surface-500">
            No stations found matching your criteria.
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Status Distribution
          </h3>
          <div className="space-y-3">
            {[
              { label: 'Online', count: 4, color: 'bg-green-500' },
              { label: 'Offline', count: 0, color: 'bg-red-500' },
              { label: 'Maintenance', count: 1, color: 'bg-yellow-500' },
              { label: 'Error', count: 1, color: 'bg-red-500/50' },
            ].map((item) => (
              <div key={item.label}>
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-surface-300">{item.label}</span>
                  <span className="text-sm text-surface-400">{item.count}</span>
                </div>
                <div className="h-2 rounded-full bg-surface-800 overflow-hidden">
                  <div
                    className={`h-full rounded-full ${item.color}`}
                    style={{
                      width: `${(item.count / stations.length) * 100}%`,
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Type Breakdown
          </h3>
          <div className="space-y-3">
            {[
              { label: 'S-Band', count: 3, color: 'bg-primary-500' },
              { label: 'X-Band', count: 2, color: 'bg-quantum-500' },
              { label: 'UHF', count: 1, color: 'bg-signal-500' },
            ].map((item) => (
              <div key={item.label}>
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-surface-300">{item.label}</span>
                  <span className="text-sm text-surface-400">{item.count}</span>
                </div>
                <div className="h-2 rounded-full bg-surface-800 overflow-hidden">
                  <div
                    className={`h-full rounded-full ${item.color}`}
                    style={{
                      width: `${(item.count / stations.length) * 100}%`,
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
