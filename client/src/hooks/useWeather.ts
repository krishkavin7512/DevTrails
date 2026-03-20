'use client';
import { useState, useEffect, useCallback } from 'react';
import { api } from '@/lib/api';
import { MOCK_WEATHER, MOCK_CITY_WEATHER } from '@/lib/mockData';

export interface WeatherData {
  city: string;
  temperature: number;
  feelsLike: number;
  humidity: number;
  description: string;
  windSpeed: number;
  rainfall: number;
  aqi: number;
  isDisruptionActive: boolean;
  lastUpdated: string;
}

export function useWeather(city: string) {
  const [data, setData] = useState<WeatherData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchWeather = useCallback(async () => {
    if (!city) return;
    try {
      setLoading(true);
      const res = await api.get(`/weather/current/${city}`);
      const w = res.data;
      setData({
        city,
        temperature: w.main?.temp ?? w.temperature ?? 30,
        feelsLike: w.main?.feels_like ?? w.feelsLike ?? 33,
        humidity: w.main?.humidity ?? w.humidity ?? 70,
        description: w.weather?.[0]?.description ?? w.description ?? 'Clear',
        windSpeed: w.wind?.speed ?? w.windSpeed ?? 10,
        rainfall: w.rain?.['1h'] ?? w.rainfall ?? 0,
        aqi: w.aqi ?? 100,
        isDisruptionActive: w.isDisruptionActive ?? false,
        lastUpdated: new Date().toISOString(),
      });
      setError(null);
    } catch {
      // Fallback to city-specific mock
      const cityMock = MOCK_CITY_WEATHER[city];
      setData({
        city,
        temperature: cityMock?.temp ?? 30,
        feelsLike: (cityMock?.temp ?? 30) + 3,
        humidity: 68,
        description: cityMock?.condition ?? 'Clear',
        windSpeed: cityMock?.wind ?? 10,
        rainfall: cityMock?.rainfall ?? 0,
        aqi: cityMock?.aqi ?? 100,
        isDisruptionActive: (cityMock?.triggers?.length ?? 0) > 0,
        lastUpdated: new Date().toISOString(),
      });
      setError(null);
    } finally {
      setLoading(false);
    }
  }, [city]);

  useEffect(() => {
    fetchWeather();
    const id = setInterval(fetchWeather, 60_000);
    return () => clearInterval(id);
  }, [fetchWeather]);

  return { data, loading, error, refresh: fetchWeather };
}
