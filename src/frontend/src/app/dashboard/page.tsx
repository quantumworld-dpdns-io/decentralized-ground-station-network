'use client';

import { useEffect, useState } from 'react';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

const stats = [
  {
    label: 'Active Stations',
    value: '127',
    change: '+3',
    changeType: 'increase' as const,
    icon: SatelliteIcon,
  },
  {
    label: 'Total Transmissions',
    value: '2,456,891',
    change: '+12.5%',
    changeType: 'increase' as const,
    icon: RadioIcon,
  },
  {
    label: 'Network Uptime',
    value: '99.97%',
    change: '+0.02%',
    changeType: 'increase' as const,
    icon: ShieldIcon,
  },
  {
    label: 'Quantum Jobs',
    value: '1,234',
    change: '+8.3%',
    changeType: 'increase' as const,
    icon: CpuIcon,
  },
  {
    label: 'Pending Receipts',
    value: '47',
    change: '-12',
    changeType: 'decrease' as const,
    icon: DocumentIcon,
  },
  {
    label: 'Active Users',
    value: '892',
    change: '+5.7%',
    changeType: 'increase' as const,
    icon: UsersIcon,
  },
];

const trafficData = [
  { time: '00:00', uplink: 240, downlink: 180 },
  { time: '04:00', uplink: 180, downlink: 120 },
  { time: '08:00', uplink: 320, downlink: 260 },
  { time: '12:00', uplink: 450, downlink: 380 },
  { time: '16:00', uplink: 380, downlink: 310 },
  { time: '20:00', uplink: 290, downlink: 220 },
  { time: '23:00', uplink: 260, downlink: 190 },
];

const stationActivity = [
  { name: 'Station A', transmissions: 1245, uptime: 99.9 },
  { name: 'Station B', transmissions: 1089, uptime: 99.8 },
  { name: 'Station C', transmissions: 967, uptime: 99.5 },
  { name: 'Station D', transmissions: 834, uptime: 98.7 },
  { name: 'Station E', transmissions: 723, uptime: 99.1 },
];

const recentReceipts = [
  {
    id: '0x7a3f...b9e2',
    station: 'Station Alpha',
    satellite: 'NOAA-19',
    timestamp: '2 min ago',
    status: 'verified' as const,
  },
  {
    id: '0x4c8e...f1a7',
    station: 'Station Beta',
    satellite: 'ISS',
    timestamp: '5 min ago',
    status: 'pending' as const,
  },
  {
    id: '0x9b2d...e4c1',
    station: 'Station Gamma',
    satellite: 'GOES-16',
    timestamp: '12 min ago',
    status: 'verified' as const,
  },
  {
    id: '0x3f6a...d8b4',
    station: 'Station Delta',
    satellite: 'Fengyun-3',
    timestamp: '18 min ago',
    status: 'failed' as const,
  },
];

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard Overview</h1>
        <p className="text-surface-400 mt-1">
          Real-time network status and performance metrics
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {stats.map((stat) => (
          <div key={stat.label} className="glass rounded-xl p-4 glass-hover">
            <div className="flex items-center justify-between mb-3">
              <stat.icon className="w-5 h-5 text-surface-400" />
              <span
                className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                  stat.changeType === 'increase'
                    ? 'bg-green-500/10 text-green-400'
                    : 'bg-red-500/10 text-red-400'
                }`}
              >
                {stat.change}
              </span>
            </div>
            <div className="text-2xl font-bold text-white mb-1">
              {stat.value}
            </div>
            <div className="text-sm text-surface-400">{stat.label}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Network Traffic
          </h3>
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={trafficData}>
              <defs>
                <linearGradient id="uplink" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="downlink" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="time" stroke="#64748b" fontSize={12} />
              <YAxis stroke="#64748b" fontSize={12} />
              <Tooltip
                contentStyle={{
                  background: '#1e293b',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                }}
              />
              <Area
                type="monotone"
                dataKey="uplink"
                stroke="#6366f1"
                fill="url(#uplink)"
                strokeWidth={2}
              />
              <Area
                type="monotone"
                dataKey="downlink"
                stroke="#22c55e"
                fill="url(#downlink)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Top Stations
          </h3>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={stationActivity}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="name" stroke="#64748b" fontSize={12} />
              <YAxis stroke="#64748b" fontSize={12} />
              <Tooltip
                contentStyle={{
                  background: '#1e293b',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                }}
              />
              <Bar dataKey="transmissions" fill="#6366f1" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Recent Receipts
          </h3>
          <div className="space-y-3">
            {recentReceipts.map((receipt) => (
              <div
                key={receipt.id}
                className="flex items-center justify-between py-2 border-b border-surface-800 last:border-0"
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`w-2 h-2 rounded-full ${
                      receipt.status === 'verified'
                        ? 'bg-green-500'
                        : receipt.status === 'pending'
                          ? 'bg-yellow-500'
                          : 'bg-red-500'
                    }`}
                  />
                  <div>
                    <div className="text-sm font-medium text-white">
                      {receipt.satellite}
                    </div>
                    <div className="text-xs text-surface-500">
                      {receipt.station} — {receipt.id}
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <div
                    className={`text-xs font-medium ${
                      receipt.status === 'verified'
                        ? 'text-green-400'
                        : receipt.status === 'pending'
                          ? 'text-yellow-400'
                          : 'text-red-400'
                    }`}
                  >
                    {receipt.status.charAt(0).toUpperCase() +
                      receipt.status.slice(1)}
                  </div>
                  <div className="text-xs text-surface-500">
                    {receipt.timestamp}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            System Health
          </h3>
          <div className="space-y-4">
            {[
              { label: 'API Gateway', status: 'Operational', pct: 100 },
              { label: 'Database Cluster', status: 'Operational', pct: 100 },
              { label: 'Quantum Service', status: 'Degraded', pct: 85 },
              { label: 'Signal Processor', status: 'Operational', pct: 100 },
              { label: 'Blockchain Indexer', status: 'Syncing', pct: 67 },
            ].map((svc) => (
              <div key={svc.label}>
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-surface-300">{svc.label}</span>
                  <span
                    className={`text-xs font-medium ${
                      svc.pct === 100
                        ? 'text-green-400'
                        : svc.pct >= 80
                          ? 'text-yellow-400'
                          : 'text-blue-400'
                    }`}
                  >
                    {svc.status}
                  </span>
                </div>
                <div className="h-1.5 rounded-full bg-surface-800 overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      svc.pct === 100
                        ? 'bg-green-500'
                        : svc.pct >= 80
                          ? 'bg-yellow-500'
                          : 'bg-blue-500'
                    }`}
                    style={{ width: `${svc.pct}%` }}
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

function SatelliteIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
      />
    </svg>
  );
}

function RadioIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
      />
    </svg>
  );
}

function ShieldIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
      />
    </svg>
  );
}

function CpuIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z"
      />
    </svg>
  );
}

function DocumentIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
      />
    </svg>
  );
}

function UsersIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
      />
    </svg>
  );
}
