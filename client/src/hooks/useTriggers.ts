'use client';
import { useState, useEffect, useCallback } from 'react';
import { api } from '@/lib/api';
import { MOCK_CITY_WEATHER, MOCK_DISRUPTIONS } from '@/lib/mockData';
import { CITIES } from '@/lib/utils';

export interface CityTriggerStatus {
  city: string;
  anyActive: boolean;
  activeTriggers: string[];
  weather: {
    temperature: number;
    feelsLike: number;
    rainfall: number;
    aqi: number;
    source: string;
  } | null;
}

export interface TriggerStatus {
  cities: CityTriggerStatus[];
  alertCities: number;
  checkedAt: string;
  loading: boolean;
  error: string | null;
}

function buildMockStatus(): { cities: CityTriggerStatus[]; alertCities: number; checkedAt: string } {
  const cities: CityTriggerStatus[] = CITIES.map(city => {
    const mock = MOCK_CITY_WEATHER[city];
    return {
      city,
      anyActive:      (mock?.triggers?.length ?? 0) > 0,
      activeTriggers: mock?.triggers ?? [],
      weather: mock ? {
        temperature: mock.temp,
        feelsLike:   mock.temp + 3,
        rainfall:    mock.rainfall,
        aqi:         mock.aqi,
        source:      'mock_data',
      } : null,
    };
  });
  return { cities, alertCities: cities.filter(c => c.anyActive).length, checkedAt: new Date().toISOString() };
}

export function useTriggers(autoRefreshMs = 60_000) {
  const [status, setStatus] = useState<Omit<TriggerStatus, 'loading' | 'error'>>({
    cities:      [],
    alertCities: 0,
    checkedAt:   new Date().toISOString(),
  });
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  const fetchAll = useCallback(async () => {
    try {
      const res = await api.get('/triggers/all-cities');
      const d   = (res as any).data ?? res;
      setStatus({
        cities:      d.cities ?? [],
        alertCities: d.alertCities ?? 0,
        checkedAt:   d.checkedAt ?? new Date().toISOString(),
      });
      setError(null);
    } catch {
      // Fallback to mock city weather
      const mock = buildMockStatus();
      setStatus(mock);
      setError(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAll();
    if (autoRefreshMs > 0) {
      const id = setInterval(fetchAll, autoRefreshMs);
      return () => clearInterval(id);
    }
  }, [fetchAll, autoRefreshMs]);

  return { ...status, loading, error, refresh: fetchAll };
}

// Simulate a trigger via backend (used by admin demo mode)
export async function simulateTrigger(
  city: string,
  triggerType: string
): Promise<{ claimsCreated: number; totalPayoutINR: number; eventId: string; processingMs: number }> {
  const res = await api.get(`/triggers/simulate/${city}/${triggerType}`);
  const d   = (res as any).data ?? res;
  return {
    claimsCreated:  d.claims?.created   ?? 0,
    totalPayoutINR: d.claims?.totalPayoutINR ?? 0,
    eventId:        d.event?._id        ?? '',
    processingMs:   d.processingMs      ?? 0,
  };
}
