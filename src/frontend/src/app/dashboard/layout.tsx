'use client';

import { Sidebar } from '@/components/layout/sidebar';
import { Header } from '@/components/layout/header';
import { useAuth } from '@/lib/hooks/use-auth';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';

const breadcrumbMap: Record<string, string> = {
  '/dashboard': 'Overview',
  '/dashboard/stations': 'Stations',
  '/dashboard/stations/register': 'Register Station',
  '/dashboard/receipts': 'Receipts',
  '/dashboard/schedule': 'Schedule',
  '/dashboard/quantum': 'Quantum',
  '/dashboard/quantum/circuits': 'Circuits',
  '/dashboard/quantum/jobs': 'Jobs',
  '/dashboard/signal': 'Signal Monitoring',
  '/dashboard/ai': 'AI Assistant',
  '/dashboard/ai/agents': 'Agents',
  '/dashboard/settings': 'Settings',
  '/dashboard/admin': 'Admin',
};

function getBreadcrumbs(path: string): { label: string; href: string }[] {
  const parts = path.split('/').filter(Boolean);
  const crumbs = [{ label: 'Dashboard', href: '/dashboard' }];
  let current = '/dashboard';
  for (let i = 1; i < parts.length; i++) {
    current += `/${parts[i]}`;
    const label = breadcrumbMap[current] || parts[i];
    crumbs.push({ label, href: current });
  }
  return crumbs;
}

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user, isLoading } = useAuth();
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const breadcrumbs = getBreadcrumbs(pathname);

  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 768) setSidebarOpen(false);
    };
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-surface-950">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary-500 to-quantum-500 animate-pulse" />
          <div className="text-surface-400 text-sm">Loading dashboard...</div>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-surface-950">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-white mb-2">
            Access Denied
          </h2>
          <p className="text-surface-400 mb-4">
            Please sign in to access the dashboard.
          </p>
          <a
            href="/auth/login"
            className="px-6 py-2 rounded-lg bg-primary-600 text-white hover:bg-primary-500 transition-colors"
          >
            Sign In
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface-950">
      <Sidebar isOpen={sidebarOpen} onToggle={() => setSidebarOpen(!sidebarOpen)} />
      <div
        className={`transition-all duration-300 ${
          sidebarOpen ? 'ml-64' : 'ml-16'
        }`}
      >
        <Header
          onMenuClick={() => setSidebarOpen(!sidebarOpen)}
          user={user}
        />
        <div className="px-6 pt-4">
          <nav className="flex items-center gap-2 text-sm text-surface-400 mb-6">
            {breadcrumbs.map((crumb, i) => (
              <span key={crumb.href} className="flex items-center gap-2">
                {i > 0 && (
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    strokeWidth={1.5}
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M8.25 4.5l7.5 7.5-7.5 7.5"
                    />
                  </svg>
                )}
                <a
                  href={crumb.href}
                  className={`hover:text-white transition-colors ${
                    i === breadcrumbs.length - 1
                      ? 'text-white font-medium'
                      : ''
                  }`}
                >
                  {crumb.label === pathname.split('/').pop() || pathname === crumb.href
                    ? crumb.label
                        .split('-')
                        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
                        .join(' ')
                    : crumb.label
                        .split('-')
                        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
                        .join(' ')}
                </a>
              </span>
            ))}
          </nav>
        </div>
        <main className="px-6 pb-8">{children}</main>
      </div>
    </div>
  );
}
