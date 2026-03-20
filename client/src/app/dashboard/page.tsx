'use client';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import Link from 'next/link';
import { Bell, RefreshCw, TrendingUp, Shield, Zap, ChevronRight, ArrowUpRight } from 'lucide-react';
import Sidebar from '@/components/layout/Sidebar';
import StatCard from '@/components/ui/StatCard';
import ClaimCard from '@/components/ui/ClaimCard';
import WeatherWidget from '@/components/ui/WeatherWidget';
import StatusBadge from '@/components/ui/StatusBadge';
import { SkeletonPage } from '@/components/ui/LoadingSkeleton';
import EmptyState from '@/components/ui/EmptyState';
import { useRiderDashboard } from '@/hooks/useRiderDashboard';
import { useWeather } from '@/hooks/useWeather';
import { fmt, formatDate, getGreeting, riskTierColors, TRIGGER_META } from '@/lib/utils';

// Simplified zone risk heatmap using SVG grid
function ZoneHeatmap({ riderZone }: { riderZone: string }) {
  const zones = [
    { name: 'Zone A', risk: 2 }, { name: 'Zone B', risk: 4 }, { name: 'Zone C', risk: 3 },
    { name: 'Zone D', risk: 1 }, { name: riderZone || 'Your Zone', risk: 3, isRider: true }, { name: 'Zone F', risk: 5 },
    { name: 'Zone G', risk: 2 }, { name: 'Zone H', risk: 3 }, { name: 'Zone I', risk: 4 },
  ];
  const riskColor = (r: number) => {
    if (r <= 1) return '#22C55E'; if (r <= 2) return '#84CC16';
    if (r <= 3) return '#F59E0B'; if (r <= 4) return '#F97316'; return '#EF4444';
  };
  return (
    <div className="grid grid-cols-3 gap-2">
      {zones.map((z) => (
        <div key={z.name} className="relative rounded-xl p-2 flex flex-col items-center justify-center aspect-square text-center"
          style={{ background: `${riskColor(z.risk)}15`, border: `1px solid ${riskColor(z.risk)}${(z as any).isRider ? '60' : '25'}` }}>
          {(z as any).isRider && (
            <div className="absolute top-1 right-1 w-2 h-2 rounded-full bg-teal-400">
              <div className="absolute inset-0 rounded-full bg-teal-400 animate-ping opacity-60" />
            </div>
          )}
          <p className="text-[10px] font-medium text-white/80 leading-tight">{z.name}</p>
          <p className="text-[10px] font-bold mt-0.5" style={{ color: riskColor(z.risk) }}>
            {'▮'.repeat(z.risk)}{'▯'.repeat(5 - z.risk)}
          </p>
        </div>
      ))}
    </div>
  );
}

export default function DashboardPage() {
  const [riderId, setRiderId] = useState<string | null>(null);
  const [riderName, setRiderName] = useState('Rider');
  const [city, setCity] = useState('Mumbai');

  useEffect(() => {
    setRiderId(localStorage.getItem('rc_rider_id'));
    setRiderName(localStorage.getItem('rc_rider_name') ?? 'Rider');
    setCity(localStorage.getItem('rc_city') ?? 'Mumbai');
  }, []);

  const { rider, policy, claims, loading } = useRiderDashboard(riderId);
  const { data: weather, loading: weatherLoading, refresh: refreshWeather } = useWeather(city);

  if (loading) {
    return (
      <div className="flex">
        <Sidebar />
        <main className="lg:ml-[240px] flex-1 min-h-screen bg-dark p-6 pt-20 lg:pt-6">
          <div className="max-w-5xl mx-auto"><SkeletonPage /></div>
        </main>
      </div>
    );
  }

  const policyActive = policy?.status === 'Active';
  const daysLeft = policy?.endDate ? Math.max(0, Math.ceil((new Date(policy.endDate).getTime() - Date.now()) / 86400000)) : 0;
  const tierColors = riskTierColors(rider?.riskTier ?? 'Medium');
  const totalPaid = claims.filter(c => c.status === 'Paid').reduce((s: number, c: any) => s + (c.payoutAmount ?? 0), 0);

  return (
    <div className="flex">
      <Sidebar riderName={rider?.name ?? riderName} riderCity={rider?.city ?? city} policyStatus={policy?.status} />

      <main className="lg:ml-[240px] flex-1 min-h-screen bg-dark bg-mesh pt-14 lg:pt-0">
        <div className="max-w-5xl mx-auto p-6 space-y-6">

          {/* Top bar */}
          <div className="flex items-center justify-between">
            <motion.div initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }}>
              <p className="text-sm text-gray-500">{getGreeting()},</p>
              <h1 className="text-2xl font-display font-bold text-white">{rider?.name ?? riderName} 👋</h1>
            </motion.div>
            <div className="flex items-center gap-3">
              {policyActive && (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-green-500/10 border border-green-500/20 rounded-full text-xs font-medium text-green-400">
                  <div className="relative w-2 h-2">
                    <div className="absolute inset-0 bg-green-400 rounded-full animate-ping opacity-60" />
                    <div className="relative w-2 h-2 bg-green-400 rounded-full" />
                  </div>
                  Coverage Active
                </div>
              )}
              <button className="relative p-2.5 bg-dark-card border border-white/6 rounded-xl text-gray-400 hover:text-white transition-colors">
                <Bell className="w-4 h-4" />
                {weather?.isDisruptionActive && (
                  <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
                )}
              </button>
            </div>
          </div>

          {/* Coverage Hero Card */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}
            className={`rounded-3xl p-6 border ${policyActive ? 'bg-linear-to-br from-teal-500/10 to-emerald-500/5 border-teal-500/20' : 'bg-dark-card border-red-500/20'}`}>
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-3 mb-3">
                  <div className={`w-10 h-10 rounded-2xl flex items-center justify-center ${policyActive ? 'bg-teal-500/20' : 'bg-red-500/20'}`}>
                    <Shield className={`w-5 h-5 ${policyActive ? 'text-teal-400' : 'text-red-400'}`} />
                  </div>
                  <div>
                    <p className={`text-lg font-display font-bold ${policyActive ? 'text-white' : 'text-red-400'}`}>
                      {policyActive ? "You're Protected ✓" : 'Coverage Inactive'}
                    </p>
                    <p className="text-xs text-gray-500">{policy?.policyNumber ?? 'No active policy'}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4 text-sm">
                  <span className="text-gray-400">Plan: <strong className="text-white">{policy?.planType ?? '—'}</strong></span>
                  {policyActive && <span className="text-gray-400">Expires in: <strong className="text-teal-400">{daysLeft} days</strong></span>}
                </div>
              </div>
              <div className="flex flex-col sm:items-end gap-2">
                <div className="text-right">
                  <p className="text-xs text-gray-500">Weekly Premium</p>
                  <p className="text-2xl font-display font-bold text-white tabular-nums">{fmt(policy?.weeklyPremium ?? 5500)}</p>
                </div>
                <div className="flex gap-2">
                  <StatusBadge status={policy?.status ?? 'PendingPayment'} />
                  <Link href="/onboarding">
                    <button className="text-xs px-3 py-1.5 border border-white/10 rounded-lg text-gray-400 hover:text-white hover:border-white/20 transition-all">
                      {policyActive ? 'Upgrade' : 'Activate'}
                    </button>
                  </Link>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Stats Row */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <StatCard label="Total Protected" value={fmt(totalPaid)} subValue={`${claims.filter((c: any) => c.status === 'Paid').length} payouts`}
              icon={Zap} iconColor="#10b981" iconBg="rgba(16,185,129,0.12)" delay={0.15} />
            <StatCard label="Risk Score" value={`${rider?.riskScore ?? 52}`}
              subValue={rider?.riskTier ?? 'Medium'} icon={Shield}
              iconColor={tierColors.text} iconBg={tierColors.bg} delay={0.2} />
            <StatCard label="Avg Earnings/Week" value={`₹${(rider?.avgWeeklyEarnings ?? 5500).toLocaleString('en-IN')}`}
              icon={TrendingUp} iconColor="#60A5FA" iconBg="rgba(96,165,250,0.12)" delay={0.25} />
            <StatCard label="Coverage Limit" value={fmt(policy?.coverageLimit ?? 1500000)}
              icon={Shield} iconColor="#a78bfa" iconBg="rgba(167,139,250,0.12)" delay={0.3} />
          </div>

          {/* Main content grid */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Weather + Zone */}
            <div className="space-y-4">
              <WeatherWidget data={weather} loading={weatherLoading} onRefresh={refreshWeather} />

              {/* Covered Disruptions */}
              <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
                <p className="text-sm font-semibold text-white mb-3">Covered Disruptions</p>
                <div className="space-y-2">
                  {(policy?.coveredDisruptions ?? ['HeavyRain', 'SevereAQI']).map((d: string) => {
                    const m = TRIGGER_META[d];
                    return m ? (
                      <div key={d} className="flex items-center gap-2.5 text-xs">
                        <span>{m.emoji}</span>
                        <span className="text-gray-300">{m.label}</span>
                        <span className="ml-auto text-green-400 font-medium">✓ Active</span>
                      </div>
                    ) : null;
                  })}
                </div>
              </div>
            </div>

            {/* Claims + Heatmap */}
            <div className="lg:col-span-2 space-y-4">
              {/* Zone Heatmap */}
              <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
                <div className="flex items-center justify-between mb-4">
                  <p className="text-sm font-semibold text-white">Zone Risk Map — {rider?.city ?? city}</p>
                  <div className="flex items-center gap-2 text-[10px] text-gray-500">
                    <span className="w-2 h-2 bg-teal-400 rounded-full" />Your Zone
                  </div>
                </div>
                <ZoneHeatmap riderZone={rider?.zone ?? 'Your Zone'} />
                <div className="flex items-center gap-4 mt-3 text-[10px] text-gray-600">
                  <span className="flex items-center gap-1"><span className="w-2 h-2 bg-green-500 rounded" />Low</span>
                  <span className="flex items-center gap-1"><span className="w-2 h-2 bg-yellow-500 rounded" />Medium</span>
                  <span className="flex items-center gap-1"><span className="w-2 h-2 bg-red-500 rounded" />High</span>
                </div>
              </div>

              {/* Recent Claims */}
              <div className="bg-dark-card border border-white/6 rounded-2xl p-5">
                <div className="flex items-center justify-between mb-4">
                  <p className="text-sm font-semibold text-white">Recent Claims</p>
                  <Link href="/claims" className="text-xs text-teal-400 hover:text-teal-300 flex items-center gap-1">
                    View All <ArrowUpRight className="w-3 h-3" />
                  </Link>
                </div>
                {claims.length === 0 ? (
                  <EmptyState emoji="📋" title="No claims yet" description="When a disruption trigger fires in your zone, your claim appears here automatically." />
                ) : (
                  <div className="space-y-2">
                    {claims.slice(0, 4).map((c: any) => <ClaimCard key={c._id} claim={c} />)}
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Quick actions */}
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }}
            className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {[
              { href: '/claims', label: 'All Claims', icon: '📋', desc: `${claims.length} total` },
              { href: '/triggers', label: 'Live Triggers', icon: '⚡', desc: `${city} status` },
              { href: '/onboarding', label: 'Upgrade Plan', icon: '🚀', desc: 'More coverage' },
            ].map(({ href, label, icon, desc }) => (
              <Link key={href} href={href}>
                <motion.div whileHover={{ y: -2, transition: { duration: 0.15 } }}
                  className="bg-dark-card border border-white/6 rounded-2xl p-4 hover:border-white/10 transition-all group cursor-pointer">
                  <span className="text-xl mb-2 block">{icon}</span>
                  <p className="text-sm font-medium text-white group-hover:text-teal-400 transition-colors">{label}</p>
                  <p className="text-xs text-gray-500">{desc}</p>
                  <ChevronRight className="w-4 h-4 text-gray-600 group-hover:text-teal-400 mt-2 transition-colors" />
                </motion.div>
              </Link>
            ))}
          </motion.div>
        </div>
      </main>
    </div>
  );
}
