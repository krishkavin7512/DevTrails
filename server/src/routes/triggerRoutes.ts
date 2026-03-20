import { Router, Request, Response } from 'express';
import { AppError } from '../middleware/errorHandler';
import { SUPPORTED_CITIES, getCityConfig } from '../config/cities';
import {
  TRIGGER_THRESHOLDS,
  TriggerType,
  processTriggeredEvent,
  evaluateAllTriggers,
} from '../services/triggerEngine';
import { getCurrentWeather } from '../services/weatherService';

const router = Router();

// Simulated threshold-exceeding values for each trigger type
const SIMULATE_VALUES: Record<TriggerType, { value: number; description: string }> = {
  HeavyRain:        { value: 82.5,  description: 'Simulated heavy rainfall — 82.5mm/hr (threshold 64mm/hr)' },
  ExtremeHeat:      { value: 49.2,  description: 'Simulated extreme heat — feels-like 49.2°C (threshold 48°C)' },
  SevereAQI:        { value: 456,   description: 'Simulated severe AQI — 456 AQI units (threshold 400)' },
  Flooding:         { value: 8.5,   description: 'Simulated flooding — sustained rain 8.5hrs (threshold 6hrs)' },
  SocialDisruption: { value: 6,     description: 'Admin-simulated disruption — bandh/curfew 6hrs (threshold 4hrs)' },
};

function validateCity(city: string): string {
  const normalized = SUPPORTED_CITIES.find(c => c.toLowerCase() === city.toLowerCase());
  if (!normalized) throw new AppError(`Unsupported city: ${city}`, 400);
  return normalized;
}

function validateTrigger(t: string): TriggerType {
  const valid: TriggerType[] = ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'];
  const found = valid.find(v => v.toLowerCase() === t.toLowerCase());
  if (!found) throw new AppError(`Invalid trigger type: ${t}. Valid: ${valid.join(', ')}`, 400);
  return found;
}

// ── GET /api/triggers/simulate/:city/:triggerType ─────────────────────────────
// Demo-critical endpoint: simulates the full parametric payout chain
// trigger detected → disruption event created → claims auto-generated → payouts queued

router.get('/simulate/:city/:triggerType', async (req: Request, res: Response) => {
  const city        = validateCity(String(req.params.city));
  const triggerType = validateTrigger(String(req.params.triggerType));
  const cityConf    = getCityConfig(city);
  const sim         = SIMULATE_VALUES[triggerType];
  const threshold   = TRIGGER_THRESHOLDS[triggerType].threshold;

  // Build a severity from the simulated value
  let severity: 'Moderate' | 'Severe' | 'Extreme' = 'Severe';
  if (triggerType === 'HeavyRain') {
    severity = sim.value > 100 ? 'Extreme' : sim.value > 75 ? 'Severe' : 'Moderate';
  } else if (triggerType === 'ExtremeHeat') {
    severity = sim.value >= 52 ? 'Extreme' : sim.value >= 50 ? 'Severe' : 'Moderate';
  } else if (triggerType === 'SevereAQI') {
    severity = sim.value >= 500 ? 'Extreme' : sim.value >= 450 ? 'Severe' : 'Moderate';
  }

  const triggerResult = {
    type:        triggerType,
    triggered:   true,
    actualValue: sim.value,
    threshold,
    severity,
    parameter:   TRIGGER_THRESHOLDS[triggerType].parameter,
    description: TRIGGER_THRESHOLDS[triggerType].description,
  };

  const zones = cityConf?.zones ?? ['Zone A', 'Zone B', 'Zone C'];
  const meta  = {
    HeavyRain:        { emoji: '🌧️', title: `Heavy Rainfall Alert — ${city}` },
    ExtremeHeat:      { emoji: '🌡️', title: `Extreme Heat Warning — ${city}` },
    SevereAQI:        { emoji: '😷', title: `Severe Air Quality Alert — ${city}` },
    Flooding:         { emoji: '🌊', title: `Flood Alert — ${city}` },
    SocialDisruption: { emoji: '🚫', title: `Social Disruption — ${city}` },
  }[triggerType];

  const startMs = Date.now();

  const { event, claimsCreated, totalPayoutPaise } = await processTriggeredEvent(
    triggerResult,
    city,
    zones,
    meta.title,
    sim.description,
    'AdminTriggered',
    { durationHours: 4 }
  );

  const processingMs = Date.now() - startMs;

  res.json({
    success: true,
    data: {
      simulation: {
        city,
        triggerType,
        simulatedValue: sim.value,
        threshold,
        overagePercent: (((sim.value - threshold) / threshold) * 100).toFixed(1),
        severity,
      },
      event: {
        _id:          event._id,
        title:        event.title,
        description:  event.description,
        severity:     event.severity,
        startTime:    event.startTime,
        isActive:     event.isActive,
      },
      claims: {
        created:          claimsCreated,
        totalPayoutPaise,
        totalPayoutINR:   totalPayoutPaise / 100,
        avgPayoutINR:     claimsCreated > 0 ? (totalPayoutPaise / 100 / claimsCreated).toFixed(0) : 0,
      },
      processingMs,
      message: `${meta.emoji} Simulation complete in ${processingMs}ms — ${claimsCreated} claims auto-initiated, ₹${(totalPayoutPaise / 100).toLocaleString('en-IN')} queued`,
    },
  });
});

// ── GET /api/triggers/status/:city ────────────────────────────────────────────
// Live trigger evaluation for a city (used by frontend real-time display)

router.get('/status/:city', async (req: Request, res: Response) => {
  const city    = validateCity(String(req.params.city));
  const weather = await getCurrentWeather(city);
  const results = evaluateAllTriggers(city, weather);

  const active = results.filter(t => t.triggered);

  res.json({
    success: true,
    data: {
      city,
      anyActive:    active.length > 0,
      activeCount:  active.length,
      triggers:     results,
      weather: {
        temperature:  weather.temperature,
        feelsLike:    weather.feelsLike,
        rainfall:     weather.rainfall,
        aqi:          weather.aqi,
        source:       weather.source,
        fetchedAt:    weather.fetchedAt,
      },
    },
  });
});

// ── GET /api/triggers/all-cities ──────────────────────────────────────────────
// Check trigger status across all 10 cities in parallel

router.get('/all-cities', async (_req: Request, res: Response) => {
  const results = await Promise.allSettled(
    SUPPORTED_CITIES.map(async city => {
      const weather  = await getCurrentWeather(city);
      const triggers = evaluateAllTriggers(city, weather);
      const active   = triggers.filter(t => t.triggered);
      return {
        city,
        anyActive:   active.length > 0,
        activeTriggers: active.map(t => t.type),
        weather: {
          temperature: weather.temperature,
          feelsLike:   weather.feelsLike,
          rainfall:    weather.rainfall,
          aqi:         weather.aqi,
          source:      weather.source,
        },
      };
    })
  );

  const cities = results.map((r, i) =>
    r.status === 'fulfilled' ? r.value : { city: SUPPORTED_CITIES[i], anyActive: false, activeTriggers: [], weather: null }
  );

  const alertCities = cities.filter(c => c.anyActive);

  res.json({
    success: true,
    data: {
      cities,
      alertCities: alertCities.length,
      checkedAt:   new Date().toISOString(),
    },
  });
});

export default router;
