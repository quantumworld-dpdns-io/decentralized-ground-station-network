'use client';

import { useState, useEffect, useRef } from 'react';

interface Signal {
  id: string;
  satellite: string;
  frequency: string;
  strength: number;
  snr: number;
  bandwidth: string;
  modulation: string;
  status: 'active' | 'idle' | 'error';
  lastUpdate: string;
}

const signals: Signal[] = [
  { id: 'sig-001', satellite: 'NOAA-19', frequency: '137.100 MHz', strength: -68, snr: 29, bandwidth: '40 kHz', modulation: 'APSK', status: 'active', lastUpdate: '2s ago' },
  { id: 'sig-002', satellite: 'ISS', frequency: '145.800 MHz', strength: -72, snr: 25, bandwidth: '20 kHz', modulation: 'FM', status: 'active', lastUpdate: '5s ago' },
  { id: 'sig-003', satellite: 'GOES-16', frequency: '1694.100 MHz', strength: -85, snr: 18, bandwidth: '200 kHz', modulation: 'QPSK', status: 'active', lastUpdate: '1s ago' },
  { id: 'sig-004', satellite: 'Fengyun-3', frequency: '137.950 MHz', strength: -90, snr: 14, bandwidth: '50 kHz', modulation: 'BPSK', status: 'idle', lastUpdate: '30s ago' },
  { id: 'sig-005', satellite: 'Meteor-M2', frequency: '137.900 MHz', strength: -76, snr: 22, bandwidth: '80 kHz', modulation: 'QPSK', status: 'active', lastUpdate: '3s ago' },
];

function generateWaterfallData(length: number): number[] {
  return Array.from({ length }, () => Math.random());
}

export default function SignalPage() {
  const [selectedSignal, setSelectedSignal] = useState<string | null>(null);
  const [waterfallData, setWaterfallData] = useState(() =>
    Array.from({ length: 200 }, () => generateWaterfallData(400)),
  );
  const [frequency, setFrequency] = useState('137.100');
  const [span, setSpan] = useState('200');
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const interval = setInterval(() => {
      setWaterfallData((prev) => {
        const next = [...prev];
        next.shift();
        next.push(generateWaterfallData(400));
        return next;
      });
    }, 200);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;

    waterfallData.forEach((row, y) => {
      row.forEach((val, x) => {
        const intensity = Math.floor(val * 255);
        const r = Math.min(255, intensity + 50);
        const g = Math.min(255, Math.max(0, 255 - intensity * 2));
        const b = Math.min(255, Math.max(0, 200 - intensity));
        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.fillRect(
          Math.floor((x / row.length) * width),
          Math.floor((y / waterfallData.length) * height),
          Math.ceil(width / row.length) + 1,
          Math.ceil(height / waterfallData.length) + 1,
        );
      });
    });
  }, [waterfallData]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Signal Monitoring</h1>
        <p className="text-surface-400 mt-1">
          Real-time spectrum analysis and signal monitoring
        </p>
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex items-center gap-4 mb-4">
          <div className="flex items-center gap-2">
            <span className="text-sm text-surface-400">Center:</span>
            <input
              type="text"
              value={frequency}
              onChange={(e) => setFrequency(e.target.value)}
              className="w-28 px-3 py-1.5 rounded bg-surface-800 border border-surface-700 text-white text-sm font-mono focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
            <span className="text-sm text-surface-400">MHz</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-sm text-surface-400">Span:</span>
            <input
              type="text"
              value={span}
              onChange={(e) => setSpan(e.target.value)}
              className="w-20 px-3 py-1.5 rounded bg-surface-800 border border-surface-700 text-white text-sm font-mono focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
            <span className="text-sm text-surface-400">kHz</span>
          </div>
          <div className="flex-1" />
          <div className="flex gap-2">
            <button className="px-3 py-1.5 text-xs rounded bg-surface-800 text-surface-300 hover:text-white">Auto</button>
            <button className="px-3 py-1.5 text-xs rounded bg-surface-800 text-surface-300 hover:text-white">Peak</button>
            <button className="px-3 py-1.5 text-xs rounded bg-primary-600 text-white">Hold</button>
          </div>
        </div>

        <div className="relative">
          <canvas
            ref={canvasRef}
            width={800}
            height={300}
            className="w-full h-[300px] rounded-lg bg-surface-950"
          />
          <div className="absolute inset-x-0 top-0 flex justify-between px-2 text-[10px] text-surface-500 pointer-events-none">
            <span>-100 kHz</span>
            <span>Center {frequency} MHz</span>
            <span>+100 kHz</span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {signals.map((signal) => (
          <div
            key={signal.id}
            onClick={() =>
              setSelectedSignal(
                selectedSignal === signal.id ? null : signal.id,
              )
            }
            className={`glass rounded-xl p-4 cursor-pointer transition-all ${
              selectedSignal === signal.id
                ? 'ring-2 ring-primary-500'
                : 'glass-hover'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <div
                  className={`w-2 h-2 rounded-full ${
                    signal.status === 'active'
                      ? 'bg-green-500 animate-pulse'
                      : signal.status === 'idle'
                        ? 'bg-yellow-500'
                        : 'bg-red-500'
                  }`}
                />
                <span className="font-medium text-white text-sm">
                  {signal.satellite}
                </span>
              </div>
              <span className="text-xs text-surface-500">{signal.lastUpdate}</span>
            </div>
            <div className="text-xs text-surface-400 font-mono mb-2">
              {signal.frequency} · {signal.modulation}
            </div>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <div>
                <span className="text-surface-500">Signal:</span>{' '}
                <span className="text-white font-mono">
                  {signal.strength} dBm
                </span>
              </div>
              <div>
                <span className="text-surface-500">SNR:</span>{' '}
                <span
                  className={`font-mono ${
                    signal.snr > 20 ? 'text-green-400' : 'text-yellow-400'
                  }`}
                >
                  {signal.snr} dB
                </span>
              </div>
              <div>
                <span className="text-surface-500">BW:</span>{' '}
                <span className="text-white font-mono">
                  {signal.bandwidth}
                </span>
              </div>
              <div>
                <span className="text-surface-500">Status:</span>{' '}
                <span
                  className={
                    signal.status === 'active'
                      ? 'text-green-400'
                      : signal.status === 'idle'
                        ? 'text-yellow-400'
                        : 'text-red-400'
                  }
                >
                  {signal.status.charAt(0).toUpperCase() +
                    signal.status.slice(1)}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
