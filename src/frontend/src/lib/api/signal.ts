'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from './client';

export interface SignalSource {
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

export interface SignalMetrics {
  frequency: number;
  centerFrequency: number;
  span: number;
  signalStrength: number;
  noiseFloor: number;
  snr: number;
  dopplerShift: number;
  elevation: number;
  polarization: string;
  dataRate: string;
  encoding: string;
}

export interface WaterfallFrame {
  data: number[][];
  startFrequency: number;
  endFrequency: number;
  timestamp: string;
}

export function useSignals() {
  return useQuery({
    queryKey: ['signals'],
    queryFn: () => api.get<SignalSource[]>('/signal'),
    refetchInterval: 15_000,
  });
}

export function useSignal(id: string) {
  return useQuery({
    queryKey: ['signal', id],
    queryFn: () => api.get<SignalSource>(`/signal/${id}`),
    enabled: !!id,
    refetchInterval: 10_000,
  });
}

export function useSignalMetrics(id: string) {
  return useQuery({
    queryKey: ['signal', id, 'metrics'],
    queryFn: () => api.get<SignalMetrics>(`/signal/${id}/metrics`),
    enabled: !!id,
    refetchInterval: 30_000,
  });
}

export function useWaterfall(params?: {
  frequency?: number;
  span?: number;
}) {
  const searchParams: Record<string, string> = {};
  if (params?.frequency) searchParams.frequency = String(params.frequency);
  if (params?.span) searchParams.span = String(params.span);

  return useQuery({
    queryKey: ['signal-waterfall', params],
    queryFn: () => api.get<WaterfallFrame[]>('/signal/waterfall', searchParams),
    refetchInterval: 1_000,
  });
}
