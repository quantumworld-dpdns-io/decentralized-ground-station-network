'use client';

import { useState } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

const metricsData = [
  { time: '00:00', signal: -72, noise: -98, temperature: 23.5 },
  { time: '04:00', signal: -68, noise: -96, temperature: 22.1 },
  { time: '08:00', signal: -65, noise: -97, temperature: 24.8 },
  { time: '12:00', signal: -70, noise: -99, temperature: 26.3 },
  { time: '16:00', signal: -67, noise: -95, temperature: 25.7 },
  { time: '20:00', signal: -71, noise: -97, temperature: 24.2 },
  { time: '23:00', signal: -69, noise: -98, temperature: 23.8 },
];

const upcomingPasses = [
  { satellite: 'NOAA-19', aos: '14:32:15', los: '14:45:22', maxElev: 45, frequency: '137.100 MHz' },
  { satellite: 'ISS', aos: '16:08:00', los: '16:21:30', maxElev: 67, frequency: '145.800 MHz' },
  { satellite: 'GOES-16', aos: '18:45:00', los: '19:02:00', maxElev: 38, frequency: '1694.100 MHz' },
  { satellite: 'Fengyun-3', aos: '21:15:30', los: '21:28:45', maxElev: 52, frequency: '137.950 MHz' },
];

export default function StationDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const [timeRange, setTimeRange] = useState('24h');

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-3 h-3 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]" />
            <h1 className="text-2xl font-bold text-white">
              Station {params.id === 'st-001' ? 'Alpha' : params.id}
            </h1>
          </div>
          <p className="text-surface-400 mt-1">
            Fairbanks, AK · S-Band · Last contact: 30s ago
          </p>
        </div>
        <div className="flex gap-2">
          <button className="px-4 py-2 rounded-lg bg-surface-800 text-surface-300 hover:text-white text-sm transition-colors">
            Edit
          </button>
          <button className="px-4 py-2 rounded-lg bg-red-600/20 text-red-400 hover:bg-red-600/30 text-sm transition-colors">
            Disconnect
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Signal Strength', value: '-68 dBm', change: '+2.3', type: 'increase' as const },
          { label: 'Noise Floor', value: '-97 dBm', change: '-1.1', type: 'decrease' as const },
          { label: 'Temperature', value: '24.8°C', change: '+0.5', type: 'increase' as const },
          { label: 'Uptime', value: '99.97%', change: '+0.01', type: 'increase' as const },
        ].map((metric) => (
          <div key={metric.label} className="glass rounded-xl p-4">
            <div className="text-sm text-surface-400 mb-1">{metric.label}</div>
            <div className="text-2xl font-bold text-white mb-1">
              {metric.value}
            </div>
            <span
              className={`text-xs font-medium ${
                metric.type === 'increase'
                  ? 'text-green-400'
                  : 'text-red-400'
              }`}
            >
              {metric.change} {metric.type === 'increase' ? '↑' : '↓'}
            </span>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-white">Signal Metrics</h3>
            <div className="flex gap-1">
              {['1h', '6h', '24h', '7d'].map((range) => (
                <button
                  key={range}
                  onClick={() => setTimeRange(range)}
                  className={`px-2 py-1 text-xs rounded ${
                    timeRange === range
                      ? 'bg-primary-600 text-white'
                      : 'text-surface-400 hover:text-surface-200'
                  }`}
                >
                  {range}
                </button>
              ))}
            </div>
          </div>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={metricsData}>
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
              <Line
                type="monotone"
                dataKey="signal"
                stroke="#6366f1"
                strokeWidth={2}
                dot={false}
              />
              <Line
                type="monotone"
                dataKey="noise"
                stroke="#22c55e"
                strokeWidth={2}
                dot={false}
              />
              <Line
                type="monotone"
                dataKey="temperature"
                stroke="#f97316"
                strokeWidth={2}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="glass rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Upcoming Passes
          </h3>
          <div className="space-y-3">
            {upcomingPasses.map((pass) => (
              <div
                key={pass.satellite}
                className="flex items-center justify-between py-2 border-b border-surface-800 last:border-0"
              >
                <div>
                  <div className="text-sm font-medium text-white">
                    {pass.satellite}
                  </div>
                  <div className="text-xs text-surface-500">{pass.frequency}</div>
                </div>
                <div className="text-right">
                  <div className="text-sm text-surface-300">
                    {pass.aos} — {pass.los}
                  </div>
                  <div className="text-xs text-surface-500">
                    Max elev: {pass.maxElev}°
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">
          Recent Activity
        </h3>
        <div className="space-y-3">
          {[
            { action: 'Data transmission completed', satellite: 'NOAA-19', time: '2 min ago', status: 'success' as const },
            { action: 'Scheduled maintenance started', satellite: '-', time: '15 min ago', status: 'warning' as const },
            { action: 'Firmware update applied', satellite: '-', time: '1h ago', status: 'success' as const },
            { action: 'Connection timeout', satellite: 'Fengyun-3', time: '3h ago', status: 'error' as const },
            { action: 'Antenna calibration completed', satellite: '-', time: '6h ago', status: 'success' as const },
          ].map((activity, i) => (
            <div
              key={i}
              className="flex items-center justify-between py-2 border-b border-surface-800 last:border-0"
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-2 h-2 rounded-full ${
                    activity.status === 'success'
                      ? 'bg-green-500'
                      : activity.status === 'warning'
                        ? 'bg-yellow-500'
                        : 'bg-red-500'
                  }`}
                />
                <div>
                  <div className="text-sm text-white">{activity.action}</div>
                  {activity.satellite !== '-' && (
                    <div className="text-xs text-surface-500">
                      {activity.satellite}
                    </div>
                  )}
                </div>
              </div>
              <div className="text-xs text-surface-500">{activity.time}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
