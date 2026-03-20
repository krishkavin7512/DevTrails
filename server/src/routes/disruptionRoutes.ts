import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import DisruptionEvent from '../models/DisruptionEvent';
import Claim from '../models/Claim';
import { validate, CitySchema } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';
import { processTriggeredEvent, TRIGGER_THRESHOLDS, TriggerType } from '../services/triggerEngine';
import { getCityConfig } from '../config/cities';

const router = Router();

const AdminTriggerSchema = z.object({
  city:        CitySchema,
  zones:       z.array(z.string()).min(1),
  type:        z.enum(['SocialDisruption', 'HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding']),
  title:       z.string().min(5).max(200),
  description: z.string().min(10).max(1000),
  durationHours: z.number().min(1).max(72),
  severity:    z.enum(['Moderate', 'Severe', 'Extreme']),
  triggerValue: z.number(),
});

// ── GET /api/disruptions/active ───────────────────────────────────────────────

router.get('/active', async (_req: Request, res: Response) => {
  const events = await DisruptionEvent.find({ isActive: true })
    .sort({ startTime: -1 })
    .lean();

  const withAge = events.map(e => ({
    ...e,
    activeForMinutes: Math.floor((Date.now() - e.startTime.getTime()) / 60_000),
  }));

  res.json({
    success: true,
    data: {
      count:  withAge.length,
      events: withAge,
    },
  });
});

// ── GET /api/disruptions/active/:city ─────────────────────────────────────────

router.get('/active/:city', async (req: Request, res: Response) => {
  const city = String(req.params.city);
  const events = await DisruptionEvent.find({ city, isActive: true })
    .sort({ startTime: -1 })
    .lean();

  const cityConf = getCityConfig(city);

  res.json({
    success: true,
    data: {
      city,
      cityRiskProfile: cityConf ? {
        baseRiskScore:      cityConf.baseRiskScore,
        topRisks:           cityConf.topRisks,
        premiumMultiplier:  cityConf.premiumMultiplier,
        floodProneZones:    cityConf.floodProneZones,
      } : null,
      activeEvents: events,
      count: events.length,
    },
  });
});

// ── GET /api/disruptions/history ──────────────────────────────────────────────

router.get('/history', async (req: Request, res: Response) => {
  const page   = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit  = Math.min(50, parseInt(req.query.limit as string) || 20);
  const skip   = (page - 1) * limit;

  const filter: any = { isActive: false };
  if (req.query.city)    filter.city = req.query.city;
  if (req.query.type)    filter.type = req.query.type;
  if (req.query.from || req.query.to) {
    filter.startTime = {};
    if (req.query.from) filter.startTime.$gte = new Date(req.query.from as string);
    if (req.query.to)   filter.startTime.$lte = new Date(req.query.to as string);
  }

  const [events, total] = await Promise.all([
    DisruptionEvent.find(filter).sort({ startTime: -1 }).skip(skip).limit(limit).lean(),
    DisruptionEvent.countDocuments(filter),
  ]);

  const enriched = events.map(e => ({
    ...e,
    durationMinutes: e.endTime
      ? Math.floor((e.endTime.getTime() - e.startTime.getTime()) / 60_000)
      : null,
    totalPayoutsINR: e.totalPayouts / 100,
  }));

  res.json({
    success: true,
    data: enriched,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  });
});

// ── POST /api/disruptions/trigger ─────────────────────────────────────────────

router.post('/trigger', validate(AdminTriggerSchema), async (req: Request, res: Response) => {
  const {
    city, zones, type, title, description,
    durationHours, severity, triggerValue,
  } = req.body;

  const threshold = TRIGGER_THRESHOLDS[type as TriggerType].threshold;
  const triggerResult = {
    type: type as TriggerType,
    triggered: true,
    actualValue: triggerValue,
    threshold,
    severity: severity as 'Moderate' | 'Severe' | 'Extreme',
    parameter: TRIGGER_THRESHOLDS[type as TriggerType].parameter,
    description: TRIGGER_THRESHOLDS[type as TriggerType].description,
  };

  const { event, claimsCreated, totalPayoutPaise } = await processTriggeredEvent(
    triggerResult, city, zones, title, description,
    'AdminTriggered', { durationHours }
  );

  res.status(201).json({
    success: true,
    data: {
      event,
      claimsCreated,
      totalPayoutPaise,
      totalPayoutINR: totalPayoutPaise / 100,
    },
    message: `Disruption event created. ${claimsCreated} claims auto-initiated. Total payout: ₹${totalPayoutPaise / 100}`,
  });
});

// ── GET /api/disruptions/:id ──────────────────────────────────────────────────

router.get('/:id', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid event ID', 400);

  const event = await DisruptionEvent.findById(req.params.id).lean();
  if (!event) throw new AppError('Disruption event not found', 404);

  const relatedClaims = await Claim.find({
    triggerType: event.type,
    'triggerData.timestamp': {
      $gte: event.startTime,
      ...(event.endTime ? { $lte: event.endTime } : {}),
    },
  })
    .select('claimNumber status payoutAmount triggerData.actualValue createdAt')
    .sort({ createdAt: -1 })
    .lean();

  res.json({
    success: true,
    data: {
      ...event,
      durationMinutes: event.endTime
        ? Math.floor((event.endTime.getTime() - event.startTime.getTime()) / 60_000)
        : null,
      totalPayoutsINR: event.totalPayouts / 100,
      relatedClaims,
      claimBreakdown: {
        paid:         relatedClaims.filter(c => c.status === 'Paid').length,
        approved:     relatedClaims.filter(c => c.status === 'Approved').length,
        pending:      relatedClaims.filter(c => ['AutoInitiated', 'UnderReview'].includes(c.status)).length,
        rejected:     relatedClaims.filter(c => c.status === 'Rejected').length,
        fraudFlagged: relatedClaims.filter(c => c.status === 'FraudSuspected').length,
      },
    },
  });
});

export default router;
