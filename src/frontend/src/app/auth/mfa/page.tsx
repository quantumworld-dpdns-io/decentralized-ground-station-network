'use client';

import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';

export default function MFAPage() {
  const router = useRouter();
  const [code, setCode] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [method, setMethod] = useState<'totp' | 'sms' | 'backup'>('totp');
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  const handleCodeChange = (index: number, value: string) => {
    if (value.length > 1) {
      const digits = value.replace(/\D/g, '').split('');
      const newCode = [...code];
      digits.forEach((d, i) => {
        if (index + i < 6) newCode[index + i] = d;
      });
      setCode(newCode);
      const nextIdx = Math.min(index + digits.length, 5);
      inputRefs.current[nextIdx]?.focus();
      return;
    }

    if (!/^\d*$/.test(value)) return;
    const newCode = [...code];
    newCode[index] = value;
    setCode(newCode);

    if (value && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !code[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
    if (e.key === 'Enter') {
      handleVerify();
    }
  };

  const handleVerify = async () => {
    const token = code.join('');
    if (token.length !== 6) {
      setError('Please enter the complete 6-digit code');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/v1/auth/mfa/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ method, token }),
      });

      if (!res.ok) throw new Error('Invalid verification code');
      router.push('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Verification failed');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (method !== 'sms') return;
    setLoading(true);
    try {
      await fetch('/api/v1/auth/mfa/send', { method: 'POST' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-surface-950 via-surface-900 to-primary-950 px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-chain-500 to-primary-500 mb-4">
            <svg
              className="w-8 h-8 text-white"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={1.5}
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
              />
            </svg>
          </div>
          <h1 className="text-3xl font-bold text-white">
            Two-Factor Authentication
          </h1>
          <p className="text-surface-400 mt-2">
            Enter the verification code from your authenticator app
          </p>
        </div>

        <div className="glass rounded-2xl p-8 space-y-6">
          <div className="flex justify-center gap-2">
            {(['totp', 'sms', 'backup'] as const).map((m) => (
              <button
                key={m}
                onClick={() => setMethod(m)}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                  method === m
                    ? 'bg-primary-600 text-white'
                    : 'bg-surface-800 text-surface-400 hover:text-surface-200'
                }`}
              >
                {m === 'totp'
                  ? 'App'
                  : m === 'sms'
                    ? 'SMS'
                    : 'Backup Code'}
              </button>
            ))}
          </div>

          {error && (
            <div className="px-4 py-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              {error}
            </div>
          )}

          <div className="flex justify-center gap-3">
            {code.map((digit, index) => (
              <input
                key={index}
                ref={(el) => {
                  inputRefs.current[index] = el;
                }}
                type="text"
                inputMode="numeric"
                maxLength={1}
                value={digit}
                onChange={(e) => handleCodeChange(index, e.target.value)}
                onKeyDown={(e) => handleKeyDown(index, e)}
                className="w-12 h-14 text-center text-xl font-bold rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all"
              />
            ))}
          </div>

          <button
            onClick={handleVerify}
            disabled={loading || code.join('').length !== 6}
            className="w-full py-2.5 rounded-lg bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Verifying...' : 'Verify'}
          </button>

          <div className="text-center">
            {method === 'sms' && (
              <button
                onClick={handleResend}
                disabled={loading}
                className="text-sm text-primary-400 hover:text-primary-300 transition-colors"
              >
                Resend code
              </button>
            )}
            <p className="text-sm text-surface-500 mt-2">
              Having trouble?{' '}
              <button className="text-primary-400 hover:text-primary-300 transition-colors">
                Use recovery codes
              </button>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
