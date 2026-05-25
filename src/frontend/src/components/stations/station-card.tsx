'use client';

import { cn } from '@/lib/utils/cn';

interface StationCardProps {
  id: string;
  name: string;
  location: string;
  status: 'online' | 'offline' | 'maintenance' | 'error';
  type: string;
  uptime: number;
  lastContact: string;
  onClick?: () => void;
  selected?: boolean;
}

const statusConfig: Record<string, { color: string; label: string }> = {
  online: { color: 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]', label: 'Online' },
  offline: { color: 'bg-red-500', label: 'Offline' },
  maintenance: { color: 'bg-yellow-500 shadow-[0_0_8px_rgba(234,179,8,0.5)]', label: 'Maintenance' },
  error: { color: 'bg-red-500 animate-pulse', label: 'Error' },
};

export function StationCard({
  name,
  location,
  status,
  type,
  uptime,
  lastContact,
  onClick,
  selected,
}: StationCardProps) {
  const cfg = statusConfig[status];

  return (
    <div
      onClick={onClick}
      className={cn(
        'glass rounded-xl p-5 cursor-pointer transition-all hover:scale-[1.02]',
        selected && 'ring-2 ring-primary-500',
      )}
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className={cn('w-2.5 h-2.5 rounded-full', cfg.color)} />
          <div>
            <h3 className="font-semibold text-white text-sm">{name}</h3>
            <p className="text-xs text-surface-500">{location}</p>
          </div>
        </div>
        <span className="text-xs text-surface-500">{lastContact}</span>
      </div>

      <div className="flex items-center justify-between text-xs">
        <span className="text-surface-400">{type}</span>
        <span className={cn(
          'font-medium',
          status === 'online' ? 'text-green-400' : status === 'maintenance' ? 'text-yellow-400' : 'text-red-400'
        )}>
          {cfg.label}
        </span>
      </div>

      <div className="mt-3">
        <div className="flex items-center justify-between text-xs mb-1">
          <span className="text-surface-500">Uptime</span>
          <span className="text-surface-400">{uptime}%</span>
        </div>
        <div className="h-1.5 rounded-full bg-surface-800 overflow-hidden">
          <div
            className={cn(
              'h-full rounded-full transition-all',
              uptime >= 99 ? 'bg-green-500' : uptime >= 95 ? 'bg-yellow-500' : 'bg-red-500',
            )}
            style={{ width: `${uptime}%` }}
          />
        </div>
      </div>
    </div>
  );
}
