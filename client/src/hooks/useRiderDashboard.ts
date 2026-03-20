'use client';
import { useState, useEffect } from 'react';
import { api } from '@/lib/api';
import { MOCK_RIDER, MOCK_POLICY, MOCK_CLAIMS } from '@/lib/mockData';

export function useRiderDashboard(riderId: string | null) {
  const [rider, setRider] = useState<any>(null);
  const [policy, setPolicy] = useState<any>(null);
  const [claims, setClaims] = useState<any[]>([]);
  const [plans, setPlans] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const isValidObjectId = (id: string) => /^[0-9a-fA-F]{24}$/.test(id);

  useEffect(() => {
    const fetchData = async () => {
      if (!riderId || !isValidObjectId(riderId)) {
        setRider(MOCK_RIDER);
        setPolicy(MOCK_POLICY);
        setClaims(MOCK_CLAIMS.slice(0, 5));
        setLoading(false);
        return;
      }
      try {
        const [dashRes, claimsRes, plansRes] = await Promise.allSettled([
          api.get(`/riders/${riderId}/dashboard`),
          api.get(`/claims/rider/${riderId}?limit=5`),
          api.get('/policies/plans'),
        ]);

        if (dashRes.status === 'fulfilled') {
          const d = (dashRes.value as any).data;
          setRider(d?.rider ?? MOCK_RIDER);
          setPolicy(d?.activePolicy ?? MOCK_POLICY);
        } else {
          setRider(MOCK_RIDER);
          setPolicy(MOCK_POLICY);
        }

        if (claimsRes.status === 'fulfilled') {
          setClaims((claimsRes.value as any).data?.claims ?? MOCK_CLAIMS.slice(0, 5));
        } else {
          setClaims(MOCK_CLAIMS.slice(0, 5));
        }

        if (plansRes.status === 'fulfilled') {
          setPlans((plansRes.value as any).data?.plans ?? []);
        }
      } catch {
        setRider(MOCK_RIDER);
        setPolicy(MOCK_POLICY);
        setClaims(MOCK_CLAIMS.slice(0, 5));
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [riderId]);

  return { rider, policy, claims, plans, loading };
}
