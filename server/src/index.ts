import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';

dotenv.config();

import { connectDB } from './config/database';
import { errorHandler } from './middleware/errorHandler';
import { rateLimiter } from './middleware/rateLimiter';
import riderRoutes      from './routes/riderRoutes';
import policyRoutes     from './routes/policyRoutes';
import claimRoutes      from './routes/claimRoutes';
import weatherRoutes    from './routes/weatherRoutes';
import disruptionRoutes from './routes/disruptionRoutes';
import analyticsRoutes  from './routes/analyticsRoutes';
import triggerRoutes    from './routes/triggerRoutes';
import adminRoutes      from './routes/adminRoutes';

const app  = express();
const PORT = process.env.PORT || 5000;

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin:      process.env.CLIENT_URL || 'http://localhost:3000',
  credentials: true,
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(rateLimiter(200, 60_000)); // 200 req/min per IP

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({
    success: true,
    data: {
      status:    'ok',
      service:   'raincheck-api',
      version:   '1.0.0',
      timestamp: new Date().toISOString(),
      env:       process.env.NODE_ENV ?? 'development',
    },
  });
});

app.get('/api', (_req, res) => {
  res.json({
    success: true,
    data: {
      message: 'RainCheck API v1.0',
      endpoints: [
        'GET  /health',
        'POST /api/riders/register',
        'GET  /api/riders/:id',
        'GET  /api/riders/:id/dashboard',
        'POST /api/policies/create',
        'GET  /api/policies/plans',
        'POST /api/claims/initiate',
        'GET  /api/claims/stats',
        'GET  /api/weather/current/:city',
        'GET  /api/weather/check-triggers/:city',
        'GET  /api/disruptions/active',
        'POST /api/disruptions/trigger',
        'GET  /api/analytics/overview',
        'GET  /api/analytics/claims-trend',
      ],
    },
  });
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/riders',      riderRoutes);
app.use('/api/policies',    policyRoutes);
app.use('/api/claims',      claimRoutes);
app.use('/api/weather',     weatherRoutes);
app.use('/api/disruptions', disruptionRoutes);
app.use('/api/analytics',   analyticsRoutes);
app.use('/api/triggers',    triggerRoutes);
app.use('/api/admin',       adminRoutes);

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Route not found' });
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start ─────────────────────────────────────────────────────────────────────
async function start() {
  try {
    await connectDB();
  } catch {
    console.warn('⚠️  MongoDB not available — running without database (mock mode)');
  }

  app.listen(PORT, () => {
    console.log(`🚀 RainCheck API  →  http://localhost:${PORT}`);
    console.log(`📋 API index      →  http://localhost:${PORT}/api`);
    console.log(`💚 Health check   →  http://localhost:${PORT}/health`);
  });
}

start();
export default app;
