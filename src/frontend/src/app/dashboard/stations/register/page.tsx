'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function RegisterStationPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    name: '',
    type: 'S-Band',
    latitude: '',
    longitude: '',
    elevation: '',
    timezone: 'UTC',
    hardware: '',
    antenna: '',
    frequency_range_min: '',
    frequency_range_max: '',
    public: true,
    agree_terms: false,
  });

  const updateField = (field: string, value: string | boolean) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/v1/stations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...form,
          latitude: parseFloat(form.latitude),
          longitude: parseFloat(form.longitude),
          elevation: parseFloat(form.elevation),
          frequencyRange: {
            min: parseFloat(form.frequency_range_min),
            max: parseFloat(form.frequency_range_max),
          },
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.message || 'Registration failed');
      }

      const station = await res.json();
      router.push(`/dashboard/stations/${station.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Register Station</h1>
        <p className="text-surface-400 mt-1">
          Add a new ground station to the DGSN network
        </p>
      </div>

      <div className="flex items-center justify-center gap-2 mb-4">
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
                className={`w-16 h-0.5 transition-colors ${
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
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-surface-300 mb-2">
                Station Name
              </label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => updateField('name', e.target.value)}
                className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                placeholder="e.g., My Ground Station"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-surface-300 mb-2">
                Station Type
              </label>
              <select
                value={form.type}
                onChange={(e) => updateField('type', e.target.value)}
                className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
              >
                <option value="S-Band">S-Band</option>
                <option value="X-Band">X-Band</option>
                <option value="UHF">UHF</option>
                <option value="VHF">VHF</option>
                <option value="L-Band">L-Band</option>
              </select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Latitude
                </label>
                <input
                  type="number"
                  step="any"
                  value={form.latitude}
                  onChange={(e) => updateField('latitude', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="64.8378"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Longitude
                </label>
                <input
                  type="number"
                  step="any"
                  value={form.longitude}
                  onChange={(e) => updateField('longitude', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="-147.7164"
                  required
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Elevation (m)
                </label>
                <input
                  type="number"
                  value={form.elevation}
                  onChange={(e) => updateField('elevation', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="142"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Timezone
                </label>
                <select
                  value={form.timezone}
                  onChange={(e) => updateField('timezone', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                >
                  <option value="UTC">UTC</option>
                  <option value="America/Anchorage">America/Anchorage</option>
                  <option value="Europe/Oslo">Europe/Oslo</option>
                  <option value="Australia/Darwin">Australia/Darwin</option>
                </select>
              </div>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-surface-300 mb-2">
                Hardware Model
              </label>
              <input
                type="text"
                value={form.hardware}
                onChange={(e) => updateField('hardware', e.target.value)}
                className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                placeholder="e.g., HackRF One, USRP B210"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-surface-300 mb-2">
                Antenna Type
              </label>
              <input
                type="text"
                value={form.antenna}
                onChange={(e) => updateField('antenna', e.target.value)}
                className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                placeholder="e.g., Yagi-Uda, Parabolic Dish"
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Frequency Min (MHz)
                </label>
                <input
                  type="number"
                  value={form.frequency_range_min}
                  onChange={(e) => updateField('frequency_range_min', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="137"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Frequency Max (MHz)
                </label>
                <input
                  type="number"
                  value={form.frequency_range_max}
                  onChange={(e) => updateField('frequency_range_max', e.target.value)}
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="138"
                />
              </div>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-4">
            <div className="glass rounded-xl p-4 text-sm text-surface-300 space-y-2">
              <p className="font-medium text-white">📋 Station Summary</p>
              <p>Name: {form.name}</p>
              <p>Type: {form.type}</p>
              <p>Location: {form.latitude}, {form.longitude}</p>
              <p>Hardware: {form.hardware || 'N/A'}</p>
              <p>Antenna: {form.antenna || 'N/A'}</p>
            </div>

            <label className="flex items-center gap-3">
              <input
                type="checkbox"
                checked={form.public}
                onChange={(e) => updateField('public', e.target.checked)}
                className="rounded border-surface-600 bg-surface-800 text-primary-500 focus:ring-primary-500"
              />
              <span className="text-sm text-surface-300">
                Make this station publicly visible
              </span>
            </label>

            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                checked={form.agree_terms}
                onChange={(e) => updateField('agree_terms', e.target.checked)}
                className="mt-1 rounded border-surface-600 bg-surface-800 text-primary-500 focus:ring-primary-500"
                required
              />
              <span className="text-sm text-surface-400">
                I confirm that this station complies with DGSN network
                requirements and local regulations
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
              disabled={loading || !form.agree_terms}
              className="flex-1 py-2.5 rounded-lg bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Registering...' : 'Register Station'}
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
