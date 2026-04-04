/**
 * Payment routes — Razorpay verification, subscription management,
 * UPI payout, and payment history.
 *
 * Razorpay dependency is NOT in package.json yet; add with:
 *   npm install razorpay
 *
 * Required env vars:
 *   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET
 */

import crypto from 'crypto';
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import Policy from '../models/Policy';
import Rider from '../models/Rider';
import { validate } from '../middleware/validateRequest';
import { AppError } from '../middleware/errorHandler';

const router = Router();

// ── Helpers ───────────────────────────────────────────────────────────────────

function getRazorpay() {
  // Lazily require so the server starts even without the package installed
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Razorpay = require('razorpay');
  return new Razorpay({
    key_id:     process.env.RAZORPAY_KEY_ID     ?? '',
    key_secret: process.env.RAZORPAY_KEY_SECRET ?? '',
  });
}

function verifySignature(
  paymentId: string,
  orderId: string,
  signature: string,
): boolean {
  const secret = process.env.RAZORPAY_KEY_SECRET ?? '';
  const body   = `${orderId}|${paymentId}`;
  const digest = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');
  return digest === signature;
}

// ── Payment record model (in-memory schema, attach to DB if needed) ───────────

interface IPaymentRecord {
  _id?: string;
  riderId: string;
  policyId?: string;
  razorpayPaymentId?: string;
  razorpayOrderId?: string;
  subscriptionId?: string;
  amountPaise: number;
  status: 'captured' | 'failed' | 'refunded' | 'pending';
  type: 'onboarding' | 'renewal' | 'payout' | 'refund';
  description?: string;
  upiId?: string;
  payoutId?: string;
  createdAt: Date;
}

// Simple in-memory log (replace with Mongoose model for production)
const paymentLog: IPaymentRecord[] = [];

function logPayment(rec: IPaymentRecord) {
  rec._id = new mongoose.Types.ObjectId().toString();
  rec.createdAt = new Date();
  paymentLog.unshift(rec); // newest first
}

// ── POST /api/payments/verify ─────────────────────────────────────────────────

const VerifySchema = z.object({
  razorpay_payment_id: z.string().min(1),
  razorpay_order_id:   z.string().optional(),
  razorpay_signature:  z.string().optional(),
  riderId:             z.string().optional(),
  policyId:            z.string().optional(),
});

router.post('/verify', validate(VerifySchema), async (req: Request, res: Response) => {
  const { razorpay_payment_id, razorpay_order_id, razorpay_signature, riderId, policyId } = req.body;

  // Signature verification (skip if order_id or signature absent — e.g. subscription flow)
  if (razorpay_order_id && razorpay_signature) {
    const valid = verifySignature(razorpay_payment_id, razorpay_order_id, razorpay_signature);
    if (!valid) throw new AppError('Payment signature verification failed', 400);
  }

  // Fetch payment details from Razorpay
  let amountPaise = 0;
  try {
    const rp      = getRazorpay();
    const payment = await rp.payments.fetch(razorpay_payment_id);
    amountPaise   = payment.amount as number;
  } catch {
    // If Razorpay SDK not installed yet, proceed without amount
  }

  logPayment({
    riderId:            riderId ?? '',
    policyId,
    razorpayPaymentId:  razorpay_payment_id,
    razorpayOrderId:    razorpay_order_id,
    amountPaise,
    status:             'captured',
    type:               'onboarding',
    createdAt:          new Date(),
  });

  res.json({ success: true, data: { verified: true, paymentId: razorpay_payment_id } });
});

// ── POST /api/payments/subscription/create ────────────────────────────────────

const CreateSubSchema = z.object({
  riderId:      z.string().min(1),
  planType:     z.enum(['Basic', 'Standard', 'Premium']),
  amountPaise:  z.number().int().positive(),
  phone:        z.string().optional(),
  email:        z.string().email().optional(),
});

router.post('/subscription/create', validate(CreateSubSchema), async (req: Request, res: Response) => {
  const { riderId, planType, amountPaise, phone, email } = req.body;

  const rider = await Rider.findById(riderId).lean();
  if (!rider) throw new AppError('Rider not found', 404);

  let subscriptionId = `sub_mock_${Date.now()}`;
  let razorpayData: Record<string, unknown> = {};

  try {
    const rp = getRazorpay();
    // Create a weekly subscription plan first, then the subscription
    const plan = await rp.plans.create({
      period:      'weekly',
      interval:    1,
      item: {
        name:     `RainCheck ${planType}`,
        amount:   amountPaise,
        currency: 'INR',
      },
    });

    const sub = await rp.subscriptions.create({
      plan_id:         plan.id,
      total_count:     52, // 1 year
      quantity:        1,
      customer_notify: 1,
      notify_info: {
        notify_phone: phone ?? (rider as any).phone ?? '',
        notify_email: email ?? (rider as any).email ?? '',
      },
      notes: { rider_id: riderId, plan_type: planType },
    });

    subscriptionId = sub.id as string;
    razorpayData   = sub;
  } catch {
    // Razorpay not installed — return mock ID so app can continue
  }

  res.status(201).json({
    success:  true,
    data: {
      subscriptionId,
      planType,
      amountPaise,
      status:    'created',
      razorpay: razorpayData,
    },
  });
});

// ── GET /api/payments/subscription/status/:riderId ────────────────────────────

router.get('/subscription/status/:riderId', async (req: Request, res: Response) => {
  if (!mongoose.isValidObjectId(req.params.riderId)) {
    throw new AppError('Invalid rider ID', 400);
  }

  // Find the most recent active policy for this rider
  const policy = await Policy.findOne({
    riderId: req.params.riderId,
    status:  { $in: ['Active', 'PendingPayment'] },
  }).sort({ createdAt: -1 }).lean();

  if (!policy) {
    return res.json({
      success: true,
      data: { status: 'none', subscriptionId: null },
    });
  }

  // Try to fetch from Razorpay if subscription ID stored
  const subId = (policy as any).subscriptionId as string | undefined;
  let razorpayStatus = 'active';
  let nextChargeAt: string | undefined;

  if (subId) {
    try {
      const rp  = getRazorpay();
      const sub = await rp.subscriptions.fetch(subId);
      razorpayStatus = (sub as any).status;
      const chargeTs = (sub as any).current_end as number | undefined;
      if (chargeTs) nextChargeAt = new Date(chargeTs * 1000).toISOString();
    } catch { /* Razorpay offline or not installed */ }
  }

  const statusMap: Record<string, string> = {
    active: 'active', authenticated: 'active',
    paused: 'paused', halted: 'grace_period',
    cancelled: 'cancelled', completed: 'cancelled',
  };

  res.json({
    success: true,
    data: {
      subscriptionId:    subId ?? null,
      status:            statusMap[razorpayStatus] ?? razorpayStatus,
      planType:          policy.planType,
      weeklyPremiumPaise: policy.weeklyPremium,
      nextChargeAt:      nextChargeAt ?? policy.endDate?.toISOString(),
      totalRenewals:     policy.renewalCount ?? 0,
    },
  });
});

// ── POST /api/payments/subscription/:id/pause ─────────────────────────────────

router.post('/subscription/:id/pause', async (req: Request, res: Response) => {
  try {
    const rp = getRazorpay();
    const sub = await rp.subscriptions.pause(req.params.id, { pause_at: 'now' });
    res.json({ success: true, data: sub });
  } catch {
    // Mock response when Razorpay not available
    res.json({ success: true, data: { id: req.params.id, status: 'paused' } });
  }
});

// ── POST /api/payments/subscription/:id/resume ────────────────────────────────

router.post('/subscription/:id/resume', async (req: Request, res: Response) => {
  try {
    const rp = getRazorpay();
    const sub = await rp.subscriptions.resume(req.params.id, { resume_at: 'now' });
    res.json({ success: true, data: sub });
  } catch {
    res.json({ success: true, data: { id: req.params.id, status: 'active' } });
  }
});

// ── POST /api/payments/subscription/:id/cancel ───────────────────────────────

router.post('/subscription/:id/cancel', async (req: Request, res: Response) => {
  try {
    const rp = getRazorpay();
    const sub = await rp.subscriptions.cancel(req.params.id, { cancel_at_cycle_end: 1 });
    res.json({ success: true, data: sub });
  } catch {
    res.json({ success: true, data: { id: req.params.id, status: 'cancelled' } });
  }
});

// ── POST /api/payments/payout ─────────────────────────────────────────────────

const PayoutSchema = z.object({
  riderId:     z.string().min(1),
  claimId:     z.string().optional(),
  amountPaise: z.number().int().positive(),
  // UPI ID format: localpart@provider  e.g. 9876543210@upi, name@okaxis
  upiId:       z.string().regex(
    /^[\w.\-+]+@[\w]+$/,
    'Invalid UPI ID format. Expected: handle@provider (e.g. 9876543210@upi)',
  ),
  description: z.string().optional(),
});

router.post('/payout', validate(PayoutSchema), async (req: Request, res: Response) => {
  const { riderId, claimId, amountPaise, upiId, description } = req.body;

  // In production use Razorpay Payouts API (requires X account)
  // For now return a mock payout ID and log it
  const payoutId = `pout_${Date.now()}`;

  logPayment({
    riderId,
    policyId:   claimId,
    amountPaise,
    status:     'captured',
    type:       'payout',
    description: description ?? 'Claim payout',
    upiId,
    payoutId,
    createdAt:  new Date(),
  });

  res.status(201).json({
    success: true,
    data: {
      payoutId,
      status:     'processing',
      amountPaise,
      upiId,
      estimatedArrival: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
      message: `₹${(amountPaise / 100).toFixed(0)} being transferred to ${upiId}`,
    },
  });
});

// ── GET /api/payments/history/:riderId ───────────────────────────────────────

router.get('/history/:riderId', (req: Request, res: Response) => {
  const { riderId } = req.params;
  const page  = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(50, parseInt(req.query.limit as string) || 20);

  const records = paymentLog
    .filter(r => r.riderId === riderId)
    .slice((page - 1) * limit, page * limit);

  res.json({
    success: true,
    data: records,
    pagination: { page, limit, total: records.length },
  });
});

// ── Notification helpers ──────────────────────────────────────────────────────

async function getRiderContact(riderId: string): Promise<{ phone: string; name: string } | null> {
  try {
    const rider = await Rider.findById(riderId).lean() as any;
    if (!rider) return null;
    return { phone: rider.phone ?? '', name: rider.fullName ?? 'Rider' };
  } catch { return null; }
}

async function sendWhatsApp(phone: string, message: string): Promise<void> {
  // Twilio WhatsApp — requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_FROM
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
      To:   `whatsapp:${phone}`,
      Body: message,
    });
    await fetch(url, {
      method:  'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    });
  } catch (e) {
    console.error('[WhatsApp] send failed:', e);
  }
}

async function sendPushNotification(riderId: string, title: string, body: string): Promise<void> {
  // Firebase Cloud Messaging — requires FCM_SERVER_KEY env var
  const fcmKey = process.env.FCM_SERVER_KEY;
  if (!fcmKey) {
    console.log(`[FCM mock] riderId=${riderId} title="${title}" body="${body}"`);
    return;
  }
  try {
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        Authorization: `key=${fcmKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to:           `/topics/rider_${riderId}`,
        notification: { title, body },
        data:         { riderId },
      }),
    });
  } catch (e) {
    console.error('[FCM] send failed:', e);
  }
}

// ── POST /api/payments/webhook ────────────────────────────────────────────────

router.post(
  '/webhook',
  // Raw body needed for signature validation — mount BEFORE express.json()
  // In index.ts register this route with express.raw({ type: 'application/json' })
  async (req: Request, res: Response) => {
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET ?? '';
    const sig           = req.headers['x-razorpay-signature'] as string | undefined;
    const rawBody       = typeof req.body === 'string'
      ? req.body
      : JSON.stringify(req.body);

    if (webhookSecret && sig) {
      const digest = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex');
      if (digest !== sig) {
        return res.status(400).json({ success: false, error: 'Invalid webhook signature' });
      }
    }

    const event = req.body as { event?: string; payload?: Record<string, any> };
    const payload = event.payload ?? {};

    switch (event.event) {
      case 'payment.captured': {
        const payment = payload?.payment?.entity as Record<string, any> | undefined;
        if (payment) {
          logPayment({
            riderId:           payment.notes?.rider_id ?? '',
            razorpayPaymentId: payment.id,
            amountPaise:       payment.amount,
            status:            'captured',
            type:              'renewal',
            createdAt:         new Date(),
          });
        }
        break;
      }

      case 'subscription.charged': {
        // Weekly renewal succeeded — extend policy by 7 days + notify rider
        const sub = payload?.subscription?.entity as Record<string, any> | undefined;
        if (sub?.notes?.rider_id) {
          const riderId  = sub.notes.rider_id as string;
          // Accept both Active and PendingPayment (grace period recovery)
          const policy   = await Policy.findOne({ riderId, status: { $in: ['Active', 'PendingPayment'] } });
          if (policy) {
            policy.endDate      = new Date(policy.endDate.getTime() + 7 * 86_400_000);
            policy.renewalCount = (policy.renewalCount ?? 0) + 1;
            policy.status       = 'Active';
            (policy as any).graceEndsAt = undefined;
            await policy.save();
          }
          const contact = await getRiderContact(riderId);
          if (contact) {
            const premiumINR = policy ? (policy.weeklyPremium / 100).toFixed(0) : '';
            const nextDate   = policy ? policy.endDate.toLocaleDateString('en-IN') : '';
            await Promise.all([
              sendWhatsApp(
                contact.phone,
                `✅ Hi ${contact.name}, your RainCheck weekly premium of ₹${premiumINR} has been collected successfully.\n\nYour coverage is active until ${nextDate}.\n\nStay safe on the road! 🛵`,
              ),
              sendPushNotification(
                riderId,
                'Premium renewed ✅',
                `₹${premiumINR} collected. Coverage active until ${nextDate}.`,
              ),
            ]);
          }
        }
        break;
      }

      case 'subscription.paused':
      case 'subscription.halted': {
        // Payment failed — 12-hour grace period, then coverage pauses
        const sub = payload?.subscription?.entity as Record<string, any> | undefined;
        if (sub?.notes?.rider_id) {
          const riderId    = sub.notes.rider_id as string;
          const graceEndsAt = new Date(Date.now() + 12 * 3_600_000);
          await Policy.updateOne(
            { riderId, status: 'Active' },
            { $set: { status: 'PendingPayment', graceEndsAt } },
          );
          const contact = await getRiderContact(riderId);
          if (contact) {
            const graceTime = graceEndsAt.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
            await Promise.all([
              sendWhatsApp(
                contact.phone,
                `⚠️ Hi ${contact.name}, your RainCheck weekly payment failed.\n\n🕐 Grace period: You have 12 hours (until ${graceTime}) to update your payment method.\n\nIf payment is not received, your coverage will be paused.\n\nOpen the app to retry payment.`,
              ),
              sendPushNotification(
                riderId,
                'Payment failed — action needed',
                `12-hour grace period started. Update payment by ${graceTime} to keep coverage.`,
              ),
            ]);
          }
        }
        break;
      }

      case 'subscription.cancelled':
      case 'subscription.completed': {
        // Grace period expired or user cancelled — deactivate policy
        const sub = payload?.subscription?.entity as Record<string, any> | undefined;
        if (sub?.notes?.rider_id) {
          const riderId = sub.notes.rider_id as string;
          await Policy.updateOne(
            { riderId, status: { $in: ['Active', 'PendingPayment'] } },
            { $set: { status: 'Cancelled', autoRenew: false } },
          );
          const contact = await getRiderContact(riderId);
          if (contact) {
            const isExpired = event.event === 'subscription.cancelled';
            await Promise.all([
              sendWhatsApp(
                contact.phone,
                isExpired
                  ? `❌ Hi ${contact.name}, your RainCheck coverage has ended because the grace period expired without payment.\n\nYour policy is now cancelled. Open the app to start a new subscription and restore coverage.`
                  : `✅ Hi ${contact.name}, your RainCheck subscription has been cancelled as requested.\n\nYour coverage remains active until the end of the current week.`,
              ),
              sendPushNotification(
                riderId,
                isExpired ? 'Coverage ended' : 'Subscription cancelled',
                isExpired
                  ? 'Grace period expired. Open app to renew coverage.'
                  : 'Subscription cancelled. Coverage active until end of week.',
              ),
            ]);
          }
        }
        break;
      }

      default:
        break;
    }

    res.json({ success: true });
  },
);

export default router;
