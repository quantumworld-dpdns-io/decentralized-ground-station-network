'use client';

import { useState, useEffect, useRef } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

const timelineData = Array.from({ length: 100 }, (_, i) => ({
  time: (i * 0.1).toFixed(1),
  amplitude: Math.sin(i * 0.3) * 0.8 + Math.sin(i * 0.7) * 0.4 + (Math.random() - 0.5) * 0.2,
}));

export default function SignalDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const [activeTab, setActiveTab] = useState<'constellation' | 'timeline' | 'spectrum'>('constellation');
  const constCanvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = constCanvasRef.current;
    if (!canvas || activeTab !== 'constellation') return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(canvas.width / 2, 0);
    ctx.lineTo(canvas.width / 2, canvas.height);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, canvas.height / 2);
    ctx.lineTo(canvas.width, canvas.height / 2);
    ctx.stroke();

    const points = 200;
    for (let i = 0; i < points; i++) {
      const angle = Math.random() * Math.PI * 2;
      const radius = Math.sqrt(-Math.log(1 - Math.random())) * 40;
      const x = canvas.width / 2 + Math.cos(angle) * radius;
      const y = canvas.height / 2 + Math.sin(angle) * radius;

      ctx.fillStyle = i % 2 === 0
        ? 'rgba(99, 102, 241, 0.6)'
        : 'rgba(34, 197, 94, 0.6)';
      ctx.beginPath();
      ctx.arc(x, y, 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }, [activeTab]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse" />
            <h1 className="text-2xl font-bold text-white">Signal Detail</h1>
          </div>
          <p className="text-surface-400 mt-1 font-mono text-sm">{params.id}</p>
        </div>
        <div className="flex gap-2">
          <button className="px-4 py-2 rounded-lg bg-primary-600 text-white text-sm hover:bg-primary-500 transition-colors">
            Record
          </button>
          <button className="px-4 py-2 rounded-lg bg-surface-800 text-surface-300 hover:text-white text-sm transition-colors">
            Export
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Frequency', value: '137.100 MHz' },
          { label: 'Strength', value: '-68 dBm' },
          { label: 'SNR', value: '29 dB' },
          { label: 'Bandwidth', value: '40 kHz' },
        ].map((stat) => (
          <div key={stat.label} className="glass rounded-xl p-4">
            <div className="text-sm text-surface-400 mb-1">{stat.label}</div>
            <div className="text-2xl font-bold text-white">{stat.value}</div>
          </div>
        ))}
      </div>

      <div className="glass rounded-xl p-6">
        <div className="flex gap-2 mb-6">
          {(['constellation', 'timeline', 'spectrum'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-2 text-sm rounded-lg transition-all ${
                activeTab === tab
                  ? 'bg-primary-600 text-white'
                  : 'text-surface-400 hover:text-surface-200'
              }`}
            >
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
            </button>
          ))}
        </div>

        {activeTab === 'constellation' && (
          <canvas
            ref={constCanvasRef}
            width={400}
            height={400}
            className="w-full max-w-[400px] mx-auto rounded-lg bg-surface-950"
          />
        )}

        {activeTab === 'timeline' && (
          <ResponsiveContainer width="100%" height={350}>
            <LineChart data={timelineData}>
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
                dataKey="amplitude"
                stroke="#6366f1"
                strokeWidth={1.5}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        )}

        {activeTab === 'spectrum' && (
          <div className="h-[350px] rounded-lg bg-surface-950 flex items-center justify-center text-surface-500">
            Spectrum analyzer visualization
          </div>
        )}
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">
          Signal Metrics
        </h3>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {[
            { label: 'Modulation', value: 'APSK' },
            { label: 'Encoding', value: 'Convolutional (K=7, R=1/2)' },
            { label: 'Data Rate', value: '2.4 MB/s' },
            { label: 'Doppler Shift', value: '+1.2 kHz' },
            { label: 'Polarization', value: 'RHCP' },
            { label: 'Elevation', value: '45.2°' },
          ].map((metric) => (
            <div key={metric.label}>
              <div className="text-xs text-surface-400 mb-1">
                {metric.label}
              </div>
              <div className="text-sm text-white font-mono">
                {metric.value}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
