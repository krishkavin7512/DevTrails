'use client';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

interface PayoutChartProps {
  data: Array<{ week: string; revenue: number; payouts: number }>;
}

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-dark-surface border border-white/10 rounded-xl p-3 shadow-xl">
      <p className="text-xs text-gray-400 mb-2">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} className="text-sm font-semibold" style={{ color: p.color }}>
          {p.name === 'revenue' ? 'Revenue' : 'Payouts'}: ₹{p.value}K
        </p>
      ))}
    </div>
  );
};

export default function PayoutChart({ data }: PayoutChartProps) {
  return (
    <ResponsiveContainer width="100%" height={220}>
      <AreaChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
        <defs>
          <linearGradient id="gradRevenue" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#0d9488" stopOpacity={0.3} />
            <stop offset="95%" stopColor="#0d9488" stopOpacity={0} />
          </linearGradient>
          <linearGradient id="gradPayouts" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
            <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
        <XAxis dataKey="week" tick={{ fill: '#6B7280', fontSize: 11 }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fill: '#6B7280', fontSize: 11 }} axisLine={false} tickLine={false}
          tickFormatter={(v) => `₹${v}K`} />
        <Tooltip content={<CustomTooltip />} />
        <Area type="monotone" dataKey="revenue" name="revenue" stroke="#0d9488" strokeWidth={2}
          fill="url(#gradRevenue)" dot={false} />
        <Area type="monotone" dataKey="payouts" name="payouts" stroke="#f59e0b" strokeWidth={2}
          fill="url(#gradPayouts)" dot={false} />
      </AreaChart>
    </ResponsiveContainer>
  );
}
