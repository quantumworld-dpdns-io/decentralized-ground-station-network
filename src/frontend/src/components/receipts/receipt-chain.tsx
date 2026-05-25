'use client';

import { cn } from '@/lib/utils/cn';

interface ChainBlock {
  block: number;
  hash: string;
  prevHash: string;
  timestamp: string;
  verified: boolean;
}

interface ReceiptChainProps {
  blocks: ChainBlock[];
  currentBlock?: number;
}

export function ReceiptChain({ blocks, currentBlock }: ReceiptChainProps) {
  return (
    <div className="space-y-2">
      {blocks.map((block, i) => {
        const isCurrent = block.block === currentBlock;
        return (
          <div key={block.block} className="relative">
            <div className={cn(
              'glass rounded-xl p-4 transition-all',
              isCurrent && 'ring-2 ring-primary-500',
            )}>
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className={cn(
                    'w-2.5 h-2.5 rounded-full',
                    isCurrent ? 'bg-primary-500' : block.verified ? 'bg-green-500' : 'bg-surface-500',
                  )} />
                  <span className="text-sm font-mono font-medium text-white">
                    Block #{block.block.toLocaleString()}
                  </span>
                </div>
                {block.verified && (
                  <svg className="w-4 h-4 text-green-500" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                )}
              </div>

              <div className="space-y-1 text-xs">
                <div className="flex items-center gap-2">
                  <span className="text-surface-500 w-20">Block Hash:</span>
                  <span className="text-surface-300 font-mono">{block.hash}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-surface-500 w-20">Prev Hash:</span>
                  <span className="text-surface-300 font-mono">{block.prevHash}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-surface-500 w-20">Timestamp:</span>
                  <span className="text-surface-300">{block.timestamp}</span>
                </div>
              </div>
            </div>

            {i < blocks.length - 1 && (
              <div className="flex justify-center py-1">
                <div className="w-px h-4 bg-surface-700" />
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
