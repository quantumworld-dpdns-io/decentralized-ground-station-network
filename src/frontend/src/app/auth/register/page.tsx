'use client';

import { useState } from 'react';
import Link from 'next/link';

export default function RegisterPage() {
  const [step, setStep] = useState(1);
  const [form, setForm] = useState({
    email: '',
    password: '',
    confirmPassword: '',
    displayName: '',
    organization: '',
    agreeTerms: false,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const updateField = (field: string, value: string | boolean) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match');
      setLoading(false);
      return;
    }

    try {
      const res = await fetch('/api/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: form.email,
          password: form.password,
          displayName: form.displayName,
          organization: form.organization,
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.message || 'Registration failed');
      }

      window.location.href = '/auth/login?registered=true';
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-surface-950 via-surface-900 to-primary-950 px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-primary-500 to-quantum-500 mb-4">
            <span className="text-3xl font-bold text-white">D</span>
          </div>
          <h1 className="text-3xl font-bold text-white">Create Account</h1>
          <p className="text-surface-400 mt-2">
            Join the Decentralized Ground Station Network
          </p>
        </div>

        <div className="flex items-center justify-center gap-2 mb-8">
          {[1, 2, 3].map((s) => (
            <div key={s} className="flex items-center gap-2">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-all ${
                  s <= step
                    ? 'bg-primary-600 text-white'
                    : 'bg-surface-800 text-surface-500'
                }`}
              >
                {s}
              </div>
              {s < 3 && (
                <div
                  className={`w-12 h-0.5 transition-colors ${
                    s < step ? 'bg-primary-600' : 'bg-surface-700'
                  }`}
                />
              )}
            </div>
          ))}
        </div>

        <form onSubmit={handleSubmit} className="glass rounded-2xl p-8 space-y-6">
          {error && (
            <div className="px-4 py-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              {error}
            </div>
          )}

          {step === 1 && (
            <>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Email Address
                </label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => updateField('email', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="you@example.com"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Password
                </label>
                <input
                  type="password"
                  value={form.password}
                  onChange={(e) => updateField('password', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Min. 12 characters"
                  minLength={12}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Confirm Password
                </label>
                <input
                  type="password"
                  value={form.confirmPassword}
                  onChange={(e) => updateField('confirmPassword', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Repeat password"
                  required
                />
              </div>
            </>
          )}

          {step === 2 && (
            <>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Display Name
                </label>
                <input
                  type="text"
                  value={form.displayName}
                  onChange={(e) => updateField('displayName', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Your name or callsign"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Organization (Optional)
                </label>
                <input
                  type="text"
                  value={form.organization}
                  onChange={(e) => updateField('organization', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="University, company, or group"
                />
              </div>
            </>
          )}

          {step === 3 && (
            <div className="space-y-4">
              <div className="glass rounded-xl p-4 text-sm text-surface-300 space-y-2">
                <p className="font-medium text-white">📋 Account Summary</p>
                <p>Email: {form.email}</p>
                <p>Name: {form.displayName}</p>
                <p>Organization: {form.organization || 'N/A'}</p>
              </div>
              <label className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={form.agreeTerms}
                  onChange={(e) => updateField('agreeTerms', e.target.checked)}
                  className="mt-1 rounded border-surface-600 bg-surface-800 text-primary-500 focus:ring-primary-500"
                  required
                />
                <span className="text-sm text-surface-400">
                  I agree to the{' '}
                  <Link href="#" className="text-primary-400 hover:text-primary-300">
                    Terms of Service
                  </Link>{' '}
                  and{' '}
                  <Link href="#" className="text-primary-400 hover:text-primary-300">
                    Privacy Policy
                  </Link>
                </span>
              </label>
            </div>
          )}

          <div className="flex gap-3">
            {step > 1 && (
              <button
                type="button"
                onClick={() => setStep((s) => s - 1)}
                className="flex-1 py-2.5 rounded-lg border border-surface-600 hover:border-primary-500 text-surface-200 hover:text-white font-medium transition-all"
              >
                Back
              </button>
            )}
            {step < 3 ? (
              <button
                type="button"
                onClick={() => setStep((s) => s + 1)}
                className="flex-1 py-2.5 rounded-lg bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white font-medium transition-all"
              >
                Continue
              </button>
            ) : (
              <button
                type="submit"
                disabled={loading || !form.agreeTerms}
                className="flex-1 py-2.5 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Creating Account...' : 'Create Account'}
              </button>
            )}
          </div>

          <p className="text-center text-sm text-surface-400">
            Already have an account?{' '}
            <Link
              href="/auth/login"
              className="text-primary-400 hover:text-primary-300 font-medium"
            >
              Sign in
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
}
