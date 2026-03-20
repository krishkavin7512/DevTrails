import mongoose from 'mongoose';
import DisruptionEvent from '../models/DisruptionEvent';
import PolicyModel from '../models/Policy';
import ClaimModel from '../models/Claim';
import RiderModel from '../models/Rider';
import { getCurrentWeather, WeatherSnapshot, evaluateDisruptionSeverity } from './weatherService';
import { getCityConfig } from '../config/cities';
import { assessClaimFraud } from './fraudDetector';

export type TriggerType = 'HeavyRain' | 'ExtremeHeat' | 'SevereAQI' | 'Flooding' | 'SocialDisruption';

export interface TriggerThreshold {
  parameter: string;
  threshold: number;
  unit: string;
  description: string;
}

export const TRIGGER_THRESHOLDS: Record<TriggerType, TriggerThreshold> = {
  HeavyRain: {
    parameter:   'Rainfall intensity (mm/hr)',
    threshold:   64,
    unit:        'mm/hr',
    description: 'Heavy rainfall exceeding 64mm/hr or sustained >30mm/hr for 3+ hours',
  },
  ExtremeHeat: {
    parameter:   'Feels-like temperature (°C)',
    threshold:   48,
    unit:        '°C',
    description: 'Actual temperature >45°C or feels-like >48°C',
  },
  SevereAQI: {
    parameter:   'AQI (CPCB National Standard)',
    threshold:   400,
    unit:        'AQI units',
    description: 'Air Quality Index >400 (Severe+ on CPCB scale)',
  },
  Flooding: {
    parameter:   'Sustained rainfall + flood zone alert (hrs)',
    threshold:   6,
    unit:        'hours',
    description: 'Sustained rain for 6+ hours in flood-prone zone',
  },
  SocialDisruption: {
    parameter:   'Admin-verified disruption duration (hrs)',
    threshold:   4,
    unit:        'hours',
    description: 'Government/admin-verified curfew, bandh or strike for 4+ hours',
  },
};

export interface TriggerResult {
  type: TriggerType;
  triggered: boolean;
  actualValue: number;
  threshold: number;
  severity: 'None' | 'Mild' | 'Moderate' | 'Severe' | 'Extreme';
  parameter: string;
  description: string;
}

// ─── Evaluate individual triggers ────────────────────────────────────────────

function evalHeavyRain(w: WeatherSnapshot): TriggerResult {
  const def = TRIGGER_THRESHOLDS.HeavyRain;
  const triggered = w.rainfall >= def.threshold;
  return {
    type: 'HeavyRain', triggered,
    actualValue: w.rainfall, threshold: def.threshold,
    severity: triggered ? evaluateDisruptionSeverity(w.rainfall, 0, 0) : 'None',
    parameter: def.parameter, description: def.description,
  };
}

function evalExtremeHeat(w: WeatherSnapshot): TriggerResult {
  const def = TRIGGER_THRESHOLDS.ExtremeHeat;
  // Trigger on feels-like >48 OR actual >45
  const value = Math.max(w.feelsLike, w.temperature);
  const triggered = w.feelsLike >= def.threshold || w.temperature >= 45;
  return {
    type: 'ExtremeHeat', triggered,
    actualValue: value, threshold: def.threshold,
    severity: triggered
      ? (value >= 50 ? 'Extreme' : value >= 47 ? 'Severe' : 'Moderate')
      : 'None',
    parameter: def.parameter, description: def.description,
  };
}

function evalSevereAQI(w: WeatherSnapshot): TriggerResult {
  const def = TRIGGER_THRESHOLDS.SevereAQI;
  const triggered = w.aqi >= def.threshold;
  return {
    type: 'SevereAQI', triggered,
    actualValue: w.aqi, threshold: def.threshold,
    severity: triggered
      ? (w.aqi >= 500 ? 'Extreme' : w.aqi >= 450 ? 'Severe' : 'Moderate')
      : 'None',
    parameter: def.parameter, description: def.description,
  };
}

function evalFlooding(w: WeatherSnapshot, city: string): TriggerResult {
  const def = TRIGGER_THRESHOLDS.Flooding;
  const cityConf = getCityConfig(city);
  // Flooding = heavy sustained rain + city has flood-prone zones
  const isFloodProne = (cityConf?.floodProneZones.length ?? 0) > 0;
  const sustainedRainHours = w.rainfall >= 30 ? 6.5 : w.rainfall >= 15 ? 4 : 0;
  const triggered = isFloodProne && sustainedRainHours >= def.threshold;
  return {
    type: 'Flooding', triggered,
    actualValue: sustainedRainHours, threshold: def.threshold,
    severity: triggered
      ? (w.rainfall > 80 ? 'Extreme' : w.rainfall > 50 ? 'Severe' : 'Moderate')
      : 'None',
    parameter: def.parameter, description: def.description,
  };
}

export function evaluateAllTriggers(city: string, weather: WeatherSnapshot): TriggerResult[] {
  return [
    evalHeavyRain(weather),
    evalExtremeHeat(weather),
    evalSevereAQI(weather),
    evalFlooding(weather, city),
    // SocialDisruption is always admin-triggered, never auto
    {
      type: 'SocialDisruption' as TriggerType,
      triggered: false, actualValue: 0,
      threshold: TRIGGER_THRESHOLDS.SocialDisruption.threshold,
      severity: 'None' as const,
      parameter: TRIGGER_THRESHOLDS.SocialDisruption.parameter,
      description: TRIGGER_THRESHOLDS.SocialDisruption.description,
    },
  ];
}

// ─── Auto-initiate claims for an active disruption ────────────────────────────

function claimNumber(seq: number): string {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return `CLM-${d}-${String(seq).padStart(5, '0')}`;
}

function estimateLostHours(severity: string): number {
  const hour = new Date().getHours();
  const isPeakHours = (hour >= 11 && hour <= 14) || (hour >= 18 && hour <= 22);
  const base: Record<string, number> = {
    Moderate: 2.5, Severe: 4.5, Extreme: 7.0,
  };
  const h = base[severity] ?? 3;
  return isPeakHours ? h * 1.2 : h;
}

export async function processTriggeredEvent(
  trigger: TriggerResult,
  city: string,
  zones: string[],
  eventTitle: string,
  eventDescription: string,
  source: 'Automated' | 'AdminTriggered' = 'Automated',
  adminData?: { durationHours: number },
): Promise<{ event: any; claimsCreated: number; totalPayoutPaise: number }> {
  const actualValue = adminData?.durationHours ?? trigger.actualValue;

  // 1. Create disruption event
  const event = await DisruptionEvent.create({
    city, zones,
    type: trigger.type,
    severity: trigger.severity === 'None' ? 'Moderate' : trigger.severity,
    title: eventTitle,
    description: eventDescription,
    startTime: new Date(),
    triggerData: {
      parameter: trigger.parameter,
      value: actualValue,
      threshold: trigger.threshold,
    },
    affectedRiders: 0,
    totalPayouts: 0,
    claimsGenerated: 0,
    isActive: true,
    source,
  });

  // 2. Find riders in the city with active policies that cover this trigger
  const activePolicies = await PolicyModel.find({
    status: 'Active',
    coveredDisruptions: trigger.type,
    endDate: { $gte: new Date() },
  }).lean();

  const policyIds = activePolicies.map(p => p._id);
  const riderIds  = activePolicies.map(p => p.riderId);

  // 3. Find riders in affected city
  const affectedRiders = await RiderModel.find({
    _id: { $in: riderIds },
    city,
    isActive: true,
  }).lean();

  let claimsCreated = 0;
  let totalPayoutPaise = 0;

  // 4. Generate claims
  const claimSeqBase = await ClaimModel.countDocuments();
  const claims = [];

  for (let i = 0; i < affectedRiders.length; i++) {
    const rider  = affectedRiders[i];
    const policy = activePolicies.find(p => p.riderId.toString() === rider._id.toString());
    if (!policy) continue;

    const lostHours   = estimateLostHours(trigger.severity);
    const hourlyRate  = rider.avgWeeklyEarnings / (rider.avgDailyHours * 7);
    const rawPayout   = hourlyRate * lostHours;
    const payoutAmount = Math.min(policy.coverageLimit, Math.round(rawPayout / 100) * 100);

    const fraudAssessment = await assessClaimFraud(
      {
        riderId:  rider._id,
        policyId: policy._id,
        triggerType: trigger.type,
        triggerData: {
          timestamp:   new Date(),
          location:    rider.location,
          actualValue: actualValue,
          threshold:   trigger.threshold,
        },
      },
      {
        _id:              rider._id,
        location:         rider.location,
        city:             rider.city,
        experienceMonths: rider.experienceMonths,
        registeredAt:     rider.registeredAt,
      }
    );

    const status = fraudAssessment.recommendation === 'flag_fraud'
      ? 'FraudSuspected'
      : 'AutoInitiated';

    claims.push({
      policyId: policy._id,
      riderId:  rider._id,
      claimNumber: claimNumber(claimSeqBase + i + 1),
      triggerType: trigger.type,
      triggerData: {
        parameter:   trigger.parameter,
        threshold:   trigger.threshold,
        actualValue: actualValue,
        dataSource:  'OpenWeatherMap + IMD',
        timestamp:   new Date(),
        location:    rider.location,
      },
      estimatedLostHours: lostHours,
      payoutAmount,
      status,
      fraudScore:  fraudAssessment.fraudScore,
      fraudFlags:  fraudAssessment.fraudFlags,
    });

    if (status === 'AutoInitiated') {
      claimsCreated++;
      totalPayoutPaise += payoutAmount;
    }
  }

  if (claims.length > 0) {
    await ClaimModel.insertMany(claims);
  }

  // 5. Update event stats
  await DisruptionEvent.findByIdAndUpdate(event._id, {
    affectedRiders: affectedRiders.length,
    totalPayouts:   totalPayoutPaise,
    claimsGenerated: claims.length,
  });

  return { event, claimsCreated, totalPayoutPaise };
}

/** Check triggers for a city and auto-process any that fire */
export async function checkAndProcessTriggers(city: string): Promise<TriggerResult[]> {
  const weather   = await getCurrentWeather(city);
  const triggers  = evaluateAllTriggers(city, weather);
  const cityConf  = getCityConfig(city);
  const allZones  = cityConf?.zones ?? [];

  for (const t of triggers) {
    if (!t.triggered) continue;

    // Don't re-trigger if there's already an active event of this type today
    const existing = await DisruptionEvent.findOne({
      city, type: t.type, isActive: true,
      startTime: { $gte: new Date(Date.now() - 6 * 3_600_000) },
    });
    if (existing) continue;

    const title = `${city} ${t.type.replace(/([A-Z])/g, ' $1').trim()} Alert — ${t.actualValue.toFixed(1)}${TRIGGER_THRESHOLDS[t.type].unit}`;
    const desc  = `Auto-detected: ${t.parameter} = ${t.actualValue.toFixed(2)} (threshold: ${t.threshold}). ${t.description}`;

    await processTriggeredEvent(t, city, allZones, title, desc);
  }

  return triggers;
}
