'use client';

import { cn } from '@/lib/utils/cn';

interface ReceiptCardProps {
  id: string;
  blockNumber: number;
  stationName: string;
  satellite: string;
  timestamp: string;
  frequency: string;
  dataSize: string;
  status: 'verified' | 'pending' | 'failed';
  onClick?: () => void;
}

const statusConfig: Record<string, { color: string; bg: string; label: string }> = {
  verified: { color: 'text-green-400', bg: 'bg-green-500/10', label: 'Verified' },
  pending: { color: 'text-yellow-400', bg: 'bg-yellow-500/10', label: 'Pending' },
  failed: { color: 'text-red-400', bg: 'bg-red-500/10', label: 'Failed' },
};

export function ReceiptCard({
  id,
  blockNumber,
  stationName,
  satellite,
  timestamp,
  frequency,
  dataSize,
  status,
  onClick,
}: ReceiptCardProps) {
  const cfg = statusConfig[status];

  return (
    <div
      onClick={onClick}
      className="glass rounded-xl p-4 cursor-pointer glass-hover"
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className={cn('w-2 h-2 rounded-full', status === 'verified' ? 'bg-green-500' : status === 'pending' ? 'bg-yellow-500' : 'bg-red-500')} />
          <span className="font-mono text-sm text-primary-400">{id}</span>
        </div>
        <span className={cn('px-2 py-0.5 text-xs rounded-full', cfg.bg, cfg.color)}>
          {cfg.label}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-2 text-xs">
        <div>
          <span className="text-surface-500">Station:</span>{' '}
          <span className="text-surface-300">{stationName}</span>
        </div>
        <div>
          <span className="text-surface-500">Satellite:</span>{' '}
          <span className="text-surface-300">{satellite}</span>
        </div>
        <div>
          <span className="text-surface-500">Block:</span>{' '}
          <span className="text-surface-300 font-mono">
            #{blockNumber.toLocaleString()}
          </span>
        </div>
        <div>
          <span className="text-surface-500">Size:</span>{' '}
          <span className="text-surface-300">{dataSize}</span>
        </div>
        <div>
          <span className="text-surface-500">Frequency:</span>{' '}
          <span className="text-surface-300 font-mono">{frequency}</span>
        </div>
        <div>
          <span className="text-surface-500">Time:</span>{' '}
          <span className="text-surface-300">{timestamp}</span>
        </div>
      </div>
    </div>
  );
}
