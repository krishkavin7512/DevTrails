'use client';
import { useState, useEffect } from 'react';
import { api } from '@/lib/api';
import { MOCK_ANALYTICS, MOCK_DISRUPTIONS } from '@/lib/mockData';

export function useAnalytics() {
  const [overview, setOverview] = useState<any>(null);
  const [weeklyTrend, setWeeklyTrend] = useState<any[]>([]);
  const [claimsByType, setClaimsByType] = useState<any[]>([]);
  const [riskDistribution, setRiskDistribution] = useState<any[]>([]);
  const [disruptions, setDisruptions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAll = async () => {
      try {
        const [overviewRes, revenueRes, claimsTypeRes, riskRes, disruptRes] = await Promise.allSettled([
          api.get('/analytics/overview'),
          api.get('/analytics/revenue'),
          api.get('/analytics/claims-trend'),
          api.get('/analytics/risk-distribution'),
          api.get('/disruptions/active'),
        ]);

        setOverview(overviewRes.status === 'fulfilled' ? (overviewRes.value as any).data : MOCK_ANALYTICS.overview);
        setWeeklyTrend(revenueRes.status === 'fulfilled' ? (revenueRes.value as any).data?.weeks ?? MOCK_ANALYTICS.weeklyTrend : MOCK_ANALYTICS.weeklyTrend);
        setClaimsByType(claimsTypeRes.status === 'fulfilled' ? (claimsTypeRes.value as any).data?.byTrigger ?? MOCK_ANALYTICS.claimsByType : MOCK_ANALYTICS.claimsByType);
        setRiskDistribution(riskRes.status === 'fulfilled' ? (riskRes.value as any).data?.tiers ?? MOCK_ANALYTICS.riskDistribution : MOCK_ANALYTICS.riskDistribution);
        setDisruptions(disruptRes.status === 'fulfilled' ? (disruptRes.value as any).data?.events ?? MOCK_DISRUPTIONS : MOCK_DISRUPTIONS);
      } catch {
        setOverview(MOCK_ANALYTICS.overview);
        setWeeklyTrend(MOCK_ANALYTICS.weeklyTrend);
        setClaimsByType(MOCK_ANALYTICS.claimsByType);
        setRiskDistribution(MOCK_ANALYTICS.riskDistribution);
        setDisruptions(MOCK_DISRUPTIONS);
      } finally {
        setLoading(false);
      }
    };

    fetchAll();
  }, []);

  return { overview, weeklyTrend, claimsByType, riskDistribution, disruptions, loading };
}
