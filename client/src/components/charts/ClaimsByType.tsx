'use client';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import { TRIGGER_META } from '@/lib/utils';

interface ClaimsByTypeProps {
  data: Array<{ type: string; count: number; pct?: number }>;
}

const COLORS = ['#60A5FA', '#C084FC', '#FB923C', '#22D3EE', '#FBBF24'];

const CustomTooltip = ({ active, payload }: any) => {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  const meta = TRIGGER_META[d.type];
  return (
    <div className="bg-dark-surface border border-white/10 rounded-xl p-3 shadow-xl">
      <p className="text-sm font-semibold text-white mb-1">{meta?.emoji} {meta?.label ?? d.type}</p>
      <p className="text-xs text-gray-400">{d.count} claims</p>
      {d.pct && <p className="text-xs text-gray-400">{d.pct}% of total</p>}
    </div>
  );
};

export default function ClaimsByType({ data }: ClaimsByTypeProps) {
  return (
    <ResponsiveContainer width="100%" height={200}>
      <BarChart data={data} margin={{ top: 5, right: 5, left: -25, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
        <XAxis dataKey="type" tick={{ fill: '#6B7280', fontSize: 10 }} axisLine={false} tickLine={false}
          tickFormatter={(v) => TRIGGER_META[v]?.emoji ?? v.slice(0, 4)} />
        <YAxis tick={{ fill: '#6B7280', fontSize: 11 }} axisLine={false} tickLine={false} />
        <Tooltip content={<CustomTooltip />} cursor={{ fill: 'rgba(255,255,255,0.03)' }} />
        <Bar dataKey="count" radius={[6, 6, 0, 0]}>
          {data.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
