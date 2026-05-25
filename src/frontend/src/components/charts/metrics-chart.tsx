'use client';

import {
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';

interface Series {
  key: string;
  label: string;
  color: string;
  type?: 'line' | 'area';
}

interface MetricsChartProps {
  data: Record<string, unknown>[];
  series: Series[];
  xKey: string;
  height?: number;
  showLegend?: boolean;
  showGrid?: boolean;
  yLabel?: string;
}

export function MetricsChart({
  data,
  series,
  xKey,
  height = 250,
  showLegend = true,
  showGrid = true,
  yLabel,
}: MetricsChartProps) {
  if (!data || data.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-surface-500 text-sm"
        style={{ height }}
      >
        No data available
      </div>
    );
  }

  return (
    <div>
      {yLabel && (
        <div className="text-xs text-surface-500 mb-2">{yLabel}</div>
      )}
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={data as Record<string, string | number>[]}>
          {showGrid && (
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
          )}
          <XAxis
            dataKey={xKey}
            stroke="#64748b"
            fontSize={11}
            tickLine={false}
          />
          <YAxis stroke="#64748b" fontSize={11} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{
              background: '#1e293b',
              border: '1px solid #334155',
              borderRadius: '8px',
              fontSize: '12px',
            }}
            content={({ active, payload, label }) => {
              if (!active || !payload?.length) return null;
              return (
                <div className="glass rounded-lg p-3 text-xs">
                  <div className="text-surface-400 mb-1">{label}</div>
                  {payload.map((entry) => (
                    <div
                      key={entry.name}
                      className="flex items-center gap-2"
                    >
                      <div
                        className="w-2 h-2 rounded-full"
                        style={{ background: entry.color }}
                      />
                      <span className="text-surface-300">{entry.name}:</span>
                      <span className="text-white font-mono">
                        {typeof entry.value === 'number'
                          ? entry.value.toFixed(2)
                          : entry.value}
                      </span>
                    </div>
                  ))}
                </div>
              );
            }}
          />
          {showLegend && (
            <Legend
              wrapperStyle={{ fontSize: '11px', color: '#94a3b8' }}
              iconType="circle"
              iconSize={6}
            />
          )}
          {series.map((s) =>
            s.type === 'area' ? (
              <defs key={`grad-${s.key}`}>
                <linearGradient id={`gradient-${s.key}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={s.color} stopOpacity={0.3} />
                  <stop offset="95%" stopColor={s.color} stopOpacity={0} />
                </linearGradient>
              </defs>
            ) : null,
          )}
          {series.map((s) =>
            s.type === 'area' ? (
              <Area
                key={s.key}
                type="monotone"
                dataKey={s.key}
                name={s.label}
                stroke={s.color}
                fill={`url(#gradient-${s.key})`}
                strokeWidth={2}
                dot={false}
              />
            ) : (
              <Line
                key={s.key}
                type="monotone"
                dataKey={s.key}
                name={s.label}
                stroke={s.color}
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, fill: s.color }}
              />
            ),
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
