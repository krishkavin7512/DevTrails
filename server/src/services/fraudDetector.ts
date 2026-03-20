import mongoose from 'mongoose';
import ClaimModel from '../models/Claim';

export interface FraudAssessment {
  fraudScore: number;       // 0-100
  fraudFlags: string[];
  recommendation: 'auto_approve' | 'manual_review' | 'flag_fraud';
}

interface ClaimInput {
  riderId: mongoose.Types.ObjectId | string;
  policyId: mongoose.Types.ObjectId | string;
  triggerType: string;
  triggerData: {
    timestamp: Date;
    location: { lat: number; lng: number };
    actualValue: number;
    threshold: number;
  };
}

interface RiderInput {
  _id: mongoose.Types.ObjectId | string;
  location: { lat: number; lng: number };
  city: string;
  experienceMonths: number;
  registeredAt: Date;
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export async function assessClaimFraud(
  claim: ClaimInput,
  rider: RiderInput,
): Promise<FraudAssessment> {
  let fraudScore = 0;
  const flags: string[] = [];

  const riderId = typeof claim.riderId === 'string'
    ? new mongoose.Types.ObjectId(claim.riderId)
    : claim.riderId;

  // ── Rule 1: Duplicate claim — same rider + same trigger type in last 14 days ──
  const fourteenDaysAgo = new Date(Date.now() - 14 * 86_400_000);
  const recentSameTrigger = await ClaimModel.countDocuments({
    riderId,
    triggerType: claim.triggerType,
    createdAt: { $gte: fourteenDaysAgo },
    status: { $nin: ['Rejected', 'FraudSuspected'] },
  });
  if (recentSameTrigger > 0) {
    fraudScore += 35;
    flags.push(`duplicate_trigger_within_14_days:${recentSameTrigger}_prior`);
  }

  // ── Rule 2: Claim frequency — >3 claims of any type in last 14 days ──
  const recentAny = await ClaimModel.countDocuments({
    riderId,
    createdAt: { $gte: fourteenDaysAgo },
    status: { $nin: ['Rejected', 'FraudSuspected'] },
  });
  if (recentAny > 3) {
    fraudScore += 30;
    flags.push(`high_claim_frequency:${recentAny}_claims_in_14_days`);
  } else if (recentAny > 2) {
    fraudScore += 15;
    flags.push(`elevated_claim_frequency:${recentAny}_claims_in_14_days`);
  }

  // ── Rule 3: GPS location mismatch — rider location vs. trigger location ──
  const distanceKm = haversineKm(
    rider.location.lat,
    rider.location.lng,
    claim.triggerData.location.lat,
    claim.triggerData.location.lng,
  );
  if (distanceKm > 15) {
    fraudScore += 25;
    flags.push(`gps_mismatch:${distanceKm.toFixed(1)}km_from_trigger_zone`);
  } else if (distanceKm > 8) {
    fraudScore += 12;
    flags.push(`gps_distance_elevated:${distanceKm.toFixed(1)}km`);
  }

  // ── Rule 4: Very new policy — registered < 7 days ago ──
  const policyAgeDays = (Date.now() - rider.registeredAt.getTime()) / 86_400_000;
  if (policyAgeDays < 7) {
    fraudScore += 15;
    flags.push(`new_policy:${policyAgeDays.toFixed(0)}_days_old`);
  }

  // ── Rule 5: New rider account — registered < 30 days ago ──
  if (policyAgeDays < 30) {
    fraudScore += 8;
    flags.push(`new_account:${policyAgeDays.toFixed(0)}_days_old`);
  }

  // ── Rule 6: Borderline trigger — actual value <5% above threshold ──
  const overagePercent =
    ((claim.triggerData.actualValue - claim.triggerData.threshold) / claim.triggerData.threshold) * 100;
  if (overagePercent < 5 && overagePercent >= 0) {
    fraudScore += 10;
    flags.push(`borderline_threshold:${overagePercent.toFixed(1)}%_over`);
  }

  // ── Rule 7: Low experience (< 3 months) — higher fraud risk ──
  if (rider.experienceMonths < 3) {
    fraudScore += 5;
    flags.push('very_new_rider_low_experience');
  }

  fraudScore = Math.min(100, fraudScore);

  let recommendation: FraudAssessment['recommendation'];
  if (fraudScore <= 20)       recommendation = 'auto_approve';
  else if (fraudScore <= 50)  recommendation = 'manual_review';
  else                        recommendation = 'flag_fraud';

  return { fraudScore, fraudFlags: flags, recommendation };
}
