import type { QuantumCircuit, QuantumGate } from './circuit-parser';

export interface RenderConfig {
  numQubits: number;
  numSteps: number;
  cellWidth: number;
  cellHeight: number;
  padding: number;
  wireColor: string;
  gateColors: Record<string, string>;
}

export interface RenderedGate {
  type: string;
  x: number;
  y: number;
  width: number;
  height: number;
  qubits: number[];
  label: string;
}

export interface RenderedCircuit {
  width: number;
  height: number;
  gates: RenderedGate[];
  wires: { y: number; label: string }[];
  steps: number[];
}

const defaultColors: Record<string, string> = {
  h: '#6366f1',
  x: '#ef4444',
  y: '#f97316',
  z: '#22c55e',
  s: '#14b8a6',
  t: '#8b5cf6',
  cx: '#6366f1',
  cz: '#a855f7',
  swap: '#ec4899',
  rx: '#f97316',
  ry: '#22c55e',
  rz: '#3b82f6',
  measure: '#fef9c3',
  reset: '#94a3b8',
  barrier: '#64748b',
};

export function renderCircuit(
  circuit: QuantumCircuit,
  config: Partial<RenderConfig> = {},
): RenderedCircuit {
  const cfg: RenderConfig = {
    numQubits: circuit.qubits,
    numSteps: circuit.gates.length,
    cellWidth: config.cellWidth || 60,
    cellHeight: config.cellHeight || 50,
    padding: config.padding || 20,
    wireColor: config.wireColor || '#334155',
    gateColors: { ...defaultColors, ...config.gateColors },
  };

  const wires: { y: number; label: string }[] = [];
  for (let i = 0; i < cfg.numQubits; i++) {
    wires.push({
      y: cfg.padding + i * cfg.cellHeight + cfg.cellHeight / 2,
      label: `q[${i}]`,
    });
  }

  const renderedGates: RenderedGate[] = [];
  const stepMap = new Map<number, QuantumGate[]>();

  circuit.gates.forEach((gate, step) => {
    if (!stepMap.has(step)) stepMap.set(step, []);
    stepMap.get(step)!.push(gate);
  });

  const sortedSteps = Array.from(stepMap.keys()).sort();

  for (const step of sortedSteps) {
    const stepGates = stepMap.get(step)!;
    const x = cfg.padding + 80 + step * cfg.cellWidth;

    for (const gate of stepGates) {
      if (gate.qubits.length === 0) continue;

      const y1 = wires[gate.qubits[0]]?.y || 0;
      const gateHeight = cfg.cellHeight * 0.6;
      const gateWidth = cfg.cellWidth * 0.7;

      if (
        gate.type === 'cx' ||
        gate.type === 'cz' ||
        gate.type === 'swap'
      ) {
        if (gate.qubits.length >= 2) {
          const y2 = wires[gate.qubits[1]]?.y || 0;
          const midY = (y1 + y2) / 2;

          renderedGates.push({
            type: gate.type,
            x: x - gateWidth / 2,
            y: Math.min(y1, y2),
            width: gateWidth,
            height: Math.abs(y2 - y1),
            qubits: gate.qubits,
            label: gate.type.toUpperCase(),
          });
        }
      } else {
        renderedGates.push({
          type: gate.type,
          x: x - gateWidth / 2,
          y: y1 - gateHeight / 2,
          width: gateWidth,
          height: gateHeight,
          qubits: gate.qubits,
          label: gate.type.toUpperCase(),
        });
      }
    }
  }

  const width =
    cfg.padding * 2 + 80 + sortedSteps.length * cfg.cellWidth + cfg.padding;
  const height =
    cfg.padding * 2 + cfg.numQubits * cfg.cellHeight + cfg.padding;

  return {
    width,
    height,
    gates: renderedGates,
    wires,
    steps: sortedSteps,
  };
}

export function drawCircuitToCanvas(
  circuit: RenderedCircuit,
  canvas: HTMLCanvasElement,
  config: Partial<RenderConfig> = {},
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;
  canvas.width = circuit.width * dpr;
  canvas.height = circuit.height * dpr;
  canvas.style.width = `${circuit.width}px`;
  canvas.style.height = `${circuit.height}px`;
  ctx.scale(dpr, dpr);

  ctx.fillStyle = '#020617';
  ctx.fillRect(0, 0, circuit.width, circuit.height);

  for (const wire of circuit.wires) {
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(0, wire.y);
    ctx.lineTo(circuit.width, wire.y);
    ctx.stroke();

    ctx.fillStyle = '#64748b';
    ctx.font = '12px monospace';
    ctx.textAlign = 'right';
    ctx.fillText(wire.label, 70, wire.y + 4);
  }

  const gateColors = { ...defaultColors, ...config.gateColors };

  for (const gate of circuit.gates) {
    const color = gateColors[gate.type] || '#6366f1';

    if (
      gate.type === 'cx' ||
      gate.type === 'cz' ||
      gate.type === 'swap'
    ) {
      if (gate.qubits.length >= 2) {
        const cx = gate.x + gate.width / 2;
        const topY = gate.y;
        const bottomY = gate.y + gate.height;

        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(cx, topY);
        ctx.lineTo(cx, bottomY);
        ctx.stroke();

        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(cx, topY, 6, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(cx, bottomY, 8, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else {
      const roundedRect = 4;
      ctx.fillStyle = `${color}33`;
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(gate.x + roundedRect, gate.y);
      ctx.lineTo(gate.x + gate.width - roundedRect, gate.y);
      ctx.quadraticCurveTo(
        gate.x + gate.width,
        gate.y,
        gate.x + gate.width,
        gate.y + roundedRect,
      );
      ctx.lineTo(gate.x + gate.width, gate.y + gate.height - roundedRect);
      ctx.quadraticCurveTo(
        gate.x + gate.width,
        gate.y + gate.height,
        gate.x + gate.width - roundedRect,
        gate.y + gate.height,
      );
      ctx.lineTo(gate.x + roundedRect, gate.y + gate.height);
      ctx.quadraticCurveTo(
        gate.x,
        gate.y + gate.height,
        gate.x,
        gate.y + gate.height - roundedRect,
      );
      ctx.lineTo(gate.x, gate.y + roundedRect);
      ctx.quadraticCurveTo(gate.x, gate.y, gate.x + roundedRect, gate.y);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = color;
      ctx.font = 'bold 11px monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(gate.label, gate.x + gate.width / 2, gate.y + gate.height / 2 + 1);
    }
  }
}
