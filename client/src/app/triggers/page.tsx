'use client';
import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { RefreshCw, Activity, AlertTriangle, CheckCircle, X } from 'lucide-react';
import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';
import TriggerCard from '@/components/ui/TriggerCard';
import AQIIndicator from '@/components/ui/AQIIndicator';
import { api } from '@/lib/api';
import { MOCK_CITY_WEATHER, MOCK_DISRUPTIONS } from '@/lib/mockData';
import { TRIGGER_META, formatDate } from '@/lib/utils';

const TRIGGER_THRESHOLDS: Record<string, { unit: string; threshold: number }> = {
  HeavyRain:        { unit: 'mm/hr', threshold: 64 },
  ExtremeHeat:      { unit: '°C',    threshold: 48 },
  SevereAQI:        { unit: 'AQI',   threshold: 400 },
  Flooding:         { unit: 'hrs',   threshold: 6 },
  SocialDisruption: { unit: 'level', threshold: 4 },
};

const CITIES_LIST = ['Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Pune', 'Kolkata', 'Jaipur', 'Ahmedabad', 'Lucknow'];

interface CityWeather {
  temp: number; aqi: number; condition: string; rainfall: number; wind: number;
  triggers: string[]; severity: string | null;
}

interface CityData extends CityWeather { lastUpdated: string; }

export default function TriggersPage() {
  const [cityData, setCityData] = useState<Record<string, CityData>>({});
  const [selectedCity, setSelectedCity] = useState<string | null>(null);
  const [disruptions, setDisruptions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastRefresh, setLastRefresh] = useState(new Date());
  const [countdown, setCountdown] = useState(60);

  const fetchAll = useCallback(async () => {
    setLoading(true);
    const result: Record<string, CityData> = {};

    // Try API, fall back to mock
    await Promise.all(CITIES_LIST.map(async (city) => {
      try {
        const res = await api.get(`/weather/current/${city}`);
        const w = res.data ?? res;
        result[city] = {
          temp: w.main?.temp ?? w.temperature ?? MOCK_CITY_WEATHER[city]?.temp ?? 30,
          aqi: w.aqi ?? MOCK_CITY_WEATHER[city]?.aqi ?? 100,
          condition: w.weather?.[0]?.description ?? w.description ?? MOCK_CITY_WEATHER[city]?.condition ?? 'Clear',
          rainfall: w.rain?.['1h'] ?? w.rainfall ?? MOCK_CITY_WEATHER[city]?.rainfall ?? 0,
          wind: w.wind?.speed ?? w.windSpeed ?? MOCK_CITY_WEATHER[city]?.wind ?? 10,
          triggers: MOCK_CITY_WEATHER[city]?.triggers ?? [],
          severity: MOCK_CITY_WEATHER[city]?.severity ?? null,
          lastUpdated: new Date().toISOString(),
        };
      } catch {
        const mock = MOCK_CITY_WEATHER[city];
        result[city] = { ...mock, lastUpdated: new Date().toISOString() };
      }
    }));

    // Fetch disruptions
    try {
      const dRes = await api.get('/disruptions/active');
      setDisruptions((dRes as any).data?.events ?? MOCK_DISRUPTIONS);
    } catch {
      setDisruptions(MOCK_DISRUPTIONS);
    }

    setCityData(result);
    setLastRefresh(new Date());
    setCountdown(60);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchAll();
    const interval = setInterval(fetchAll, 60_000);
    return () => clearInterval(interval);
  }, [fetchAll]);

  useEffect(() => {
    const t = setInterval(() => setCountdown(c => Math.max(0, c - 1)), 1000);
    return () => clearInterval(t);
  }, [lastRefresh]);

  const activeTriggerCount = Object.values(cityData).filter(c => c.triggers.length > 0).length;

  return (
    <div className="min-h-screen bg-dark bg-mesh">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-24 pb-16 space-y-8">

        {/* Header */}
        <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }}
          className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <div className="relative">
                <Activity className="w-5 h-5 text-teal-400" />
                {activeTriggerCount > 0 && <span className="absolute -top-1 -right-1 w-2 h-2 bg-red-500 rounded-full animate-pulse" />}
              </div>
              <h1 className="text-2xl font-display font-bold text-white">Live Trigger Monitor</h1>
            </div>
            <p className="text-sm text-gray-500">Real-time weather and disruption data across 10 Indian cities</p>
          </div>
          <div className="flex items-center gap-3">
            {activeTriggerCount > 0 && (
              <div className="flex items-center gap-2 px-3 py-1.5 bg-red-500/10 border border-red-500/20 rounded-full text-xs font-medium text-red-400">
                <AlertTriangle className="w-3.5 h-3.5" />
                {activeTriggerCount} active {activeTriggerCount === 1 ? 'trigger' : 'triggers'}
              </div>
            )}
            <button onClick={fetchAll} disabled={loading}
              className="flex items-center gap-2 px-4 py-2 bg-dark-card border border-white/6 rounded-xl text-sm text-gray-400 hover:text-white transition-colors disabled:opacity-50">
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </motion.div>

        {/* Auto-refresh indicator */}
        <div className="flex items-center gap-3">
          <div className="flex-1 h-0.5 bg-dark-card rounded-full overflow-hidden">
            <motion.div className="h-full bg-teal-500/40 rounded-full"
              animate={{ width: `${(countdown / 60) * 100}%` }}
              transition={{ duration: 0.5 }} />
          </div>
          <span className="text-[11px] text-gray-600 flex-shrink-0">Auto-refresh in {countdown}s</span>
        </div>

        {/* Active disruptions banner */}
        {disruptions.length > 0 && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            className="space-y-2">
            {disruptions.map((d: any) => {
              const m = TRIGGER_META[d.triggerType];
              return (
                <motion.div key={d._id} layout
                  className="flex items-center gap-4 bg-red-500/8 border border-red-500/20 rounded-2xl px-5 py-4">
                  <motion.div animate={{ scale: [1, 1.1, 1] }} transition={{ repeat: Infinity, duration: 2 }}>
                    <AlertTriangle className="w-5 h-5 text-red-400" />
                  </motion.div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-white">{m?.emoji} {d.title}</p>
                    <p className="text-xs text-gray-400">{d.city} · {d.affectedRiders} riders affected · Claims processing automatically</p>
                  </div>
                  <span className={`text-xs font-medium px-2.5 py-1 rounded-full flex-shrink-0 ${
                    d.severity === 'Extreme' ? 'bg-red-500/20 text-red-400' : d.severity === 'Severe' ? 'bg-orange-500/20 text-orange-400' : 'bg-yellow-500/20 text-yellow-400'
                  }`}>{d.severity}</span>
                </motion.div>
              );
            })}
          </motion.div>
        )}

        {/* City grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {CITIES_LIST.map((city, i) => {
            const d = cityData[city];
            const hasAlert = d?.triggers?.length > 0;
            const isSelected = selectedCity === city;

            return (
              <motion.div key={city}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.04 }}
                whileHover={{ y: -2, transition: { duration: 0.15 } }}
                onClick={() => setSelectedCity(isSelected ? null : city)}
                className={`rounded-2xl p-5 border cursor-pointer transition-all duration-200 ${
                  hasAlert
                    ? 'bg-red-500/5 border-red-500/30 shadow-lg shadow-red-500/10'
                    : isSelected
                      ? 'bg-teal-500/8 border-teal-500/25'
                      : 'bg-dark-card border-white/6 hover:border-white/10'
                }`}>
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="text-base font-display font-semibold text-white">{city}</h3>
                    {!d ? (
                      <div className="shimmer h-3 w-20 rounded mt-1" />
                    ) : (
                      <p className="text-xs text-gray-500 capitalize">{d.condition}</p>
                    )}
                  </div>
                  <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 mt-1 ${hasAlert ? 'bg-red-500' : 'bg-green-500/60'} ${hasAlert ? 'animate-pulse' : ''}`} />
                </div>

                {!d ? (
                  <div className="space-y-2">
                    <div className="shimmer h-8 w-24 rounded" />
                    <div className="shimmer h-3 w-full rounded" />
                  </div>
                ) : (
                  <>
                    <div className="flex items-baseline gap-1 mb-3">
                      <span className="text-3xl font-display font-bold text-white tabular-nums">{Math.round(d.temp)}°</span>
                      <span className="text-sm text-gray-500">/ AQI {d.aqi}</span>
                    </div>

                    <div className="space-y-1.5 mb-3">
                      <div className="flex justify-between text-[11px]">
                        <span className="text-gray-500">Rainfall</span>
                        <span className={d.rainfall > 64 ? 'text-blue-400 font-bold' : 'text-gray-300'}>{d.rainfall.toFixed(1)} mm/hr</span>
                      </div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-gray-500">Wind</span>
                        <span className="text-gray-300">{d.wind} km/h</span>
                      </div>
                    </div>

                    {hasAlert ? (
                      <div className="space-y-1">
                        {d.triggers.map(t => {
                          const m = TRIGGER_META[t];
                          return (
                            <div key={t} className="flex items-center gap-2 text-xs font-medium text-red-400 bg-red-500/10 rounded-lg px-2.5 py-1.5">
                              <span>{m?.emoji}</span> {m?.label ?? t}
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="flex items-center gap-1.5 text-xs text-green-400/70">
                        <CheckCircle className="w-3.5 h-3.5" />
                        All clear
                      </div>
                    )}
                  </>
                )}
              </motion.div>
            );
          })}
        </div>

        {/* City detail panel */}
        <AnimatePresence>
          {selectedCity && cityData[selectedCity] && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden"
            >
              <div className="bg-dark-card border border-teal-500/20 rounded-3xl p-6">
                <div className="flex items-center justify-between mb-6">
                  <div>
                    <h2 className="text-xl font-display font-bold text-white">{selectedCity} — Detailed View</h2>
                    <p className="text-xs text-gray-500">Last updated: {new Date(cityData[selectedCity].lastUpdated).toLocaleTimeString('en-IN')}</p>
                  </div>
                  <button onClick={() => setSelectedCity(null)} className="p-2 rounded-xl hover:bg-white/5 text-gray-400 hover:text-white transition-colors">
                    <X className="w-4 h-4" />
                  </button>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                  <div className="bg-dark-surface rounded-2xl p-5">
                    <p className="text-xs text-gray-500 mb-3">Current Conditions</p>
                    <p className="text-4xl font-display font-bold text-white mb-1 tabular-nums">{Math.round(cityData[selectedCity].temp)}°C</p>
                    <p className="text-sm text-gray-400 capitalize">{cityData[selectedCity].condition}</p>
                    <div className="mt-3 grid grid-cols-2 gap-2 text-xs">
                      <div className="text-gray-500">Wind: <span className="text-white">{cityData[selectedCity].wind} km/h</span></div>
                      <div className="text-gray-500">Rain: <span className="text-white">{cityData[selectedCity].rainfall.toFixed(1)} mm/hr</span></div>
                    </div>
                  </div>

                  <div className="bg-dark-surface rounded-2xl p-5">
                    <p className="text-xs text-gray-500 mb-3">Air Quality</p>
                    <AQIIndicator aqi={cityData[selectedCity].aqi} />
                  </div>

                  <div className="bg-dark-surface rounded-2xl p-5">
                    <p className="text-xs text-gray-500 mb-3">Trigger Status</p>
                    {cityData[selectedCity].triggers.length === 0 ? (
                      <div className="flex flex-col items-center justify-center h-20">
                        <CheckCircle className="w-8 h-8 text-green-400 mb-2" />
                        <p className="text-sm text-green-400 font-medium">All Clear</p>
                        <p className="text-xs text-gray-500">No active triggers</p>
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {cityData[selectedCity].triggers.map(t => {
                          const m = TRIGGER_META[t];
                          return (
                            <div key={t} className="flex items-center gap-2 text-sm font-medium text-red-400">
                              <motion.div animate={{ scale: [1, 1.2, 1] }} transition={{ repeat: Infinity, duration: 1.5 }}>
                                <AlertTriangle className="w-4 h-4" />
                              </motion.div>
                              {m?.emoji} {m?.label} Active
                            </div>
                          );
                        })}
                        <p className="text-xs text-gray-500 mt-2">Claims processing automatically for active policies in this zone.</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Threshold bars */}
                <p className="text-sm font-semibold text-white mb-3">Threshold Monitoring</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <TriggerCard triggerType="HeavyRain" threshold={64} actualValue={cityData[selectedCity].rainfall}
                    unit="mm/hr" isActive={cityData[selectedCity].rainfall >= 64} />
                  <TriggerCard triggerType="SevereAQI" threshold={400} actualValue={cityData[selectedCity].aqi}
                    unit="AQI" isActive={cityData[selectedCity].aqi >= 400} />
                  <TriggerCard triggerType="ExtremeHeat" threshold={48} actualValue={cityData[selectedCity].temp + 3}
                    unit="°C feels-like" isActive={(cityData[selectedCity].temp + 3) >= 48} />
                  <TriggerCard triggerType="Flooding" threshold={6}
                    unit="hrs" isActive={cityData[selectedCity].triggers.includes('Flooding')} />
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Legend */}
        <div className="flex flex-wrap items-center gap-6 text-xs text-gray-500 justify-center">
          <span className="flex items-center gap-2"><span className="w-3 h-3 rounded-full bg-green-500/60" />All Clear</span>
          <span className="flex items-center gap-2"><span className="w-3 h-3 rounded-full bg-red-500 animate-pulse" />Active Trigger — Claims Processing</span>
          <span className="flex items-center gap-2"><Activity className="w-3.5 h-3.5 text-teal-400" />Auto-refresh every 60 seconds</span>
        </div>
      </div>

      <Footer />
    </div>
  );
}
