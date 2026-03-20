'use client';
import { useState, useEffect, useCallback } from 'react';
import { api } from '@/lib/api';
import { MOCK_CLAIMS } from '@/lib/mockData';

export interface ClaimsFilter {
  status: string;
  triggerType: string;
  page: number;
}

export function useClaims(riderId: string | null, filter: ClaimsFilter) {
  const [claims, setClaims] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  const isValidObjectId = (id: string) => /^[0-9a-fA-F]{24}$/.test(id);

  const fetchClaims = useCallback(async () => {
    setLoading(true);
    try {
      // Skip API if riderId is not a valid MongoDB ObjectId (e.g. demo mode)
      if (riderId && !isValidObjectId(riderId)) throw new Error('demo');

      const params = new URLSearchParams({ page: String(filter.page), limit: '10' });
      if (filter.status && filter.status !== 'All') params.set('status', filter.status);
      if (filter.triggerType && filter.triggerType !== 'All') params.set('triggerType', filter.triggerType);

      let res: any;
      if (riderId) {
        res = await api.get(`/claims/rider/${riderId}?${params}`);
      } else {
        // Admin: get all claims
        res = await api.get(`/claims?${params}`);
      }
      const d = res.data;
      setClaims(d?.claims ?? d?.data ?? MOCK_CLAIMS);
      setTotal(d?.total ?? MOCK_CLAIMS.length);
    } catch {
      // Filter mock data client-side
      let filtered = [...MOCK_CLAIMS];
      if (filter.status !== 'All') filtered = filtered.filter(c => c.status === filter.status);
      if (filter.triggerType !== 'All') filtered = filtered.filter(c => c.triggerType === filter.triggerType);
      setClaims(filtered);
      setTotal(filtered.length);
    } finally {
      setLoading(false);
    }
  }, [riderId, filter.status, filter.triggerType, filter.page]);

  useEffect(() => { fetchClaims(); }, [fetchClaims]);

  return { claims, total, loading, refresh: fetchClaims };
}
