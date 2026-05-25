'use client';

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from 'recharts';

interface HistogramBar {
  state: string;
  count: number;
}

interface ResultHistogramProps {
  data: HistogramBar[];
  height?: number;
  title?: string;
}

const COLORS = [
  '#6366f1', '#22c55e', '#f97316', '#ef4444',
  '#14b8a6', '#a855f7', '#ec4899', '#3b82f6',
];

export function ResultHistogram({
  data,
  height = 300,
  title,
}: ResultHistogramProps) {
  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-[300px] text-surface-500 text-sm">
        No results available
      </div>
    );
  }

  const totalShots = data.reduce((sum, d) => sum + d.count, 0);

  return (
    <div>
      {title && (
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-medium text-white">{title}</h3>
          <span className="text-xs text-surface-500">
            {totalShots.toLocaleString()} shots
          </span>
        </div>
      )}
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
          <XAxis
            dataKey="state"
            stroke="#64748b"
            fontSize={11}
            tick={{ fontFamily: 'monospace' }}
          />
          <YAxis stroke="#64748b" fontSize={11} />
          <Tooltip
            contentStyle={{
              background: '#1e293b',
              border: '1px solid #334155',
              borderRadius: '8px',
              fontSize: '12px',
            }}
            formatter={(value: number) => [
              `${value} (${((value / totalShots) * 100).toFixed(1)}%)`,
              'Count',
            ]}
          />
          <Bar dataKey="count" radius={[4, 4, 0, 0]} maxBarSize={48}>
            {data.map((_, index) => (
              <Cell
                key={index}
                fill={COLORS[index % COLORS.length]}
                fillOpacity={0.8}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
