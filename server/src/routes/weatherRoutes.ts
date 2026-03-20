import { Router, Request, Response } from 'express';
import { AppError } from '../middleware/errorHandler';
import { SUPPORTED_CITIES } from '../config/cities';
import {
  getCurrentWeather,
  getAQI,
  getForecast,
} from '../services/weatherService';
import { evaluateAllTriggers, TRIGGER_THRESHOLDS } from '../services/triggerEngine';

const router = Router();

function validateCity(city: string): string {
  const normalized = Object.keys(
    SUPPORTED_CITIES.reduce((acc, c) => ({ ...acc, [c]: true }), {} as any)
  ).find(c => c.toLowerCase() === city.toLowerCase());
  if (!normalized) throw new AppError(`Unsupported city: ${city}. Supported: ${SUPPORTED_CITIES.join(', ')}`, 400);
  return normalized;
}

// ── GET /api/weather/current/:city ────────────────────────────────────────────

router.get('/current/:city', async (req: Request, res: Response) => {
  const city    = validateCity(String(req.params.city));
  const weather = await getCurrentWeather(city);

  res.json({
    success: true,
    data: {
      ...weather,
      thresholds: {
        heavyRain:   `>${TRIGGER_THRESHOLDS.HeavyRain.threshold}mm/hr`,
        extremeHeat: `>${TRIGGER_THRESHOLDS.ExtremeHeat.threshold}°C feels-like`,
        severeAQI:   `>${TRIGGER_THRESHOLDS.SevereAQI.threshold} AQI`,
      },
    },
  });
});

// ── GET /api/weather/forecast/:city ───────────────────────────────────────────

router.get('/forecast/:city', async (req: Request, res: Response) => {
  const city     = validateCity(String(req.params.city));
  const forecast = await getForecast(city);

  res.json({
    success: true,
    data: {
      city,
      days: forecast,
      generatedAt: new Date(),
    },
  });
});

// ── GET /api/weather/aqi/:city ────────────────────────────────────────────────

router.get('/aqi/:city', async (req: Request, res: Response) => {
  const city   = validateCity(String(req.params.city));
  const aqiData = await getAQI(city);

  const levelMap: Record<string, { color: string; advice: string }> = {
    Good:         { color: '#22c55e', advice: 'Safe to ride all day' },
    Satisfactory: { color: '#84cc16', advice: 'Safe to ride — sensitive riders may feel effects' },
    Moderate:     { color: '#eab308', advice: 'Ride with N95 mask recommended' },
    Poor:         { color: '#f97316', advice: 'Limit outdoor exposure, use mask' },
    VeryPoor:     { color: '#ef4444', advice: 'Avoid riding if possible — health risk' },
    Severe:       { color: '#7c3aed', advice: 'PAYOUT TRIGGER ACTIVE — stop riding' },
  };

  const levelInfo = levelMap[aqiData.severity] ?? levelMap.Moderate!;

  res.json({
    success: true,
    data: {
      city,
      ...aqiData,
      ...levelInfo,
      triggerThreshold: TRIGGER_THRESHOLDS.SevereAQI.threshold,
      triggerActive:    aqiData.aqi >= TRIGGER_THRESHOLDS.SevereAQI.threshold,
      pollutantBreakdown: {
        pm25:  { value: aqiData.pm25,  unit: 'µg/m³', safeLimit: 60 },
        pm10:  { value: aqiData.pm10,  unit: 'µg/m³', safeLimit: 100 },
      },
      fetchedAt: new Date(),
    },
  });
});

// ── GET /api/weather/check-triggers/:city ─────────────────────────────────────

router.get('/check-triggers/:city', async (req: Request, res: Response) => {
  const city    = validateCity(String(req.params.city));
  const weather = await getCurrentWeather(city);
  const triggers = evaluateAllTriggers(city, weather);

  const active     = triggers.filter(t => t.triggered);
  const anyActive  = active.length > 0;
  const maxSeverity = active.reduce((max, t) => {
    const order = ['None', 'Mild', 'Moderate', 'Severe', 'Extreme'];
    return order.indexOf(t.severity) > order.indexOf(max) ? t.severity : max;
  }, 'None' as string);

  res.json({
    success: true,
    data: {
      city,
      anyTriggerActive: anyActive,
      activeTriggerCount: active.length,
      overallSeverity: maxSeverity,
      triggers: triggers.map(t => ({
        type:         t.type,
        triggered:    t.triggered,
        actualValue:  t.actualValue,
        threshold:    t.threshold,
        severity:     t.severity,
        parameter:    t.parameter,
        overagePercent: t.triggered
          ? (((t.actualValue - t.threshold) / t.threshold) * 100).toFixed(1)
          : null,
      })),
      currentWeather: {
        temperature:  weather.temperature,
        feelsLike:    weather.feelsLike,
        rainfall:     weather.rainfall,
        aqi:          weather.aqi,
        fetchedAt:    weather.fetchedAt,
      },
    },
  });
});

// ── GET /api/weather/history/:city ────────────────────────────────────────────

router.get('/history/:city', async (req: Request, res: Response) => {
  const city = validateCity(String(req.params.city));
  const days = Math.min(30, parseInt(req.query.days as string) || 30);

  const WeatherData = (await import('../models/WeatherData')).default;
  const since = new Date(Date.now() - days * 86_400_000);

  const records = await WeatherData.find({
    city,
    fetchedAt: { $gte: since },
  })
    .sort({ fetchedAt: -1 })
    .limit(days * 4)  // up to 4 readings per day
    .lean();

  // Generate mock history if no records
  if (records.length === 0) {
    const mockHistory = Array.from({ length: Math.min(days, 30) }, (_, i) => {
      const d = new Date(Date.now() - i * 86_400_000);
      return {
        date: d.toISOString().slice(0, 10),
        temperature: 28 + Math.floor(Math.random() * 10),
        rainfall:    Math.random() > 0.8 ? Math.floor(Math.random() * 80) : 0,
        aqi:         80 + Math.floor(Math.random() * 120),
        source:      'mock_historical',
      };
    });

    return res.json({
      success: true,
      data: { city, days, records: mockHistory, source: 'mock_data' },
    });
  }

  res.json({
    success: true,
    data: {
      city, days,
      records: records.map(r => ({
        date:        r.fetchedAt.toISOString().slice(0, 10),
        temperature: r.data.temperature,
        rainfall:    r.data.rainfall,
        aqi:         r.data.aqi,
        severity:    r.disruptionSeverity,
        source:      r.source,
      })),
      source: 'database',
    },
  });
});

export default router;
