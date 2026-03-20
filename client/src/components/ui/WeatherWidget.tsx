'use client';
import { RefreshCw, Wind, Droplets, AlertTriangle } from 'lucide-react';
import { aqiCategory } from '@/lib/utils';
import type { WeatherData } from '@/hooks/useWeather';

const CONDITION_ICON: Record<string, string> = {
  'clear': '☀️', 'sunny': '☀️', 'mostly clear': '🌤️', 'partly cloudy': '⛅',
  'cloudy': '☁️', 'overcast': '☁️', 'rain': '🌧️', 'heavy rain': '⛈️',
  'drizzle': '🌦️', 'thunderstorm': '⛈️', 'fog': '🌫️', 'haze': '🌫️',
  'hazy': '🌫️', 'mist': '🌫️', 'dusty': '🌪️', 'hot': '🌡️', 'humid': '💧',
};

function getIcon(description: string): string {
  const key = description.toLowerCase();
  for (const [k, v] of Object.entries(CONDITION_ICON)) {
    if (key.includes(k)) return v;
  }
  return '🌡️';
}

interface WeatherWidgetProps {
  data: WeatherData | null;
  loading?: boolean;
  onRefresh?: () => void;
}

export default function WeatherWidget({ data, loading, onRefresh }: WeatherWidgetProps) {
  if (loading || !data) {
    return (
      <div className="bg-dark-card border border-white/6 rounded-2xl p-5 space-y-3">
        <div className="shimmer h-4 w-24 rounded" />
        <div className="shimmer h-10 w-20 rounded" />
        <div className="shimmer h-4 w-full rounded" />
      </div>
    );
  }

  const aqi = aqiCategory(data.aqi);

  return (
    <div className={`bg-dark-card border rounded-2xl p-5 transition-all ${
      data.isDisruptionActive ? 'border-red-500/30 shadow-lg shadow-red-500/10' : 'border-white/6'
    }`}>
      {data.isDisruptionActive && (
        <div className="flex items-center gap-2 bg-red-500/10 border border-red-500/20 rounded-xl px-3 py-2 mb-4">
          <AlertTriangle className="w-4 h-4 text-red-400 flex-shrink-0" />
          <p className="text-xs font-medium text-red-400">Disruption trigger active — payouts processing</p>
        </div>
      )}

      <div className="flex items-start justify-between mb-4">
        <div>
          <p className="text-xs text-gray-500 mb-1">{data.city} · Live Weather</p>
          <div className="flex items-baseline gap-2">
            <span className="text-4xl">{getIcon(data.description)}</span>
            <span className="text-3xl font-display font-bold text-white tabular-nums">{Math.round(data.temperature)}°</span>
            <span className="text-sm text-gray-400">/ Feels {Math.round(data.feelsLike)}°</span>
          </div>
          <p className="text-sm text-gray-400 capitalize mt-1">{data.description}</p>
        </div>
        <button onClick={onRefresh} className="p-2 rounded-lg hover:bg-white/5 text-gray-500 hover:text-white transition-colors">
          <RefreshCw className="w-4 h-4" />
        </button>
      </div>

      <div className="grid grid-cols-3 gap-2">
        <div className="bg-white/[0.03] rounded-xl p-2.5 text-center">
          <Droplets className="w-3.5 h-3.5 text-blue-400 mx-auto mb-1" />
          <p className="text-xs font-semibold text-white">{data.humidity}%</p>
          <p className="text-[10px] text-gray-500">Humidity</p>
        </div>
        <div className="bg-white/[0.03] rounded-xl p-2.5 text-center">
          <Wind className="w-3.5 h-3.5 text-gray-400 mx-auto mb-1" />
          <p className="text-xs font-semibold text-white">{data.windSpeed}km/h</p>
          <p className="text-[10px] text-gray-500">Wind</p>
        </div>
        <div className="rounded-xl p-2.5 text-center" style={{ background: `${aqi.bg}88` }}>
          <p className="text-xs font-bold" style={{ color: aqi.color }}>{data.aqi}</p>
          <p className="text-[10px]" style={{ color: aqi.color }}>{aqi.label}</p>
          <p className="text-[10px] text-gray-500">AQI</p>
        </div>
      </div>

      {data.rainfall > 0 && (
        <div className="mt-3 flex items-center gap-2 text-xs text-blue-400 bg-blue-500/10 rounded-xl px-3 py-2">
          <span>🌧️</span>
          <span>Current rainfall: {data.rainfall.toFixed(1)} mm/hr</span>
          {data.rainfall > 64 && <span className="ml-auto font-bold text-red-400">⚠ Above threshold!</span>}
        </div>
      )}

      <p className="text-[10px] text-gray-600 mt-3 text-right">
        Updated {new Date(data.lastUpdated).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
      </p>
    </div>
  );
}
