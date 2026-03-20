'use client';
import { motion } from 'framer-motion';

interface RiskMeterProps {
  score: number;   // 0-100
  tier: string;
  size?: number;
}

const TIER_COLOR: Record<string, string> = {
  Low: '#22C55E', Medium: '#F59E0B', High: '#F97316', VeryHigh: '#EF4444',
};

export default function RiskMeter({ score, tier, size = 120 }: RiskMeterProps) {
  const color = TIER_COLOR[tier] ?? '#6B7280';
  const r = (size - 20) / 2;
  const cx = size / 2;
  const circumference = 2 * Math.PI * r;
  // Semi-circle: use 180° arc (half circumference)
  const arc = Math.PI * r;
  const progress = arc * (score / 100);
  const dashOffset = arc - progress;

  return (
    <div className="relative flex flex-col items-center">
      <svg width={size} height={size / 2 + 10} viewBox={`0 0 ${size} ${size / 2 + 10}`}>
        {/* Background track */}
        <path
          d={`M 10 ${cx} A ${r} ${r} 0 0 1 ${size - 10} ${cx}`}
          fill="none"
          stroke="rgba(255,255,255,0.06)"
          strokeWidth="10"
          strokeLinecap="round"
        />
        {/* Progress arc */}
        <motion.path
          d={`M 10 ${cx} A ${r} ${r} 0 0 1 ${size - 10} ${cx}`}
          fill="none"
          stroke={color}
          strokeWidth="10"
          strokeLinecap="round"
          strokeDasharray={arc}
          initial={{ strokeDashoffset: arc }}
          animate={{ strokeDashoffset: dashOffset }}
          transition={{ duration: 1.2, ease: 'easeOut', delay: 0.2 }}
          style={{ filter: `drop-shadow(0 0 6px ${color}80)` }}
        />
      </svg>

      {/* Score label centered below arc midpoint */}
      <div className="absolute bottom-0 flex flex-col items-center">
        <motion.span
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.6 }}
          className="text-2xl font-display font-bold text-white tabular-nums"
        >
          {score}
        </motion.span>
        <span className="text-[11px] font-medium" style={{ color }}>{tier}</span>
      </div>
    </div>
  );
}
