'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { toast } from 'react-hot-toast';
import { ChevronRight, ChevronLeft, Check, CloudRain, Shield, User, MapPin, Briefcase, BarChart3, CreditCard } from 'lucide-react';
import Navbar from '@/components/layout/Navbar';
import RiskMeter from '@/components/ui/RiskMeter';
import PlanCard from '@/components/ui/PlanCard';
import { api, mlApi } from '@/lib/api';
import { CITIES, TRIGGER_META } from '@/lib/utils';

const STEPS = [
  { id: 1, icon: User,      label: 'Basic Info' },
  { id: 2, icon: MapPin,    label: 'Location' },
  { id: 3, icon: Briefcase, label: 'Work Profile' },
  { id: 4, icon: BarChart3, label: 'Risk Analysis' },
  { id: 5, icon: Shield,    label: 'Choose Plan' },
  { id: 6, icon: CreditCard, label: 'Confirm' },
];

const PLAN_DEFS = [
  { planType: 'Basic' as const,    weeklyPremium: 2900, coverageLimit: 750000,  coveredDisruptions: ['HeavyRain', 'SevereAQI'] },
  { planType: 'Standard' as const, weeklyPremium: 5500, coverageLimit: 1500000, coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'], recommended: true },
  { planType: 'Premium' as const,  weeklyPremium: 7500, coverageLimit: 2500000, coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'] },
];

const ZONE_SUGGESTIONS: Record<string, string[]> = {
  Mumbai: ['Andheri West', 'Bandra', 'Kurla', 'Dadar', 'Thane'],
  Delhi: ['Connaught Place', 'Lajpat Nagar', 'Rohini', 'Dwarka', 'Saket'],
  Bangalore: ['Koramangala', 'Indiranagar', 'Whitefield', 'HSR Layout', 'Jayanagar'],
  Hyderabad: ['Banjara Hills', 'Hitech City', 'Kukatpally', 'Ameerpet', 'Gachibowli'],
  Chennai: ['Anna Nagar', 'T Nagar', 'Velachery', 'Adyar', 'Tambaram'],
  Pune: ['Kothrud', 'Viman Nagar', 'Baner', 'Aundh', 'Hadapsar'],
  Kolkata: ['Park Street', 'Salt Lake', 'Howrah', 'Behala', 'Dum Dum'],
  Jaipur: ['Malviya Nagar', 'Vaishali Nagar', 'Mansarovar', 'C Scheme', 'Sodala'],
  Ahmedabad: ['Navrangpura', 'Satellite', 'Prahlad Nagar', 'Bopal', 'Maninagar'],
  Lucknow: ['Hazratganj', 'Gomti Nagar', 'Alambagh', 'Charbagh', 'Vikas Nagar'],
};

const slide = {
  initial: { opacity: 0, x: 40 },
  animate: { opacity: 1, x: 0 },
  exit:    { opacity: 0, x: -40 },
};

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [form, setForm] = useState({
    name: '', phone: '', email: '', platform: 'Swiggy',
    city: 'Mumbai', zone: '', pincode: '',
    weeklyEarnings: 4000, dailyHours: 8, shift: 'evening',
    vehicle: 'motorcycle', experienceMonths: 12,
  });
  const [risk, setRisk] = useState<{ score: number; tier: string; topRisks: string[] } | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [analyzeProgress, setAnalyzeProgress] = useState(0);
  const [selectedPlan, setSelectedPlan] = useState<string | null>('Standard');
  const [completing, setCompleting] = useState(false);

  const update = (key: string, value: any) => setForm(f => ({ ...f, [key]: value }));

  const runRiskAnalysis = async () => {
    setAnalyzing(true);
    setAnalyzeProgress(0);

    // Animate progress bar
    const prog = setInterval(() => setAnalyzeProgress(p => Math.min(p + 3, 90)), 80);

    try {
      const res = await mlApi.post('/assess-risk', {
        city: form.city, platform: form.platform, preferred_shift: form.shift,
        vehicle_type: form.vehicle, avg_weekly_earnings: form.weeklyEarnings,
        avg_daily_hours: form.dailyHours, experience_months: form.experienceMonths,
        historical_claims_count: 0, historical_disruption_freq: 0.2,
        zone_risk_level: 3, aqi_avg_30d: 120, rainfall_avg_30d: 40, temperature_avg_30d: 32,
      });
      const d = res.data ?? res;
      clearInterval(prog);
      setAnalyzeProgress(100);
      setTimeout(() => {
        setRisk({
          score: d.risk_score ?? 52,
          tier: d.risk_tier ?? 'Medium',
          topRisks: d.top_risk_factors ?? ['HeavyRain', 'SevereAQI'],
        });
        setAnalyzing(false);
      }, 400);
    } catch {
      clearInterval(prog);
      setAnalyzeProgress(100);
      // Fallback heuristic risk based on city
      const cityRisk: Record<string, { score: number; tier: string }> = {
        Delhi: { score: 72, tier: 'High' }, Mumbai: { score: 55, tier: 'Medium' },
        Bangalore: { score: 32, tier: 'Low' }, Jaipur: { score: 63, tier: 'High' },
        Ahmedabad: { score: 61, tier: 'High' },
      };
      const c = cityRisk[form.city] ?? { score: 48, tier: 'Medium' };
      setTimeout(() => {
        setRisk({ score: c.score, tier: c.tier, topRisks: ['HeavyRain', 'SevereAQI', 'ExtremeHeat'] });
        setAnalyzing(false);
      }, 400);
    }
  };

  const goNext = async () => {
    if (step === 1) {
      if (!form.name || !form.phone) { toast.error('Please fill in your name and phone number'); return; }
      if (!/^[6-9]\d{9}$/.test(form.phone)) { toast.error('Enter a valid 10-digit Indian mobile number'); return; }
    }
    if (step === 2) {
      if (!form.zone) { toast.error('Please enter your operating zone'); return; }
      if (form.pincode && !/^\d{6}$/.test(form.pincode)) { toast.error('Enter a valid 6-digit pincode'); return; }
    }
    if (step === 3) {
      setStep(4);
      await runRiskAnalysis();
      return;
    }
    setStep(s => s + 1);
  };

  const handleActivate = async () => {
    setCompleting(true);
    try {
      // Create rider
      const riderRes = await api.post('/riders/register', {
        name: form.name, phone: form.phone, email: form.email || undefined,
        city: form.city, platform: form.platform, vehicleType: form.vehicle,
        preferredShift: form.shift, avgWeeklyEarnings: form.weeklyEarnings,
        avgDailyHours: form.dailyHours, experienceMonths: form.experienceMonths,
        zone: form.zone, pincode: form.pincode,
      });
      const riderId = (riderRes as any).data?.rider?._id ?? 'demo-rider-001';

      // Create policy
      await api.post('/policies/create', {
        riderId, planType: selectedPlan,
        city: form.city, experienceMonths: form.experienceMonths, recentClaims: 0,
      });

      localStorage.setItem('rc_rider_id', riderId);
      localStorage.setItem('rc_rider_name', form.name);
      localStorage.setItem('rc_city', form.city);
      localStorage.setItem('rc_plan', selectedPlan ?? 'Standard');
    } catch {
      // Demo mode — save mock values
      localStorage.setItem('rc_rider_id', 'demo-rider-001');
      localStorage.setItem('rc_rider_name', form.name || 'Rahul Sharma');
      localStorage.setItem('rc_city', form.city);
      localStorage.setItem('rc_plan', selectedPlan ?? 'Standard');
    }

    toast.success('Coverage activated!');
    setTimeout(() => router.push('/dashboard'), 1000);
  };

  const PLAN_BREAKDOWNS: Record<string, string> = {
    Basic:    `₹29/wk = ₹29 base rate · 2 disruption types covered`,
    Standard: `₹55/wk = ₹35 base + ₹12 city risk + ₹8 seasonal — ₹5 exp. discount`,
    Premium:  `₹75/wk = ₹45 base + ₹18 city risk + ₹12 all triggers included`,
  };

  return (
    <div className="min-h-screen bg-dark bg-mesh">
      <Navbar />

      <div className="max-w-3xl mx-auto px-4 pt-24 pb-16">
        {/* Progress bar */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-4 overflow-x-auto gap-1">
            {STEPS.map(({ id, icon: Icon, label }) => (
              <div key={id} className="flex flex-col items-center gap-1 min-w-0 flex-1">
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all duration-300 ${
                  id < step ? 'bg-teal-500 text-white' : id === step ? 'bg-teal-500/20 border-2 border-teal-500 text-teal-400' : 'bg-dark-card border border-white/6 text-gray-600'
                }`}>
                  {id < step ? <Check className="w-4 h-4" /> : <Icon className="w-4 h-4" />}
                </div>
                <span className={`text-[10px] font-medium hidden sm:block ${id === step ? 'text-teal-400' : id < step ? 'text-gray-400' : 'text-gray-600'}`}>{label}</span>
              </div>
            ))}
          </div>
          <div className="h-1 bg-dark-card rounded-full overflow-hidden">
            <motion.div className="h-full bg-linear-to-r from-teal-500 to-emerald-500 rounded-full"
              animate={{ width: `${((step - 1) / (STEPS.length - 1)) * 100}%` }}
              transition={{ duration: 0.4 }} />
          </div>
        </div>

        {/* Step cards */}
        <div className="bg-dark-card border border-white/6 rounded-3xl p-6 sm:p-8 min-h-[420px] flex flex-col">
          <AnimatePresence mode="wait">
            {/* STEP 1: Basic Info */}
            {step === 1 && (
              <motion.div key="s1" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col">
                <h2 className="text-2xl font-display font-bold text-white mb-2">Let's get started</h2>
                <p className="text-gray-400 text-sm mb-8">30 seconds — that's all it takes.</p>

                <div className="space-y-4 flex-1">
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">Full Name *</label>
                    <input value={form.name} onChange={e => update('name', e.target.value)}
                      placeholder="Rahul Sharma"
                      className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-teal-500/50 transition-colors text-sm" />
                  </div>
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">Mobile Number * (+91)</label>
                    <div className="flex gap-3">
                      <div className="flex items-center px-3 bg-dark-surface border border-white/8 rounded-xl text-gray-400 text-sm">+91</div>
                      <input value={form.phone} onChange={e => update('phone', e.target.value.replace(/\D/g, '').slice(0, 10))}
                        placeholder="9876543210" inputMode="numeric"
                        className="flex-1 bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-teal-500/50 transition-colors text-sm" />
                    </div>
                  </div>
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">Email (optional)</label>
                    <input value={form.email} onChange={e => update('email', e.target.value)} type="email"
                      placeholder="rahul@example.com"
                      className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-teal-500/50 transition-colors text-sm" />
                  </div>
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-2 block">Delivery Platform</label>
                    <div className="grid grid-cols-3 gap-3">
                      {['Zomato', 'Swiggy', 'Both'].map(p => (
                        <button key={p} onClick={() => update('platform', p)}
                          className={`py-3 rounded-xl border text-sm font-medium transition-all ${form.platform === p ? 'border-teal-500/50 bg-teal-500/10 text-teal-400' : 'border-white/8 bg-dark-surface text-gray-400 hover:border-white/15'}`}>
                          {p === 'Zomato' ? '🍕 Zomato' : p === 'Swiggy' ? '🧡 Swiggy' : '🛵 Both'}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* STEP 2: Location */}
            {step === 2 && (
              <motion.div key="s2" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col">
                <h2 className="text-2xl font-display font-bold text-white mb-2">Where do you deliver?</h2>
                <p className="text-gray-400 text-sm mb-8">We use your city to calibrate risk thresholds.</p>

                <div className="space-y-4 flex-1">
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">City *</label>
                    <select value={form.city} onChange={e => update('city', e.target.value)}
                      className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-teal-500/50 transition-colors text-sm">
                      {CITIES.map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">Operating Zone / Locality *</label>
                    <input value={form.zone} onChange={e => update('zone', e.target.value)}
                      placeholder="e.g. Andheri West"
                      list="zone-suggestions"
                      className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-teal-500/50 transition-colors text-sm" />
                    <datalist id="zone-suggestions">
                      {(ZONE_SUGGESTIONS[form.city] ?? []).map(z => <option key={z} value={z} />)}
                    </datalist>
                  </div>
                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-1.5 block">Pincode</label>
                    <input value={form.pincode} onChange={e => update('pincode', e.target.value.replace(/\D/g, '').slice(0, 6))}
                      placeholder="400053" inputMode="numeric"
                      className="w-full bg-dark-surface border border-white/8 rounded-xl px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-teal-500/50 transition-colors text-sm" />
                  </div>

                  <div className="bg-linear-to-br from-teal-500/8 to-emerald-500/5 border border-teal-500/15 rounded-2xl p-4">
                    <p className="text-xs text-teal-400 font-medium mb-1">📍 {form.city} coverage zone active</p>
                    <p className="text-xs text-gray-500">Weather sensors monitoring your zone 24/7 for disruption triggers.</p>
                  </div>
                </div>
              </motion.div>
            )}

            {/* STEP 3: Work Profile */}
            {step === 3 && (
              <motion.div key="s3" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col">
                <h2 className="text-2xl font-display font-bold text-white mb-2">Your work profile</h2>
                <p className="text-gray-400 text-sm mb-8">Used to calculate your personalised premium.</p>

                <div className="space-y-5 flex-1">
                  <div>
                    <div className="flex justify-between text-xs mb-2">
                      <span className="text-gray-400 font-medium">Avg Weekly Earnings</span>
                      <span className="text-teal-400 font-bold">₹{form.weeklyEarnings.toLocaleString('en-IN')}</span>
                    </div>
                    <input type="range" min={2000} max={8000} step={100} value={form.weeklyEarnings}
                      onChange={e => update('weeklyEarnings', +e.target.value)}
                      className="w-full accent-teal-500" />
                    <div className="flex justify-between text-[10px] text-gray-600 mt-1"><span>₹2,000</span><span>₹8,000</span></div>
                  </div>

                  <div>
                    <div className="flex justify-between text-xs mb-2">
                      <span className="text-gray-400 font-medium">Avg Daily Hours</span>
                      <span className="text-teal-400 font-bold">{form.dailyHours} hrs</span>
                    </div>
                    <input type="range" min={4} max={14} step={1} value={form.dailyHours}
                      onChange={e => update('dailyHours', +e.target.value)}
                      className="w-full accent-teal-500" />
                    <div className="flex justify-between text-[10px] text-gray-600 mt-1"><span>4h</span><span>14h</span></div>
                  </div>

                  <div>
                    <div className="flex justify-between text-xs mb-2">
                      <span className="text-gray-400 font-medium">Experience</span>
                      <span className="text-teal-400 font-bold">{form.experienceMonths} months</span>
                    </div>
                    <input type="range" min={1} max={60} step={1} value={form.experienceMonths}
                      onChange={e => update('experienceMonths', +e.target.value)}
                      className="w-full accent-teal-500" />
                    <div className="flex justify-between text-[10px] text-gray-600 mt-1"><span>1m</span><span>5 years</span></div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-2 block">Preferred Shift</label>
                    <div className="grid grid-cols-5 gap-2">
                      {[['morning','🌅'], ['afternoon','☀️'], ['evening','🌆'], ['night','🌙'], ['mixed','🔄']].map(([s, e]) => (
                        <button key={s} onClick={() => update('shift', s)}
                          className={`py-2 rounded-xl border text-xs font-medium transition-all flex flex-col items-center gap-1 ${form.shift === s ? 'border-teal-500/50 bg-teal-500/10 text-teal-400' : 'border-white/8 bg-dark-surface text-gray-500'}`}>
                          <span>{e}</span>
                          <span className="capitalize hidden sm:block">{s}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-gray-400 mb-2 block">Vehicle Type</label>
                    <div className="grid grid-cols-3 gap-3">
                      {[['bicycle','🚲'], ['scooter','🛵'], ['motorcycle','🏍️']].map(([v, e]) => (
                        <button key={v} onClick={() => update('vehicle', v)}
                          className={`py-3 rounded-xl border text-sm font-medium transition-all flex items-center justify-center gap-2 ${form.vehicle === v ? 'border-teal-500/50 bg-teal-500/10 text-teal-400' : 'border-white/8 bg-dark-surface text-gray-400'}`}>
                          <span>{e}</span>
                          <span className="capitalize hidden sm:block">{v}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* STEP 4: Risk Analysis */}
            {step === 4 && (
              <motion.div key="s4" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col items-center justify-center text-center">
                {analyzing ? (
                  <>
                    <div className="w-20 h-20 rounded-2xl bg-teal-500/10 border border-teal-500/20 flex items-center justify-center mb-6">
                      <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1.5, ease: 'linear' }}>
                        <BarChart3 className="w-8 h-8 text-teal-400" />
                      </motion.div>
                    </div>
                    <h2 className="text-2xl font-display font-bold text-white mb-2">Analysing your risk profile</h2>
                    <p className="text-sm text-gray-400 mb-8">Our AI models are crunching your city data, historical patterns, and weather trends...</p>
                    <div className="w-64 h-2 bg-dark-surface rounded-full overflow-hidden mb-3">
                      <motion.div className="h-full bg-linear-to-r from-teal-500 to-emerald-500 rounded-full"
                        animate={{ width: `${analyzeProgress}%` }} transition={{ duration: 0.3 }} />
                    </div>
                    <p className="text-xs text-gray-500">{analyzeProgress}% complete</p>
                  </>
                ) : risk ? (
                  <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="w-full">
                    <h2 className="text-2xl font-display font-bold text-white mb-6">Your Risk Profile</h2>
                    <div className="flex justify-center mb-6">
                      <RiskMeter score={risk.score} tier={risk.tier} size={160} />
                    </div>
                    <div className="grid grid-cols-3 gap-3 mb-6">
                      {risk.topRisks.map(r => {
                        const m = TRIGGER_META[r];
                        return m ? (
                          <div key={r} className="bg-dark-surface rounded-xl p-3 text-center">
                            <div className="text-xl mb-1">{m.emoji}</div>
                            <p className="text-xs text-gray-400">{m.label}</p>
                          </div>
                        ) : null;
                      })}
                    </div>
                    <p className="text-sm text-gray-400">Based on {form.city} data, your primary disruption risk is <strong className="text-white">{TRIGGER_META[risk.topRisks[0]]?.label ?? 'Weather Events'}</strong>.</p>
                  </motion.div>
                ) : null}
              </motion.div>
            )}

            {/* STEP 5: Plan Selection */}
            {step === 5 && (
              <motion.div key="s5" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col">
                <h2 className="text-2xl font-display font-bold text-white mb-2">Choose your coverage</h2>
                <p className="text-gray-400 text-sm mb-6">AI-personalised pricing for {form.city}.</p>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 flex-1">
                  {PLAN_DEFS.map(p => (
                    <PlanCard key={p.planType} {...p}
                      selected={selectedPlan === p.planType}
                      onSelect={() => setSelectedPlan(p.planType)}
                      breakdown={PLAN_BREAKDOWNS[p.planType]} />
                  ))}
                </div>
              </motion.div>
            )}

            {/* STEP 6: Confirm */}
            {step === 6 && (
              <motion.div key="s6" {...slide} transition={{ duration: 0.3 }} className="flex-1 flex flex-col">
                <h2 className="text-2xl font-display font-bold text-white mb-2">Activate your coverage</h2>
                <p className="text-gray-400 text-sm mb-6">Review your details and go live.</p>

                <div className="bg-dark-surface rounded-2xl p-5 mb-5 space-y-3">
                  {[
                    ['Name', form.name], ['Phone', `+91 ${form.phone}`],
                    ['City', form.city], ['Zone', form.zone],
                    ['Platform', form.platform], ['Plan', `${selectedPlan} Plan`],
                    ['Weekly Premium', `₹${PLAN_DEFS.find(p => p.planType === selectedPlan)?.weeklyPremium ? Math.round(PLAN_DEFS.find(p => p.planType === selectedPlan)!.weeklyPremium / 100) : 55}/week`],
                  ].map(([k, v]) => (
                    <div key={k} className="flex items-center justify-between text-sm">
                      <span className="text-gray-500">{k}</span>
                      <span className="text-white font-medium">{v}</span>
                    </div>
                  ))}
                </div>

                <div className="bg-dark-surface rounded-2xl p-5 mb-6">
                  <p className="text-xs text-gray-500 mb-3">Demo Payment (UPI)</p>
                  <div className="flex gap-3">
                    <input readOnly value="rahul@upi" className="flex-1 bg-dark-card border border-white/6 rounded-xl px-4 py-3 text-gray-400 text-sm" />
                    <div className="flex items-center px-4 py-3 bg-teal-500/10 border border-teal-500/20 rounded-xl text-teal-400 text-sm font-medium">Pay via UPI</div>
                  </div>
                </div>

                <label className="flex items-start gap-3 text-sm text-gray-400 mb-6 cursor-pointer">
                  <input type="checkbox" defaultChecked className="mt-0.5 accent-teal-500" />
                  I agree to the Terms of Service and understand that payouts are triggered automatically based on verified sensor data.
                </label>

                <motion.button
                  whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}
                  onClick={handleActivate} disabled={completing}
                  className="w-full py-4 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-bold text-base rounded-2xl shadow-lg shadow-teal-500/30 disabled:opacity-70 flex items-center justify-center gap-2">
                  {completing ? (
                    <>
                      <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: 'linear' }}>
                        <CloudRain className="w-5 h-5" />
                      </motion.div>
                      Activating...
                    </>
                  ) : (
                    <><Shield className="w-5 h-5" /> Activate Coverage</>
                  )}
                </motion.button>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Nav buttons */}
          {step !== 4 && (
            <div className="flex items-center justify-between mt-6 pt-4 border-t border-white/5">
              {step > 1 ? (
                <button onClick={() => setStep(s => s - 1)} className="flex items-center gap-2 text-sm text-gray-400 hover:text-white transition-colors">
                  <ChevronLeft className="w-4 h-4" /> Back
                </button>
              ) : <div />}

              {step < 6 && (
                <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} onClick={goNext}
                  className="flex items-center gap-2 px-6 py-2.5 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-semibold text-sm rounded-xl shadow-lg shadow-teal-500/20">
                  Continue <ChevronRight className="w-4 h-4" />
                </motion.button>
              )}
            </div>
          )}

          {/* Step 4: auto-advance when done */}
          {step === 4 && !analyzing && risk && (
            <div className="flex justify-end mt-6 pt-4 border-t border-white/5">
              <motion.button initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }}
                whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} onClick={() => setStep(5)}
                className="flex items-center gap-2 px-6 py-2.5 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-semibold text-sm rounded-xl">
                Choose a Plan <ChevronRight className="w-4 h-4" />
              </motion.button>
            </div>
          )}
        </div>

        <p className="text-center text-xs text-gray-600 mt-6">
          Step {step} of {STEPS.length} · Your data is encrypted and never shared.
        </p>
      </div>
    </div>
  );
}
