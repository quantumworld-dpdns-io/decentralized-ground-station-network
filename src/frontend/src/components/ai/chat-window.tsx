'use client';

import { useState, useRef, useEffect } from 'react';

interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
}

interface ChatWindowProps {
  messages: Message[];
  onSend: (message: string) => void;
  loading?: boolean;
  placeholder?: string;
  className?: string;
  suggestedQuestions?: string[];
}

export function ChatWindow({
  messages,
  onSend,
  loading = false,
  placeholder = 'Type a message...',
  className,
  suggestedQuestions = [],
}: ChatWindowProps) {
  const [input, setInput] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSend = () => {
    if (!input.trim() || loading) return;
    onSend(input.trim());
    setInput('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className={`flex flex-col h-full ${className || ''}`}>
      <div className="flex-1 overflow-y-auto p-4 space-y-4 scrollbar-thin">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex gap-3 ${msg.role === 'user' ? 'justify-end' : ''}`}
          >
            {msg.role === 'assistant' && (
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-500 to-quantum-500 flex items-center justify-center shrink-0">
                <span className="text-white text-xs font-bold">AI</span>
              </div>
            )}
            <div
              className={`max-w-[80%] rounded-2xl px-4 py-3 ${
                msg.role === 'user'
                  ? 'bg-primary-600/20 border border-primary-500/30'
                  : 'bg-surface-800/50 border border-surface-700/50'
              }`}
            >
              {msg.role === 'assistant' && (
                <div className="text-xs text-primary-400 mb-1 font-medium">
                  Assistant
                </div>
              )}
              <div className="text-sm text-surface-200 whitespace-pre-wrap leading-relaxed">
                {msg.content}
              </div>
              <div className="text-[10px] text-surface-600 mt-2">
                {msg.timestamp.toLocaleTimeString()}
              </div>
            </div>
            {msg.role === 'user' && (
              <div className="w-8 h-8 rounded-lg bg-surface-700 flex items-center justify-center shrink-0">
                <svg
                  className="w-4 h-4 text-surface-300"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"
                  />
                </svg>
              </div>
            )}
          </div>
        ))}

        {loading && (
          <div className="flex gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-500 to-quantum-500 flex items-center justify-center shrink-0">
              <span className="text-white text-xs font-bold">AI</span>
            </div>
            <div className="bg-surface-800/50 border border-surface-700/50 rounded-2xl px-4 py-3">
              <div className="flex gap-1">
                <div className="w-2 h-2 rounded-full bg-primary-400 animate-bounce" />
                <div
                  className="w-2 h-2 rounded-full bg-primary-400 animate-bounce"
                  style={{ animationDelay: '0.2s' }}
                />
                <div
                  className="w-2 h-2 rounded-full bg-primary-400 animate-bounce"
                  style={{ animationDelay: '0.4s' }}
                />
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {messages.length === 1 && suggestedQuestions.length > 0 && (
        <div className="px-4 pb-2">
          <div className="flex flex-wrap gap-2">
            {suggestedQuestions.map((q) => (
              <button
                key={q}
                onClick={() => {
                  setInput(q);
                  inputRef.current?.focus();
                }}
                className="px-3 py-1.5 text-xs rounded-full bg-surface-800 text-surface-300 hover:text-white hover:bg-surface-700 border border-surface-700 transition-all"
              >
                {q}
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="border-t border-surface-800 p-4">
        <div className="flex gap-3">
          <textarea
            ref={inputRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={placeholder}
            rows={1}
            className="flex-1 px-4 py-2.5 rounded-xl bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 resize-none text-sm"
          />
          <button
            onClick={handleSend}
            disabled={!input.trim() || loading}
            className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={1.5}
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}
