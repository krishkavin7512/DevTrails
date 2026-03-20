import { Request, Response, NextFunction } from 'express';

interface RateRecord {
  count: number;
  resetAt: number;
}

const store = new Map<string, RateRecord>();

// Cleanup stale entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of store.entries()) {
    if (now > record.resetAt) store.delete(key);
  }
}, 5 * 60_000);

export const rateLimiter = (
  limit = 100,
  windowMs = 60_000
) => (req: Request, res: Response, next: NextFunction): void => {
  const ip = req.ip ?? req.socket.remoteAddress ?? 'unknown';
  const now = Date.now();
  const record = store.get(ip);

  if (!record || now > record.resetAt) {
    store.set(ip, { count: 1, resetAt: now + windowMs });
    next();
    return;
  }

  if (record.count >= limit) {
    const retryAfter = Math.ceil((record.resetAt - now) / 1000);
    res.setHeader('Retry-After', retryAfter);
    res.status(429).json({
      success: false,
      error: `Rate limit exceeded. Try again in ${retryAfter}s.`,
    });
    return;
  }

  record.count++;
  next();
};
