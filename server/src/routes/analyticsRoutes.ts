import { Router, Request, Response } from 'express';
import mongoose from 'mongoose';
import Rider from '../models/Rider';
import Policy from '../models/Policy';
import Claim from '../models/Claim';
import DisruptionEvent from '../models/DisruptionEvent';
import { AppError } from '../middleware/errorHandler';

const router = Router();

// ── GET /api/analytics/overview ───────────────────────────────────────────────

router.get('/overview', async (_req: Request, res: Response) => {
  const [
    totalRiders, activeRiders,
    totalPolicies, activePolicies,
    claimStats, revenueStats, eventStats,
  ] = await Promise.all([
    Rider.countDocuments(),
    Rider.countDocuments({ isActive: true }),
    Policy.countDocuments(),
    Policy.countDocuments({ status: 'Active' }),
    Claim.aggregate([
      {
        $group: {
          _id: null,
          totalClaims:      { $sum: 1 },
          totalPayoutsPaise: { $sum: { $cond: [{ $in: ['$status', ['Paid', 'Approved']] }, '$payoutAmount', 0] } },
          paidCount:         { $sum: { $cond: [{ $eq: ['$status', 'Paid'] }, 1, 0] } },
          rejectedCount:     { $sum: { $cond: [{ $eq: ['$status', 'Rejected'] }, 1, 0] } },
          fraudCount:        { $sum: { $cond: [{ $eq: ['$status', 'FraudSuspected'] }, 1, 0] } },
          avgFraudScore:     { $avg: '$fraudScore' },
        },
      },
    ]),
    Policy.aggregate([
      { $match: { status: { $in: ['Active', 'Expired'] } } },
      { $group: { _id: null, totalRevenuePaise: { $sum: '$weeklyPremium' } } },
    ]),
    DisruptionEvent.aggregate([
      { $group: { _id: null, total: { $sum: 1 }, active: { $sum: { $cond: ['$isActive', 1, 0] } } } },
    ]),
  ]);

  const cs = claimStats[0] ?? { totalClaims: 0, totalPayoutsPaise: 0, paidCount: 0, rejectedCount: 0, fraudCount: 0, avgFraudScore: 0 };
  const rs = revenueStats[0] ?? { totalRevenuePaise: 0 };
  const es = eventStats[0] ?? { total: 0, active: 0 };

  const lossRatio = rs.totalRevenuePaise > 0
    ? ((cs.totalPayoutsPaise / rs.totalRevenuePaise) * 100).toFixed(1)
    : '0';

  res.json({
    success: true,
    data: {
      riders: {
        total:  totalRiders,
        active: activeRiders,
        kycVerified: await Rider.countDocuments({ kycVerified: true }),
      },
      policies: {
        total:    totalPolicies,
        active:   activePolicies,
        renewalRate: totalPolicies > 0
          ? ((activePolicies / totalPolicies) * 100).toFixed(1) + '%'
          : '0%',
      },
      claims: {
        total:    cs.totalClaims,
        paid:     cs.paidCount,
        rejected: cs.rejectedCount,
        fraud:    cs.fraudCount,
        approvalRate: cs.totalClaims > 0
          ? ((cs.paidCount / cs.totalClaims) * 100).toFixed(1) + '%'
          : '0%',
        avgFraudScore: Math.round(cs.avgFraudScore ?? 0),
      },
      financials: {
        totalRevenuePaise:  rs.totalRevenuePaise,
        totalRevenueINR:    rs.totalRevenuePaise / 100,
        totalPayoutsPaise:  cs.totalPayoutsPaise,
        totalPayoutsINR:    cs.totalPayoutsPaise / 100,
        lossRatio:          `${lossRatio}%`,
        netProfitINR:       (rs.totalRevenuePaise - cs.totalPayoutsPaise) / 100,
      },
      disruptions: {
        total:  es.total,
        active: es.active,
      },
      generatedAt: new Date(),
    },
  });
});

// ── GET /api/analytics/city/:city ─────────────────────────────────────────────

router.get('/city/:city', async (req: Request, res: Response) => {
  const city = req.params.city;

  const [riders, activePolicies, cityClaimStats, events] = await Promise.all([
    Rider.aggregate([
      { $match: { city } },
      {
        $group: {
          _id: null,
          total:    { $sum: 1 },
          avgRisk:  { $avg: '$riskScore' },
          avgEarnings: { $avg: '$avgWeeklyEarnings' },
          byPlatform: { $push: '$platform' },
          byVehicle:  { $push: '$vehicleType' },
          byTier:     { $push: '$riskTier' },
        },
      },
    ]),
    Policy.countDocuments({ status: 'Active' }),
    Claim.aggregate([
      {
        $lookup: {
          from: 'riders',
          localField: 'riderId',
          foreignField: '_id',
          as: 'rider',
        },
      },
      { $unwind: '$rider' },
      { $match: { 'rider.city': city } },
      {
        $group: {
          _id: '$triggerType',
          count:       { $sum: 1 },
          totalPayout: { $sum: '$payoutAmount' },
        },
      },
      { $sort: { count: -1 } },
    ]),
    DisruptionEvent.find({ city }).sort({ startTime: -1 }).limit(5).lean(),
  ]);

  const riderStats = riders[0];
  const countBy = (arr: string[]) =>
    arr.reduce((acc: Record<string, number>, v) => { acc[v] = (acc[v] ?? 0) + 1; return acc; }, {});

  res.json({
    success: true,
    data: {
      city,
      riders: riderStats ? {
        total:         riderStats.total,
        avgRiskScore:  Math.round(riderStats.avgRisk),
        avgWeeklyEarningsINR: Math.round(riderStats.avgEarnings / 100),
        byPlatform:    countBy(riderStats.byPlatform),
        byVehicle:     countBy(riderStats.byVehicle),
        byRiskTier:    countBy(riderStats.byTier),
      } : { total: 0 },
      activePolicies,
      claimsByTrigger: cityClaimStats.map((c: any) => ({
        triggerType:    c._id,
        count:          c.count,
        totalPayoutINR: c.totalPayout / 100,
      })),
      recentEvents: events,
    },
  });
});

// ── GET /api/analytics/claims-trend ───────────────────────────────────────────

router.get('/claims-trend', async (_req: Request, res: Response) => {
  const weeks = 8;
  const result = [];

  for (let i = weeks - 1; i >= 0; i--) {
    const weekStart = new Date(Date.now() - (i + 1) * 7 * 86_400_000);
    const weekEnd   = new Date(Date.now() - i * 7 * 86_400_000);

    const [stats] = await Claim.aggregate([
      { $match: { createdAt: { $gte: weekStart, $lt: weekEnd } } },
      {
        $group: {
          _id:          null,
          totalClaims:  { $sum: 1 },
          paidClaims:   { $sum: { $cond: [{ $in: ['$status', ['Paid', 'Approved']] }, 1, 0] } },
          totalPayout:  { $sum: '$payoutAmount' },
          fraudClaims:  { $sum: { $cond: [{ $eq: ['$status', 'FraudSuspected'] }, 1, 0] } },
        },
      },
    ]);

    result.push({
      weekLabel:    `W${weeks - i} (${weekStart.toISOString().slice(5, 10)})`,
      weekStart:    weekStart.toISOString().slice(0, 10),
      weekEnd:      weekEnd.toISOString().slice(0, 10),
      totalClaims:  stats?.totalClaims  ?? 0,
      paidClaims:   stats?.paidClaims   ?? 0,
      totalPayoutINR: (stats?.totalPayout ?? 0) / 100,
      fraudClaims:  stats?.fraudClaims  ?? 0,
    });
  }

  res.json({ success: true, data: result });
});

// ── GET /api/analytics/risk-distribution ──────────────────────────────────────

router.get('/risk-distribution', async (_req: Request, res: Response) => {
  const [tierDist, cityDist] = await Promise.all([
    Rider.aggregate([
      { $group: { _id: '$riskTier', count: { $sum: 1 }, avgScore: { $avg: '$riskScore' } } },
      { $sort: { avgScore: 1 } },
    ]),
    Rider.aggregate([
      { $group: { _id: '$city', count: { $sum: 1 }, avgRisk: { $avg: '$riskScore' } } },
      { $sort: { avgRisk: -1 } },
    ]),
  ]);

  const total = tierDist.reduce((s: number, t: any) => s + t.count, 0);

  res.json({
    success: true,
    data: {
      byTier: tierDist.map((t: any) => ({
        tier:       t._id,
        count:      t.count,
        percentage: total > 0 ? ((t.count / total) * 100).toFixed(1) : '0',
        avgScore:   Math.round(t.avgScore),
      })),
      byCity: cityDist.map((c: any) => ({
        city:        c._id,
        riderCount:  c.count,
        avgRiskScore: Math.round(c.avgRisk),
      })),
      totalRiders: total,
    },
  });
});

// ── GET /api/analytics/trigger-frequency ──────────────────────────────────────

router.get('/trigger-frequency', async (_req: Request, res: Response) => {
  const [claimFreq, eventFreq] = await Promise.all([
    Claim.aggregate([
      { $group: { _id: '$triggerType', count: { $sum: 1 }, totalPayout: { $sum: '$payoutAmount' }, avgFraud: { $avg: '$fraudScore' } } },
      { $sort: { count: -1 } },
    ]),
    DisruptionEvent.aggregate([
      { $group: { _id: '$type', count: { $sum: 1 }, avgAffected: { $avg: '$affectedRiders' } } },
      { $sort: { count: -1 } },
    ]),
  ]);

  const totalClaims = claimFreq.reduce((s: number, c: any) => s + c.count, 0);

  res.json({
    success: true,
    data: {
      byClaims: claimFreq.map((c: any) => ({
        triggerType:     c._id,
        claimCount:      c.count,
        share:           totalClaims > 0 ? ((c.count / totalClaims) * 100).toFixed(1) + '%' : '0%',
        totalPayoutINR:  c.totalPayout / 100,
        avgPayoutINR:    c.count > 0 ? Math.round(c.totalPayout / c.count / 100) : 0,
        avgFraudScore:   Math.round(c.avgFraud ?? 0),
      })),
      byEvents: eventFreq.map((e: any) => ({
        triggerType:    e._id,
        eventCount:     e.count,
        avgAffectedRiders: Math.round(e.avgAffected ?? 0),
      })),
    },
  });
});

// ── GET /api/analytics/revenue ────────────────────────────────────────────────

router.get('/revenue', async (_req: Request, res: Response) => {
  const weeks = 8;
  const result = [];

  for (let i = weeks - 1; i >= 0; i--) {
    const weekStart = new Date(Date.now() - (i + 1) * 7 * 86_400_000);
    const weekEnd   = new Date(Date.now() - i * 7 * 86_400_000);

    const [premiums, payouts] = await Promise.all([
      Policy.aggregate([
        { $match: { createdAt: { $gte: weekStart, $lt: weekEnd } } },
        { $group: { _id: null, total: { $sum: '$weeklyPremium' }, count: { $sum: 1 } } },
      ]),
      Claim.aggregate([
        { $match: { status: { $in: ['Paid', 'Approved'] }, paidAt: { $gte: weekStart, $lt: weekEnd } } },
        { $group: { _id: null, total: { $sum: '$payoutAmount' }, count: { $sum: 1 } } },
      ]),
    ]);

    const premiumTotal = premiums[0]?.total ?? 0;
    const payoutTotal  = payouts[0]?.total  ?? 0;

    result.push({
      weekLabel:      `W${weeks - i} (${weekStart.toISOString().slice(5, 10)})`,
      weekStart:      weekStart.toISOString().slice(0, 10),
      premiumINR:     premiumTotal / 100,
      payoutINR:      payoutTotal  / 100,
      netINR:         (premiumTotal - payoutTotal) / 100,
      lossRatio:      premiumTotal > 0
        ? ((payoutTotal / premiumTotal) * 100).toFixed(1)
        : '0',
      newPolicies:    premiums[0]?.count ?? 0,
      claimsPaid:     payouts[0]?.count  ?? 0,
    });
  }

  const totals = result.reduce((acc, w) => ({
    premiumINR: acc.premiumINR + w.premiumINR,
    payoutINR:  acc.payoutINR  + w.payoutINR,
    netINR:     acc.netINR     + w.netINR,
  }), { premiumINR: 0, payoutINR: 0, netINR: 0 });

  res.json({
    success: true,
    data: {
      weekly: result,
      totals: {
        ...totals,
        overallLossRatio: totals.premiumINR > 0
          ? ((totals.payoutINR / totals.premiumINR) * 100).toFixed(1) + '%'
          : '0%',
      },
    },
  });
});

export default router;
