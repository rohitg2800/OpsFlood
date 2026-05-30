import { useEffect, useState, useCallback } from 'react';
import { apiUrl } from '../config/api';
import type { HealthResponse } from '../types/health';

export type HealthStatus = 'loading' | 'online' | 'offline' | 'error';

export function useHealth() {
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [status, setStatus] = useState<HealthStatus>('loading');
  const [error, setError] = useState<string | null>(null);

  const fetchHealth = useCallback(async () => {
    setStatus('loading');
    setError(null);
    try {
      const res = await fetch(apiUrl('/health'), {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: HealthResponse = await res.json();
      setHealth(data);
      setStatus(data.status === 'ok' ? 'online' : 'error');
    } catch (err) {
      setStatus('offline');
      setError(err instanceof Error ? err.message : 'Network error');
    }
  }, []);

  useEffect(() => {
    void fetchHealth();
    // Re-poll every 60 seconds
    const id = setInterval(() => void fetchHealth(), 60_000);
    return () => clearInterval(id);
  }, [fetchHealth]);

  const allowLiveCWC = health?.source_policy?.allow_live_cwc_in_app ?? false;
  const policyLabel = health?.source_policy?.label ?? null;
  const policyMode = health?.source_policy?.mode ?? null;
  const telemetryMode = health?.source_policy?.telemetry_mode ?? null;
  const modelReady = health?.model_ready ?? false;

  return { health, status, error, allowLiveCWC, policyLabel, policyMode, telemetryMode, modelReady, refresh: fetchHealth };
}
