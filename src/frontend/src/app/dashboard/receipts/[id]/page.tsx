'use client';

import { useState } from 'react';

const chainData = [
  { block: 18457234, hash: '0x7a3f...b9e2', prevHash: '0x1a2b...c3d4', timestamp: '2024-01-15 14:32:15', txCount: 3, verified: true },
  { block: 18457233, hash: '0x1a2b...c3d4', prevHash: '0x4e5f...g6h7', timestamp: '2024-01-15 14:31:50', txCount: 5, verified: true },
  { block: 18457232, hash: '0x4e5f...g6h7', prevHash: '0x8i9j...k0l1', timestamp: '2024-01-15 14:31:22', txCount: 2, verified: true },
  { block: 18457231, hash: '0x8i9j...k0l1', prevHash: '0x2m3n...o4p5', timestamp: '2024-01-15 14:30:55', txCount: 4, verified: true },
];

const receiptData = {
  id: '0x7a3f...b9e2',
  blockNumber: 18457234,
  status: 'verified' as const,
  station: {
    id: 'st-001',
    name: 'Station Alpha',
    location: 'Fairbanks, AK',
  },
  satellite: 'NOAA-19',
  timestamp: '2024-01-15 14:32:15 UTC',
  frequency: '137.100 MHz',
  dataSize: '2.4 MB',
  modulation: 'APSK',
  encoding: 'Convolutional (K=7, R=1/2)',
  signalStrength: '-68 dBm',
  noiseFloor: '-97 dBm',
  snr: '29 dB',
  dopplerShift: '+1.2 kHz',
  txHash: '0x8f3c...a1b2',
  signature: '0xdeadbeefcafebabe...0123456789abcdef',
  publicKey: '0x04a1b2c3...d4e5f6',
};

const statusColors: Record<string, string> = {
  verified: 'bg-green-500/10 text-green-400 border-green-500/20',
  pending: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20',
  failed: 'bg-red-500/10 text-red-400 border-red-500/20',
};

export default function ReceiptDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const [verifying, setVerifying] = useState(false);
  const [verifyResult, setVerifyResult] = useState<null | {
    valid: boolean;
    message: string;
  }>(null);

  const handleVerify = async () => {
    setVerifying(true);
    setVerifyResult(null);

    try {
      const res = await fetch(`/api/v1/receipts/${params.id}/verify`, {
        method: 'POST',
      });

      if (!res.ok) throw new Error('Verification failed');

      const data = await res.json();
      setVerifyResult({
        valid: data.valid,
        message: data.valid
          ? 'Receipt cryptographically verified on-chain'
          : 'Receipt verification failed — data integrity check did not pass',
      });
    } catch {
      setVerifyResult({
        valid: false,
        message: 'Verification request failed. Please try again.',
      });
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-white">Receipt Details</h1>
          <span
            className={`px-3 py-1 text-xs font-medium rounded-full border ${
              statusColors[receiptData.status]
            }`}
          >
            {receiptData.status.charAt(0).toUpperCase() +
              receiptData.status.slice(1)}
          </span>
        </div>
        <p className="text-surface-400 mt-1 font-mono text-sm">
          {receiptData.id}
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="glass rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">
              Transmission Details
            </h3>
            <div className="grid grid-cols-2 gap-4">
              {[
                { label: 'Satellite', value: receiptData.satellite },
                { label: 'Frequency', value: receiptData.frequency },
                { label: 'Data Size', value: receiptData.dataSize },
                { label: 'Modulation', value: receiptData.modulation },
                { label: 'Encoding', value: receiptData.encoding },
                { label: 'Signal Strength', value: receiptData.signalStrength },
                { label: 'Noise Floor', value: receiptData.noiseFloor },
                { label: 'SNR', value: receiptData.snr },
                { label: 'Doppler Shift', value: receiptData.dopplerShift },
                { label: 'Timestamp', value: receiptData.timestamp },
              ].map((field) => (
                <div key={field.label}>
                  <div className="text-sm text-surface-400 mb-1">
                    {field.label}
                  </div>
                  <div className="text-sm text-white font-mono">
                    {field.value}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="glass rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">
              Cryptographic Proof
            </h3>
            <div className="space-y-4">
              <div>
                <div className="text-sm text-surface-400 mb-1">Transaction Hash</div>
                <div className="text-sm text-white font-mono break-all">
                  {receiptData.txHash}
                </div>
              </div>
              <div>
                <div className="text-sm text-surface-400 mb-1">Digital Signature</div>
                <div className="text-sm text-white font-mono break-all text-xs">
                  {receiptData.signature}
                </div>
              </div>
              <div>
                <div className="text-sm text-surface-400 mb-1">Public Key</div>
                <div className="text-sm text-white font-mono break-all text-xs">
                  {receiptData.publicKey}
                </div>
              </div>
            </div>
          </div>

          <div className="glass rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">
              On-Chain Verification
            </h3>
            <button
              onClick={handleVerify}
              disabled={verifying}
              className="px-6 py-3 rounded-lg bg-gradient-to-r from-primary-600 to-chain-600 hover:from-primary-500 hover:to-chain-500 text-white font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {verifying ? 'Verifying on Chain...' : 'Verify Receipt on Chain'}
            </button>

            {verifyResult && (
              <div
                className={`mt-4 px-4 py-3 rounded-lg ${
                  verifyResult.valid
                    ? 'bg-green-500/10 border border-green-500/20'
                    : 'bg-red-500/10 border border-red-500/20'
                }`}
              >
                <div className="flex items-center gap-2">
                  <div
                    className={`w-2 h-2 rounded-full ${
                      verifyResult.valid ? 'bg-green-500' : 'bg-red-500'
                    }`}
                  />
                  <span
                    className={`text-sm font-medium ${
                      verifyResult.valid ? 'text-green-400' : 'text-red-400'
                    }`}
                  >
                    {verifyResult.valid ? 'Valid ✓' : 'Invalid ✗'}
                  </span>
                </div>
                <p
                  className={`text-sm mt-1 ${
                    verifyResult.valid ? 'text-green-300' : 'text-red-300'
                  }`}
                >
                  {verifyResult.message}
                </p>
              </div>
            )}
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">
              Station Info
            </h3>
            <div className="space-y-3">
              <div>
                <div className="text-sm text-surface-400">Name</div>
                <div className="text-sm text-white">{receiptData.station.name}</div>
              </div>
              <div>
                <div className="text-sm text-surface-400">ID</div>
                <div className="text-sm text-white font-mono">{receiptData.station.id}</div>
              </div>
              <div>
                <div className="text-sm text-surface-400">Location</div>
                <div className="text-sm text-white">{receiptData.station.location}</div>
              </div>
            </div>
          </div>

          <div className="glass rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">
              Block #{receiptData.blockNumber.toLocaleString()}
            </h3>
            <div className="space-y-3">
              {chainData.map((block, i) => (
                <div key={block.block}>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      {i === 0 && (
                        <div className="w-2 h-2 rounded-full bg-primary-500" />
                      )}
                      <span className="text-sm font-mono text-white">
                        #{block.block.toLocaleString()}
                      </span>
                    </div>
                    {block.verified && (
                      <svg
                        className="w-4 h-4 text-green-500"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth={2}
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M4.5 12.75l6 6 9-13.5"
                        />
                      </svg>
                    )}
                  </div>
                  <div className="text-xs text-surface-500 font-mono mt-1">
                    {block.hash}
                  </div>
                  {i < chainData.length - 1 && (
                    <div className="ml-[3px] w-[2px] h-3 bg-surface-700 mt-1" />
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
