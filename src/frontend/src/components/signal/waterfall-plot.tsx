'use client';

import { useEffect, useRef } from 'react';

interface WaterfallPlotProps {
  data: number[][];
  frequencyRange?: { start: number; end: number };
  height?: number;
  colorScheme?: 'classic' | 'inferno' | 'viridis';
  className?: string;
}

function getColor(value: number, scheme: string): [number, number, number] {
  const v = Math.max(0, Math.min(1, value));

  switch (scheme) {
    case 'inferno':
      return [
        Math.min(255, Math.floor(v * 255)),
        Math.floor((1 - v) * 200),
        Math.floor(v * 150 + 50),
      ];
    case 'viridis':
      return [
        Math.floor(v * 150),
        Math.min(255, Math.floor(v * 255)),
        Math.floor((1 - v) * 150 + 50),
      ];
    default:
      return [
        Math.min(255, Math.floor(v * 200 + 55)),
        Math.min(255, Math.max(0, Math.floor(255 - v * 200))),
        Math.min(255, Math.max(0, Math.floor(200 - v * 150))),
      ];
  }
}

export function WaterfallPlot({
  data,
  frequencyRange,
  height = 300,
  colorScheme = 'classic',
  className,
}: WaterfallPlotProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || data.length === 0) return;

    const dpr = window.devicePixelRatio || 1;
    const width = canvas.clientWidth || 600;
    canvas.width = width * dpr;
    canvas.height = height * dpr;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, width, height);

    const rows = data.length;
    const cols = data[0]?.length || 1;
    const cellW = width / cols;
    const cellH = height / rows;

    for (let y = 0; y < rows; y++) {
      const row = data[y];
      if (!row) continue;
      for (let x = 0; x < cols; x++) {
        const [r, g, b] = getColor(row[x] || 0, colorScheme);
        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.fillRect(
          Math.floor(x * cellW),
          Math.floor(y * cellH),
          Math.ceil(cellW),
          Math.ceil(cellH),
        );
      }
    }
  }, [data, height, colorScheme]);

  return (
    <div className={className}>
      <div className="relative">
        <canvas
          ref={canvasRef}
          style={{ width: '100%', height }}
          className="rounded-lg bg-surface-950"
        />
        {frequencyRange && (
          <div className="absolute inset-x-0 top-0 flex justify-between px-2 text-[10px] text-surface-500 pointer-events-none">
            <span>{frequencyRange.start.toFixed(3)} MHz</span>
            <span>{frequencyRange.end.toFixed(3)} MHz</span>
          </div>
        )}
      </div>
      <div className="flex items-center gap-4 mt-2 text-[10px] text-surface-500">
        <div className="flex items-center gap-1">
          <div className="w-4 h-2 rounded bg-gradient-to-r from-[rgb(255,55,55)] via-[rgb(55,255,55)] to-[rgb(55,55,255)]" />
          <span>Power</span>
        </div>
        <span>Low</span>
        <div className="flex-1 h-1 rounded bg-gradient-to-r from-blue-500 via-green-500 to-red-500" />
        <span>High</span>
      </div>
    </div>
  );
}
