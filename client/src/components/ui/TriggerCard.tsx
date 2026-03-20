'use client';
import { motion } from 'framer-motion';
import { AlertTriangle, CheckCircle, Activity } from 'lucide-react';
import { TRIGGER_META } from '@/lib/utils';

interface TriggerCardProps {
  triggerType: string;
  threshold: number;
  actualValue?: number;
  unit: string;
  isActive: boolean;
  label?: string;
}

export default function TriggerCard({ triggerType, threshold, actualValue, unit, isActive, label }: TriggerCardProps) {
  const meta = TRIGGER_META[triggerType] ?? TRIGGER_META.HeavyRain;
  const pct = actualValue !== undefined ? Math.min((actualValue / (threshold * 1.5)) * 100, 100) : 0;
  const breached = actualValue !== undefined && actualValue >= threshold;

  return (
    <div className={`rounded-xl p-4 border transition-all ${
      isActive ? 'bg-red-500/5 border-red-500/25' : 'bg-white/[0.02] border-white/6'
    }`}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <span className="text-lg">{meta.emoji}</span>
          <span className="text-sm font-medium text-white">{label ?? meta.label}</span>
        </div>
        {isActive
          ? <motion.div animate={{ opacity: [1, 0.3, 1] }} transition={{ repeat: Infinity, duration: 1.5 }}>
              <AlertTriangle className="w-4 h-4 text-red-400" />
            </motion.div>
          : <CheckCircle className="w-4 h-4 text-green-500/50" />
        }
      </div>

      {actualValue !== undefined && (
        <>
          <div className="flex items-baseline justify-between text-xs mb-1.5">
            <span className="text-gray-500">Current</span>
            <span className={`font-bold tabular-nums ${breached ? 'text-red-400' : 'text-white'}`}>
              {actualValue.toFixed(1)} {unit}
            </span>
          </div>
          <div className="h-1.5 bg-white/[0.06] rounded-full overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${pct}%` }}
              transition={{ duration: 0.8, ease: 'easeOut' }}
              className="h-full rounded-full"
              style={{ background: breached ? '#EF4444' : meta.color }}
            />
          </div>
          <div className="flex justify-between text-[10px] text-gray-600 mt-1">
            <span>0</span>
            <span>Threshold: {threshold} {unit}</span>
          </div>
        </>
      )}

      {!actualValue && (
        <div className="flex items-center gap-1 text-xs text-gray-500">
          <Activity className="w-3 h-3" />
          Threshold: {threshold} {unit}
        </div>
      )}
    </div>
  );
}
