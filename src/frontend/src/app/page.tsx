import Link from 'next/link';

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-surface-950 via-surface-900 to-primary-950">
      <header className="fixed top-0 w-full z-50 glass">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-500 to-quantum-500 flex items-center justify-center">
                <span className="text-white font-bold text-sm">D</span>
              </div>
              <span className="font-bold text-lg text-white">DGSN</span>
            </div>
            <nav className="hidden md:flex items-center gap-6">
              <Link
                href="#features"
                className="text-surface-300 hover:text-white transition-colors text-sm"
              >
                Features
              </Link>
              <Link
                href="#network"
                className="text-surface-300 hover:text-white transition-colors text-sm"
              >
                Network
              </Link>
              <Link
                href="/auth/login"
                className="px-4 py-2 rounded-lg bg-primary-600 hover:bg-primary-500 text-white text-sm font-medium transition-colors"
              >
                Sign In
              </Link>
              <Link
                href="/auth/register"
                className="px-4 py-2 rounded-lg border border-surface-600 hover:border-primary-500 text-surface-200 hover:text-white text-sm font-medium transition-all"
              >
                Get Started
              </Link>
            </nav>
          </div>
        </div>
      </header>

      <main>
        <section className="pt-32 pb-20 px-4">
          <div className="max-w-5xl mx-auto text-center">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full glass text-sm text-primary-300 mb-8">
              <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              Network Active — 127 Stations Online
            </div>
            <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6">
              <span className="text-white">Decentralized</span>{' '}
              <span className="text-gradient">Ground Station</span>{' '}
              <span className="text-white">Network</span>
            </h1>
            <p className="text-xl text-surface-400 max-w-3xl mx-auto mb-12 leading-relaxed">
              A blockchain-powered global network of satellite ground stations.
              Secure, quantum-resistant, and community-owned satellite
              communications infrastructure.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link
                href="/auth/register"
                className="px-8 py-3 rounded-xl bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-semibold text-lg transition-all shadow-lg shadow-primary-500/25"
              >
                Join the Network
              </Link>
              <Link
                href="#features"
                className="px-8 py-3 rounded-xl glass glass-hover text-white font-semibold text-lg transition-all"
              >
                Learn More
              </Link>
            </div>
          </div>
        </section>

        <section
          id="features"
          className="py-20 px-4 bg-surface-900/50"
        >
          <div className="max-w-7xl mx-auto">
            <h2 className="text-3xl md:text-4xl font-bold text-center text-white mb-16">
              Everything You Need for{' '}
              <span className="text-gradient">Satellite Comms</span>
            </h2>
            <div className="grid md:grid-cols-3 gap-8">
              {features.map((feature) => (
                <div
                  key={feature.title}
                  className="glass rounded-2xl p-8 glass-hover"
                >
                  <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary-500/20 to-quantum-500/20 flex items-center justify-center mb-4">
                    <feature.icon className="w-6 h-6 text-primary-400" />
                  </div>
                  <h3 className="text-xl font-semibold text-white mb-3">
                    {feature.title}
                  </h3>
                  <p className="text-surface-400 leading-relaxed">
                    {feature.description}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="network" className="py-20 px-4">
          <div className="max-w-7xl mx-auto">
            <div className="glass rounded-3xl p-8 md:p-12 relative overflow-hidden">
              <div className="absolute inset-0 bg-grid-pattern opacity-20" />
              <div className="relative z-10">
                <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">
                  Global Station Coverage
                </h2>
                <p className="text-surface-400 text-lg mb-8 max-w-2xl">
                  Our network spans across 6 continents with 127 active ground
                  stations. Each station is verified on-chain with hardware-
                  backed identities.
                </p>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
                  {stats.map((stat) => (
                    <div key={stat.label}>
                      <div className="text-3xl font-bold text-white mb-1">
                        {stat.value}
                      </div>
                      <div className="text-sm text-surface-400">
                        {stat.label}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="py-20 px-4 bg-surface-900/50">
          <div className="max-w-4xl mx-auto text-center">
            <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">
              Ready to Join the{' '}
              <span className="text-gradient">Decentralized Future</span>?
            </h2>
            <p className="text-surface-400 text-lg mb-8">
              Deploy your own ground station, earn rewards, and help build a
              resilient global satellite infrastructure.
            </p>
            <Link
              href="/auth/register"
              className="inline-flex px-8 py-3 rounded-xl bg-gradient-to-r from-primary-600 to-quantum-600 hover:from-primary-500 hover:to-quantum-500 text-white font-semibold text-lg transition-all shadow-lg shadow-primary-500/25"
            >
              Deploy Your Station
            </Link>
          </div>
        </section>
      </main>

      <footer className="py-8 px-4 border-t border-surface-800">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-md bg-gradient-to-br from-primary-500 to-quantum-500 flex items-center justify-center">
              <span className="text-white font-bold text-xs">D</span>
            </div>
            <span className="text-sm text-surface-400">
              Decentralized Ground Station Network
            </span>
          </div>
          <div className="flex items-center gap-6 text-sm text-surface-500">
            <span>© 2024 DGSN</span>
            <Link href="#" className="hover:text-surface-300 transition-colors">
              Docs
            </Link>
            <Link href="#" className="hover:text-surface-300 transition-colors">
              GitHub
            </Link>
            <Link href="#" className="hover:text-surface-300 transition-colors">
              Status
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}

const features = [
  {
    title: 'Blockchain-Verified Receipts',
    description:
      'Every signal transmission is cryptographically signed and stored on-chain, creating an immutable record of data relay operations.',
    icon: ShieldIcon,
  },
  {
    title: 'Quantum-Resistant Security',
    description:
      'Post-quantum cryptographic algorithms protect your data against both classical and quantum computing threats.',
    icon: AtomIcon,
  },
  {
    title: 'Real-Time Signal Processing',
    description:
      'Advanced DSP pipelines process satellite signals in real-time with adaptive filtering and error correction.',
    icon: RadioIcon,
  },
  {
    title: 'Global Station Network',
    description:
      'Distributed network of community-operated ground stations providing global coverage for satellite communications.',
    icon: GlobeIcon,
  },
  {
    title: 'AI-Powered Optimization',
    description:
      'Machine learning models optimize station scheduling, signal decoding, and network resource allocation.',
    icon: CpuIcon,
  },
  {
    title: 'Open Protocol',
    description:
      'Fully open-source protocol and API. Build your own applications on top of the DGSN infrastructure.',
    icon: CodeIcon,
  },
];

const stats = [
  { value: '127', label: 'Active Stations' },
  { value: '48+', label: 'Countries' },
  { value: '2.4M+', label: 'Transmissions' },
  { value: '99.97%', label: 'Uptime' },
];

function ShieldIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
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
  );
}

function AtomIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
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
  );
}

function RadioIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
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
  );
}

function GlobeIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418"
      />
    </svg>
  );
}

function CpuIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z"
      />
    </svg>
  );
}

function CodeIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5"
      />
    </svg>
  );
}
