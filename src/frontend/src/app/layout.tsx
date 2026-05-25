import type { Metadata, Viewport } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    template: '%s | DGSN',
    default: 'Decentralized Ground Station Network',
  },
  description:
    'A decentralized network of satellite ground stations powered by blockchain and quantum-resistant cryptography.',
  keywords: [
    'satellite',
    'ground station',
    'blockchain',
    'quantum',
    'signal processing',
  ],
  authors: [{ name: 'DGSN' }],
  creator: 'DGSN',
  openGraph: {
    type: 'website',
    locale: 'en_US',
    siteName: 'DGSN',
    title: 'Decentralized Ground Station Network',
    description:
      'A decentralized network of satellite ground stations powered by blockchain and quantum-resistant cryptography.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Decentralized Ground Station Network',
    description:
      'A decentralized network of satellite ground stations powered by blockchain and quantum-resistant cryptography.',
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: dark)', color: '#0f172a' },
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
  ],
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={`${inter.variable} ${jetbrainsMono.variable} font-sans`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
