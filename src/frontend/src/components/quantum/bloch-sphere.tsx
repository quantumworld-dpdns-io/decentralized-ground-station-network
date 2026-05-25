'use client';

import { useEffect, useRef } from 'react';

interface BlochSphereProps {
  theta?: number;
  phi?: number;
  label?: string;
  size?: number;
}

export function BlochSphere({
  theta = Math.PI / 4,
  phi = Math.PI / 6,
  label = '|ψ⟩',
  size = 200,
}: BlochSphereProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

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
    const r = size / 2 - 20;

    ctx.clearRect(0, 0, size, size);

    // Background
    ctx.fillStyle = '#020617';
    ctx.beginPath();
    ctx.arc(cx, cy, r + 2, 0, Math.PI * 2);
    ctx.fill();

    // Sphere outline
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();

    // Equator
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(cx, cy, r, r * 0.4, 0, 0, Math.PI * 2);
    ctx.stroke();

    // Meridians
    for (let i = 0; i < 4; i++) {
      const angle = (i * Math.PI) / 4;
      ctx.strokeStyle = '#1e293b';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.ellipse(
        cx,
        cy,
        r * 0.4,
        r,
        angle,
        0,
        Math.PI * 2,
      );
      ctx.stroke();
    }

    // Axes
    const axisLen = r + 12;
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 1;

    // Z axis (vertical)
    ctx.beginPath();
    ctx.moveTo(cx, cy - axisLen);
    ctx.lineTo(cx, cy + axisLen);
    ctx.stroke();

    // X axis (horizontal)
    ctx.beginPath();
    ctx.moveTo(cx - axisLen, cy);
    ctx.lineTo(cx + axisLen, cy);
    ctx.stroke();

    // Axis labels
    ctx.fillStyle = '#64748b';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('|0⟩', cx, cy - axisLen - 8);
    ctx.fillText('|1⟩', cx, cy + axisLen + 8);

    // State vector
    const x = cx + r * Math.sin(theta) * Math.cos(phi);
    const y = cy - r * Math.cos(theta);
    const z = cx + r * Math.sin(theta) * Math.sin(phi);

    // Vector line
    const gradient = ctx.createLinearGradient(cx, cy, x, y);
    gradient.addColorStop(0, 'rgba(99, 102, 241, 0.2)');
    gradient.addColorStop(1, 'rgba(99, 102, 241, 0.8)');

    ctx.strokeStyle = '#6366f1';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(x, y);
    ctx.stroke();

    // Vector endpoint
    ctx.fillStyle = '#6366f1';
    ctx.shadowColor = '#6366f1';
    ctx.shadowBlur = 10;
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;

    // Label
    ctx.fillStyle = '#c7d2fe';
    ctx.font = '13px sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'bottom';
    ctx.fillText(label, x + 8, y - 4);

    // Theta arc
    ctx.strokeStyle = 'rgba(99, 102, 241, 0.3)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.3, -Math.PI / 2, -Math.PI / 2 + theta);
    ctx.stroke();

    // Theta label
    ctx.fillStyle = '#818cf8';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'bottom';
    const labelAngle = -Math.PI / 2 + theta / 2;
    ctx.fillText(
      'θ',
      cx + r * 0.38 * Math.cos(labelAngle),
      cy + r * 0.38 * Math.sin(labelAngle),
    );
  }, [theta, phi, label, size]);

  return (
    <div className="flex items-center justify-center">
      <canvas
        ref={canvasRef}
        style={{ width: size, height: size }}
        className="rounded-lg"
      />
    </div>
  );
}
