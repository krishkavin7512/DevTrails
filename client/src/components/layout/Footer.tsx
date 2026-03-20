import Link from 'next/link';
import { CloudRain, Shield, Heart } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="border-t border-white/5 bg-dark mt-auto">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="md:col-span-2">
            <div className="flex items-center gap-2.5 mb-4">
              <div className="relative flex items-center justify-center w-9 h-9 bg-linear-to-br from-teal-500 to-emerald-600 rounded-xl">
                <CloudRain className="w-5 h-5 text-white" />
                <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-emerald-400 rounded-full flex items-center justify-center">
                  <Shield className="w-2 h-2 text-emerald-900" />
                </div>
              </div>
              <span className="font-display font-bold text-lg text-white">RainCheck</span>
            </div>
            <p className="text-sm text-gray-400 max-w-xs leading-relaxed">
              AI-powered parametric insurance protecting India's food delivery partners from income loss due to weather and disruptions.
            </p>
            <div className="mt-4 inline-flex items-center gap-2 px-3 py-1.5 bg-teal-500/10 border border-teal-500/20 rounded-full text-xs text-teal-400">
              <div className="w-1.5 h-1.5 bg-teal-400 rounded-full animate-pulse" />
              12,847 riders protected
            </div>
          </div>

          {/* Links */}
          <div>
            <h4 className="text-sm font-semibold text-white mb-4">Platform</h4>
            <ul className="space-y-2.5">
              {[['/', 'Home'], ['/onboarding', 'Get Protected'], ['/dashboard', 'My Dashboard'], ['/triggers', 'Live Monitor']].map(([href, label]) => (
                <li key={href}>
                  <Link href={href} className="text-sm text-gray-400 hover:text-teal-400 transition-colors">{label}</Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Hackathon Info */}
          <div>
            <h4 className="text-sm font-semibold text-white mb-4">Built By</h4>
            <div className="space-y-2">
              <p className="text-sm text-gray-300 font-medium">Team CEIL</p>
              <p className="text-xs text-gray-400">Guidewire DEVTrails 2026</p>
              <div className="mt-3 pt-3 border-t border-white/5">
                <p className="text-xs text-gray-500 leading-relaxed">
                  Parametric insurance for gig economy workers. Automatic payouts, no paperwork.
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-10 pt-6 border-t border-white/5 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-gray-500">
            © 2026 RainCheck · Team CEIL · Guidewire DEVTrails Hackathon
          </p>
          <p className="text-xs text-gray-500 flex items-center gap-1">
            Built with <Heart className="w-3 h-3 text-red-400 fill-red-400" /> for India's gig workers
          </p>
        </div>
      </div>
    </footer>
  );
}
