'use client';

import { useEffect, useCallback } from 'react';
import { useWebSocket } from './use-websocket';
import { useQueryClient } from '@tanstack/react-query';

interface RealtimeEvent {
  type: string;
  payload: unknown;
  timestamp: string;
}

type EventHandler = (event: RealtimeEvent) => void;

const handlers = new Map<string, Set<EventHandler>>();

export function onRealtimeEvent(type: string, handler: EventHandler) {
  if (!handlers.has(type)) {
    handlers.set(type, new Set());
  }
  handlers.get(type)!.add(handler);
  return () => handlers.get(type)?.delete(handler);
}

export function useRealtime() {
  const queryClient = useQueryClient();

  const handleMessage = useCallback(
    (data: unknown) => {
      const event = data as RealtimeEvent;
      if (!event?.type) return;

      const eventHandlers = handlers.get(event.type);
      eventHandlers?.forEach((handler) => handler(event));

      switch (event.type) {
        case 'station:update':
          queryClient.invalidateQueries({ queryKey: ['stations'] });
          break;
        case 'station:metrics':
          queryClient.invalidateQueries({ queryKey: ['station', 'metrics'] });
          break;
        case 'receipt:new':
          queryClient.invalidateQueries({ queryKey: ['receipts'] });
          break;
        case 'receipt:verify':
          queryClient.invalidateQueries({ queryKey: ['receipt', 'chain'] });
          break;
        case 'signal:update':
          queryClient.invalidateQueries({ queryKey: ['signals'] });
          break;
        case 'signal:waterfall':
          queryClient.invalidateQueries({ queryKey: ['signal-waterfall'] });
          break;
        case 'quantum:job':
          queryClient.invalidateQueries({ queryKey: ['quantum-jobs'] });
          break;
        case 'quantum:result':
          queryClient.invalidateQueries({ queryKey: ['quantum-circuit', 'results'] });
          break;
      }
    },
    [queryClient],
  );

  const wsUrl =
    typeof window !== 'undefined'
      ? `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${
          window.location.host
        }/ws/events`
      : '';

  const { status, send } = useWebSocket({
    url: wsUrl,
    onMessage: handleMessage,
    reconnect: true,
    reconnectInterval: 3000,
  });

  const subscribe = useCallback(
    (channel: string, filter?: Record<string, unknown>) => {
      send({ type: 'subscribe', channel, filter });
    },
    [send],
  );

  const unsubscribe = useCallback(
    (channel: string) => {
      send({ type: 'unsubscribe', channel });
    },
    [send],
  );

  return { status, subscribe, unsubscribe };
}
