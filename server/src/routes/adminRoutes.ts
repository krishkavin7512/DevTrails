/**
 * Admin Routes — seed database, run demo, system controls
 * POST /api/admin/seed      — drops all collections and seeds with rich mock data
 * POST /api/admin/demo      — seeds + fires a simulated trigger in a city
 * GET  /api/admin/status    — DB health + collection counts
 */

import { Router, Request, Response } from 'express';
import mongoose from 'mongoose';
import RiderModel from '../models/Rider';
import PolicyModel from '../models/Policy';
import ClaimModel from '../models/Claim';
import DisruptionEvent from '../models/DisruptionEvent';
import WeatherData from '../models/WeatherData';
import { TRIGGER_THRESHOLDS, TriggerType, processTriggeredEvent } from '../services/triggerEngine';
import { getCityConfig, SUPPORTED_CITIES } from '../config/cities';

const router = Router();

// ── Helper: generate a policyNumber ──────────────────────────────────────────
function policyNum(): string {
  const d    = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `RC-${d}-${rand}`;
}

function claimNum(seq: number): string {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return `CLM-${d}-${String(seq).padStart(5, '0')}`;
}

function daysAgo(n: number): Date {
  return new Date(Date.now() - n * 86_400_000);
}

// ── GET /api/admin/status ─────────────────────────────────────────────────────

router.get('/status', async (_req: Request, res: Response) => {
  const dbState = mongoose.connection.readyState;
  const dbStateMap: Record<number, string> = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };

  let counts = { riders: 0, policies: 0, claims: 0, disruptions: 0, weather: 0 };
  if (dbState === 1) {
    const [r, p, c, d, w] = await Promise.all([
      RiderModel.countDocuments(),
      PolicyModel.countDocuments(),
      ClaimModel.countDocuments(),
      DisruptionEvent.countDocuments(),
      WeatherData.countDocuments(),
    ]);
    counts = { riders: r, policies: p, claims: c, disruptions: d, weather: w };
  }

  res.json({
    success: true,
    data: {
      db: { state: dbStateMap[dbState] ?? 'unknown', readyState: dbState },
      counts,
      seeded: counts.riders > 0,
    },
  });
});

// ── POST /api/admin/seed ──────────────────────────────────────────────────────

router.post('/seed', async (_req: Request, res: Response) => {
  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({ success: false, error: 'MongoDB not connected — cannot seed' });
  }

  // Drop all collections
  await Promise.all([
    RiderModel.deleteMany({}),
    PolicyModel.deleteMany({}),
    ClaimModel.deleteMany({}),
    DisruptionEvent.deleteMany({}),
    WeatherData.deleteMany({}),
  ]);

  // ── Seed Riders ─────────────────────────────────────────────────────────────
  const riderDefs = [
    { fullName: 'Rahul Sharma',   phone: '9876543210', email: 'rahul@example.com', city: 'Mumbai',    platform: 'Swiggy',  vehicleType: 'motorcycle', preferredShift: 'evening', avgWeeklyEarnings: 550000, avgDailyHours: 8,  experienceMonths: 24, riskScore: 52, riskTier: 'Medium', zone: 'Andheri West',  pincode: '400053' },
    { fullName: 'Priya Nair',     phone: '8765432109', email: 'priya@example.com',  city: 'Delhi',     platform: 'Zomato',  vehicleType: 'scooter',    preferredShift: 'morning', avgWeeklyEarnings: 480000, avgDailyHours: 7,  experienceMonths: 18, riskScore: 71, riskTier: 'High',   zone: 'Connaught Place', pincode: '110001' },
    { fullName: 'Arjun Mehta',    phone: '7654321098', email: 'arjun@example.com',  city: 'Bangalore', platform: 'Both',    vehicleType: 'motorcycle', preferredShift: 'mixed',   avgWeeklyEarnings: 620000, avgDailyHours: 9,  experienceMonths: 36, riskScore: 31, riskTier: 'Low',    zone: 'Koramangala',     pincode: '560034' },
    { fullName: 'Kavya Reddy',    phone: '6543210987', email: 'kavya@example.com',  city: 'Hyderabad', platform: 'Swiggy',  vehicleType: 'scooter',    preferredShift: 'evening', avgWeeklyEarnings: 510000, avgDailyHours: 8,  experienceMonths: 12, riskScore: 58, riskTier: 'Medium', zone: 'Banjara Hills',   pincode: '500034' },
    { fullName: 'Rohit Das',      phone: '9988776655', email: 'rohit@example.com',  city: 'Kolkata',   platform: 'Zomato',  vehicleType: 'bicycle',    preferredShift: 'morning', avgWeeklyEarnings: 380000, avgDailyHours: 6,  experienceMonths: 6,  riskScore: 44, riskTier: 'Medium', zone: 'Salt Lake',       pincode: '700064' },
    { fullName: 'Sneha Joshi',    phone: '8877665544', email: 'sneha@example.com',  city: 'Pune',      platform: 'Both',    vehicleType: 'motorcycle', preferredShift: 'afternoon', avgWeeklyEarnings: 520000, avgDailyHours: 8, experienceMonths: 20, riskScore: 39, riskTier: 'Low',   zone: 'Kothrud',         pincode: '411038' },
    { fullName: 'Vikram Patel',   phone: '7766554433', email: 'vikram@example.com', city: 'Ahmedabad', platform: 'Swiggy',  vehicleType: 'motorcycle', preferredShift: 'evening', avgWeeklyEarnings: 490000, avgDailyHours: 9,  experienceMonths: 30, riskScore: 62, riskTier: 'High',   zone: 'Satellite',       pincode: '380015' },
    { fullName: 'Meera Singh',    phone: '6655443322', email: 'meera@example.com',  city: 'Jaipur',    platform: 'Zomato',  vehicleType: 'scooter',    preferredShift: 'morning', avgWeeklyEarnings: 460000, avgDailyHours: 7,  experienceMonths: 15, riskScore: 65, riskTier: 'High',   zone: 'Malviya Nagar',   pincode: '302017' },
    { fullName: 'Aditya Kumar',   phone: '9911223344', email: 'aditya@example.com', city: 'Chennai',   platform: 'Both',    vehicleType: 'motorcycle', preferredShift: 'mixed',   avgWeeklyEarnings: 540000, avgDailyHours: 9,  experienceMonths: 28, riskScore: 47, riskTier: 'Medium', zone: 'Anna Nagar',      pincode: '600040' },
    { fullName: 'Sunita Verma',   phone: '8822334455', email: 'sunita@example.com', city: 'Lucknow',   platform: 'Swiggy',  vehicleType: 'scooter',    preferredShift: 'evening', avgWeeklyEarnings: 420000, avgDailyHours: 7,  experienceMonths: 10, riskScore: 68, riskTier: 'High',   zone: 'Hazratganj',      pincode: '226001' },
  ];

  const riders = await RiderModel.insertMany(
    riderDefs.map(r => ({ ...r, isActive: true, kycVerified: true, registeredAt: daysAgo(Math.floor(30 + Math.random() * 90)) }))
  );

  // ── Seed Policies ────────────────────────────────────────────────────────────
  const planMap: Record<string, { weeklyPremium: number; coverageLimit: number; coveredDisruptions: string[] }> = {
    Basic:    { weeklyPremium: 3500,  coverageLimit: 80000000,  coveredDisruptions: ['HeavyRain', 'ExtremeHeat'] },
    Standard: { weeklyPremium: 5500,  coverageLimit: 150000000, coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'] },
    Premium:  { weeklyPremium: 7500,  coverageLimit: 250000000, coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'] },
  };

  const planTypes = ['Basic', 'Standard', 'Standard', 'Premium', 'Standard', 'Basic', 'Premium', 'Standard', 'Standard', 'Basic'];

  const policies = await PolicyModel.insertMany(
    riders.map((rider, i) => {
      const plan = planMap[planTypes[i]];
      return {
        riderId:             rider._id,
        planType:            planTypes[i],
        weeklyPremium:       plan.weeklyPremium,
        coverageLimit:       plan.coverageLimit,
        coveredDisruptions:  plan.coveredDisruptions,
        status:              'Active',
        startDate:           daysAgo(30),
        endDate:             new Date(Date.now() + 7 * 86_400_000),
        policyNumber:        policyNum(),
        renewalCount:        Math.floor(Math.random() * 3),
        autoRenew:           true,
      };
    })
  );

  // ── Seed Claims ──────────────────────────────────────────────────────────────
  const claimDefs = [
    { riderIdx: 0, triggerType: 'HeavyRain',   payoutAmount: 120000,  status: 'Paid',          fraudScore: 8,  createdAt: daysAgo(14), triggerValue: 78.5,  threshold: 64  },
    { riderIdx: 1, triggerType: 'SevereAQI',   payoutAmount: 85000,   status: 'Paid',          fraudScore: 12, createdAt: daysAgo(20), triggerValue: 435,   threshold: 400 },
    { riderIdx: 0, triggerType: 'ExtremeHeat', payoutAmount: 95000,   status: 'AutoInitiated', fraudScore: 5,  createdAt: daysAgo(2),  triggerValue: 49.2,  threshold: 48  },
    { riderIdx: 2, triggerType: 'Flooding',    payoutAmount: 150000,  status: 'Approved',      fraudScore: 18, createdAt: daysAgo(7),  triggerValue: 8.5,   threshold: 6   },
    { riderIdx: 1, triggerType: 'HeavyRain',   payoutAmount: 0,       status: 'Rejected',      fraudScore: 72, createdAt: daysAgo(30), triggerValue: 62.1,  threshold: 64  },
    { riderIdx: 3, triggerType: 'SevereAQI',   payoutAmount: 75000,   status: 'Paid',          fraudScore: 9,  createdAt: daysAgo(45), triggerValue: 412,   threshold: 400 },
    { riderIdx: 4, triggerType: 'HeavyRain',   payoutAmount: 95000,   status: 'Paid',          fraudScore: 14, createdAt: daysAgo(60), triggerValue: 71.3,  threshold: 64  },
    { riderIdx: 6, triggerType: 'ExtremeHeat', payoutAmount: 110000,  status: 'UnderReview',   fraudScore: 22, createdAt: daysAgo(1),  triggerValue: 48.9,  threshold: 48  },
  ];

  const TRIGGER_PARAMS: Record<string, string> = {
    HeavyRain: 'rainfall_mm_hr', ExtremeHeat: 'feels_like_c',
    SevereAQI: 'aqi', Flooding: 'rain_duration_hrs', SocialDisruption: 'admin_triggered',
  };

  const cityConfs: Record<string, { lat: number; lng: number }> = {
    Mumbai: { lat: 19.076, lng: 72.878 }, Delhi: { lat: 28.614, lng: 77.209 },
    Bangalore: { lat: 12.972, lng: 77.595 }, Hyderabad: { lat: 17.385, lng: 78.487 },
  };

  await ClaimModel.insertMany(
    claimDefs.map((cd, i) => {
      const rider  = riders[cd.riderIdx];
      const policy = policies[cd.riderIdx];
      const conf   = cityConfs[rider.city] ?? { lat: 19.076, lng: 72.878 };
      return {
        policyId:           policy._id,
        riderId:            rider._id,
        claimNumber:        claimNum(i + 1),
        triggerType:        cd.triggerType,
        triggerData: {
          parameter:   TRIGGER_PARAMS[cd.triggerType],
          threshold:   cd.threshold,
          actualValue: cd.triggerValue,
          dataSource:  'OpenWeatherMap',
          timestamp:   cd.createdAt,
          location:    conf,
        },
        estimatedLostHours: cd.payoutAmount > 0 ? 4.5 : 0,
        payoutAmount:       cd.payoutAmount,
        status:             cd.status,
        fraudScore:         cd.fraudScore,
        fraudFlags:         cd.fraudScore > 60 ? ['Threshold not exceeded', 'Borderline value'] : [],
        createdAt:          cd.createdAt,
        ...(cd.status === 'Paid' ? { processedAt: new Date(cd.createdAt.getTime() + 90000), paidAt: new Date(cd.createdAt.getTime() + 120000) } : {}),
      };
    })
  );

  // ── Seed Disruption Events ───────────────────────────────────────────────────
  await DisruptionEvent.insertMany([
    {
      city: 'Delhi', zones: ['Connaught Place', 'Lajpat Nagar', 'Rohini'],
      type: 'SevereAQI', severity: 'Severe',
      title: 'Severe Air Quality Alert — Delhi NCR',
      description: 'AQI exceeded 400 threshold across central Delhi zones. GRAP Stage III active.',
      startTime: new Date(Date.now() - 3 * 3600000),
      triggerData: { parameter: 'aqi', value: 456, threshold: 400 },
      affectedRiders: 234, totalPayouts: 25000000, claimsGenerated: 234,
      isActive: true, source: 'Automated',
    },
    {
      city: 'Jaipur', zones: ['Malviya Nagar', 'Mansarovar', 'C Scheme'],
      type: 'ExtremeHeat', severity: 'Moderate',
      title: 'Extreme Heat Warning — Jaipur',
      description: 'Feels-like temperature exceeding 48°C. Prolonged exposure advisory issued.',
      startTime: new Date(Date.now() - 1.5 * 3600000),
      triggerData: { parameter: 'feels_like_c', value: 49.1, threshold: 48 },
      affectedRiders: 89, totalPayouts: 8400000, claimsGenerated: 89,
      isActive: true, source: 'Automated',
    },
    {
      city: 'Mumbai', zones: ['Andheri West', 'Kurla', 'Dadar'],
      type: 'HeavyRain', severity: 'Severe',
      title: 'Heavy Rainfall Alert — Mumbai Western Suburbs',
      description: 'Rainfall exceeding 78mm/hr — IMD Red Alert active.',
      startTime: daysAgo(14), endTime: new Date(daysAgo(14).getTime() + 4 * 3600000),
      triggerData: { parameter: 'rainfall_mm_hr', value: 78.5, threshold: 64 },
      affectedRiders: 312, totalPayouts: 37440000, claimsGenerated: 312,
      isActive: false, source: 'Automated',
    },
  ]);

  // ── Seed Weather Snapshots ───────────────────────────────────────────────────
  const weatherSnaps = [
    { city: 'Mumbai',    pincode: '400053', dataType: 'Weather' as const, data: { temperature: 32, feelsLike: 37, humidity: 80, rainfall: 0,  windSpeed: 3.8, aqi: 92,  pm25: 42,  pm10: 78,  weatherCondition: 'Partly Cloudy', description: 'Warm and humid' }, isDisruptionActive: false, disruptionSeverity: 'None' as const, source: 'mock_data' },
    { city: 'Delhi',     pincode: '110001', dataType: 'AQI' as const,     data: { temperature: 24, feelsLike: 23, humidity: 55, rainfall: 0,  windSpeed: 2.1, aqi: 456, pm25: 298, pm10: 415, weatherCondition: 'Haze',          description: 'Severe AQI — GRAP Stage III' }, isDisruptionActive: true,  disruptionSeverity: 'Severe' as const, source: 'mock_data' },
    { city: 'Bangalore', pincode: '560034', dataType: 'Weather' as const, data: { temperature: 27, feelsLike: 28, humidity: 60, rainfall: 0,  windSpeed: 3.2, aqi: 62,  pm25: 28,  pm10: 45,  weatherCondition: 'Clear',         description: 'Pleasant and clear' }, isDisruptionActive: false, disruptionSeverity: 'None' as const, source: 'mock_data' },
    { city: 'Jaipur',    pincode: '302017', dataType: 'Weather' as const, data: { temperature: 41, feelsLike: 49.1, humidity: 28, rainfall: 0, windSpeed: 7.1, aqi: 175, pm25: 95,  pm10: 145, weatherCondition: 'Hot',           description: 'Extreme heat — feels-like 49°C' }, isDisruptionActive: true,  disruptionSeverity: 'Moderate' as const, source: 'mock_data' },
    { city: 'Ahmedabad', pincode: '380015', dataType: 'Weather' as const, data: { temperature: 43, feelsLike: 47.2, humidity: 22, rainfall: 0, windSpeed: 6.0, aqi: 155, pm25: 85,  pm10: 128, weatherCondition: 'Very Hot',      description: 'Heat advisory in effect' }, isDisruptionActive: false, disruptionSeverity: 'Mild' as const, source: 'mock_data' },
  ];

  await WeatherData.insertMany(weatherSnaps.map(s => ({ ...s, fetchedAt: new Date() })));

  const finalCounts = await Promise.all([
    RiderModel.countDocuments(),
    PolicyModel.countDocuments(),
    ClaimModel.countDocuments(),
    DisruptionEvent.countDocuments(),
    WeatherData.countDocuments(),
  ]);

  res.json({
    success: true,
    data: {
      seeded: {
        riders:      finalCounts[0],
        policies:    finalCounts[1],
        claims:      finalCounts[2],
        disruptions: finalCounts[3],
        weather:     finalCounts[4],
      },
    },
    message: `Database seeded: ${finalCounts[0]} riders, ${finalCounts[1]} policies, ${finalCounts[2]} claims, ${finalCounts[3]} disruption events`,
  });
});

// ── POST /api/admin/demo ──────────────────────────────────────────────────────
// Seed + fire a live trigger simulation for demo purposes

router.post('/demo', async (req: Request, res: Response) => {
  const city        = (req.body.city as string) || 'Mumbai';
  const triggerType = (req.body.triggerType as TriggerType) || 'HeavyRain';

  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({ success: false, error: 'MongoDB not connected' });
  }

  const validCities = SUPPORTED_CITIES;
  if (!validCities.includes(city)) {
    return res.status(400).json({ success: false, error: `Invalid city: ${city}` });
  }

  const cityConf = getCityConfig(city);
  const zones    = cityConf?.zones ?? ['All Zones'];

  const DEMO_VALUES: Record<string, { value: number; severity: 'Moderate' | 'Severe' | 'Extreme'; title: string; desc: string }> = {
    HeavyRain:        { value: 82.5, severity: 'Severe',   title: `Heavy Rainfall Alert — ${city}`, desc: 'Demo: rainfall 82.5mm/hr exceeds 64mm/hr threshold' },
    ExtremeHeat:      { value: 49.2, severity: 'Moderate', title: `Extreme Heat Warning — ${city}`,  desc: 'Demo: feels-like 49.2°C exceeds 48°C threshold' },
    SevereAQI:        { value: 456,  severity: 'Severe',   title: `Severe AQI Alert — ${city}`,     desc: 'Demo: AQI 456 exceeds 400 threshold' },
    Flooding:         { value: 8.5,  severity: 'Moderate', title: `Flood Alert — ${city}`,           desc: 'Demo: sustained rain 8.5hrs exceeds 6hr threshold' },
    SocialDisruption: { value: 6,    severity: 'Moderate', title: `Social Disruption — ${city}`,     desc: 'Demo: admin-triggered curfew/bandh' },
  };

  const demo = DEMO_VALUES[triggerType] ?? DEMO_VALUES.HeavyRain;

  const triggerResult = {
    type:        triggerType,
    triggered:   true,
    actualValue: demo.value,
    threshold:   TRIGGER_THRESHOLDS[triggerType].threshold,
    severity:    demo.severity,
    parameter:   TRIGGER_THRESHOLDS[triggerType].parameter,
    description: TRIGGER_THRESHOLDS[triggerType].description,
  };

  const startMs = Date.now();
  const { event, claimsCreated, totalPayoutPaise } = await processTriggeredEvent(
    triggerResult, city, zones, demo.title, demo.desc, 'AdminTriggered', { durationHours: 4 }
  );

  res.json({
    success: true,
    data: {
      step1_trigger:    { type: triggerType, city, value: demo.value, threshold: triggerResult.threshold, breached: true },
      step2_event:      { id: event._id, title: event.title, severity: demo.severity, isActive: true },
      step3_claims:     { created: claimsCreated, totalINR: totalPayoutPaise / 100 },
      step4_processing: { method: 'parametric', fraudCheck: true, avgProcessingMs: Math.floor((Date.now() - startMs) / Math.max(1, claimsCreated)) },
      processingMs:     Date.now() - startMs,
    },
    message: `Demo complete — ${claimsCreated} claims auto-initiated, ₹${(totalPayoutPaise / 100).toLocaleString('en-IN')} queued for payout`,
  });
});

export default router;
