import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Policy from '../models/Policy';
import Rider from '../models/Rider';
import Claim from '../models/Claim';
import { validate, CitySchema } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';
import { calculateWeeklyPremium, getAllPlansForCity, PLAN_CONFIG, PlanType } from '../services/premiumCalculator';

const router = Router();

// ── Helpers ───────────────────────────────────────────────────────────────────

function policyNumber(): string {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const rand = Math.floor(10000 + Math.random() * 90000);
  return `RC-${d}-${rand}`;
}

// ── Zod schemas ───────────────────────────────────────────────────────────────

const CreatePolicySchema = z.object({
  riderId:    z.string().regex(/^[0-9a-fA-F]{24}$/, 'Invalid rider ID'),
  planType:   z.enum(['Basic', 'Standard', 'Premium']),
  autoRenew:  z.boolean().default(true),
});

const CalcPremiumSchema = z.object({
  city:              CitySchema,
  planType:          z.enum(['Basic', 'Standard', 'Premium']),
  experienceMonths:  z.number().int().min(1).max(60),
  recentClaimsCount: z.number().int().min(0).default(0),
});

// ── GET /api/policies/plans ───────────────────────────────────────────────────
// NOTE: must come before /:id to avoid route conflict

router.get('/plans', async (req: Request, res: Response) => {
  const city = req.query.city as string;
  const experienceMonths = parseInt(req.query.experienceMonths as string) || 12;

  if (!city) {
    // Return plans for all cities
    const allCities = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow'];
    const result = allCities.reduce<Record<string, any>>((acc, c) => {
      acc[c] = getAllPlansForCity(c, experienceMonths);
      return acc;
    }, {});
    return res.json({ success: true, data: result });
  }

  const plans = getAllPlansForCity(city, experienceMonths);
  res.json({ success: true, data: plans });
});

// ── POST /api/policies/calculate-premium ─────────────────────────────────────

router.post('/calculate-premium', validate(CalcPremiumSchema), async (req: Request, res: Response) => {
  const { city, planType, experienceMonths, recentClaimsCount } = req.body;

  // Try ML service first
  let mlPremium: number | null = null;
  const mlUrl = process.env.ML_SERVICE_URL ?? 'http://localhost:8000';
  try {
    const mlRes = await fetch(`${mlUrl}/api/predict/premium`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ city: city.toLowerCase(), monthly_income_inr: 16000, riding_days_per_week: 6 }),
      signal: AbortSignal.timeout(4000),
    });
    if (mlRes.ok) {
      const mlData = await mlRes.json() as any;
      mlPremium = mlData?.data?.premium_paise ?? null;
    }
  } catch { /* ML offline */ }

  const breakdown = calculateWeeklyPremium(city, planType as PlanType, experienceMonths, recentClaimsCount);

  res.json({
    success: true,
    data: {
      ...breakdown,
      mlServicePremiumPaise: mlPremium,
      mlServicePremiumINR:   mlPremium ? mlPremium / 100 : null,
      source: mlPremium ? 'ml_service_fallback_local' : 'local_calculator',
    },
  });
});

// ── POST /api/policies/create ─────────────────────────────────────────────────

router.post('/create', validate(CreatePolicySchema), async (req: Request, res: Response) => {
  const { riderId, planType, autoRenew } = req.body;

  const rider = await Rider.findById(riderId).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  // No duplicate active policy
  const existingActive = await Policy.findOne({ riderId, status: 'Active' });
  if (existingActive) {
    throw new AppError('Rider already has an active policy. Cancel or wait for expiry first.', 409);
  }

  const fourWeeksAgo = new Date(Date.now() - 28 * 86_400_000);
  const recentClaims = await Claim.countDocuments({
    riderId,
    createdAt: { $gte: fourWeeksAgo },
    status: { $nin: ['Rejected', 'FraudSuspected'] },
  });

  const breakdown = calculateWeeklyPremium(rider.city, planType as PlanType, rider.experienceMonths, recentClaims);
  const startDate  = new Date();
  const endDate    = new Date(startDate.getTime() + 7 * 86_400_000);

  const policy = await Policy.create({
    riderId,
    planType,
    weeklyPremium:       breakdown.finalPremiumPaise,
    coverageLimit:       PLAN_CONFIG[planType as PlanType].coverageLimit,
    coveredDisruptions:  PLAN_CONFIG[planType as PlanType].disruptions,
    status:              'Active',
    startDate, endDate,
    autoRenew,
    policyNumber:        policyNumber(),
    renewalCount:        0,
  });

  res.status(201).json({
    success: true,
    data: { policy, premiumBreakdown: breakdown },
    message: `${planType} policy created. Premium: ₹${breakdown.finalPremiumINR}/week`,
  });
});

// ── GET /api/policies/rider/:riderId ──────────────────────────────────────────

router.get('/rider/:riderId', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.riderId)) throw new AppError('Invalid rider ID', 400);

  const page  = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(50, parseInt(req.query.limit as string) || 10);
  const skip  = (page - 1) * limit;

  const filter: any = { riderId: req.params.riderId };
  if (req.query.status) filter.status = req.query.status;

  const [policies, total] = await Promise.all([
    Policy.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    Policy.countDocuments(filter),
  ]);

  res.json({
    success: true,
    data: policies,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  });
});

// ── GET /api/policies/:id ─────────────────────────────────────────────────────

router.get('/:id', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid policy ID', 400);

  const policy = await Policy.findById(req.params.id).populate('riderId').lean();
  if (!policy) throw new AppError('Policy not found', 404);

  const claimsCount = await Claim.countDocuments({ policyId: req.params.id });

  res.json({ success: true, data: { ...policy, claimsCount } });
});

// ── PUT /api/policies/:id/cancel ──────────────────────────────────────────────

router.put('/:id/cancel', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid policy ID', 400);

  const policy = await Policy.findById(req.params.id);
  if (!policy) throw new AppError('Policy not found', 404);
  if (policy.status === 'Cancelled') throw new AppError('Policy is already cancelled', 400);
  if (policy.status === 'Expired')   throw new AppError('Cannot cancel an expired policy', 400);

  policy.status    = 'Cancelled';
  policy.autoRenew = false;
  await policy.save();

  res.json({ success: true, data: policy, message: 'Policy cancelled successfully' });
});

// ── PUT /api/policies/:id/renew ───────────────────────────────────────────────

router.put('/:id/renew', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid policy ID', 400);

  const policy = await Policy.findById(req.params.id);
  if (!policy) throw new AppError('Policy not found', 404);
  if (policy.status === 'Cancelled') throw new AppError('Cannot renew a cancelled policy', 400);

  const rider = await Rider.findById(policy.riderId).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  const fourWeeksAgo = new Date(Date.now() - 28 * 86_400_000);
  const recentClaims = await Claim.countDocuments({
    riderId: policy.riderId,
    createdAt: { $gte: fourWeeksAgo },
    status: { $nin: ['Rejected', 'FraudSuspected'] },
  });

  const breakdown = calculateWeeklyPremium(
    rider.city, policy.planType as PlanType, rider.experienceMonths, recentClaims
  );

  const now    = new Date();
  const newEnd = new Date(now.getTime() + 7 * 86_400_000);

  policy.weeklyPremium = breakdown.finalPremiumPaise;
  policy.startDate     = now;
  policy.endDate       = newEnd;
  policy.status        = 'Active';
  policy.renewalCount  = (policy.renewalCount ?? 0) + 1;
  await policy.save();

  res.json({
    success: true,
    data: { policy, premiumBreakdown: breakdown },
    message: `Policy renewed for 7 days. New premium: ₹${breakdown.finalPremiumINR}/week`,
  });
});

// ── POST /api/policies — alias for /api/policies/create ──────────────────────
// Flutter calls POST /policies; keep /create for backwards compat

router.post('/', validate(CreatePolicySchema), async (req: Request, res: Response) => {
  // Forward to the same handler logic by reusing internal function
  // Re-use the same logic as /create inline
  const { riderId, planType, autoRenew } = req.body;

  const rider = await Rider.findById(riderId).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  const existingActive = await Policy.findOne({ riderId, status: 'Active' });
  if (existingActive) throw new AppError('Rider already has an active policy', 409);

  const breakdown  = calculateWeeklyPremium(rider.city, planType as PlanType, rider.experienceMonths, 0);
  const planConfig = PLAN_CONFIG[planType as PlanType];

  const startDate = new Date();
  const endDate   = new Date(startDate.getTime() + 7 * 86_400_000);

  const policy = await Policy.create({
    riderId,
    planType,
    weeklyPremium:       breakdown.finalPremiumPaise,
    coverageLimit:       planConfig.coverageLimit,
    coveredDisruptions:  planConfig.disruptions,
    status:              'PendingPayment',
    startDate,
    endDate,
    autoRenew:           autoRenew ?? true,
    policyNumber:        policyNumber(),
    renewalCount:        0,
  });

  res.status(201).json({
    success: true,
    data:    policy,
    message: `${planType} policy created. Complete payment to activate.`,
  });
});

export default router;
