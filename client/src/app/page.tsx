'use client';
import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { motion, useInView } from 'framer-motion';
import { ArrowRight, Zap, Shield, Clock, ChevronRight, Star, CloudRain, AlertTriangle, Users, Play } from 'lucide-react';
import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';

function Counter({ target, prefix = '', suffix = '' }: { target: number; prefix?: string; suffix?: string }) {
  const [value, setValue] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true });

  useEffect(() => {
    if (!inView) return;
    const steps = 60;
    const increment = target / steps;
    let current = 0;
    const timer = setInterval(() => {
      current = Math.min(current + increment, target);
      setValue(Math.floor(current));
      if (current >= target) clearInterval(timer);
    }, 1800 / steps);
    return () => clearInterval(timer);
  }, [inView, target]);

  return <span ref={ref} className="tabular-nums">{prefix}{value.toLocaleString('en-IN')}{suffix}</span>;
}

const TRIGGERS = [
  { key: 'rain',   emoji: '🌧️', title: 'Heavy Rainfall',    desc: '>64mm/hr sustained rain stops deliveries',   color: '#60A5FA', threshold: '64mm/hr' },
  { key: 'heat',   emoji: '🌡️', title: 'Extreme Heat',      desc: 'Feels-like temperature above 48°C',           color: '#FB923C', threshold: '48°C feels-like' },
  { key: 'aqi',    emoji: '😷', title: 'Severe AQI',        desc: 'Air quality index crosses 400 — unsafe',      color: '#C084FC', threshold: 'AQI > 400' },
  { key: 'flood',  emoji: '🌊', title: 'Flooding',          desc: '6+ hours sustained rain in flood-prone zones', color: '#22D3EE', threshold: '6hr+ rain' },
  { key: 'social', emoji: '🚫', title: 'Social Disruption', desc: 'Curfew, strike, or city-wide shutdown',       color: '#FBBF24', threshold: 'Admin triggered' },
];

const HOW_STEPS = [
  { num: '01', icon: Users,  title: 'Sign Up in 30 Seconds',  desc: 'Just your name, phone, and delivery platform. No documents, no KYC, no wait.' },
  { num: '02', icon: Shield, title: 'Pick Your Plan',         desc: 'Basic, Standard, or Premium from ₹29/week. Our AI tailors the price to your city and risk profile.' },
  { num: '03', icon: Zap,    title: 'Get Paid Automatically', desc: 'Sensors detect disruptions in your zone → payout lands in your account within 2 minutes. Zero effort.' },
];

const TESTIMONIALS = [
  { name: 'Mohammed Irfan', city: 'Mumbai · Swiggy', stars: 5, quote: 'Monsoon season is the worst for earnings. RainCheck credited ₹1,200 the same day heavy rain hit Andheri. No forms, nothing.', plan: 'Standard' },
  { name: 'Suresh Kumar',   city: 'Delhi · Zomato',  stars: 5, quote: 'Delhi AQI goes insane in November. Lost 3 working days last year. This year RainCheck covered all of it automatically. Life changer.', plan: 'Premium' },
  { name: 'Priya Devi',     city: 'Bangalore · Swiggy', stars: 5, quote: 'Simple to sign up. My earnings are protected year-round. Live weather alerts for my zone are a bonus I didn\'t expect.', plan: 'Basic' },
];

export default function LandingPage() {
  const router = useRouter();

  const handleQuickDemo = () => {
    localStorage.setItem('rc_rider_id', 'demo-rider-001');
    localStorage.setItem('rc_rider_name', 'Rahul Sharma');
    localStorage.setItem('rc_city', 'Mumbai');
    localStorage.setItem('rc_plan', 'Standard');
    router.push('/dashboard');
  };

  return (
    <div className="min-h-screen bg-mesh">
      <Navbar />

      {/* HERO */}
      <section className="relative min-h-screen flex flex-col items-center justify-center overflow-hidden pt-16">
        <div className="absolute top-1/4 left-1/4 w-[500px] h-[500px] bg-teal-500/8 rounded-full blur-[120px] pointer-events-none" />
        <div className="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-emerald-500/8 rounded-full blur-[100px] pointer-events-none" />

        <div className="relative z-10 max-w-5xl mx-auto px-4 text-center">
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.5 }}
            className="inline-flex items-center gap-2 bg-teal-500/10 border border-teal-500/20 rounded-full px-4 py-1.5 mb-8 text-sm text-teal-400 font-medium">
            <span className="relative flex w-2 h-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-teal-400" />
            </span>
            Live in 10 cities · 12,847 riders protected
          </motion.div>

          <motion.h1 initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.7, delay: 0.1 }}
            className="text-5xl sm:text-6xl lg:text-7xl font-display font-bold text-white leading-[1.05] mb-6">
            Income Protection for<br />
            <span className="text-gradient">India's Delivery Heroes</span>
          </motion.h1>

          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.25 }}
            className="text-lg sm:text-xl text-gray-400 max-w-2xl mx-auto mb-10 leading-relaxed">
            AI-powered insurance that pays you automatically when heavy rains, extreme heat, or disruptions stop you working.{' '}
            <span className="text-white font-medium">No claims. No paperwork. Just protection.</span>
          </motion.p>

          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.4 }}
            className="flex flex-col sm:flex-row gap-4 justify-center mb-16">
            <Link href="/onboarding">
              <motion.button whileHover={{ scale: 1.03, y: -2 }} whileTap={{ scale: 0.98 }}
                className="group flex items-center justify-center gap-2 px-8 py-4 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-semibold text-base rounded-2xl shadow-lg shadow-teal-500/30 hover:shadow-teal-500/50 transition-shadow">
                Get Protected Today
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </motion.button>
            </Link>
            <motion.button onClick={handleQuickDemo} whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}
              className="flex items-center justify-center gap-2 px-8 py-4 border border-teal-500/30 bg-teal-500/5 text-teal-300 font-medium text-base rounded-2xl hover:bg-teal-500/10 transition-all">
              <Play className="w-4 h-4 fill-teal-300" />
              Try Live Demo
            </motion.button>
          </motion.div>

          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.55 }}
            className="grid grid-cols-3 gap-4 max-w-xl mx-auto">
            {[
              { target: 12847, prefix: '', suffix: '+', label: 'Riders Protected' },
              { target: 45,    prefix: '₹', suffix: 'L+', label: 'Payouts Processed' },
              { target: 2,     prefix: '<', suffix: 'min', label: 'Avg Payout Time' },
            ].map(s => (
              <div key={s.label} className="glass rounded-2xl p-4 text-center">
                <p className="text-xl sm:text-2xl font-display font-bold text-gradient">
                  <Counter target={s.target} prefix={s.prefix} suffix={s.suffix} />
                </p>
                <p className="text-[11px] text-gray-500 mt-1">{s.label}</p>
              </div>
            ))}
          </motion.div>
        </div>

        <motion.div animate={{ y: [0, 8, 0] }} transition={{ repeat: Infinity, duration: 2 }}
          className="absolute bottom-8 left-1/2 -translate-x-1/2 w-6 h-10 border-2 border-white/10 rounded-full flex items-start justify-center pt-2">
          <div className="w-1 h-2 bg-white/30 rounded-full" />
        </motion.div>
      </section>

      {/* HOW IT WORKS */}
      <section className="py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <motion.p initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}
              className="text-sm font-semibold text-teal-400 uppercase tracking-widest mb-3">How It Works</motion.p>
            <motion.h2 initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
              className="text-3xl sm:text-4xl font-display font-bold text-white">Protection in 3 Simple Steps</motion.h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 relative">
            <div className="hidden md:block absolute top-16 left-[22%] right-[22%] h-px bg-linear-to-r from-transparent via-teal-500/30 to-transparent" />
            {HOW_STEPS.map(({ num, icon: Icon, title, desc }, i) => (
              <motion.div key={num} initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }} transition={{ delay: i * 0.15 }}
                className="relative bg-dark-card border border-white/6 rounded-2xl p-7 hover:border-teal-500/20 transition-all group">
                <div className="absolute -top-3 left-6 bg-linear-to-r from-teal-600 to-emerald-600 rounded-full px-2.5 py-0.5 text-xs font-bold text-white">{num}</div>
                <div className="w-12 h-12 rounded-2xl bg-teal-500/10 border border-teal-500/15 flex items-center justify-center mb-5 group-hover:scale-110 transition-transform">
                  <Icon className="w-5 h-5 text-teal-400" />
                </div>
                <h3 className="text-base font-display font-bold text-white mb-3">{title}</h3>
                <p className="text-sm text-gray-400 leading-relaxed">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* DISRUPTIONS */}
      <section className="py-24 px-4 bg-linear-to-b from-transparent via-teal-950/10 to-transparent">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <motion.p initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}
              className="text-sm font-semibold text-teal-400 uppercase tracking-widest mb-3">Coverage</motion.p>
            <motion.h2 initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
              className="text-3xl sm:text-4xl font-display font-bold text-white mb-4">5 Disruptions. Fully Covered.</motion.h2>
            <p className="text-gray-400 max-w-lg mx-auto">When any threshold is breached in your zone, your payout processes automatically.</p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {TRIGGERS.map(({ key, emoji, title, desc, color, threshold }, i) => (
              <motion.div key={key} initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }} transition={{ delay: i * 0.08 }}
                whileHover={{ y: -4, transition: { duration: 0.2 } }}
                className="bg-dark-card border border-white/6 rounded-2xl p-6 hover:border-white/10 transition-all">
                <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl mb-4" style={{ background: `${color}18` }}>{emoji}</div>
                <h3 className="text-base font-display font-bold text-white mb-2">{title}</h3>
                <p className="text-sm text-gray-400 leading-relaxed mb-4">{desc}</p>
                <div className="flex items-center gap-2 text-xs font-medium rounded-lg px-3 py-1.5 w-fit" style={{ color, background: `${color}15` }}>
                  <AlertTriangle className="w-3 h-3" />
                  Trigger: {threshold}
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* TESTIMONIALS */}
      <section className="py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <motion.p initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}
              className="text-sm font-semibold text-teal-400 uppercase tracking-widest mb-3">Testimonials</motion.p>
            <motion.h2 initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
              className="text-3xl sm:text-4xl font-display font-bold text-white">Riders Who Trust RainCheck</motion.h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {TESTIMONIALS.map(({ name, city, stars, quote, plan }, i) => (
              <motion.div key={name} initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }} transition={{ delay: i * 0.12 }}
                className="bg-dark-card border border-white/6 rounded-2xl p-6">
                <div className="flex gap-1 mb-4">{[...Array(stars)].map((_, j) => <Star key={j} className="w-4 h-4 text-yellow-400 fill-yellow-400" />)}</div>
                <p className="text-sm text-gray-300 leading-relaxed mb-5">"{quote}"</p>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-white">{name}</p>
                    <p className="text-xs text-gray-500">{city}</p>
                  </div>
                  <span className="text-[10px] font-medium text-teal-400 bg-teal-500/10 border border-teal-500/15 rounded-full px-2.5 py-1">{plan} Plan</span>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* FINAL CTA */}
      <section className="py-24 px-4">
        <div className="max-w-3xl mx-auto text-center">
          <motion.div initial={{ opacity: 0, scale: 0.95 }} whileInView={{ opacity: 1, scale: 1 }} viewport={{ once: true }}
            className="bg-linear-to-br from-teal-500/10 to-emerald-500/5 border border-teal-500/20 rounded-3xl p-12">
            <div className="w-16 h-16 rounded-2xl bg-linear-to-br from-teal-500 to-emerald-600 flex items-center justify-center mx-auto mb-6 shadow-lg shadow-teal-500/30">
              <CloudRain className="w-8 h-8 text-white" />
            </div>
            <h2 className="text-3xl sm:text-4xl font-display font-bold text-white mb-4">
              Don't Let Rain Wash Away<br />Your Earnings
            </h2>
            <p className="text-gray-400 mb-8 max-w-md mx-auto">Join 12,847 partners protecting their earnings. Start for just ₹29/week.</p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/onboarding">
                <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.98 }}
                  className="flex items-center gap-2 px-8 py-4 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-semibold rounded-2xl shadow-lg shadow-teal-500/30">
                  Get Protected — Free to Start
                  <ArrowRight className="w-4 h-4" />
                </motion.button>
              </Link>
              <motion.button onClick={handleQuickDemo} whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
                className="flex items-center gap-2 px-8 py-4 border border-white/10 text-gray-300 font-medium rounded-2xl hover:bg-white/5 transition-all">
                <Play className="w-4 h-4" />
                Try Demo
              </motion.button>
            </div>
            <div className="flex items-center justify-center gap-6 mt-8 text-xs text-gray-500 flex-wrap">
              <span className="flex items-center gap-1.5"><Zap className="w-3 h-3 text-teal-400" /> Instant payouts</span>
              <span className="flex items-center gap-1.5"><Shield className="w-3 h-3 text-teal-400" /> No claims needed</span>
              <span className="flex items-center gap-1.5"><Clock className="w-3 h-3 text-teal-400" /> 30 sec signup</span>
            </div>
          </motion.div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
