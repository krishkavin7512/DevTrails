'use client';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Filter, Search, FileText } from 'lucide-react';
import Sidebar from '@/components/layout/Sidebar';
import ClaimCard from '@/components/ui/ClaimCard';
import EmptyState from '@/components/ui/EmptyState';
import { SkeletonRow } from '@/components/ui/LoadingSkeleton';
import { useClaims } from '@/hooks/useClaims';
import { fmt } from '@/lib/utils';

const STATUSES = ['All', 'Paid', 'Approved', 'AutoInitiated', 'UnderReview', 'Rejected', 'FraudSuspected'];
const TRIGGERS = ['All', 'HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'];
const TRIGGER_LABELS: Record<string, string> = {
  HeavyRain: '🌧️ Rain', ExtremeHeat: '🌡️ Heat', SevereAQI: '😷 AQI', Flooding: '🌊 Flood', SocialDisruption: '🚫 Social',
};

export default function ClaimsPage() {
  const [riderId, setRiderId] = useState<string | null>(null);
  const [riderName, setRiderName] = useState('Rider');
  const [city, setCity] = useState('Mumbai');
  const [filter, setFilter] = useState({ status: 'All', triggerType: 'All', page: 1 });

  useEffect(() => {
    setRiderId(localStorage.getItem('rc_rider_id'));
    setRiderName(localStorage.getItem('rc_rider_name') ?? 'Rider');
    setCity(localStorage.getItem('rc_city') ?? 'Mumbai');
  }, []);

  const { claims, total, loading } = useClaims(riderId, filter);

  const totalPaid = claims.filter(c => c.status === 'Paid').reduce((s: number, c: any) => s + (c.payoutAmount ?? 0), 0);
  const totalPaidCount = claims.filter(c => c.status === 'Paid').length;

  return (
    <div className="flex">
      <Sidebar riderName={riderName} riderCity={city} policyStatus="Active" />

      <main className="lg:ml-[240px] flex-1 min-h-screen bg-dark bg-mesh pt-14 lg:pt-0">
        <div className="max-w-4xl mx-auto p-6 space-y-6">

          {/* Header */}
          <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }}>
            <h1 className="text-2xl font-display font-bold text-white mb-1">Claims History</h1>
            <p className="text-sm text-gray-500">All your auto-initiated insurance payouts</p>
          </motion.div>

          {/* Stats bar */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.1 }}
            className="grid grid-cols-3 gap-4">
            {[
              { label: 'Total Claims', value: String(total) },
              { label: 'Successful Payouts', value: String(totalPaidCount) },
              { label: 'Total Received', value: fmt(totalPaid) },
            ].map(({ label, value }) => (
              <div key={label} className="bg-dark-card border border-white/6 rounded-2xl p-4 text-center">
                <p className="text-xl font-display font-bold text-white">{value}</p>
                <p className="text-xs text-gray-500 mt-1">{label}</p>
              </div>
            ))}
          </motion.div>

          {/* Filters */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.15 }}
            className="bg-dark-card border border-white/6 rounded-2xl p-4 space-y-3">
            <div className="flex items-center gap-2 text-sm text-gray-400">
              <Filter className="w-4 h-4" />
              <span className="font-medium">Filters</span>
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              {/* Status filter */}
              <div className="flex-1">
                <p className="text-[10px] text-gray-500 uppercase tracking-wide mb-1.5">Status</p>
                <div className="flex flex-wrap gap-1.5">
                  {STATUSES.map(s => (
                    <button key={s} onClick={() => setFilter(f => ({ ...f, status: s, page: 1 }))}
                      className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-all ${
                        filter.status === s ? 'bg-teal-500/20 text-teal-400 border border-teal-500/30' : 'bg-dark-surface text-gray-400 border border-white/5 hover:border-white/10'
                      }`}>
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              {/* Trigger filter */}
              <div className="flex-1">
                <p className="text-[10px] text-gray-500 uppercase tracking-wide mb-1.5">Trigger Type</p>
                <div className="flex flex-wrap gap-1.5">
                  {TRIGGERS.map(t => (
                    <button key={t} onClick={() => setFilter(f => ({ ...f, triggerType: t, page: 1 }))}
                      className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-all ${
                        filter.triggerType === t ? 'bg-teal-500/20 text-teal-400 border border-teal-500/30' : 'bg-dark-surface text-gray-400 border border-white/5 hover:border-white/10'
                      }`}>
                      {t === 'All' ? 'All Types' : (TRIGGER_LABELS[t] ?? t)}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </motion.div>

          {/* Claims list */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }} className="space-y-3">
            {loading ? (
              <div className="bg-dark-card border border-white/6 rounded-2xl divide-y divide-white/5">
                {[...Array(4)].map((_, i) => <SkeletonRow key={i} />)}
              </div>
            ) : claims.length === 0 ? (
              <EmptyState icon={FileText} title="No claims found"
                description="No claims match the selected filters. Auto-initiated claims appear here when disruption triggers fire."
                action={
                  <button onClick={() => setFilter({ status: 'All', triggerType: 'All', page: 1 })}
                    className="text-sm text-teal-400 hover:text-teal-300 border border-teal-500/20 px-4 py-2 rounded-xl transition-colors">
                    Clear Filters
                  </button>
                }
              />
            ) : (
              <div className="space-y-2">
                {claims.map((claim: any, i: number) => (
                  <motion.div key={claim._id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: i * 0.04 }}>
                    <ClaimCard claim={claim} />
                  </motion.div>
                ))}
              </div>
            )}
          </motion.div>

          {/* Pagination */}
          {total > 10 && (
            <div className="flex items-center justify-center gap-3">
              <button onClick={() => setFilter(f => ({ ...f, page: Math.max(1, f.page - 1) }))}
                disabled={filter.page === 1}
                className="px-4 py-2 text-sm text-gray-400 border border-white/6 rounded-xl hover:border-white/10 disabled:opacity-40 transition-all">
                Previous
              </button>
              <span className="text-sm text-gray-500">Page {filter.page}</span>
              <button onClick={() => setFilter(f => ({ ...f, page: f.page + 1 }))}
                disabled={claims.length < 10}
                className="px-4 py-2 text-sm text-gray-400 border border-white/6 rounded-xl hover:border-white/10 disabled:opacity-40 transition-all">
                Next
              </button>
            </div>
          )}

          {/* Info box */}
          <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
            <div className="flex items-start gap-3">
              <span className="text-2xl">⚡</span>
              <div>
                <p className="text-sm font-semibold text-white mb-1">How Automatic Claims Work</p>
                <p className="text-xs text-gray-400 leading-relaxed">
                  RainCheck monitors weather and disruption data 24/7. When a trigger threshold is breached in your zone, a claim is automatically initiated — no action required from you. Approved payouts are credited within 2 minutes.
                </p>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
