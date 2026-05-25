'use client';

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

interface TimelinePlotProps {
  data: { time: string | number; value: number }[];
  height?: number;
  color?: string;
  title?: string;
  yLabel?: string;
  showGrid?: boolean;
}

export function TimelinePlot({
  data,
  height = 200,
  color = '#6366f1',
  title,
  yLabel,
  showGrid = true,
}: TimelinePlotProps) {
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
      {title && (
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-sm font-medium text-white">{title}</h3>
          {yLabel && (
            <span className="text-xs text-surface-500">{yLabel}</span>
          )}
        </div>
      )}
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={data}>
          {showGrid && (
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
          )}
          <XAxis
            dataKey="time"
            stroke="#64748b"
            fontSize={11}
            tickFormatter={(v) => String(v)}
          />
          <YAxis stroke="#64748b" fontSize={11} />
          <Tooltip
            contentStyle={{
              background: '#1e293b',
              border: '1px solid #334155',
              borderRadius: '8px',
              fontSize: '12px',
            }}
          />
          <Line
            type="monotone"
            dataKey="value"
            stroke={color}
            strokeWidth={1.5}
            dot={false}
            activeDot={{ r: 4, fill: color }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
