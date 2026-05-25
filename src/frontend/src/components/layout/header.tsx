'use client';

import { useState } from 'react';
import { signOut } from 'next-auth/react';

interface HeaderProps {
  onMenuClick: () => void;
  user: {
    id: string;
    name: string;
    email: string;
    role: string;
  } | null;
}

export function Header({ onMenuClick, user }: HeaderProps) {
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);

  const notifications = [
    { id: 'n1', title: 'Station Alpha offline', time: '2m ago', type: 'error' as const },
    { id: 'n2', title: 'Receipt verified on chain', time: '5m ago', type: 'success' as const },
    { id: 'n3', title: 'Quantum job completed', time: '10m ago', type: 'info' as const },
  ];

  return (
    <header className="sticky top-0 z-30 glass border-b border-surface-800">
      <div className="flex items-center justify-between h-16 px-6">
        <div className="flex items-center gap-4">
          <button
            onClick={onMenuClick}
            className="text-surface-400 hover:text-white transition-colors"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={1.5}
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            </svg>
          </button>

          <div className="hidden md:flex items-center gap-2 flex-1 max-w-md">
            <div className="relative w-full">
              <svg
                className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-surface-500"
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={1.5}
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
              <input
                type="text"
                placeholder="Search stations, receipts, circuits..."
                className="w-full pl-10 pr-4 py-2 rounded-lg bg-surface-800/50 border border-surface-700 text-white placeholder:text-surface-500 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all"
              />
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className="relative p-2 rounded-lg text-surface-400 hover:text-white hover:bg-surface-800 transition-all"
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
                  d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"
                />
              </svg>
              <span className="absolute top-1 right-1 w-2 h-2 rounded-full bg-primary-500" />
            </button>

            {showNotifications && (
              <div className="absolute right-0 mt-2 w-80 glass rounded-xl border border-surface-700 shadow-xl overflow-hidden">
                <div className="p-3 border-b border-surface-800">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-white">
                      Notifications
                    </span>
                    <button className="text-xs text-primary-400 hover:text-primary-300">
                      Mark all read
                    </button>
                  </div>
                </div>
                <div className="max-h-64 overflow-y-auto">
                  {notifications.map((n) => (
                    <div
                      key={n.id}
                      className="flex items-start gap-3 px-4 py-3 hover:bg-surface-800/50 cursor-pointer border-b border-surface-800/50 last:border-0"
                    >
                      <div
                        className={`w-2 h-2 rounded-full mt-1.5 ${
                          n.type === 'error'
                            ? 'bg-red-500'
                            : n.type === 'success'
                              ? 'bg-green-500'
                              : 'bg-primary-500'
                        }`}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="text-sm text-white">{n.title}</div>
                        <div className="text-xs text-surface-500">{n.time}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-surface-800 transition-all"
            >
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-500 to-quantum-500 flex items-center justify-center">
                <span className="text-white text-sm font-medium">
                  {user?.name?.charAt(0) || 'U'}
                </span>
              </div>
              <div className="hidden md:block text-left">
                <div className="text-sm font-medium text-white">
                  {user?.name || 'User'}
                </div>
                <div className="text-xs text-surface-400 capitalize">
                  {user?.role || 'Operator'}
                </div>
              </div>
            </button>

            {showUserMenu && (
              <div className="absolute right-0 mt-2 w-56 glass rounded-xl border border-surface-700 shadow-xl overflow-hidden">
                <div className="p-3 border-b border-surface-800">
                  <div className="text-sm font-medium text-white">{user?.name}</div>
                  <div className="text-xs text-surface-500">{user?.email}</div>
                </div>
                <div className="py-1">
                  <button className="w-full px-4 py-2 text-left text-sm text-surface-300 hover:bg-surface-800 hover:text-white transition-colors">
                    Profile
                  </button>
                  <button className="w-full px-4 py-2 text-left text-sm text-surface-300 hover:bg-surface-800 hover:text-white transition-colors">
                    Settings
                  </button>
                  <button className="w-full px-4 py-2 text-left text-sm text-surface-300 hover:bg-surface-800 hover:text-white transition-colors">
                    API Keys
                  </button>
                </div>
                <div className="border-t border-surface-800 py-1">
                  <button
                    onClick={() => signOut({ callbackUrl: '/auth/login' })}
                    className="w-full px-4 py-2 text-left text-sm text-red-400 hover:bg-surface-800 transition-colors"
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
