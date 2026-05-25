'use client';

import { useQuery, useMutation } from '@tanstack/react-query';
import { api } from './client';

export interface Receipt {
  id: string;
  blockNumber: number;
  stationId: string;
  stationName: string;
  satellite: string;
  timestamp: string;
  frequency: string;
  dataSize: string;
  status: 'verified' | 'pending' | 'failed';
  txHash: string;
  signature?: string;
  publicKey?: string;
  verificationProof?: string;
}

export interface ReceiptVerificationResult {
  valid: boolean;
  message: string;
  verifiedAt?: string;
  verifiedBy?: string;
}

export function useReceipts(params?: { status?: string; limit?: number }) {
  const searchParams: Record<string, string> = {};
  if (params?.status) searchParams.status = params.status;
  if (params?.limit) searchParams.limit = String(params.limit);

  return useQuery({
    queryKey: ['receipts', params],
    queryFn: () => api.get<Receipt[]>('/receipts', searchParams),
  });
}

export function useReceipt(id: string) {
  return useQuery({
    queryKey: ['receipt', id],
    queryFn: () => api.get<Receipt>(`/receipts/${id}`),
    enabled: !!id,
  });
}

export function useVerifyReceipt() {
  return useMutation({
    mutationFn: (id: string) =>
      api.post<ReceiptVerificationResult>(`/receipts/${id}/verify`),
  });
}

export function useReceiptChain(id: string) {
  return useQuery({
    queryKey: ['receipt', id, 'chain'],
    queryFn: () =>
      api.get<{ block: number; hash: string; prevHash: string; timestamp: string }[]>(
        `/receipts/${id}/chain`,
      ),
    enabled: !!id,
  });
}
