'use client';
import { motion } from 'framer-motion';
import { Check, Star, Zap } from 'lucide-react';

interface PlanCardProps {
  planType: 'Basic' | 'Standard' | 'Premium';
  weeklyPremium: number;
  coverageLimit: number;
  coveredDisruptions: string[];
  recommended?: boolean;
  onSelect?: () => void;
  selected?: boolean;
  breakdown?: string;
}

const PLAN_META = {
  Basic:    { color: '#60A5FA', gradient: 'from-blue-500/15 to-blue-600/5',    border: 'border-blue-500/20', icon: '🛡️' },
  Standard: { color: '#10b981', gradient: 'from-teal-500/15 to-emerald-600/5', border: 'border-teal-500/20', icon: '⚡' },
  Premium:  { color: '#a78bfa', gradient: 'from-violet-500/15 to-purple-600/5', border: 'border-violet-500/20', icon: '👑' },
};

const DISRUPTION_LABELS: Record<string, string> = {
  HeavyRain: 'Heavy Rainfall', ExtremeHeat: 'Extreme Heat',
  SevereAQI: 'Severe AQI', Flooding: 'Flooding', SocialDisruption: 'Social Disruption',
};

const ALL_DISRUPTIONS = ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'];

export default function PlanCard({
  planType, weeklyPremium, coverageLimit, coveredDisruptions,
  recommended = false, onSelect, selected = false, breakdown,
}: PlanCardProps) {
  const meta = PLAN_META[planType];
  const weeklyRs = Math.round(weeklyPremium / 100);
  const limitRs = coverageLimit / 100;

  return (
    <motion.div
      whileHover={{ y: -4, transition: { duration: 0.2 } }}
      className={`relative rounded-2xl border p-5 cursor-pointer transition-all duration-200 ${
        selected || recommended
          ? `bg-linear-to-br ${meta.gradient} ${meta.border} shadow-lg`
          : 'bg-dark-card border-white/6 hover:border-white/10'
      }`}
      onClick={onSelect}
    >
      {recommended && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 flex items-center gap-1 px-3 py-1 bg-linear-to-r from-teal-500 to-emerald-500 rounded-full text-[11px] font-bold text-white shadow-lg shadow-teal-500/30">
          <Star className="w-3 h-3 fill-white" />
          Recommended
        </div>
      )}

      <div className="flex items-center justify-between mb-4">
        <div>
          <span className="text-2xl">{meta.icon}</span>
          <h3 className="text-lg font-display font-bold text-white mt-1">{planType}</h3>
        </div>
        <div className="text-right">
          <p className="text-2xl font-display font-bold text-white tabular-nums">₹{weeklyRs}</p>
          <p className="text-xs text-gray-500">/week</p>
        </div>
      </div>

      <div className="mb-4 p-3 bg-white/[0.03] rounded-xl">
        <p className="text-xs text-gray-500 mb-1">Coverage Limit</p>
        <p className="text-base font-semibold" style={{ color: meta.color }}>
          ₹{limitRs >= 1000 ? `${(limitRs / 1000).toFixed(0)}K` : limitRs}
        </p>
      </div>

      <ul className="space-y-2 mb-5">
        {ALL_DISRUPTIONS.map(d => {
          const covered = coveredDisruptions.includes(d);
          return (
            <li key={d} className={`flex items-center gap-2 text-xs ${covered ? 'text-gray-300' : 'text-gray-600'}`}>
              <div className={`w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0 ${covered ? '' : 'opacity-30'}`}
                style={{ background: covered ? `${meta.color}20` : 'rgba(255,255,255,0.05)' }}>
                <Check className="w-2.5 h-2.5" style={{ color: covered ? meta.color : '#4B5563' }} />
              </div>
              {DISRUPTION_LABELS[d]}
            </li>
          );
        })}
      </ul>

      {breakdown && (
        <p className="text-[10px] text-gray-500 mb-4 leading-relaxed border-t border-white/5 pt-3">{breakdown}</p>
      )}

      <motion.button
        whileTap={{ scale: 0.97 }}
        className={`w-full py-2.5 rounded-xl text-sm font-semibold transition-all ${
          selected
            ? 'bg-linear-to-r from-teal-600 to-emerald-600 text-white shadow-lg'
            : 'border text-gray-300 hover:text-white hover:bg-white/5'
        }`}
        style={{ borderColor: selected ? 'transparent' : `${meta.color}30` }}
        onClick={onSelect}
      >
        {selected ? (
          <span className="flex items-center justify-center gap-2">
            <Zap className="w-4 h-4" />
            Selected
          </span>
        ) : 'Choose Plan'}
      </motion.button>
    </motion.div>
  );
}
