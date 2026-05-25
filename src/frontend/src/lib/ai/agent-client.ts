'use client';

import { useWebSocket } from '@/lib/hooks/use-websocket';
import { useCallback } from 'react';

export interface AgentMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export interface AgentAction {
  type: string;
  parameters: Record<string, unknown>;
  status: 'pending' | 'executing' | 'completed' | 'failed';
  result?: unknown;
  error?: string;
}

export interface AgentState {
  agentId: string;
  status: 'idle' | 'thinking' | 'responding' | 'error';
  currentAction?: AgentAction;
  conversationId: string;
}

type MessageHandler = (message: AgentMessage) => void;
type StateHandler = (state: AgentState) => void;
type ActionHandler = (action: AgentAction) => void;

export function createAgentClient(agentId: string) {
  const messageHandlers = new Set<MessageHandler>();
  const stateHandlers = new Set<StateHandler>();
  const actionHandlers = new Set<ActionHandler>();

  const wsUrl =
    typeof window !== 'undefined'
      ? `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${
          window.location.host
        }/ws/agent/${agentId}`
      : '';

  function handleMessage(data: unknown) {
    const msg = data as { type: string; payload: unknown };

    switch (msg.type) {
      case 'message':
        messageHandlers.forEach((h) => h(msg.payload as AgentMessage));
        break;
      case 'state':
        stateHandlers.forEach((h) => h(msg.payload as AgentState));
        break;
      case 'action':
        actionHandlers.forEach((h) => h(msg.payload as AgentAction));
        break;
    }
  }

  function useAgent() {
    const { send, status } = useWebSocket({
      url: wsUrl,
      onMessage: handleMessage,
      reconnect: true,
    });

    const sendMessage = useCallback(
      (content: string) => {
        send({
          type: 'message',
          payload: {
            role: 'user',
            content,
            timestamp: new Date().toISOString(),
          },
        });
      },
      [send],
    );

    const executeAction = useCallback(
      (action: string, parameters: Record<string, unknown>) => {
        send({
          type: 'action',
          payload: { type: action, parameters },
        });
      },
      [send],
    );

    const onMessage = useCallback((handler: MessageHandler) => {
      messageHandlers.add(handler);
      return () => messageHandlers.delete(handler);
    }, []);

    const onStateChange = useCallback((handler: StateHandler) => {
      stateHandlers.add(handler);
      return () => stateHandlers.delete(handler);
    }, []);

    const onAction = useCallback((handler: ActionHandler) => {
      actionHandlers.add(handler);
      return () => actionHandlers.delete(handler);
    }, []);

    return {
      sendMessage,
      executeAction,
      onMessage,
      onStateChange,
      onAction,
      connectionStatus: status,
    };
  }

  return { useAgent };
}
