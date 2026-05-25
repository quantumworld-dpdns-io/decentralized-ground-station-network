'use client';

import { useEffect, useRef } from 'react';

interface Node {
  id: string;
  label: string;
  group: string;
  x?: number;
  y?: number;
  size?: number;
}

interface Edge {
  source: string;
  target: string;
  weight?: number;
  label?: string;
}

interface NetworkGraphProps {
  nodes: Node[];
  edges: Edge[];
  width?: number;
  height?: number;
  className?: string;
}

export function NetworkGraph({
  nodes,
  edges,
  width = 600,
  height = 400,
  className,
}: NetworkGraphProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr;
    canvas.height = height * dpr;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.scale(dpr, dpr);

    const cx = width / 2;
    const cy = height / 2;
    const radius = Math.min(width, height) * 0.35;

    ctx.fillStyle = '#020617';
    ctx.fillRect(0, 0, width, height);

    const groupColors: Record<string, string> = {
      station: '#6366f1',
      satellite: '#22c55e',
      gateway: '#f97316',
      user: '#a855f7',
    };

    const positionedNodes = nodes.map((node, i) => {
      const angle = (2 * Math.PI * i) / nodes.length - Math.PI / 2;
      return {
        ...node,
        x: node.x ?? cx + radius * Math.cos(angle),
        y: node.y ?? cy + radius * Math.sin(angle),
        size: node.size || 8,
      };
    });

    const nodeMap = new Map(positionedNodes.map((n) => [n.id, n]));

    for (const edge of edges) {
      const source = nodeMap.get(edge.source);
      const target = nodeMap.get(edge.target);
      if (!source || !target) continue;

      ctx.strokeStyle = `rgba(99, 102, 241, ${edge.weight ? 0.2 + edge.weight * 0.4 : 0.3})`;
      ctx.lineWidth = edge.weight ? 1 + edge.weight * 3 : 1.5;
      ctx.beginPath();
      ctx.moveTo(source.x!, source.y!);
      ctx.lineTo(target.x!, target.y!);
      ctx.stroke();
    }

    for (const node of positionedNodes) {
      const color = groupColors[node.group] || '#64748b';

      ctx.fillStyle = `${color}33`;
      ctx.shadowColor = color;
      ctx.shadowBlur = 15;
      ctx.beginPath();
      ctx.arc(node.x!, node.y!, node.size + 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;

      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(node.x!, node.y!, node.size, 0, Math.PI * 2);
      ctx.fill();
    }

    for (const node of positionedNodes) {
      ctx.fillStyle = '#94a3b8';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(node.label, node.x!, node.y! + node.size + 6);
    }

    // Legend
    const legendY = 16;
    let legendX = 16;
    for (const [group, color] of Object.entries(groupColors)) {
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(legendX + 5, legendY + 5, 4, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#64748b';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(group.charAt(0).toUpperCase() + group.slice(1), legendX + 14, legendY + 5);
      legendX += 80;
    }
  }, [nodes, edges, width, height]);

  return (
    <canvas
      ref={canvasRef}
      style={{ width, height }}
      className={`rounded-lg ${className || ''}`}
    />
  );
}
