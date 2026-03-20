'use client';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';

interface RiskDistributionProps {
  data: Array<{ tier: string; count: number; pct: number }>;
}

const TIER_COLORS: Record<string, string> = {
  Low: '#22C55E', Medium: '#F59E0B', High: '#F97316', VeryHigh: '#EF4444',
};

const CustomTooltip = ({ active, payload }: any) => {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div className="bg-dark-surface border border-white/10 rounded-xl p-3 shadow-xl">
      <p className="text-sm font-semibold text-white mb-1">{d.tier} Risk</p>
      <p className="text-xs text-gray-400">{d.count.toLocaleString('en-IN')} riders</p>
      <p className="text-xs text-gray-400">{d.pct}%</p>
    </div>
  );
};

export default function RiskDistribution({ data }: RiskDistributionProps) {
  return (
    <div className="flex items-center gap-4">
      <ResponsiveContainer width={140} height={140}>
        <PieChart>
          <Pie data={data} dataKey="count" cx="50%" cy="50%" innerRadius={40} outerRadius={65}
            paddingAngle={3} strokeWidth={0}>
            {data.map((d) => <Cell key={d.tier} fill={TIER_COLORS[d.tier] ?? '#6B7280'} />)}
          </Pie>
          <Tooltip content={<CustomTooltip />} />
        </PieChart>
      </ResponsiveContainer>

      <div className="flex-1 space-y-2">
        {data.map((d) => (
          <div key={d.tier} className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: TIER_COLORS[d.tier] }} />
            <span className="text-xs text-gray-400 flex-1">{d.tier}</span>
            <span className="text-xs font-medium text-white tabular-nums">{d.pct}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}
