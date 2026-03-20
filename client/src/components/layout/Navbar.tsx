'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { CloudRain, Shield, Menu, X, ChevronRight } from 'lucide-react';

const NAV_LINKS = [
  { href: '/', label: 'Home' },
  { href: '/triggers', label: 'Live Monitor' },
  { href: '/admin', label: 'For Insurers' },
];

export default function Navbar() {
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const isDashboard = pathname?.startsWith('/dashboard') || pathname?.startsWith('/claims');

  return (
    <motion.nav
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5 }}
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? 'bg-dark/90 backdrop-blur-xl border-b border-white/5 shadow-lg shadow-black/20' : 'bg-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="relative flex items-center justify-center w-9 h-9 bg-linear-to-br from-teal-500 to-emerald-600 rounded-xl shadow-lg shadow-teal-500/30">
              <CloudRain className="w-5 h-5 text-white" />
              <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-emerald-400 rounded-full flex items-center justify-center">
                <Shield className="w-2 h-2 text-emerald-900" />
              </div>
            </div>
            <span className="font-display font-bold text-lg text-white group-hover:text-teal-300 transition-colors">
              RainCheck
            </span>
          </Link>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {NAV_LINKS.map(link => (
              <Link
                key={link.href}
                href={link.href}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                  pathname === link.href
                    ? 'text-teal-400 bg-teal-500/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                {link.label}
              </Link>
            ))}
          </div>

          {/* Right CTA */}
          <div className="hidden md:flex items-center gap-3">
            {isDashboard ? (
              <Link href="/dashboard">
                <button className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-linear-to-r from-teal-600 to-emerald-600 rounded-xl hover:from-teal-500 hover:to-emerald-500 transition-all shadow-lg shadow-teal-500/20">
                  My Dashboard
                  <ChevronRight className="w-4 h-4" />
                </button>
              </Link>
            ) : (
              <>
                <Link href="/dashboard" className="text-sm text-gray-400 hover:text-white transition-colors px-3 py-2">
                  Sign In
                </Link>
                <Link href="/onboarding">
                  <button className="flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-linear-to-r from-teal-600 to-emerald-600 rounded-xl hover:from-teal-500 hover:to-emerald-500 transition-all shadow-lg shadow-teal-500/20 hover:shadow-teal-500/40 hover:-translate-y-0.5">
                    Get Protected
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </Link>
              </>
            )}
          </div>

          {/* Mobile toggle */}
          <button
            className="md:hidden p-2 text-gray-400 hover:text-white"
            onClick={() => setMobileOpen(v => !v)}
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="md:hidden bg-dark-card/95 backdrop-blur-xl border-t border-white/5"
          >
            <div className="px-4 py-4 flex flex-col gap-2">
              {NAV_LINKS.map(link => (
                <Link key={link.href} href={link.href} onClick={() => setMobileOpen(false)}
                  className="px-4 py-3 rounded-xl text-gray-300 hover:text-white hover:bg-white/5 text-sm font-medium">
                  {link.label}
                </Link>
              ))}
              <Link href="/onboarding" onClick={() => setMobileOpen(false)}
                className="mt-2 px-4 py-3 rounded-xl text-center text-sm font-semibold text-white bg-linear-to-r from-teal-600 to-emerald-600">
                Get Protected
              </Link>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
}
