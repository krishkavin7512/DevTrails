'use client';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { CloudRain, Home, ArrowLeft } from 'lucide-react';

export default function NotFound() {
  return (
    <div className="min-h-screen bg-dark bg-mesh flex flex-col items-center justify-center px-4 text-center">
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="max-w-md w-full"
      >
        {/* Icon */}
        <div className="w-20 h-20 rounded-3xl bg-teal-500/10 border border-teal-500/20 flex items-center justify-center mx-auto mb-8">
          <CloudRain className="w-9 h-9 text-teal-400" />
        </div>

        {/* 404 */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="text-8xl font-display font-bold text-gradient mb-4 tabular-nums"
        >
          404
        </motion.p>

        <h1 className="text-2xl font-display font-bold text-white mb-3">
          Page not found
        </h1>
        <p className="text-gray-400 text-sm mb-10 leading-relaxed">
          The page you're looking for doesn't exist or has been moved.<br />
          Head back home — your coverage is still active.
        </p>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link href="/">
            <motion.button
              whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-linear-to-r from-teal-600 to-emerald-600 text-white font-semibold text-sm rounded-xl shadow-lg shadow-teal-500/25"
            >
              <Home className="w-4 h-4" />
              Back to Home
            </motion.button>
          </Link>
          <Link href="/dashboard">
            <motion.button
              whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
              className="flex items-center justify-center gap-2 px-6 py-3 border border-white/10 text-white font-medium text-sm rounded-xl hover:bg-white/5 transition-all"
            >
              <ArrowLeft className="w-4 h-4" />
              Go to Dashboard
            </motion.button>
          </Link>
        </div>

        <p className="text-xs text-gray-600 mt-10">
          RainCheck · Guidewire DEVTrails 2026
        </p>
      </motion.div>
    </div>
  );
}
