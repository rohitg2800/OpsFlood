import { useEffect, useState, useCallback } from 'react';
import { apiUrl } from '../config/api';
import type { LiveTelemetryResponse, SensorNode } from '../types/telemetry';

interface UseLiveTelemetryOptions {
  state?: string;
  station?: string;
  limit?: number;
  /** Pass allowLiveCWC from useHealth — telemetry fetch is skipped when false */
  enabled: boolean;
  autoRefreshMs?: number;
}

export function useLiveTelemetry({
  state = 'Maharashtra',
  station = 'Kolhapur',
  limit = 6,
  enabled,
  autoRefreshMs = 30_000,
}: UseLiveTelemetryOptions) {
  const [data, setData] = useState<SensorNode[]>([]);
  const [response, setResponse] = useState<LiveTelemetryResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastFetched, setLastFetched] = useState<Date | null>(null);

  const fetch_ = useCallback(async () => {
    if (!enabled) return;
    setLoading(true);
    setError(null);
    try {
      const url = apiUrl(`/api/live-telemetry?state=${encodeURIComponent(state)}&station=${encodeURIComponent(station)}&limit=${limit}`);
      const res = await fetch(url, { method: 'GET' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json: LiveTelemetryResponse = await res.json();
      setResponse(json);
      // Backend may nest sensors under json.data or return flat array
      const nodes = Array.isArray(json.data) ? json.data : [];
      setData(nodes);
      setLastFetched(new Date());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Telemetry fetch failed');
    } finally {
      setLoading(false);
    }
  }, [enabled, state, station, limit]);

  useEffect(() => {
    void fetch_();
    if (!enabled) return;
    const id = setInterval(() => void fetch_(), autoRefreshMs);
    return () => clearInterval(id);
  }, [fetch_, enabled, autoRefreshMs]);

  return { data, response, loading, error, lastFetched, refresh: fetch_ };
}
