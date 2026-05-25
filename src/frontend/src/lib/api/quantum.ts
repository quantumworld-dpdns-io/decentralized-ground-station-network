'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from './client';

export interface QuantumCircuit {
  id: string;
  name: string;
  qubits: number;
  depth: number;
  gates: number;
  qasm?: string;
  createdAt: string;
  lastRun?: string;
  runs: number;
  tags: string[];
}

export interface QuantumJob {
  id: string;
  circuitId: string;
  circuitName: string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  shots: number;
  qubits: number;
  submitted: string;
  duration?: string;
  result?: Record<string, number>;
  error?: string;
}

export interface CircuitResult {
  counts: Record<string, number>;
  histogram: { state: string; count: number }[];
  fidelity?: number;
  executionTime?: string;
}

export function useCircuits() {
  return useQuery({
    queryKey: ['quantum-circuits'],
    queryFn: () => api.get<QuantumCircuit[]>('/quantum/circuits'),
  });
}

export function useCircuit(id: string) {
  return useQuery({
    queryKey: ['quantum-circuit', id],
    queryFn: () => api.get<QuantumCircuit>(`/quantum/circuits/${id}`),
    enabled: !!id,
  });
}

export function useCircuitResults(id: string) {
  return useQuery({
    queryKey: ['quantum-circuit', id, 'results'],
    queryFn: () => api.get<CircuitResult>(`/quantum/circuits/${id}/results`),
    enabled: !!id,
  });
}

export function useCreateCircuit() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: { name: string; qubits: number; qasm: string }) =>
      api.post<QuantumCircuit>('/quantum/circuits', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['quantum-circuits'] });
    },
  });
}

export function useExecuteCircuit() {
  return useMutation({
    mutationFn: (data: { circuitId: string; shots?: number }) =>
      api.post<QuantumJob>('/quantum/execute', data),
  });
}

export function useJobs() {
  return useQuery({
    queryKey: ['quantum-jobs'],
    queryFn: () => api.get<QuantumJob[]>('/quantum/jobs'),
    refetchInterval: 10_000,
  });
}

export function useJob(id: string) {
  return useQuery({
    queryKey: ['quantum-job', id],
    queryFn: () => api.get<QuantumJob>(`/quantum/jobs/${id}`),
    enabled: !!id,
    refetchInterval: 5_000,
  });
}
