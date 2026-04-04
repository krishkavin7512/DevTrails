import { Router, Request, Response } from 'express';
import { z } from 'zod';
import crypto from 'crypto';
import mongoose from 'mongoose';
import ClaimModel from '../models/Claim';
import RiderModel from '../models/Rider';

const router = Router();

// ── Schemas ───────────────────────────────────────────────────────────────────

const deviceCheckSchema = z.object({
  riderId: z.string().min(1),
  fingerprint: z.object({
    deviceId:           z.string(),
    model:              z.string().optional(),
    manufacturer:       z.string().optional(),
    brand:              z.string().optional(),
    board:              z.string().optional(),
    hardware:           z.string().optional(),
    display:            z.string().optional(),
    host:               z.string().optional(),
    androidVersion:     z.string().optional(),
    sdkInt:             z.number().optional(),
    isPhysicalDevice:   z.boolean().optional(),
    clientFingerprintId: z.string().optional(),
  }),
});

const ringCheckSchema = z.object({
  clientFingerprintId: z.string().min(1),
  riderId:             z.string().min(1),
});

const reviewSchema = z.object({
  decision:  z.enum(['approve', 'reject']),
  adminNote: z.string().optional(),
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function sha256(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function fingerprintHash(fp: Record<string, unknown>): string {
  const raw = Object.entries(fp)
    .filter(([k]) => k !== 'clientFingerprintId')
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join('|');
  return sha256(raw);
}

// ── POST /fraud/check-device ──────────────────────────────────────────────────
// Checks if a device is already associated with a different rider (ring signal)
// and computes the authoritative SHA-256 fingerprint hash.
router.post('/check-device', async (req: Request, res: Response) => {
  const parsed = deviceCheckSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.flatten() });
  }

  const { riderId, fingerprint } = parsed.data;
  let fraudScore = 0;
  const fraudFlags: string[] = [];

  try {
    const hash = fingerprintHash(fingerprint as Record<string, unknown>);

    // Find any other rider that has submitted claims with this device hash
    const otherRiderClaims = await ClaimModel.find({
      'deviceFingerprint.hash': hash,
      riderId: { $ne: new mongoose.Types.ObjectId(riderId) },
    })
      .select('riderId')
      .limit(5)
      .lean();

    const sharedRiderIds = [...new Set(otherRiderClaims.map((c) => c.riderId?.toString()))];

    if (sharedRiderIds.length > 0) {
      fraudScore += 40;
      fraudFlags.push(`SHARED_DEVICE:${sharedRiderIds.length}_other_riders`);
    }

    // Non-physical device (emulator) — belt-and-suspenders server check
    if (fingerprint.isPhysicalDevice === false) {
      fraudScore += 40;
      fraudFlags.push('EMULATOR_DETECTED');
    }

    return res.json({
      success: true,
      data: {
        fingerprintHash: hash,
        fraudScore: Math.min(100, fraudScore),
        fraudFlags,
        sharedRiderCount: sharedRiderIds.length,
        recommendation: fraudScore >= 40 ? 'manual_review' : 'auto_approve',
      },
    });
  } catch (err) {
    console.error('[fraud/check-device]', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ── POST /fraud/check-ring ────────────────────────────────────────────────────
// Detects fraud rings: GPS clustering + shared device fingerprint across riders.
router.post('/check-ring', async (req: Request, res: Response) => {
  const parsed = ringCheckSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.flatten() });
  }

  const { clientFingerprintId, riderId } = parsed.data;
  const hash = sha256(clientFingerprintId);

  try {
    // Count riders who submitted claims with the same hashed fingerprint
    const matchingClaims = await ClaimModel.find({
      'deviceFingerprint.clientId': clientFingerprintId,
      riderId: { $ne: new mongoose.Types.ObjectId(riderId) },
    })
      .select('riderId triggerData.location')
      .limit(20)
      .lean();

    const uniqueRiders = new Set(matchingClaims.map((c) => c.riderId?.toString()));
    const isRingMember = uniqueRiders.size >= 2;

    // GPS cluster: check if multiple riders share a very close trigger location
    let gpsClusterFlag = false;
    if (matchingClaims.length > 0) {
      const locations = matchingClaims
        .map((c) => c.triggerData?.location)
        .filter(Boolean) as { lat: number; lng: number }[];

      if (locations.length >= 2) {
        // Simple check: any two claims within 0.5 km = cluster
        outer: for (let i = 0; i < locations.length; i++) {
          for (let j = i + 1; j < locations.length; j++) {
            const dLat = locations[i].lat - locations[j].lat;
            const dLng = locations[i].lng - locations[j].lng;
            const approxKm = Math.sqrt(dLat * dLat + dLng * dLng) * 111;
            if (approxKm < 0.5) {
              gpsClusterFlag = true;
              break outer;
            }
          }
        }
      }
    }

    return res.json({
      success: true,
      data: {
        isRingMember,
        sharedDeviceRiderCount: uniqueRiders.size,
        gpsCluster: gpsClusterFlag,
        fingerprintHash: hash,
      },
    });
  } catch (err) {
    console.error('[fraud/check-ring]', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ── GET /fraud/review-queue ───────────────────────────────────────────────────
// Admin: paginated list of claims pending manual fraud review.
router.get('/review-queue', async (req: Request, res: Response) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page  as string) || 1);
    const limit = Math.min(50, parseInt(req.query.limit as string) || 20);

    const [claims, total] = await Promise.all([
      ClaimModel.find({ status: 'UnderReview' })
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .populate('riderId', 'name phone city')
        .lean(),
      ClaimModel.countDocuments({ status: 'UnderReview' }),
    ]);

    return res.json({
      success: true,
      data: { claims, total, page, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('[fraud/review-queue]', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ── PUT /fraud/review/:claimId ────────────────────────────────────────────────
// Admin: approve or reject a flagged claim.
router.put('/review/:claimId', async (req: Request, res: Response) => {
  const parsed = reviewSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ success: false, error: parsed.error.flatten() });
  }

  const { claimId } = req.params;
  const { decision, adminNote } = parsed.data;

  try {
    const newStatus = decision === 'approve' ? 'Approved' : 'Rejected';
    const claim = await ClaimModel.findByIdAndUpdate(
      claimId,
      {
        status: newStatus,
        ...(adminNote ? { adminNote } : {}),
        reviewedAt: new Date(),
      },
      { new: true },
    );

    if (!claim) {
      return res.status(404).json({ success: false, error: 'Claim not found' });
    }

    return res.json({ success: true, data: { claimId, status: newStatus } });
  } catch (err) {
    console.error('[fraud/review]', err);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

export default router;
