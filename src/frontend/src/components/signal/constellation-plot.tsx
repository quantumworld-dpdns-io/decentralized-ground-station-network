'use client';

import { useEffect, useRef } from 'react';

interface ConstellationPlotProps {
  points?: { i: number; q: number }[];
  size?: number;
  className?: string;
}

function generateQAM16Points(): { i: number; q: number }[] {
  const points: { i: number; q: number }[] = [];
  for (let i = 0; i < 200; i++) {
    const symIdx = Math.floor(Math.random() * 16);
    const row = Math.floor(symIdx / 4);
    const col = symIdx % 4;
    const iVal = (col - 1.5) * 0.3 + (Math.random() - 0.5) * 0.08;
    const qVal = (row - 1.5) * 0.3 + (Math.random() - 0.5) * 0.08;
    points.push({ i: iVal, q: qVal });
  }
  return points;
}

export function ConstellationPlot({
  points,
  size = 300,
  className,
}: ConstellationPlotProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const data = points || generateQAM16Points();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const dpr = window.devicePixelRatio || 1;
    canvas.width = size * dpr;
    canvas.height = size * dpr;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.scale(dpr, dpr);

    const cx = size / 2;
    const cy = size / 2;
    const scale = size * 0.42;

    ctx.fillStyle = '#020617';
    ctx.fillRect(0, 0, size, size);

    // Grid
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 1;
    for (let i = -2; i <= 2; i++) {
      const pos = cx + i * (scale / 2);
      ctx.beginPath();
      ctx.moveTo(pos, 0);
      ctx.lineTo(pos, size);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, pos);
      ctx.lineTo(size, pos);
      ctx.stroke();
    }

    // Axes
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(cx, 10);
    ctx.lineTo(cx, size - 10);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(10, cy);
    ctx.lineTo(size - 10, cy);
    ctx.stroke();

    // Axis labels
    ctx.fillStyle = '#64748b';
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText('I', size - 10, cy + 4);
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.fillText('Q', cx - 8, 14);

    // Ideal constellation points (QAM-16)
    const idealPoints: { i: number; q: number }[] = [];
    for (let row = 0; row < 4; row++) {
      for (let col = 0; col < 4; col++) {
        idealPoints.push({
          i: (col - 1.5) * (scale / 4),
          q: (row - 1.5) * (scale / 4),
        });
      }
    }

    // Ideal points (faint)
    for (const pt of idealPoints) {
      ctx.fillStyle = 'rgba(99, 102, 241, 0.15)';
      ctx.beginPath();
      ctx.arc(cx + pt.i, cy + pt.q, 4, 0, Math.PI * 2);
      ctx.fill();
    }

    // Data points
    for (const pt of data) {
      const x = cx + pt.i * scale;
      const y = cy + pt.q * scale;
      if (x < 0 || x > size || y < 0 || y > size) continue;

      ctx.fillStyle = 'rgba(99, 102, 241, 0.6)';
      ctx.beginPath();
      ctx.arc(x, y, 2.5, 0, Math.PI * 2);
      ctx.fill();
    }

    // EVM ring
    ctx.strokeStyle = 'rgba(239, 68, 68, 0.2)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.arc(cx, cy, scale * 0.12, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
  }, [data, size]);

  return (
    <div className={className}>
      <canvas
        ref={canvasRef}
        style={{ width: size, height: size }}
        className="rounded-lg mx-auto"
      />
      <div className="flex items-center justify-center gap-4 mt-2 text-[10px] text-surface-500">
        <div className="flex items-center gap-1">
          <div className="w-2 h-2 rounded-full bg-primary-500/60" />
          <span>Symbols</span>
        </div>
        <div className="flex items-center gap-1">
          <div className="w-2 h-2 rounded-full border border-dashed border-red-500/30" />
          <span>EVM Limit</span>
        </div>
      </div>
    </div>
  );
}
