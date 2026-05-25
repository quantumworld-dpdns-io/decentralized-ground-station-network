'use client';

import { useState } from 'react';

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState('profile');
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [profile, setProfile] = useState({
    displayName: 'Dennis Lee',
    email: 'dennis@example.com',
    organization: 'DGSN Labs',
    timezone: 'UTC',
  });
  const [notifications, setNotifications] = useState({
    emailAlerts: true,
    stationOffline: true,
    passReminders: true,
    quantumComplete: true,
    weeklyDigest: false,
  });
  const [apiKey, setApiKey] = useState('dgsn_sk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');

  const handleSave = async () => {
    setSaving(true);
    await new Promise((r) => setTimeout(r, 1000));
    setSaving(false);
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  const regenerateKey = () => {
    const chars = 'abcdef0123456789';
    const key = Array.from({ length: 32 }, () =>
      chars[Math.floor(Math.random() * chars.length)],
    ).join('');
    setApiKey(`dgsn_sk_${key}`);
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <p className="text-surface-400 mt-1">
          Manage your account and preferences
        </p>
      </div>

      <div className="glass rounded-xl p-1 flex">
        {(['profile', 'notifications', 'api', 'security'] as const).map(
          (tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-2 text-sm rounded-lg font-medium transition-all ${
                activeTab === tab
                  ? 'bg-primary-600 text-white'
                  : 'text-surface-400 hover:text-surface-200'
              }`}
            >
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
            </button>
          ),
        )}
      </div>

      <div className="glass rounded-2xl p-8 space-y-6">
        {activeTab === 'profile' && (
          <>
            <h3 className="text-lg font-semibold text-white">
              Profile Information
            </h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Display Name
                </label>
                <input
                  type="text"
                  value={profile.displayName}
                  onChange={(e) =>
                    setProfile((p) => ({ ...p, displayName: e.target.value }))
                  }
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Email
                </label>
                <input
                  type="email"
                  value={profile.email}
                  onChange={(e) =>
                    setProfile((p) => ({ ...p, email: e.target.value }))
                  }
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Organization
                </label>
                <input
                  type="text"
                  value={profile.organization}
                  onChange={(e) =>
                    setProfile((p) => ({ ...p, organization: e.target.value }))
                  }
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Timezone
                </label>
                <select
                  value={profile.timezone}
                  onChange={(e) =>
                    setProfile((p) => ({ ...p, timezone: e.target.value }))
                  }
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                >
                  <option value="UTC">UTC</option>
                  <option value="America/New_York">America/New_York</option>
                  <option value="America/Anchorage">America/Anchorage</option>
                  <option value="Europe/London">Europe/London</option>
                  <option value="Europe/Oslo">Europe/Oslo</option>
                  <option value="Asia/Tokyo">Asia/Tokyo</option>
                  <option value="Australia/Darwin">Australia/Darwin</option>
                </select>
              </div>
            </div>
          </>
        )}

        {activeTab === 'notifications' && (
          <>
            <h3 className="text-lg font-semibold text-white">
              Notification Preferences
            </h3>
            <div className="space-y-4">
              {Object.entries(notifications).map(([key, value]) => (
                <label
                  key={key}
                  className="flex items-center justify-between py-2"
                >
                  <div>
                    <div className="text-sm text-white">
                      {key
                        .replace(/([A-Z])/g, ' $1')
                        .replace(/^./, (s) => s.toUpperCase())}
                    </div>
                    <div className="text-xs text-surface-500">
                      Receive notifications for this event type
                    </div>
                  </div>
                  <button
                    onClick={() =>
                      setNotifications((n) => ({ ...n, [key]: !value }))
                    }
                    className={`relative w-12 h-6 rounded-full transition-colors ${
                      value ? 'bg-primary-600' : 'bg-surface-700'
                    }`}
                  >
                    <div
                      className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-transform ${
                        value ? 'translate-x-6' : 'translate-x-0.5'
                      }`}
                    />
                  </button>
                </label>
              ))}
            </div>
          </>
        )}

        {activeTab === 'api' && (
          <>
            <h3 className="text-lg font-semibold text-white">API Key</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Your API Key
                </label>
                <div className="flex gap-2">
                  <input
                    type="password"
                    value={apiKey}
                    readOnly
                    className="flex-1 px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white font-mono text-sm focus:outline-none"
                  />
                  <button
                    onClick={() => navigator.clipboard.writeText(apiKey)}
                    className="px-4 py-2 rounded-lg bg-surface-800 text-surface-300 hover:text-white text-sm transition-colors"
                  >
                    Copy
                  </button>
                </div>
              </div>
              <button
                onClick={regenerateKey}
                className="px-4 py-2 rounded-lg border border-red-500/30 text-red-400 hover:bg-red-500/10 text-sm transition-colors"
              >
                Regenerate Key
              </button>
              <div className="text-xs text-surface-500">
                Keep your API key secure. Regenerating will invalidate the
                current key immediately.
              </div>
            </div>
          </>
        )}

        {activeTab === 'security' && (
          <>
            <h3 className="text-lg font-semibold text-white">Security</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Current Password
                </label>
                <input
                  type="password"
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Current password"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  New Password
                </label>
                <input
                  type="password"
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Min. 12 characters"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-surface-300 mb-2">
                  Confirm New Password
                </label>
                <input
                  type="password"
                  className="w-full px-4 py-2.5 rounded-lg bg-surface-800 border border-surface-700 text-white focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
                  placeholder="Repeat new password"
                />
              </div>
              <div className="pt-2">
                <label className="flex items-center justify-between py-2">
                  <div>
                    <div className="text-sm text-white">
                      Two-Factor Authentication
                    </div>
                    <div className="text-xs text-surface-500">
                      Add an extra layer of security
                    </div>
                  </div>
                  <button className="px-4 py-1.5 rounded-lg bg-primary-600 text-white text-sm hover:bg-primary-500 transition-colors">
                    Enable
                  </button>
                </label>
              </div>
            </div>
          </>
        )}

        <div className="flex items-center gap-3 pt-2">
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-6 py-2.5 rounded-lg bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white font-medium transition-all disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
          {saved && (
            <span className="text-sm text-green-400">
              ✓ Settings saved successfully
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
