import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Rider from '../models/Rider';
import Policy from '../models/Policy';
import Claim from '../models/Claim';
import { validate, ObjectIdSchema, CitySchema } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';
import { calculateWeeklyPremium } from '../services/premiumCalculator';

const router = Router();

// ── Zod schemas ───────────────────────────────────────────────────────────────

const RegisterSchema = z.object({
  fullName:           z.string().min(2).max(100).trim(),
  phone:              z.string().regex(/^[6-9]\d{9}$/, 'Must be a valid 10-digit Indian mobile number'),
  email:              z.string().email().optional(),
  city:               CitySchema,
  platform:           z.enum(['Zomato', 'Swiggy', 'Both']),
  operatingZone:      z.string().min(2).max(100),
  operatingPincode:   z.string().regex(/^\d{6}$/, 'Must be a 6-digit pincode'),
  avgWeeklyEarnings:  z.number().int().min(200000).max(600000),
  avgDailyHours:      z.number().min(6).max(14),
  preferredShift:     z.enum(['Morning', 'Afternoon', 'Evening', 'Night', 'Mixed']),
  vehicleType:        z.enum(['Bicycle', 'Scooter', 'Motorcycle']),
  experienceMonths:   z.number().int().min(1).max(60),
  location: z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
  }),
});

const UpdateSchema = RegisterSchema.partial().omit({ phone: true });

// ── POST /api/riders/register ─────────────────────────────────────────────────

router.post('/register', validate(RegisterSchema), async (req: Request, res: Response) => {
  const existing = await Rider.findOne({ phone: req.body.phone });
  if (existing) {
    throw new AppError('A rider with this phone number already exists', 409);
  }

  // Calculate initial risk score
  const { city, avgDailyHours, experienceMonths, vehicleType } = req.body;
  const cityRiskBase: Record<string, number> = {
    Delhi: 80, Mumbai: 65, Chennai: 58, Kolkata: 60,
    Jaipur: 62, Lucknow: 58, Hyderabad: 50, Pune: 44,
    Ahmedabad: 46, Bangalore: 30,
  };
  let riskScore = cityRiskBase[city] ?? 50;
  if (avgDailyHours > 10) riskScore += 5;
  if (vehicleType === 'Bicycle') riskScore += 8;
  if (experienceMonths < 6) riskScore += 10;
  if (experienceMonths > 24) riskScore -= 10;
  riskScore = Math.min(100, Math.max(0, riskScore));

  let riskTier: 'Low' | 'Medium' | 'High' | 'VeryHigh';
  if (riskScore >= 80) riskTier = 'VeryHigh';
  else if (riskScore >= 60) riskTier = 'High';
  else if (riskScore >= 40) riskTier = 'Medium';
  else riskTier = 'Low';

  const rider = await Rider.create({
    ...req.body,
    riskScore,
    riskTier,
    kycVerified: false,
    isActive: true,
  });

  res.status(201).json({
    success: true,
    data: rider,
    message: 'Rider registered successfully',
  });
});

// ── GET /api/riders/:id ───────────────────────────────────────────────────────

router.get('/:id', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid rider ID', 400);

  const rider = await Rider.findById(req.params.id).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  const activePolicy = await Policy.findOne({ riderId: rider._id, status: 'Active' }).lean();

  res.json({ success: true, data: { ...rider, activePolicy } });
});

// ── PUT /api/riders/:id ───────────────────────────────────────────────────────

router.put('/:id', validate(UpdateSchema), async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid rider ID', 400);

  const rider = await Rider.findByIdAndUpdate(
    req.params.id,
    { $set: req.body },
    { new: true, runValidators: true }
  );
  if (!rider) throw new AppError('Rider not found', 404);

  res.json({ success: true, data: rider, message: 'Profile updated' });
});

// ── GET /api/riders/:id/dashboard ────────────────────────────────────────────

router.get('/:id/dashboard', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid rider ID', 400);

  const rider = await Rider.findById(req.params.id).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  const [activePolicy, allPolicies, recentClaims] = await Promise.all([
    Policy.findOne({ riderId: rider._id, status: 'Active' }).lean(),
    Policy.find({ riderId: rider._id }).sort({ createdAt: -1 }).limit(5).lean(),
    Claim.find({ riderId: rider._id }).sort({ createdAt: -1 }).limit(10).lean(),
  ]);

  // Earnings protected = sum of all paid payouts
  const totalEarningsProtected = await Claim.aggregate([
    { $match: { riderId: new mongoose.Types.ObjectId(String(req.params.id)), status: { $in: ['Paid', 'Approved'] } } },
    { $group: { _id: null, total: { $sum: '$payoutAmount' } } },
  ]);

  // Premium plans for this rider
  const plans = (['Basic', 'Standard', 'Premium'] as const).map(plan =>
    calculateWeeklyPremium(rider.city, plan, rider.experienceMonths, recentClaims.filter(c =>
      c.status !== 'Rejected' && c.status !== 'FraudSuspected' &&
      new Date(c.createdAt).getTime() > Date.now() - 28 * 86400000
    ).length)
  );

  // Risk breakdown
  const riskBreakdown = {
    score: rider.riskScore,
    tier: rider.riskTier,
    factors: {
      cityRisk: rider.city,
      vehicleRisk: rider.vehicleType,
      experienceLevel: rider.experienceMonths > 24 ? 'Experienced' : rider.experienceMonths > 12 ? 'Intermediate' : 'New',
      shiftRisk: rider.preferredShift,
    },
  };

  res.json({
    success: true,
    data: {
      rider,
      activePolicy,
      recentPolicies: allPolicies,
      recentClaims,
      stats: {
        totalEarningsProtected: totalEarningsProtected[0]?.total ?? 0,
        totalEarningsProtectedINR: (totalEarningsProtected[0]?.total ?? 0) / 100,
        totalClaims: recentClaims.length,
        activePolicySince: activePolicy?.startDate ?? null,
        activePolicyExpiry: activePolicy?.endDate ?? null,
        avgWeeklyEarningsINR: rider.avgWeeklyEarnings / 100,
      },
      riskBreakdown,
      availablePlans: plans,
    },
  });
});

// ── POST /api/riders/:id/risk-assessment ──────────────────────────────────────

router.post('/:id/risk-assessment', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new AppError('Invalid rider ID', 400);

  const rider = await Rider.findById(req.params.id).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  const fourWeeksAgo = new Date(Date.now() - 28 * 86_400_000);
  const recentClaims = await Claim.countDocuments({
    riderId: rider._id,
    createdAt: { $gte: fourWeeksAgo },
    status: { $nin: ['Rejected', 'FraudSuspected'] },
  });

  // Call ML service
  let mlResult: any = null;
  const mlUrl = process.env.ML_SERVICE_URL ?? 'http://localhost:8000';
  try {
    const mlRes = await fetch(`${mlUrl}/api/predict/risk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        city: rider.city,
        rainfall_mm: 0,
        temperature_c: 28,
        aqi: 100,
        wind_speed_kmh: 15,
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (mlRes.ok) mlResult = await mlRes.json();
  } catch { /* ML service offline — use local calc */ }

  // Update rider risk score
  const cityRiskBase: Record<string, number> = {
    Delhi: 80, Mumbai: 65, Chennai: 58, Kolkata: 60,
    Jaipur: 62, Lucknow: 58, Hyderabad: 50, Pune: 44,
    Ahmedabad: 46, Bangalore: 30,
  };
  let riskScore = cityRiskBase[rider.city] ?? 50;
  if (rider.avgDailyHours > 10) riskScore += 5;
  if (rider.vehicleType === 'Bicycle') riskScore += 8;
  if (rider.experienceMonths < 6) riskScore += 10;
  if (rider.experienceMonths > 24) riskScore -= 10;
  if (recentClaims > 2) riskScore += 10;
  riskScore = Math.min(100, Math.max(0, riskScore));

  let riskTier: 'Low' | 'Medium' | 'High' | 'VeryHigh';
  if (riskScore >= 80) riskTier = 'VeryHigh';
  else if (riskScore >= 60) riskTier = 'High';
  else if (riskScore >= 40) riskTier = 'Medium';
  else riskTier = 'Low';

  await Rider.findByIdAndUpdate(req.params.id, { riskScore, riskTier });

  res.json({
    success: true,
    data: {
      riderId: req.params.id,
      riskScore,
      riskTier,
      recentClaimsCount: recentClaims,
      mlServiceResult: mlResult?.data ?? null,
      assessedAt: new Date(),
    },
  });
});

export default router;
