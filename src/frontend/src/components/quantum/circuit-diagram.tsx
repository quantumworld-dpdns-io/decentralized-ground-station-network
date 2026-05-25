'use client';

import { useEffect, useRef } from 'react';
import { drawCircuitToCanvas } from '@/lib/quantum/circuit-renderer';
import type { RenderedCircuit } from '@/lib/quantum/circuit-renderer';

interface CircuitDiagramProps {
  circuit: RenderedCircuit;
  className?: string;
  width?: number;
  height?: number;
}

export function CircuitDiagram({
  circuit,
  className,
  width,
  height,
}: CircuitDiagramProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!canvasRef.current) return;
    drawCircuitToCanvas(circuit, canvasRef.current);
  }, [circuit]);

  return (
    <div className={className}>
      <canvas
        ref={canvasRef}
        className="rounded-lg w-full"
        style={{ maxWidth: width || circuit.width, maxHeight: height || circuit.height }}
      />
    </div>
  );
}
