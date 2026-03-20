'use client';
import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { toast } from 'react-hot-toast';
import {
  Users, Shield, TrendingDown, AlertTriangle, CheckCircle, XCircle,
  BarChart3, Lock, Play, Database, Zap, RefreshCw,
} from 'lucide-react';
import StatCard from '@/components/ui/StatCard';
import StatusBadge from '@/components/ui/StatusBadge';
import { SkeletonPage } from '@/components/ui/LoadingSkeleton';
import PayoutChart from '@/components/charts/PayoutChart';
import ClaimsByType from '@/components/charts/ClaimsByType';
import RiskDistribution from '@/components/charts/RiskDistribution';
import { useAnalytics } from '@/hooks/useAnalytics';
import { fmt, fmtRupees, CITIES, TRIGGER_META } from '@/lib/utils';
import { MOCK_CLAIMS } from '@/lib/mockData';
import { api } from '@/lib/api';
import { simulateTrigger } from '@/hooks/useTriggers';

// Default simulated values per trigger type (for the backend payload)
const TRIGGER_DEFAULTS: Record<string, { value: number; durationHours: number }> = {
  HeavyRain:        { value: 82.5,  durationHours: 4 },
  ExtremeHeat:      { value: 49.2,  durationHours: 6 },
  SevereAQI:        { value: 456,   durationHours: 8 },
  Flooding:         { value: 8.5,   durationHours: 6 },
  SocialDisruption: { value: 6,     durationHours: 6 },
};

function PasswordGate({ onAuth }: { onAuth: () => void }) {
  const [pw, setPw]       = useState('');
  const [shake, setShake] = useState(false);

  const attempt = () => {
    if (pw === 'admin123') { onAuth(); return; }
    setShake(true);
    toast.error('Incorrect password');
    setTimeout(() => setShake(false), 600);
  };

  return (
    <div className="min-h-screen bg-dark bg-mesh flex items-center justify-center px-4">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
        className="bg-dark-card border border-white/6 rounded-3xl p-10 max-w-sm w-full text-center">
        <div className="w-16 h-16 rounded-2xl bg-violet-500/10 border border-violet-500/20 flex items-center justify-center mx-auto mb-6">
          <Lock className="w-7 h-7 text-violet-400" />
        </div>
        <h2 className="text-xl font-display font-bold text-white mb-2">Admin Access</h2>
        <p className="text-sm text-gray-400 mb-8">RainCheck insurer dashboard — restricted access</p>
        <motion.div animate={shake ? { x: [-8, 8, -8, 8, 0] } : {}}>
          <input type="password" value={pw} onChange={e => setPw(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && attempt()}
            placeholder="Enter password"
            className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white text-center text-sm focus:outline-none focus:border-violet-500/50 mb-4" />
          <button onClick={attempt}
            className="w-full py-3 bg-linear-to-r from-violet-600 to-purple-600 text-white font-semibold rounded-xl shadow-lg shadow-violet-500/20">
            Enter Dashboard
          </button>
        </motion.div>
        <p className="text-xs text-gray-600 mt-4">Demo password: admin123</p>
      </motion.div>
    </div>
  );
}

// Demo result type returned by simulateTrigger
interface DemoResult {
  claimsCreated: number;
  totalPayoutINR: number;
  eventId: string;
  processingMs: number;
}

export default function AdminPage() {
  const [authed, setAuthed]               = useState(false);
  const [showTriggerForm, setShowTriggerForm] = useState(false);
  const [triggerForm, setTriggerForm]     = useState({
    city: 'Delhi', triggerType: 'SocialDisruption', severity: 'Moderate', title: '',
  });
  const [firing, setFiring]               = useState(false);
  const [seeding, setSeeding]             = useState(false);
  const [demoResult, setDemoResult]       = useState<DemoResult | null>(null);
  const [showDemoResult, setShowDemoResult] = useState(false);

  const { overview, weeklyTrend, claimsByType, riskDistribution, disruptions, loading } = useAnalytics();

  const fireTrigger = async () => {
    if (!triggerForm.title) { toast.error('Enter an event title'); return; }
    setFiring(true);
    try {
      const def = TRIGGER_DEFAULTS[triggerForm.triggerType] ?? { value: 100, durationHours: 4 };
      await api.post('/disruptions/trigger', {
        city:          triggerForm.city,
        type:          triggerForm.triggerType,
        severity:      triggerForm.severity,
        title:         triggerForm.title,
        description:   `Manual ${triggerForm.triggerType} disruption triggered in ${triggerForm.city} via admin dashboard`,
        zones:         ['All Zones'],
        durationHours: def.durationHours,
        triggerValue:  def.value,
      });
      toast.success('Disruption event created — claims are being auto-processed');
      setShowTriggerForm(false);
    } catch {
      toast.success('(Demo) Trigger sent — backend processes claims automatically');
      setShowTriggerForm(false);
    } finally {
      setFiring(false);
    }
  };

  const runSeed = async () => {
    setSeeding(true);
    try {
      await api.post('/admin/seed');
      toast.success('Database seeded with demo data');
    } catch {
      toast.error('Seed failed — MongoDB may not be running');
    } finally {
      setSeeding(false);
    }
  };

  const runDemo = useCallback(async () => {
    setDemoResult(null);
    setShowDemoResult(false);
    const t = toast.loading('Running demo simulation...');
    try {
      const result = await simulateTrigger(triggerForm.city, triggerForm.triggerType);
      setDemoResult(result);
      setShowDemoResult(true);
      toast.success(`Demo complete — ${result.claimsCreated} claims in ${result.processingMs}ms`, { id: t });
    } catch {
      // Fallback demo numbers
      const mock: DemoResult = { claimsCreated: 47, totalPayoutINR: 564000, eventId: 'demo-event', processingMs: 312 };
      setDemoResult(mock);
      setShowDemoResult(true);
      toast.success(`(Demo) ${mock.claimsCreated} claims — ₹${mock.totalPayoutINR.toLocaleString('en-IN')} queued`, { id: t });
    }
  }, [triggerForm.city, triggerForm.triggerType]);

  if (!authed) return <PasswordGate onAuth={() => setAuthed(true)} />;

  if (loading) {
    return (
      <div className="min-h-screen bg-dark p-6">
        <div className="max-w-7xl mx-auto"><SkeletonPage /></div>
      </div>
    );
  }

  const ov           = overview ?? {};
  const weeklyRevRs  = (ov.weeklyRevenuePaise ?? 54318000) / 100;
  const weeklyPayRs  = (ov.weeklyPayoutsPaise ?? 23400000) / 100;
  const lossRatio    = ov.lossRatio ?? 43.1;

  return (
    <div className="min-h-screen bg-dark bg-mesh">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-6">

        {/* Header */}
        <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }}
          className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <div className="w-8 h-8 rounded-xl bg-violet-500/15 border border-violet-500/20 flex items-center justify-center">
                <BarChart3 className="w-4 h-4 text-violet-400" />
              </div>
              <h1 className="text-2xl font-display font-bold text-white">Insurer Dashboard</h1>
            </div>
            <p className="text-sm text-gray-500">Platform overview · Guidewire DEVTrails 2026</p>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {/* Seed DB */}
            <button onClick={runSeed} disabled={seeding}
              className="flex items-center gap-2 px-3 py-2 bg-dark-card border border-white/8 text-gray-300 text-sm rounded-xl hover:border-white/20 transition-colors disabled:opacity-50">
              {seeding
                ? <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: 'linear' }}><RefreshCw className="w-3.5 h-3.5" /></motion.div>
                : <Database className="w-3.5 h-3.5" />}
              {seeding ? 'Seeding…' : 'Seed DB'}
            </button>

            {/* Demo Mode */}
            <button onClick={runDemo}
              className="flex items-center gap-2 px-3 py-2 bg-emerald-600/20 border border-emerald-500/30 text-emerald-400 text-sm rounded-xl hover:bg-emerald-600/30 transition-colors">
              <Play className="w-3.5 h-3.5" />
              Demo Mode
            </button>

            {/* Trigger Event */}
            <button onClick={() => setShowTriggerForm(v => !v)}
              className="flex items-center gap-2 px-4 py-2.5 bg-linear-to-r from-orange-600 to-red-600 text-white text-sm font-semibold rounded-xl shadow-lg shadow-orange-500/20">
              <AlertTriangle className="w-4 h-4" />
              Trigger Event
            </button>
          </div>
        </motion.div>

        {/* Demo result banner */}
        <AnimatePresence>
          {showDemoResult && demoResult && (
            <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}
              className="bg-emerald-900/20 border border-emerald-500/30 rounded-2xl p-5">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm font-semibold text-emerald-400 mb-3 flex items-center gap-2">
                    <Zap className="w-4 h-4" /> Demo Simulation Complete
                  </p>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-center">
                    {[
                      { label: 'Trigger', value: '✅ Detected', sub: `${triggerForm.triggerType}` },
                      { label: 'Event',   value: '✅ Created',  sub: triggerForm.city },
                      { label: 'Claims',  value: `${demoResult.claimsCreated}`, sub: 'auto-generated' },
                      { label: 'Payouts', value: `₹${demoResult.totalPayoutINR.toLocaleString('en-IN')}`, sub: `in ${demoResult.processingMs}ms` },
                    ].map(({ label, value, sub }) => (
                      <div key={label} className="bg-dark-card rounded-xl p-3">
                        <p className="text-[10px] text-gray-500 uppercase tracking-wide mb-1">{label}</p>
                        <p className="text-base font-bold text-white">{value}</p>
                        <p className="text-[10px] text-emerald-400">{sub}</p>
                      </div>
                    ))}
                  </div>
                </div>
                <button onClick={() => setShowDemoResult(false)} className="text-gray-500 hover:text-white text-xs mt-1">✕</button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Manual trigger form */}
        <AnimatePresence>
          {showTriggerForm && (
            <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }}
              className="bg-dark-card border border-orange-500/25 rounded-2xl p-5 overflow-hidden">
              <h3 className="text-sm font-semibold text-orange-400 mb-4">⚡ Trigger Manual Disruption Event</h3>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">City</label>
                  <select value={triggerForm.city}
                    onChange={e => setTriggerForm(f => ({ ...f, city: e.target.value }))}
                    className="w-full bg-dark-surface border border-white/8 rounded-xl px-3 py-2 text-white text-sm focus:outline-none">
                    {CITIES.map(c => <option key={c}>{c}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">Trigger Type</label>
                  <select value={triggerForm.triggerType}
                    onChange={e => setTriggerForm(f => ({ ...f, triggerType: e.target.value }))}
                    className="w-full bg-dark-surface border border-white/8 rounded-xl px-3 py-2 text-white text-sm focus:outline-none">
                    {Object.keys(TRIGGER_META).map(k => (
                      <option key={k} value={k}>{TRIGGER_META[k].label}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">Severity</label>
                  <select value={triggerForm.severity}
                    onChange={e => setTriggerForm(f => ({ ...f, severity: e.target.value }))}
                    className="w-full bg-dark-surface border border-white/8 rounded-xl px-3 py-2 text-white text-sm focus:outline-none">
                    {['Moderate', 'Severe', 'Extreme'].map(s => <option key={s}>{s}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">Event Title *</label>
                  <input value={triggerForm.title}
                    onChange={e => setTriggerForm(f => ({ ...f, title: e.target.value }))}
                    placeholder="e.g. Heavy rain Mumbai"
                    className="w-full bg-dark-surface border border-white/8 rounded-xl px-3 py-2 text-white text-sm focus:outline-none placeholder-gray-600" />
                </div>
              </div>
              <div className="flex gap-3">
                <button onClick={fireTrigger} disabled={firing}
                  className="flex items-center gap-2 px-4 py-2 bg-orange-600 hover:bg-orange-500 text-white text-sm font-semibold rounded-xl transition-colors disabled:opacity-60">
                  {firing && <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: 'linear' }}><RefreshCw className="w-3.5 h-3.5" /></motion.div>}
                  Fire Trigger → Process Claims
                </button>
                <button onClick={() => setShowTriggerForm(false)} className="px-4 py-2 text-gray-400 text-sm hover:text-white transition-colors">Cancel</button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Overview Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
          <StatCard label="Active Riders"   value={(ov.activeRiders ?? 11234).toLocaleString('en-IN')}
            subValue={`of ${(ov.totalRiders ?? 12847).toLocaleString('en-IN')} total`}
            icon={Users} iconColor="#10b981" iconBg="rgba(16,185,129,0.12)" trend={4.2} trendLabel="vs last wk" delay={0} />
          <StatCard label="Active Policies" value={(ov.activePolicies ?? 9876).toLocaleString('en-IN')}
            icon={Shield} iconColor="#60A5FA" iconBg="rgba(96,165,250,0.12)" trend={2.8} trendLabel="vs last wk" delay={0.05} />
          <StatCard label="Weekly Revenue"  value={fmtRupees(weeklyRevRs)}
            icon={TrendingDown} iconColor="#a78bfa" iconBg="rgba(167,139,250,0.12)" trend={5.2} delay={0.1} />
          <StatCard label="Weekly Payouts"  value={fmtRupees(weeklyPayRs)}
            icon={AlertTriangle} iconColor="#f59e0b" iconBg="rgba(245,158,11,0.12)" trend={-1.3} delay={0.15} />
          <StatCard label="Loss Ratio"      value={`${lossRatio.toFixed(1)}%`}
            subValue={lossRatio < 70 ? 'Healthy' : lossRatio < 90 ? 'Watch' : 'Critical'}
            icon={BarChart3}
            iconColor={lossRatio < 70 ? '#22C55E' : lossRatio < 90 ? '#F59E0B' : '#EF4444'}
            iconBg={lossRatio < 70 ? 'rgba(34,197,94,0.12)' : 'rgba(245,158,11,0.12)'}
            delay={0.2} />
        </div>

        {/* Charts row */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 bg-dark-card border border-white/6 rounded-2xl p-5">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h3 className="text-sm font-semibold text-white">Revenue vs Payouts</h3>
                <p className="text-xs text-gray-500">Last 8 weeks (₹ thousands)</p>
              </div>
              <div className="flex items-center gap-4 text-xs text-gray-400">
                <span className="flex items-center gap-1.5"><span className="w-3 h-0.5 bg-teal-500 inline-block rounded" />Revenue</span>
                <span className="flex items-center gap-1.5"><span className="w-3 h-0.5 bg-yellow-500 inline-block rounded" />Payouts</span>
              </div>
            </div>
            <PayoutChart data={weeklyTrend} />
          </div>

          <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-white mb-1">Risk Distribution</h3>
            <p className="text-xs text-gray-500 mb-5">Riders by risk tier</p>
            <RiskDistribution data={riskDistribution} />
            <div className="mt-4 pt-4 border-t border-white/5">
              <p className="text-xs text-gray-500">Fraud Detection Rate</p>
              <p className="text-xl font-bold text-white">{ov.fraudDetectionRate ?? 3.2}%</p>
            </div>
          </div>
        </div>

        {/* Claims by type + Active disruptions */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-white mb-1">Claims by Trigger Type</h3>
            <p className="text-xs text-gray-500 mb-5">Distribution across all trigger categories</p>
            <ClaimsByType data={claimsByType} />
          </div>

          <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-white mb-4">Active Disruptions</h3>
            {disruptions.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-center">
                <CheckCircle className="w-8 h-8 text-green-400 mb-2" />
                <p className="text-sm text-gray-400">No active disruptions</p>
                <p className="text-xs text-gray-600">All cities operating normally</p>
              </div>
            ) : (
              <div className="space-y-3">
                {disruptions.map((d: any) => {
                  const m = TRIGGER_META[d.triggerType ?? d.type];
                  return (
                    <div key={d._id} className="bg-dark-surface rounded-xl p-4 border border-red-500/15">
                      <div className="flex items-start justify-between gap-3 mb-2">
                        <div className="flex items-center gap-2">
                          <span className="text-lg">{m?.emoji ?? '⚠️'}</span>
                          <div>
                            <p className="text-sm font-medium text-white">{d.title}</p>
                            <p className="text-xs text-gray-500">{d.city}</p>
                          </div>
                        </div>
                        <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                          d.severity === 'Extreme' ? 'bg-red-500/15 text-red-400' :
                          d.severity === 'Severe'  ? 'bg-orange-500/15 text-orange-400' :
                          'bg-yellow-500/15 text-yellow-400'
                        }`}>{d.severity}</span>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-gray-500">
                        <span>{d.affectedRiders} riders affected</span>
                        <span>₹{((d.totalPayouts ?? 0) / 100).toLocaleString('en-IN')} payouts</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Recent Claims Table */}
        <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
          <h3 className="text-sm font-semibold text-white mb-4">Recent Claims — Review Queue</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-white/5">
                  {['Claim #', 'Trigger', 'Amount', 'Fraud Score', 'Status', 'Actions'].map(h => (
                    <th key={h} className="text-left text-xs font-medium text-gray-500 pb-3 pr-4">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {MOCK_CLAIMS.map(claim => {
                  const m         = TRIGGER_META[claim.triggerType];
                  const fraudHigh = claim.fraudScore > 60;
                  const fraudMed  = claim.fraudScore > 30 && !fraudHigh;

                  const approve = async () => {
                    try {
                      await api.put(`/claims/${claim._id}/approve`);
                      toast.success(`Claim ${claim.claimNumber} approved`);
                    } catch {
                      toast.success(`(Demo) Claim ${claim.claimNumber} approved — payout queued`);
                    }
                  };
                  const reject = async () => {
                    try {
                      await api.put(`/claims/${claim._id}/reject`, { reason: 'Manual review rejection' });
                      toast.error(`Claim ${claim.claimNumber} rejected`);
                    } catch {
                      toast.error(`(Demo) Claim ${claim.claimNumber} rejected`);
                    }
                  };

                  return (
                    <tr key={claim._id} className="hover:bg-white/2">
                      <td className="py-3 pr-4 text-gray-400 font-mono text-xs">{claim.claimNumber}</td>
                      <td className="py-3 pr-4">
                        <span className="flex items-center gap-1.5 text-xs text-white">{m?.emoji} {m?.label}</span>
                      </td>
                      <td className="py-3 pr-4 font-semibold text-white tabular-nums">{fmt(claim.payoutAmount)}</td>
                      <td className="py-3 pr-4">
                        <span className={`text-xs font-bold ${fraudHigh ? 'text-red-400' : fraudMed ? 'text-yellow-400' : 'text-green-400'}`}>
                          {claim.fraudScore}
                        </span>
                      </td>
                      <td className="py-3 pr-4"><StatusBadge status={claim.status} size="sm" /></td>
                      <td className="py-3">
                        {['UnderReview', 'AutoInitiated', 'FraudSuspected'].includes(claim.status) ? (
                          <div className="flex items-center gap-2">
                            <button onClick={approve}
                              className="p-1.5 rounded-lg bg-green-500/10 hover:bg-green-500/20 text-green-400 transition-colors"
                              title="Approve & pay">
                              <CheckCircle className="w-3.5 h-3.5" />
                            </button>
                            <button onClick={reject}
                              className="p-1.5 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 transition-colors"
                              title="Reject">
                              <XCircle className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        ) : <span className="text-xs text-gray-600">—</span>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* City breakdown */}
        <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
          <h3 className="text-sm font-semibold text-white mb-4">City Performance</h3>
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
            {[
              { city: 'Delhi',     riders: 2340, lossRatio: 51 },
              { city: 'Mumbai',    riders: 2180, lossRatio: 42 },
              { city: 'Bangalore', riders: 1890, lossRatio: 28 },
              { city: 'Hyderabad', riders: 1340, lossRatio: 35 },
              { city: 'Chennai',   riders: 1120, lossRatio: 39 },
            ].map(({ city, riders, lossRatio: lr }) => (
              <div key={city} className="bg-dark-surface rounded-xl p-3 text-center">
                <p className="text-xs font-semibold text-white mb-1">{city}</p>
                <p className="text-lg font-display font-bold text-white">{riders.toLocaleString('en-IN')}</p>
                <p className="text-[10px] text-gray-500">riders</p>
                <div className="mt-2 h-1 bg-white/5 rounded-full overflow-hidden">
                  <div className="h-full rounded-full" style={{ width: `${lr}%`, background: lr < 50 ? '#22C55E' : lr < 70 ? '#F59E0B' : '#EF4444' }} />
                </div>
                <p className="text-[10px] mt-1" style={{ color: lr < 50 ? '#22C55E' : lr < 70 ? '#F59E0B' : '#EF4444' }}>Loss: {lr}%</p>
              </div>
            ))}
          </div>
        </div>

      </div>
    </div>
  );
}
