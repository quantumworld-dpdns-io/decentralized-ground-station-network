'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from './client';

export interface Station {
  id: string;
  name: string;
  location: string;
  status: 'online' | 'offline' | 'maintenance' | 'error';
  type: string;
  uptime: number;
  lastContact: string;
  latitude: number;
  longitude: number;
  elevation?: number;
  hardware?: string;
  antenna?: string;
  frequencyRange?: {
    min: number;
    max: number;
  };
  createdAt?: string;
  ownerId?: string;
}

export interface StationMetrics {
  signalStrength: number;
  noiseFloor: number;
  temperature: number;
  uptime: number;
  lastPass?: string;
  nextPass?: string;
}

export interface StationPass {
  id: string;
  satellite: string;
  startTime: string;
  endTime: string;
  maxElevation: number;
  frequency: string;
}

export interface CreateStationInput {
  name: string;
  type: string;
  latitude: number;
  longitude: number;
  elevation?: number;
  timezone?: string;
  hardware?: string;
  antenna?: string;
  frequencyRange?: {
    min: number;
    max: number;
  };
  public?: boolean;
}

export function useStations() {
  return useQuery({
    queryKey: ['stations'],
    queryFn: () => api.get<Station[]>('/stations'),
  });
}

export function useStation(id: string) {
  return useQuery({
    queryKey: ['station', id],
    queryFn: () => api.get<Station>(`/stations/${id}`),
    enabled: !!id,
  });
}

export function useStationMetrics(id: string) {
  return useQuery({
    queryKey: ['station', id, 'metrics'],
    queryFn: () => api.get<StationMetrics>(`/stations/${id}/metrics`),
    enabled: !!id,
    refetchInterval: 30_000,
  });
}

export function useStationPasses(id: string) {
  return useQuery({
    queryKey: ['station', id, 'passes'],
    queryFn: () => api.get<StationPass[]>(`/stations/${id}/passes`),
    enabled: !!id,
  });
}

export function useCreateStation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateStationInput) =>
      api.post<Station>('/stations', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stations'] });
    },
  });
}

export function useUpdateStation(id: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: Partial<Station>) =>
      api.put<Station>(`/stations/${id}`, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['station', id] });
      queryClient.invalidateQueries({ queryKey: ['stations'] });
    },
  });
}

export function useDeleteStation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => api.delete(`/stations/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stations'] });
    },
  });
}
