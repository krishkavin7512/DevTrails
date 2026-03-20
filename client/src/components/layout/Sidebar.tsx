'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { motion } from 'framer-motion';
import { LayoutDashboard, FileText, Zap, BarChart3, LogOut, CloudRain, Shield, Bell, Menu } from 'lucide-react';
import { useState } from 'react';

const NAV_ITEMS = [
  { href: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { href: '/claims',    icon: FileText,        label: 'My Claims' },
  { href: '/triggers',  icon: Zap,             label: 'Live Alerts' },
  { href: '/admin',     icon: BarChart3,        label: 'Analytics' },
];

interface SidebarProps {
  riderName?: string;
  riderCity?: string;
  policyStatus?: string;
}

export default function Sidebar({ riderName = 'Rider', riderCity = '', policyStatus }: SidebarProps) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* ── Mobile top bar (visible below lg) ─────────────────────────── */}
      <div className="lg:hidden fixed top-0 left-0 right-0 h-14 bg-[#0D1420] border-b border-white/6 flex items-center justify-between px-4 z-50">
        <div className="flex items-center gap-2.5">
          <div className="relative flex items-center justify-center w-7 h-7 bg-linear-to-br from-teal-500 to-emerald-600 rounded-lg">
            <CloudRain className="w-3.5 h-3.5 text-white" />
          </div>
          <span className="font-display font-bold text-white text-sm">RainCheck</span>
          {policyStatus === 'Active' && (
            <div className="relative w-2 h-2">
              <div className="absolute inset-0 bg-green-400 rounded-full animate-ping opacity-60" />
              <div className="w-2 h-2 bg-green-400 rounded-full" />
            </div>
          )}
        </div>

        {/* Mobile icon nav */}
        <nav className="flex items-center gap-1">
          {NAV_ITEMS.map(({ href, icon: Icon }) => {
            const active = pathname === href;
            return (
              <Link key={href} href={href}>
                <div className={`p-2.5 rounded-xl transition-colors ${active ? 'bg-teal-500/15 text-teal-400' : 'text-gray-500 hover:text-white hover:bg-white/5'}`}>
                  <Icon className="w-4 h-4" />
                </div>
              </Link>
            );
          })}
        </nav>
      </div>

      {/* ── Desktop sidebar (visible lg+) ─────────────────────────────── */}
      <aside className="hidden lg:flex fixed left-0 top-0 bottom-0 w-[240px] bg-[#0D1420] border-r border-white/6 flex-col z-40">
        {/* Logo */}
        <div className="flex items-center gap-2.5 px-5 h-16 border-b border-white/6">
          <div className="relative flex items-center justify-center w-8 h-8 bg-linear-to-br from-teal-500 to-emerald-600 rounded-lg">
            <CloudRain className="w-4 h-4 text-white" />
            <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-emerald-400 rounded-full flex items-center justify-center">
              <Shield className="w-1.5 h-1.5 text-emerald-900" />
            </div>
          </div>
          <span className="font-display font-bold text-white">RainCheck</span>
        </div>

        {/* Rider info */}
        <div className="px-4 py-4 border-b border-white/6">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-linear-to-br from-teal-500/30 to-emerald-500/20 border border-teal-500/20 flex items-center justify-center shrink-0">
              <span className="text-sm font-bold text-teal-400">{riderName.charAt(0)}</span>
            </div>
            <div className="min-w-0">
              <p className="text-sm font-medium text-white truncate">{riderName}</p>
              <p className="text-xs text-gray-500">{riderCity || 'Rider Account'}</p>
            </div>
            {policyStatus === 'Active' && (
              <div className="relative ml-auto shrink-0">
                <div className="w-2 h-2 bg-green-400 rounded-full" />
                <div className="absolute inset-0 w-2 h-2 bg-green-400 rounded-full animate-ping opacity-50" />
              </div>
            )}
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 overflow-y-auto">
          <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-600 px-2 mb-2">Menu</p>
          <ul className="space-y-1">
            {NAV_ITEMS.map(({ href, icon: Icon, label }) => {
              const active = pathname === href;
              return (
                <li key={href}>
                  <Link href={href}>
                    <motion.div whileHover={{ x: 2 }}
                      className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors ${
                        active
                          ? 'bg-teal-500/15 text-teal-400 border border-teal-500/20'
                          : 'text-gray-400 hover:text-white hover:bg-white/5'
                      }`}>
                      <Icon className={`w-4 h-4 shrink-0 ${active ? 'text-teal-400' : ''}`} />
                      {label}
                      {active && <div className="ml-auto w-1.5 h-1.5 bg-teal-400 rounded-full" />}
                    </motion.div>
                  </Link>
                </li>
              );
            })}
          </ul>

          <div className="mt-6 pt-4 border-t border-white/6">
            <p className="text-[10px] font-semibold uppercase tracking-widest text-gray-600 px-2 mb-2">Account</p>
            <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-gray-500 hover:text-red-400 hover:bg-red-500/5 transition-colors">
              <LogOut className="w-4 h-4" />
              Sign Out
            </button>
          </div>
        </nav>

        {/* Bottom alert hint */}
        <div className="px-4 pb-4">
          <div className="bg-teal-500/8 border border-teal-500/15 rounded-xl p-3">
            <div className="flex items-center gap-2 mb-1">
              <Bell className="w-3.5 h-3.5 text-teal-400" />
              <span className="text-xs font-medium text-teal-400">Coverage Active</span>
            </div>
            <p className="text-[11px] text-gray-500">Auto-payouts enabled for your zone</p>
          </div>
        </div>
      </aside>
    </>
  );
}
