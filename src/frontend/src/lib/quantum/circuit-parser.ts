export interface QuantumGate {
  type: string;
  qubits: number[];
  params?: number[];
  conditional?: {
    qubit: number;
    value: number;
  };
}

export interface QuantumCircuit {
  qubits: number;
  bits: number;
  gates: QuantumGate[];
  name?: string;
  include: string[];
}

export function parseQasm(qasm: string): QuantumCircuit {
  const lines = qasm.split('\n');
  const circuit: QuantumCircuit = {
    qubits: 0,
    bits: 0,
    gates: [],
    include: [],
  };

  const qubitMap = new Map<string, number>();
  const bitMap = new Map<string, number>();

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('//')) continue;

    if (trimmed.startsWith('OPENQASM') || trimmed.startsWith('include')) {
      if (trimmed.startsWith('include')) {
        const match = trimmed.match(/["']([^"']+)["']/);
        if (match) {
          circuit.include.push(match[1]);
        }
      }
      continue;
    }

    if (trimmed.startsWith('qubit')) {
      const match = trimmed.match(/\[(\d+)\]/);
      if (match) {
        circuit.qubits = parseInt(match[1]);
      } else {
        circuit.qubits = 1;
      }
      continue;
    }

    if (trimmed.startsWith('qreg')) {
      const match = trimmed.match(/qreg\s+(\w+)\[(\d+)\]/);
      if (match) {
        qubitMap.set(match[1], parseInt(match[2]));
        circuit.qubits += parseInt(match[2]);
      }
      continue;
    }

    if (trimmed.startsWith('creg')) {
      const match = trimmed.match(/creg\s+(\w+)\[(\d+)\]/);
      if (match) {
        bitMap.set(match[1], parseInt(match[2]));
        circuit.bits += parseInt(match[2]);
      }
      continue;
    }

    const gateMatch = trimmed.match(
      /^(\w+)\s*(?:\(([^)]*)\))?\s+(.+?)(?:\s*if\s+\((.+)\))?;?$/,
    );
    if (!gateMatch) continue;

    const gateType = gateMatch[1].toLowerCase();
    const paramsStr = gateMatch[2];
    const operands = gateMatch[3];
    const conditionalStr = gateMatch[4];

    const params = paramsStr
      ? paramsStr.split(',').map((p) => parseFloat(p.trim()))
      : undefined;

    const qubits: number[] = [];
    const operandsList = operands.split(',').map((o) => o.trim());

    for (const operand of operandsList) {
      const match = operand.match(/(\w+)\[(\d+)\]/);
      if (match) {
        qubits.push(parseInt(match[2]));
      }
    }

    let conditional: { qubit: number; value: number } | undefined;
    if (conditionalStr) {
      const condMatch = conditionalStr.match(/(\w+)\[(\d+)\]\s*==\s*(\d+)/);
      if (condMatch) {
        conditional = {
          qubit: parseInt(condMatch[2]),
          value: parseInt(condMatch[3]),
        };
      }
    }

    if (qubits.length > 0) {
      circuit.gates.push({ type: gateType, qubits, params, conditional });
    }
  }

  return circuit;
}

export function circuitToQasm(circuit: QuantumCircuit): string {
  const lines: string[] = [];

  lines.push('OPENQASM 3.0;');
  lines.push('');

  for (const inc of circuit.include) {
    lines.push(`include "${inc}";`);
  }

  if (circuit.include.length > 0) lines.push('');

  lines.push(`qubit[${circuit.qubits}] q;`);
  if (circuit.bits > 0) {
    lines.push(`bit[${circuit.bits}] c;`);
  }
  lines.push('');

  for (const gate of circuit.gates) {
    const qubitStr = gate.qubits.map((q) => `q[${q}]`).join(', ');
    if (gate.params && gate.params.length > 0) {
      const paramsStr = gate.params.map((p) => p.toString()).join(', ');
      lines.push(`${gate.type}(${paramsStr}) ${qubitStr};`);
    } else {
      lines.push(`${gate.type} ${qubitStr};`);
    }
  }

  return lines.join('\n');
}

export function validateQasm(qasm: string): {
  valid: boolean;
  errors: string[];
} {
  const errors: string[] = [];
  const lines = qasm.split('\n');

  let hasHeader = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('OPENQASM')) {
      hasHeader = true;
      break;
    }
  }

  if (!hasHeader) {
    errors.push('Missing OPENQASM header');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

export function estimateCircuitDepth(gates: QuantumGate[]): number {
  if (gates.length === 0) return 0;

  const qubitDepths = new Map<number, number>();
  for (const gate of gates) {
    let maxDepth = 0;
    for (const q of gate.qubits) {
      const depth = qubitDepths.get(q) || 0;
      maxDepth = Math.max(maxDepth, depth);
    }
    const newDepth = maxDepth + 1;
    for (const q of gate.qubits) {
      qubitDepths.set(q, newDepth);
    }
  }

  return Math.max(...qubitDepths.values(), 0);
}

export function countGates(gates: QuantumGate[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const gate of gates) {
    counts.set(gate.type, (counts.get(gate.type) || 0) + 1);
  }
  return counts;
}
