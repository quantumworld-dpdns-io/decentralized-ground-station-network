'use client';

import { useState, useRef, useEffect } from 'react';

interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
}

const suggestedQuestions = [
  'What satellites are overhead right now?',
  'Show me the status of all ground stations',
  'Analyze recent signal quality trends',
  'Schedule a pass for ISS at next opportunity',
  'Explain the quantum circuit optimization',
  'Verify the latest blockchain receipt',
];

export default function AIPage() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '0',
      role: 'assistant',
      content: "Hello! I'm your DGSN AI assistant. I can help you monitor stations, analyze signals, schedule passes, work with quantum circuits, and more. How can I help?",
      timestamp: new Date(),
    },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [model, setModel] = useState('gpt-4');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || loading) return;

    const userMsg: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: input.trim(),
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput('');
    setLoading(true);

    setTimeout(() => {
      const responses: Record<string, string> = {
        'stations': 'I can see 127 active stations in the network. Station Alpha (Fairbanks, AK) is online with 99.97% uptime. Station Beta (Tromsø, Norway) is also online. Would you like details on a specific station?',
        'signal': 'Recent signal quality is good across the network. Average SNR is 24.3 dB with signal strength at -71 dBm. NOAA-19 is currently active on 137.100 MHz with strong reception.',
        'quantum': 'Quantum processing is available with 32 qubit simulator. There are 847 circuits in the library and 12,453 jobs have been executed with 99.2% average fidelity.',
        'schedule': 'I see 14 upcoming passes in the next 24 hours. The next pass is ISS at 16:08 UTC with max elevation 67°. Would you like me to schedule a specific pass?',
        'receipt': 'The latest receipt was verified on block #18,457,234. All cryptographic signatures are valid. There are 47 pending receipts awaiting blockchain confirmation.',
      };

      let response = "I'll help you with that. Let me check the current network status...\n\nBased on my analysis:\n- Network is operating normally\n- All critical systems are within expected parameters\n- No anomalies detected\n\nIs there anything specific you'd like to know?";
      const lower = userMsg.content.toLowerCase();
      for (const [key, val] of Object.entries(responses)) {
        if (lower.includes(key)) {
          response = val;
          break;
        }
      }

      const assistantMsg: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response,
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, assistantMsg]);
      setLoading(false);
    }, 1500);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-12rem)]">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-white">AI Assistant</h1>
          <p className="text-surface-400 mt-1">
            Natural language interface for DGSN operations
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={model}
            onChange={(e) => setModel(e.target.value)}
            className="px-3 py-1.5 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="gpt-4">GPT-4</option>
            <option value="gpt-3.5">GPT-3.5</option>
            <option value="claude-3">Claude 3</option>
          </select>
          <button className="px-3 py-1.5 rounded-lg bg-surface-800 text-surface-300 hover:text-white text-sm transition-colors">
            Clear
          </button>
        </div>
      </div>

      <div className="flex-1 glass rounded-2xl flex flex-col overflow-hidden">
        <div className="flex-1 overflow-y-auto p-6 space-y-4 scrollbar-thin">
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
                    DGSN Assistant
                  </div>
                )}
                <div className="text-sm text-surface-200 whitespace-pre-wrap leading-relaxed">
                  {msg.content}
                </div>
              </div>
              {msg.role === 'user' && (
                <div className="w-8 h-8 rounded-lg bg-surface-700 flex items-center justify-center shrink-0">
                  <svg className="w-4 h-4 text-surface-300" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0" />
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
                  <div className="w-2 h-2 rounded-full bg-primary-400 animate-bounce" style={{ animationDelay: '0.2s' }} />
                  <div className="w-2 h-2 rounded-full bg-primary-400 animate-bounce" style={{ animationDelay: '0.4s' }} />
                </div>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {messages.length === 1 && (
          <div className="px-6 pb-4">
            <div className="flex flex-wrap gap-2">
              {suggestedQuestions.map((q) => (
                <button
                  key={q}
                  onClick={() => {
                    setInput(q);
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
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Ask about stations, signals, quantum, or anything DGSN..."
              rows={1}
              className="flex-1 px-4 py-2.5 rounded-xl bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 resize-none text-sm"
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || loading}
              className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
