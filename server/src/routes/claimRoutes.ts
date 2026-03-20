import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Claim from '../models/Claim';
import Policy from '../models/Policy';
import Rider from '../models/Rider';
import DisruptionEvent from '../models/DisruptionEvent';
import { validate } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';
import { assessClaimFraud } from '../services/fraudDetector';

const router = Router();

// ── Zod schemas ───────────────────────────────────────────────────────────────

const InitiateClaimSchema = z.object({
  policyId:    z.string().regex(/^[0-9a-fA-F]{24}$/),
  riderId:     z.string().regex(/^[0-9a-fA-F]{24}$/),
  triggerType: z.enum(['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption']),
  triggerData: z.object({
    parameter:   z.string(),
    threshold:   z.number(),
    actualValue: z.number(),
    dataSource:  z.string(),
    timestamp:   z.string().datetime().transform(s => new Date(s)),
    location:    z.object({ lat: z.number(), lng: z.number() }),
  }),
  estimatedLostHours: z.number().min(0).max(24),
  payoutAmount:       z.number().int().min(0),
});

const RejectSchema = z.object({
  reason: z.string().min(5).max(500),
});

function claimNumber(seq: number): string {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return `CLM-${d}-${String(seq).padStart(5, '0')}`;
}

// ── GET /api/claims (admin: all claims) ──────────────────────────────────────

router.get('/', async (req: Request, res: Response) => {
  const page  = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(50, parseInt(req.query.limit as string) || 10);
  const skip  = (page - 1) * limit;
  const filter: any = {};
  if (req.query.status) filter.status = req.query.status;

  const [claims, total] = await Promise.all([
    Claim.find(filter)
      .populate('riderId', 'fullName city operatingZone')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Claim.countDocuments(filter),
  ]);

  res.json({
    success: true,
    claims,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  });
});

// ── GET /api/claims/stats ─────────────────────────────────────────────────────
// NOTE: must be before /:id

router.get('/stats', async (_req: Request, res: Response) => {
  const [statusAgg, triggerAgg, payoutAgg] = await Promise.all([
    Claim.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
    Claim.aggregate([
      { $group: { _id: '$triggerType', count: { $sum: 1 }, totalPayout: { $sum: '$payoutAmount' } } },
      { $sort: { count: -1 } },
    ]),
    Claim.aggregate([
      { $match: { status: { $in: ['Paid', 'Approved'] } } },
      { $group: { _id: null, total: { $sum: '$payoutAmount' }, count: { $sum: 1 }, avg: { $avg: '$payoutAmount' } } },
    ]),
  ]);

  const statusMap = statusAgg.reduce((acc: any, s: any) => {
    acc[s._id] = s.count; return acc;
  }, {});
  const payoutStats = payoutAgg[0] ?? { total: 0, count: 0, avg: 0 };

  res.json({
    success: true,
    data: {
      byStatus: {
        paid:            statusMap.Paid            ?? 0,
        approved:        statusMap.Approved        ?? 0,
        autoInitiated:   statusMap.AutoInitiated   ?? 0,
        underReview:     statusMap.UnderReview     ?? 0,
        rejected:        statusMap.Rejected        ?? 0,
        fraudSuspected:  statusMap.FraudSuspected  ?? 0,
        total: Object.values(statusMap).reduce((a: any, b: any) => a + b, 0),
      },
      byTrigger: triggerAgg.map((t: any) => ({
        triggerType:     t._id,
        count:           t.count,
        totalPayoutPaise: t.totalPayout,
        totalPayoutINR:  t.totalPayout / 100,
      })),
      payouts: {
        totalPaidPaise:  payoutStats.total,
        totalPaidINR:    payoutStats.total / 100,
        totalPaidCount:  payoutStats.count,
        avgPayoutPaise:  Math.round(payoutStats.avg),
        avgPayoutINR:    Math.round(payoutStats.avg) / 100,
      },
    },
  });
});

// ── GET /api/claims/event/:eventId ────────────────────────────────────────────

router.get('/event/:eventId', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.eventId)) throw new AppError('Invalid event ID', 400);

  // Find the event to get its time range and city
  const event = await DisruptionEvent.findById(req.params.eventId).lean();
  if (!event) throw new AppError('Disruption event not found', 404);

  const claims = await Claim.find({
    triggerType: event.type,
    'triggerData.timestamp': { $gte: event.startTime, ...(event.endTime ? { $lte: event.endTime } : {}) },
  })
    .populate('riderId', 'fullName city operatingZone vehicleType')
    .sort({ createdAt: -1 })
    .lean();

  const totalPayout = claims.reduce((sum, c) => sum + c.payoutAmount, 0);

  res.json({
    success: true,
    data: {
      event,
      claims,
      summary: {
        totalClaims:     claims.length,
        totalPayoutPaise: totalPayout,
        totalPayoutINR:  totalPayout / 100,
        paidCount:       claims.filter(c => c.status === 'Paid').length,
        pendingCount:    claims.filter(c => ['AutoInitiated', 'UnderReview'].includes(c.status)).length,
      },
    },
  });
});

// ── POST /api/claims/initiate ─────────────────────────────────────────────────

router.post('/initiate', validate(InitiateClaimSchema), async (req: Request, res: Response) => {
  const { policyId, riderId, triggerType, triggerData, estimatedLostHours, payoutAmount } = req.body;

  const [policy, rider] = await Promise.all([
    Policy.findById(policyId).lean(),
    Rider.findById(riderId).lean(),
  ]);
  if (!policy) throw new AppError('Policy not found', 404);
  if (!rider)  throw new AppError('Rider not found', 404);
  if (policy.status !== 'Active') throw new AppError('Policy is not active', 400);
  if (!policy.coveredDisruptions.includes(triggerType)) {
    throw new AppError(`Trigger type ${triggerType} is not covered under ${policy.planType} plan`, 400);
  }

  const capped = Math.min(payoutAmount, policy.coverageLimit);
  const fraud  = await assessClaimFraud(
    { riderId: rider._id, policyId: policy._id, triggerType, triggerData },
    { _id: rider._id, location: rider.location, city: rider.city, experienceMonths: rider.experienceMonths, registeredAt: rider.registeredAt }
  );

  const status = fraud.recommendation === 'flag_fraud' ? 'FraudSuspected' : 'AutoInitiated';
  const total  = await Claim.countDocuments();

  const claim = await Claim.create({
    policyId, riderId, triggerType, triggerData,
    claimNumber: claimNumber(total + 1),
    estimatedLostHours,
    payoutAmount: capped,
    status,
    fraudScore:  fraud.fraudScore,
    fraudFlags:  fraud.fraudFlags,
  });

  res.status(201).json({
    success: true,
    data: { claim, fraudAssessment: fraud },
    message: status === 'FraudSuspected'
      ? 'Claim flagged for fraud review'
      : 'Claim auto-initiated successfully',
  });
});

// ── GET /api/claims/rider/:riderId ────────────────────────────────────────────

router.get('/rider/:riderId', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.riderId)) throw new AppError('Invalid rider ID', 400);

  const page   = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit  = Math.min(50, parseInt(req.query.limit as string) || 10);
  const skip   = (page - 1) * limit;
  const filter: any = { riderId: req.params.riderId };
  if (req.query.status) filter.status = req.query.status;

  const [claims, total] = await Promise.all([
    Claim.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    Claim.countDocuments(filter),
  ]);

  res.json({
    success: true,
    data: claims,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  });
});

// ── GET /api/claims/:id ───────────────────────────────────────────────────────

router.get('/:id', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid claim ID', 400);

  const claim = await Claim.findById(req.params.id)
    .populate('riderId', 'fullName phone city operatingZone vehicleType riskTier')
    .populate('policyId', 'planType weeklyPremium coverageLimit policyNumber')
    .lean();
  if (!claim) throw new AppError('Claim not found', 404);

  const overagePercent = claim.triggerData.actualValue > 0
    ? (((claim.triggerData.actualValue - claim.triggerData.threshold) / claim.triggerData.threshold) * 100).toFixed(1)
    : '0';

  res.json({
    success: true,
    data: { ...claim, overagePercent: `${overagePercent}%` },
  });
});

// ── PUT /api/claims/:id/approve ───────────────────────────────────────────────

router.put('/:id/approve', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid claim ID', 400);

  const claim = await Claim.findById(req.params.id);
  if (!claim) throw new AppError('Claim not found', 404);
  if (claim.status === 'Paid')     throw new AppError('Claim already paid', 400);
  if (claim.status === 'Rejected') throw new AppError('Cannot approve a rejected claim', 400);

  const now = new Date();
  claim.status      = 'Paid';
  claim.processedAt = now;
  claim.paidAt      = now;
  await claim.save();

  res.json({
    success: true,
    data: claim,
    message: `Claim ${claim.claimNumber} approved. ₹${claim.payoutAmount / 100} payout processed.`,
  });
});

// ── PUT /api/claims/:id/reject ────────────────────────────────────────────────

router.put('/:id/reject', validate(RejectSchema), async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid claim ID', 400);

  const claim = await Claim.findById(req.params.id);
  if (!claim) throw new AppError('Claim not found', 404);
  if (claim.status === 'Paid')     throw new AppError('Cannot reject an already-paid claim', 400);
  if (claim.status === 'Rejected') throw new AppError('Claim already rejected', 400);

  claim.status      = 'Rejected';
  claim.payoutAmount = 0;
  claim.processedAt = new Date();
  claim.fraudFlags  = [...claim.fraudFlags, `rejected_reason:${req.body.reason}`];
  await claim.save();

  res.json({
    success: true,
    data: claim,
    message: `Claim ${claim.claimNumber} rejected. Reason: ${req.body.reason}`,
  });
});

export default router;
