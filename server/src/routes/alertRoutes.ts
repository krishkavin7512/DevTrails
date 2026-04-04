import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import { validate } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';

const router = Router();

// ── In-memory store (replace with MongoDB model for production) ───────────────

interface CommunityAlert {
  _id: string;
  riderId: string;
  type: string;
  description: string;
  lat: number;
  lng: number;
  locationAccuracy: number;
  verified: boolean;
  confirmations: string[];
  createdAt: Date;
}

const alerts: CommunityAlert[] = [];

// ── Schemas ───────────────────────────────────────────────────────────────────

const SubmitAlertSchema = z.object({
  riderId:          z.string().min(1),
  type:             z.enum(['Flooding', 'RoadClosure', 'HeavyRain', 'Accident', 'SevereAQI', 'ExtremeHeat', 'SocialDisruption']),
  description:      z.string().max(300).optional().default(''),
  lat:              z.number().min(-90).max(90),
  lng:              z.number().min(-180).max(180),
  locationAccuracy: z.number().optional().default(999),
});

// ── POST /api/alerts ──────────────────────────────────────────────────────────

router.post('/', validate(SubmitAlertSchema), (req: Request, res: Response) => {
  const { riderId, type, description, lat, lng, locationAccuracy } = req.body;

  const alert: CommunityAlert = {
    _id:              new mongoose.Types.ObjectId().toString(),
    riderId,
    type,
    description,
    lat,
    lng,
    locationAccuracy,
    verified:         false,
    confirmations:    [riderId],
    createdAt:        new Date(),
  };

  alerts.unshift(alert);
  // Keep at most 500 recent alerts in memory
  if (alerts.length > 500) alerts.splice(500);

  res.status(201).json({ success: true, data: alert });
});

// ── GET /api/alerts/nearby ────────────────────────────────────────────────────

router.get('/nearby', (req: Request, res: Response) => {
  const lat    = parseFloat(req.query.lat as string);
  const lng    = parseFloat(req.query.lng as string);
  const radius = parseFloat(req.query.radius as string) || 5.0; // km

  if (isNaN(lat) || isNaN(lng)) throw new AppError('lat and lng are required', 400);

  // Haversine approximation
  const R = 6371;
  const nearby = alerts.filter(a => {
    const dLat = ((a.lat - lat) * Math.PI) / 180;
    const dLng = ((a.lng - lng) * Math.PI) / 180;
    const h =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat * Math.PI) / 180) *
        Math.cos((a.lat * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    const dist = 2 * R * Math.asin(Math.sqrt(h));
    return dist <= radius;
  });

  res.json({ success: true, data: nearby });
});

// ── POST /api/alerts/:id/confirm ──────────────────────────────────────────────

router.post('/:id/confirm', (req: Request, res: Response) => {
  const alert = alerts.find(a => a._id === req.params.id);
  if (!alert) throw new AppError('Alert not found', 404);

  const riderId = (req.body.riderId as string) || 'anon';
  if (!alert.confirmations.includes(riderId)) {
    alert.confirmations.push(riderId);
  }

  // Auto-verify at 3+ confirmations
  if (alert.confirmations.length >= 3) {
    alert.verified = true;
  }

  res.json({ success: true, data: alert });
});

export default router;
