'use client';
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, MapPin, Clock } from 'lucide-react';
import StatusBadge from './StatusBadge';
import { TRIGGER_META, fmt, formatDate, timeAgo } from '@/lib/utils';

interface ClaimCardProps {
  claim: any;
}

export default function ClaimCard({ claim }: ClaimCardProps) {
  const [expanded, setExpanded] = useState(false);
  const meta = TRIGGER_META[claim.triggerType] ?? TRIGGER_META.HeavyRain;

  return (
    <motion.div
      layout
      className="bg-dark-card border border-white/6 rounded-2xl overflow-hidden hover:border-white/10 transition-colors"
    >
      <button
        className="w-full flex items-center gap-4 p-4 text-left"
        onClick={() => setExpanded(v => !v)}
      >
        {/* Trigger icon */}
        <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-lg"
          style={{ background: meta.bg }}>
          {meta.emoji}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-sm font-medium text-white">{meta.label}</span>
            <span className="text-[11px] text-gray-500">#{claim.claimNumber}</span>
          </div>
          <p className="text-xs text-gray-500 mt-0.5">{timeAgo(claim.createdAt)}</p>
        </div>

        <div className="flex items-center gap-3 flex-shrink-0">
          {claim.payoutAmount > 0 && (
            <span className="text-sm font-semibold text-green-400 tabular-nums">{fmt(claim.payoutAmount)}</span>
          )}
          <StatusBadge status={claim.status} size="sm" />
          <ChevronDown className={`w-4 h-4 text-gray-500 transition-transform duration-200 ${expanded ? 'rotate-180' : ''}`} />
        </div>
      </button>

      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25 }}
          >
            <div className="px-4 pb-4 pt-0 border-t border-white/5">
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-3">
                <div className="bg-white/[0.03] rounded-xl p-3">
                  <p className="text-[10px] text-gray-500 mb-1">Parameter</p>
                  <p className="text-xs font-medium text-white capitalize">{claim.triggerData?.parameter?.replace(/_/g, ' ')}</p>
                </div>
                <div className="bg-white/[0.03] rounded-xl p-3">
                  <p className="text-[10px] text-gray-500 mb-1">Actual Value</p>
                  <p className="text-xs font-bold" style={{ color: meta.color }}>{claim.triggerData?.actualValue?.toFixed(1)}</p>
                </div>
                <div className="bg-white/[0.03] rounded-xl p-3">
                  <p className="text-[10px] text-gray-500 mb-1">Threshold</p>
                  <p className="text-xs font-medium text-gray-300">{claim.triggerData?.threshold}</p>
                </div>
                <div className="bg-white/[0.03] rounded-xl p-3">
                  <p className="text-[10px] text-gray-500 mb-1">Lost Hours</p>
                  <p className="text-xs font-medium text-gray-300">{claim.estimatedLostHours}h</p>
                </div>
              </div>

              <div className="flex items-center gap-4 mt-3 text-[11px] text-gray-500">
                <span className="flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  {formatDate(claim.createdAt)}
                </span>
                <span className="flex items-center gap-1">
                  <MapPin className="w-3 h-3" />
                  {claim.triggerData?.dataSource}
                </span>
                {claim.fraudScore !== undefined && (
                  <span className={`ml-auto font-medium ${claim.fraudScore > 60 ? 'text-red-400' : claim.fraudScore > 30 ? 'text-yellow-400' : 'text-green-400'}`}>
                    Fraud Score: {claim.fraudScore}
                  </span>
                )}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
