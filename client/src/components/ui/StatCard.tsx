'use client';
import { motion } from 'framer-motion';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { type LucideIcon } from 'lucide-react';

interface StatCardProps {
  label: string;
  value: string;
  subValue?: string;
  trend?: number;        // positive = up, negative = down
  trendLabel?: string;
  icon?: LucideIcon;
  iconColor?: string;
  iconBg?: string;
  highlight?: boolean;
  delay?: number;
}

export default function StatCard({
  label, value, subValue, trend, trendLabel, icon: Icon,
  iconColor = '#0d9488', iconBg = 'rgba(13,148,136,0.12)',
  highlight = false, delay = 0,
}: StatCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, duration: 0.4 }}
      whileHover={{ y: -2, transition: { duration: 0.15 } }}
      className={`relative rounded-2xl p-5 border transition-all duration-200 ${
        highlight
          ? 'bg-linear-to-br from-teal-500/10 to-emerald-500/5 border-teal-500/20'
          : 'bg-dark-card border-white/6 hover:border-white/10'
      }`}
    >
      <div className="flex items-start justify-between mb-3">
        <p className="text-sm text-gray-400 font-medium">{label}</p>
        {Icon && (
          <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: iconBg }}>
            <Icon className="w-4.5 h-4.5" style={{ color: iconColor, width: 18, height: 18 }} />
          </div>
        )}
      </div>

      <p className={`text-2xl font-display font-bold tabular-nums ${highlight ? 'text-gradient' : 'text-white'}`}>
        {value}
      </p>

      {subValue && <p className="text-xs text-gray-500 mt-0.5">{subValue}</p>}

      {(trend !== undefined || trendLabel) && (
        <div className="flex items-center gap-1.5 mt-3 pt-3 border-t border-white/5">
          {trend !== undefined && (
            <>
              {trend > 0
                ? <TrendingUp className="w-3.5 h-3.5 text-green-400" />
                : trend < 0
                  ? <TrendingDown className="w-3.5 h-3.5 text-red-400" />
                  : <Minus className="w-3.5 h-3.5 text-gray-500" />
              }
              <span className={`text-xs font-medium ${trend > 0 ? 'text-green-400' : trend < 0 ? 'text-red-400' : 'text-gray-500'}`}>
                {trend > 0 ? '+' : ''}{trend}%
              </span>
            </>
          )}
          {trendLabel && <span className="text-xs text-gray-500">{trendLabel}</span>}
        </div>
      )}
    </motion.div>
  );
}
