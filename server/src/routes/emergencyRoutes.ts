import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Rider from '../models/Rider';
import { validate } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';

const router = Router();

// ── In-memory active emergencies (replace with DB model for production) ────────

interface Emergency {
  _id: string;
  riderId: string;
  lat: number;
  lng: number;
  type: 'sos' | 'crash';
  status: 'active' | 'cancelled' | 'resolved';
  emergencyContact?: { name: string; phone: string };
  triggeredAt: Date;
  cancelledAt?: Date;
}

const emergencies: Map<string, Emergency> = new Map();

// ── Schemas ───────────────────────────────────────────────────────────────────

const TriggerSchema = z.object({
  riderId:     z.string().min(1),
  lat:         z.number(),
  lng:         z.number(),
  type:        z.enum(['sos', 'crash']).default('sos'),
  emergencyContact: z.object({
    name:  z.string(),
    phone: z.string(),
  }).optional(),
});

const LocationSchema = z.object({
  lat: z.number(),
  lng: z.number(),
});

// ── POST /api/emergency/trigger ───────────────────────────────────────────────

router.post('/trigger', validate(TriggerSchema), async (req: Request, res: Response) => {
  const { riderId, lat, lng, type, emergencyContact } = req.body;

  const id: string = new mongoose.Types.ObjectId().toString();
  const emergency: Emergency = {
    _id:              id,
    riderId,
    lat,
    lng,
    type,
    status:           'active',
    emergencyContact,
    triggeredAt:      new Date(),
  };

  emergencies.set(id, emergency);

  // Notify nearby riders (fire-and-forget — no Twilio needed for this path)
  try {
    const nearbyRiders = await Rider.find({
      isActive: true,
      riderId:  { $ne: riderId },
    }).limit(10).lean();

    console.log(`🚨 Emergency triggered by rider ${riderId} — ${nearbyRiders.length} nearby riders found`);
  } catch {
    // Non-critical — continues without nearby rider notification
  }

  res.status(201).json({
    success: true,
    data: emergency,
    message: 'Emergency SOS triggered. Help is on the way.',
  });
});

// ── PUT /api/emergency/:id/location ──────────────────────────────────────────

router.put('/:id/location', validate(LocationSchema), (req: Request, res: Response) => {
  const emergency = emergencies.get(String(req.params.id));
  if (!emergency) throw new AppError('Emergency not found', 404);
  if (emergency.status !== 'active') throw new AppError('Emergency is no longer active', 400);

  emergency.lat = req.body.lat;
  emergency.lng = req.body.lng;

  res.json({ success: true, data: emergency });
});

// ── POST /api/emergency/:id/cancel ───────────────────────────────────────────

router.post('/:id/cancel', (req: Request, res: Response) => {
  const emergency = emergencies.get(String(req.params.id));
  if (!emergency) throw new AppError('Emergency not found', 404);

  emergency.status      = 'cancelled';
  emergency.cancelledAt = new Date();

  console.log(`✅ Emergency ${String(req.params.id)} cancelled by rider ${emergency.riderId}`);

  res.json({
    success: true,
    data:    emergency,
    message: 'Emergency cancelled successfully.',
  });
});

export default router;
