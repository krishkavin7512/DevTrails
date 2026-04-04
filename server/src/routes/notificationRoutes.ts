/**
 * Notification routes — FCM token registration, send notification,
 * notification preferences, and WhatsApp delivery via Twilio.
 *
 * Required env vars (all optional in dev — falls back to console.log):
 *   FCM_SERVER_KEY       — Firebase Cloud Messaging server key
 *   TWILIO_ACCOUNT_SID   — Twilio account SID
 *   TWILIO_AUTH_TOKEN    — Twilio auth token
 *   TWILIO_WHATSAPP_FROM — Twilio WhatsApp number (default sandbox)
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Rider from '../models/Rider';
import { validate } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';

const router = Router();

// ── FCM helpers ───────────────────────────────────────────────────────────────

async function sendFcm(
  tokens: string | string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  const key = process.env.FCM_SERVER_KEY;
  const tokenArr = Array.isArray(tokens) ? tokens : [tokens];
  if (!key) {
    console.log(`[FCM mock] title="${title}" body="${body}" tokens=${tokenArr.join(',')}`);
    return;
  }
  try {
    const payload: Record<string, unknown> = {
      notification: { title, body },
      data,
    };
    if (tokenArr.length === 1) {
      payload.to = tokenArr[0];
    } else {
      payload.registration_ids = tokenArr;
    }
    const res = await fetch('https://fcm.googleapis.com/fcm/send', {
      method:  'POST',
      headers: {
        Authorization:  `key=${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (!res.ok) console.error('[FCM] HTTP', res.status, await res.text());
  } catch (e) {
    console.error('[FCM] send failed:', e);
  }
}

async function sendFcmToTopic(
  topic: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  return sendFcm(`/topics/${topic}`, title, body, data);
}

// ── WhatsApp helper ───────────────────────────────────────────────────────────

async function sendWhatsApp(phone: string, message: string): Promise<void> {
  const sid   = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from  = process.env.TWILIO_WHATSAPP_FROM ?? 'whatsapp:+14155238886';
  if (!sid || !token) {
    console.log(`[WhatsApp mock] To: ${phone}\n${message}`);
    return;
  }
  try {
    const url  = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;
    const body = new URLSearchParams({
      From: from,
      To:   `whatsapp:${phone.startsWith('+') ? phone : '+' + phone}`,
      Body: message,
    });
    const res = await fetch(url, {
      method:  'POST',
      headers: {
        Authorization:  `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    });
    if (!res.ok) console.error('[WhatsApp] HTTP', res.status, await res.text());
  } catch (e) {
    console.error('[WhatsApp] send failed:', e);
  }
}

// ── Notification templates ────────────────────────────────────────────────────

const templates = {
  trigger_alert: (zone: string, type: string) => ({
    title: '⚡ Trigger Alert',
    body:  `${type} detected in ${zone}. Your coverage is active.`,
  }),
  claim_approved: (claimNumber: string, amountINR: number) => ({
    title: '✅ Claim Approved',
    body:  `Claim ${claimNumber} approved. ₹${amountINR} payout initiated.`,
  }),
  payment_success: (amountINR: number, nextDate: string) => ({
    title: '💳 Premium Received',
    body:  `₹${amountINR} collected. Coverage active until ${nextDate}.`,
  }),
  payment_failed: (amountINR: number, graceEnds: string) => ({
    title: '⚠️ Payment Failed',
    body:  `₹${amountINR} premium failed. 12-hour grace period (until ${graceEnds}).`,
  }),
  welcome: (firstName: string) => ({
    title: '👋 Welcome to RainCheck',
    body:  `Hi ${firstName}! Complete onboarding to activate your coverage.`,
  }),
  panic_alert: (riderName: string, distKm: number) => ({
    title: '🚨 Emergency Alert',
    body:  `${riderName} needs help ${distKm.toFixed(1)} km away. Tap to view.`,
  }),
  predictive_alert: (type: string, zone: string, forecastTime: string) => ({
    title: '🔮 Forecast Alert',
    body:  `${type} forecast for ${zone} at ${forecastTime}. Adjust your schedule.`,
  }),
};

// ── PUT /api/notifications/fcm-token/:riderId ─────────────────────────────────
// (also mounted at PUT /api/riders/:riderId/fcm-token via riderRoutes for mobile SDK)

router.put('/fcm-token/:riderId', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.riderId)) {
    throw new AppError('Invalid rider ID', 400);
  }
  const { fcmToken } = req.body as { fcmToken?: string };
  if (!fcmToken) throw new AppError('fcmToken required', 400);

  await Rider.findByIdAndUpdate(req.params.riderId, { $set: { fcmToken } });
  res.json({ success: true });
});

// ── PUT /api/notifications/prefs/:riderId ─────────────────────────────────────

const PrefsSchema = z.object({
  pushEnabled:      z.boolean().optional(),
  whatsappEnabled:  z.boolean().optional(),
  triggerAlerts:    z.boolean().optional(),
  claimUpdates:     z.boolean().optional(),
  paymentReminders: z.boolean().optional(),
  communityAlerts:  z.boolean().optional(),
});

router.put('/prefs/:riderId', validate(PrefsSchema), async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.riderId)) {
    throw new AppError('Invalid rider ID', 400);
  }
  await Rider.findByIdAndUpdate(req.params.riderId, {
    $set: { notificationPrefs: req.body },
  });
  res.json({ success: true });
});

// ── POST /api/notifications/send ──────────────────────────────────────────────

const SendSchema = z.object({
  riderId:    z.string().optional(),
  riderIds:   z.array(z.string()).optional(),
  topic:      z.string().optional(),
  type:       z.enum([
    'trigger_alert', 'claim_approved', 'payment_success',
    'payment_failed', 'welcome', 'panic_alert', 'predictive_alert',
  ]),
  templateArgs: z.record(z.string(), z.any()).optional(),
  whatsapp:   z.boolean().default(false),
});

router.post('/send', validate(SendSchema), async (req: Request, res: Response) => {
  const { riderId, riderIds, topic, type, templateArgs = {}, whatsapp } = req.body;

  // Build message from template
  let title = '';
  let body  = '';
  switch (type) {
    case 'trigger_alert':
      ({ title, body } = templates.trigger_alert(
        templateArgs.zone ?? '', templateArgs.triggerType ?? ''));
      break;
    case 'claim_approved':
      ({ title, body } = templates.claim_approved(
        templateArgs.claimNumber ?? '', templateArgs.amountINR ?? 0));
      break;
    case 'payment_success':
      ({ title, body } = templates.payment_success(
        templateArgs.amountINR ?? 0, templateArgs.nextDate ?? ''));
      break;
    case 'payment_failed':
      ({ title, body } = templates.payment_failed(
        templateArgs.amountINR ?? 0, templateArgs.graceEnds ?? ''));
      break;
    case 'welcome':
      ({ title, body } = templates.welcome(templateArgs.firstName ?? 'Rider'));
      break;
    case 'panic_alert':
      ({ title, body } = templates.panic_alert(
        templateArgs.riderName ?? 'A rider', templateArgs.distKm ?? 0));
      break;
    case 'predictive_alert':
      ({ title, body } = templates.predictive_alert(
        templateArgs.triggerType ?? '', templateArgs.zone ?? '',
        templateArgs.forecastTime ?? ''));
      break;
  }

  const data: Record<string, string> = { type, ...Object.fromEntries(
    Object.entries(templateArgs).map(([k, v]) => [k, String(v)])
  )};

  const sent: string[] = [];

  // Send FCM
  if (topic) {
    await sendFcmToTopic(topic, title, body, data);
    sent.push(`topic:${topic}`);
  } else {
    const ids = riderIds ?? (riderId ? [riderId] : []);
    if (ids.length > 0) {
      // Fetch FCM tokens for these rider IDs
      const riders = await Rider.find(
        { _id: { $in: ids } },
        { fcmToken: 1, phone: 1, fullName: 1, notificationPrefs: 1 },
      ).lean() as any[];

      const tokens = riders
        .map((r: any) => r.fcmToken as string | undefined)
        .filter(Boolean) as string[];

      if (tokens.length > 0) await sendFcm(tokens, title, body, data);

      // WhatsApp delivery
      if (whatsapp) {
        for (const rider of riders) {
          const prefs = (rider.notificationPrefs ?? {}) as Record<string, boolean>;
          if (prefs.whatsappEnabled === false) continue;
          await sendWhatsApp(rider.phone, `${title}\n\n${body}`);
        }
      }
      sent.push(...ids);
    }
  }

  res.json({ success: true, data: { sent: sent.length, title, body } });
});

// ── POST /api/notifications/send-whatsapp ─────────────────────────────────────

const WASchema = z.object({
  phone:   z.string().min(10),
  message: z.string().min(1),
});

router.post('/send-whatsapp', validate(WASchema), async (req: Request, res: Response) => {
  const { phone, message } = req.body as { phone: string; message: string };
  await sendWhatsApp(phone, message);
  res.json({ success: true });
});

// ── POST /api/notifications/broadcast ────────────────────────────────────────
// Send to all riders in a city/zone (for disruption alerts)

const BroadcastSchema = z.object({
  city:     z.string().optional(),
  zone:     z.string().optional(),
  type:     z.enum([
    'trigger_alert', 'predictive_alert', 'panic_alert',
  ]),
  templateArgs: z.record(z.string(), z.any()),
  whatsapp: z.boolean().default(false),
});

router.post('/broadcast', validate(BroadcastSchema), async (req: Request, res: Response) => {
  const { city, zone, type, templateArgs, whatsapp } = req.body;

  const filter: Record<string, unknown> = { isActive: true };
  if (city) filter.city = city;
  if (zone) filter.operatingZone = zone;

  const riders = await Rider.find(filter, {
    fcmToken: 1, phone: 1, notificationPrefs: 1,
  }).lean() as any[];

  let title = '';
  let body  = '';
  switch (type) {
    case 'trigger_alert':
      ({ title, body } = templates.trigger_alert(
        templateArgs.zone ?? zone ?? city ?? '', templateArgs.triggerType ?? ''));
      break;
    case 'predictive_alert':
      ({ title, body } = templates.predictive_alert(
        templateArgs.triggerType ?? '', templateArgs.zone ?? zone ?? '',
        templateArgs.forecastTime ?? ''));
      break;
    case 'panic_alert':
      ({ title, body } = templates.panic_alert(
        templateArgs.riderName ?? 'A rider', templateArgs.distKm ?? 0));
      break;
  }

  const data: Record<string, string> = { type, ...Object.fromEntries(
    Object.entries(templateArgs).map(([k, v]) => [k, String(v)])
  )};

  const tokens = riders
    .map((r: any) => r.fcmToken as string | undefined)
    .filter(Boolean) as string[];

  if (tokens.length > 0) {
    // FCM batch limit is 500 tokens per request
    for (let i = 0; i < tokens.length; i += 500) {
      await sendFcm(tokens.slice(i, i + 500), title, body, data);
    }
  }

  if (whatsapp) {
    for (const rider of riders) {
      const prefs = (rider.notificationPrefs ?? {}) as Record<string, boolean>;
      if (prefs.whatsappEnabled === false) continue;
      await sendWhatsApp(rider.phone, `${title}\n\n${body}`);
    }
  }

  res.json({
    success: true,
    data: { broadcast: riders.length, tokens: tokens.length, title, body },
  });
});

export { sendFcm, sendFcmToTopic, sendWhatsApp };
export default router;
