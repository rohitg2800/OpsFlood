import React, { Suspense, lazy, useCallback, useEffect, useMemo, useState } from 'react';
import { CloudRain, Wind, Thermometer, Gauge, Eye, Droplets, RefreshCw, ShieldCheck, AlertTriangle, Radio } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import type { LocationData, WeatherData } from '../weatherWidget';
import { apiUrl } from '../config/api';
import WeatherService from '../weatherService';
import { isLiteMotionDevice } from '../utils/performance';

const LazyWeatherWidget = lazy(() => import('../weatherWidget'));

interface WeatherConsolePanelProps {
  target: string;
  subtitle?: string;
  className?: string;
  coordinates?: { lat: number; lon: number };
}

type WeatherProxyStatus = 'SECURE' | 'DEGRADED' | 'MISSING_KEY' | 'OFFLINE' | 'CHECKING';

const normalizeWeatherLabel = (value: string | null | undefined) =>
  (value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const sameLocation = (left: Partial<LocationData> | null | undefined, right: Partial<LocationData> | null | undefined) =>
  Boolean(
    left &&
      right &&
      left.name === right.name &&
      left.state === right.state &&
      left.lat === right.lat &&
      left.lon === right.lon,
  );

export const WeatherConsolePanel: React.FC<WeatherConsolePanelProps> = ({
  target,
  subtitle,
  className = '',
  coordinates,
}) => {
  const { state, dispatch } = useAppState();
  const weatherSnapshot = state.data.weatherData;
  const coordinateLat = coordinates?.lat;
  const coordinateLon = coordinates?.lon;
  const [proxyStatus, setProxyStatus] = useState<WeatherProxyStatus>('CHECKING');
  const [resolvedDestination, setResolvedDestination] = useState<LocationData | null>(null);
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);
  const destinationCandidates = useMemo(
    () =>
      [
        state.prediction.selectedCity,
        state.form.data.station,
        state.prediction.selectedState,
        state.form.data.state,
        target,
        state.data.locationData?.name,
      ].filter(
        (value, index, source): value is string =>
          Boolean(value && value.trim()) && source.indexOf(value) === index,
      ),
    [
      state.data.locationData?.name,
      state.form.data.state,
      state.form.data.station,
      state.prediction.selectedCity,
      state.prediction.selectedState,
      target,
    ],
  );
  const lockedDestination = (destinationCandidates[0] || target || 'Selected Region').trim();
  const hasSpecificLocationLock = Boolean(
    (state.prediction.selectedCity && state.prediction.selectedCity.trim()) ||
      (state.form.data.station && state.form.data.station.trim()),
  );
  const resolvedNodeLabel = resolvedDestination?.name?.trim() || null;
  const normalizedResolvedNodeLabel = resolvedNodeLabel?.toLowerCase() || '';
  const normalizedLockedDestination = normalizeWeatherLabel(lockedDestination);
  const effectiveCoordinates =
    hasSpecificLocationLock
      ? resolvedDestination
        ? { lat: resolvedDestination.lat, lon: resolvedDestination.lon }
        : undefined
      : resolvedDestination
      ? { lat: resolvedDestination.lat, lon: resolvedDestination.lon }
      : coordinates;
  const weatherSnapshotMatchesLock = Boolean(
    weatherSnapshot &&
      normalizeWeatherLabel(weatherSnapshot.location).includes(normalizedLockedDestination),
  );
  const lockedWeatherSnapshot = weatherSnapshotMatchesLock ? weatherSnapshot : null;
  const showRainOverlay = Boolean(
    lockedWeatherSnapshot &&
      (/(rain|drizzle|thunderstorm)/i.test(String(lockedWeatherSnapshot.weather_condition || '')) ||
        Number(lockedWeatherSnapshot.rain_1h ?? lockedWeatherSnapshot.rain_3h ?? 0) > 0),
  );
  const showResolvedNodeLabel =
    Boolean(resolvedNodeLabel) &&
    normalizedResolvedNodeLabel !== lockedDestination.toLowerCase();
  const widgetResetKey = `${lockedDestination}|${effectiveCoordinates?.lat ?? 'na'}|${effectiveCoordinates?.lon ?? 'na'}`;

  useEffect(() => {
    let cancelled = false;

    const fetchStatus = async () => {
      try {
        const response = await fetch(apiUrl('/weather/status'));
        if (!response.ok) {
          throw new Error(`Status error: ${response.status}`);
        }

        const data = await response.json();
        if (!cancelled) {
          setProxyStatus(
            data?.status === 'SECURE'
              ? 'SECURE'
              : data?.status === 'DEGRADED'
              ? 'DEGRADED'
              : 'MISSING_KEY',
          );
        }
      } catch {
        if (!cancelled) {
          setProxyStatus('OFFLINE');
        }
      }
    };

    fetchStatus();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    const resolveDestination = async () => {
      const coordinateBackedLocation =
        coordinateLat !== undefined && coordinateLon !== undefined
          ? {
              name: lockedDestination,
              lat: coordinateLat,
              lon: coordinateLon,
              country: 'IN',
              state: state.prediction.selectedState || state.form.data.state || undefined,
            }
          : null;

      if (hasSpecificLocationLock) {
        const exactLockedLocation = await WeatherService.resolveLocation(lockedDestination);
        if (exactLockedLocation) {
          if (!cancelled) {
            setResolvedDestination((current) =>
              sameLocation(current, exactLockedLocation) ? current : exactLockedLocation,
            );
          }
          return;
        }
      }

      if (coordinateBackedLocation) {
        if (!cancelled) {
          setResolvedDestination((current) =>
            sameLocation(current, coordinateBackedLocation) ? current : coordinateBackedLocation,
          );
        }
        return;
      }

      for (const candidate of destinationCandidates) {
        if (normalizeWeatherLabel(candidate) === normalizedLockedDestination) {
          continue;
        }
        const resolved = await WeatherService.resolveLocation(candidate);
        if (resolved) {
          if (!cancelled) {
            setResolvedDestination((current) => (sameLocation(current, resolved) ? current : resolved));
          }
          return;
        }
      }

      if (!cancelled) {
        setResolvedDestination(null);
      }
    };

    void resolveDestination();

    return () => {
      cancelled = true;
    };
  }, [
    coordinateLat,
    coordinateLon,
    destinationCandidates,
    hasSpecificLocationLock,
    lockedDestination,
    normalizedLockedDestination,
    state.form.data.state,
    state.prediction.selectedState,
  ]);

  const handleWeatherSelect = useCallback((weatherData: WeatherData) => {
    dispatch({ type: 'SET_WEATHER_DATA', payload: weatherData });
  }, [dispatch]);

  const handleLocationSelect = useCallback((location: LocationData) => {
    dispatch({ type: 'SET_LOCATION_DATA', payload: location });
  }, [dispatch]);

  const statusMeta =
    proxyStatus === 'SECURE'
      ? {
          icon: ShieldCheck,
          label: 'Weather API: SECURE',
          tone: 'bg-emerald-500/10 text-emerald-300',
        }
      : proxyStatus === 'DEGRADED'
      ? {
          icon: AlertTriangle,
          label: 'Weather API: DEGRADED',
          tone: 'bg-amber-500/10 text-amber-300',
        }
      : proxyStatus === 'MISSING_KEY'
      ? {
          icon: AlertTriangle,
          label: 'Weather API: MISSING KEY',
          tone: 'bg-amber-500/10 text-amber-300',
        }
      : proxyStatus === 'OFFLINE'
      ? {
          icon: AlertTriangle,
          label: 'Weather API: OFFLINE',
          tone: 'bg-[#ff0037]/10 text-[#ff9eb1]',
        }
      : {
          icon: Radio,
          label: 'Weather API: CHECKING',
          tone: 'bg-white/[0.05] text-stone-300',
        };
  const StatusIcon = statusMeta.icon;

  return (
    <div
      className={`${className} ${liteMotion ? 'weather-console-lite' : ''} weather-console-shell relative overflow-hidden rounded-[1.75rem] border-0 ring-0 bg-[linear-gradient(145deg,rgba(255,255,255,0.03),rgba(10,12,16,0.18)_28%,rgba(6,9,12,0.08)_100%)] p-6 ${liteMotion ? 'shadow-[0_14px_36px_rgba(0,0,0,0.16)] backdrop-blur-md' : 'shadow-[0_28px_80px_rgba(0,0,0,0.24)] backdrop-blur-[24px]'} sm:p-8`}
    >
      <style>{`
        @keyframes weather-console-drift {
          0%, 100% { transform: translate3d(0, 0, 0); }
          50% { transform: translate3d(0, -4px, 0); }
        }
        @keyframes weather-console-scan {
          0% { transform: translateX(-120%); opacity: 0; }
          18% { opacity: 0.28; }
          100% { transform: translateX(120%); opacity: 0; }
        }
        @keyframes weather-console-glow {
          0%, 100% { opacity: 0.32; }
          50% { opacity: 0.58; }
        }
        @keyframes weather-chip-breathe {
          0%, 100% { transform: translateY(0); box-shadow: 0 0 0 rgba(255,255,255,0); }
          50% { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(255, 127, 150, 0.1); }
        }
        @keyframes weather-console-rain-fall {
          0% { transform: translate3d(10px, -18%, 0) rotate(12deg); opacity: 0; }
          12% { opacity: 0.82; }
          100% { transform: translate3d(-26px, 155px, 0) rotate(12deg); opacity: 0; }
        }
        .weather-console-shell::before {
          content: '';
          position: absolute;
          inset: 0;
          background:
            radial-gradient(circle at 16% 20%, rgba(255,255,255,0.08), transparent 24%),
            radial-gradient(circle at 82% 18%, rgba(255,127,150,0.12), transparent 26%),
            linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0));
          animation: weather-console-glow 8s ease-in-out infinite;
          pointer-events: none;
        }
        .weather-console-shell::after {
          content: '';
          position: absolute;
          top: 0;
          bottom: 0;
          width: 22%;
          background: linear-gradient(90deg, transparent, rgba(255,255,255,0.08), transparent);
          filter: blur(10px);
          animation: weather-console-scan 10s linear infinite;
          pointer-events: none;
        }
        .weather-console-float {
          animation: weather-console-drift 7.5s ease-in-out infinite;
        }
        .weather-chip-float {
          animation: weather-chip-breathe 4.6s ease-in-out infinite;
        }
        .weather-console-rain {
          animation: weather-console-rain-fall linear infinite;
        }
        .weather-console-lite::after {
          display: none;
        }
        .weather-console-lite::before {
          animation: none;
          opacity: 0.58;
        }
        .weather-console-lite .weather-console-float,
        .weather-console-lite .weather-chip-float,
        .weather-console-lite .weather-console-rain {
          animation: none !important;
        }
        @media (prefers-reduced-motion: reduce) {
          .weather-console-shell::before,
          .weather-console-shell::after,
          .weather-console-float,
          .weather-chip-float,
          .weather-console-rain {
            animation: none !important;
          }
        }
      `}</style>

      <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.04),transparent_24%,rgba(255,255,255,0.015)_72%,transparent)] pointer-events-none" />
      <div className="absolute inset-x-8 top-0 h-px bg-gradient-to-r from-transparent via-white/30 to-transparent pointer-events-none" />
      {showRainOverlay ? (
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          {Array.from({ length: liteMotion ? 14 : 34 }).map((_, index) => (
            <span
              key={`console-rain-${index}`}
              className="weather-console-rain absolute top-[-20%] h-14 w-[1.5px] rounded-full bg-gradient-to-b from-[#dff0ff]/0 via-[#dff0ff]/88 to-[#73b9ff]/0"
              style={{
                left: `${2 + (index * 3.1) % 98}%`,
                animationDelay: `${(index % 9) * 0.16}s`,
                animationDuration: `${0.9 + (index % 5) * 0.14}s`,
                opacity: 0.26 + (index % 4) * 0.12,
              }}
            />
          ))}
        </div>
      ) : null}

      <div className="weather-console-float relative z-10 mb-8 flex flex-col items-center gap-4 pb-6 text-center">
        <div className="space-y-2">
          <h3 className="flex items-center justify-center gap-3 text-xs font-black uppercase tracking-[0.3em] text-[#ff7f96]">
            <CloudRain size={18} /> Weather Console
          </h3>
          <p className="text-sm text-stone-400">
            {subtitle || (
              <>
                Atmospheric conditions for <span className="font-black text-white">{lockedDestination}</span>.
              </>
            )}
          </p>
          {destinationCandidates.length ? (
            <div className="text-[10px] font-mono uppercase tracking-[0.16em] text-white/45">
              Destination lock: <span className="text-white/70">{lockedDestination}</span>
              {showResolvedNodeLabel ? (
                <span className="text-stone-400">{' // weather node '}{resolvedNodeLabel}</span>
              ) : null}
            </div>
          ) : null}
          <div className={`weather-chip-float inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.2em] ${liteMotion ? '' : 'backdrop-blur-md'} ${statusMeta.tone}`}>
            <StatusIcon size={12} className={proxyStatus === 'CHECKING' ? 'animate-pulse' : ''} />
            <span>{statusMeta.label}</span>
          </div>
        </div>
        <div className={`weather-chip-float inline-flex w-fit items-center gap-2 rounded-full bg-[#ff0037]/8 px-4 py-2 text-[10px] font-black uppercase tracking-[0.22em] text-[#ff9eb1] ${liteMotion ? '' : 'backdrop-blur-md'}`}>
          <Wind size={14} className={!state.data.weatherLastUpdate ? 'animate-pulse' : ''} />
          {state.data.weatherLastUpdate
            ? `Last Weather Load ${new Date(state.data.weatherLastUpdate).toLocaleTimeString('en-US', { hour12: false })}`
            : 'Manual Refresh Ready'}
        </div>
      </div>

      <Suspense
        fallback={
          <div className={`flex h-40 items-center justify-center rounded-[2rem] bg-black/25 ${liteMotion ? '' : 'backdrop-blur-xl'}`}>
            <RefreshCw className="h-6 w-6 animate-spin text-[#ff0037]" />
          </div>
        }
      >
        <LazyWeatherWidget
          key={widgetResetKey}
          city={lockedDestination}
          displayLocation={lockedDestination}
          coordinates={effectiveCoordinates}
          onWeatherSelect={handleWeatherSelect}
          onLocationSelect={handleLocationSelect}
          autoRefresh={false}
          showLocationName
          showDetailedInfo={false}
          showMetaStrip={false}
        />
      </Suspense>

      {lockedWeatherSnapshot ? (
        <div className="relative z-10 mt-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
          <div className={`weather-chip-float rounded-2xl bg-white/[0.035] p-4 ${liteMotion ? '' : 'shadow-[inset_0_1px_0_rgba(255,255,255,0.06)] backdrop-blur-md'}`}>
            <div className="flex items-center gap-2 text-[9px] font-black uppercase tracking-[0.22em] text-stone-500">
              <Thermometer size={12} className="text-[#ff7f96]" />
              Feels Like
            </div>
            <div className="mt-3 text-2xl font-black font-mono text-white">
              {Number(lockedWeatherSnapshot.feels_like || lockedWeatherSnapshot.temperature || 0).toFixed(0)}°C
            </div>
          </div>
          <div className={`weather-chip-float rounded-2xl bg-white/[0.035] p-4 ${liteMotion ? '' : 'shadow-[inset_0_1px_0_rgba(255,255,255,0.06)] backdrop-blur-md'}`} style={{ animationDelay: '0.35s' }}>
            <div className="flex items-center gap-2 text-[9px] font-black uppercase tracking-[0.22em] text-stone-500">
              <Gauge size={12} className="text-[#ff7f96]" />
              Pressure
            </div>
            <div className="mt-3 text-2xl font-black font-mono text-white">
              {Number(lockedWeatherSnapshot.pressure || 0).toFixed(0)} <span className="text-xs text-stone-500">hPa</span>
            </div>
          </div>
          <div className={`weather-chip-float rounded-2xl bg-white/[0.035] p-4 ${liteMotion ? '' : 'shadow-[inset_0_1px_0_rgba(255,255,255,0.06)] backdrop-blur-md'}`} style={{ animationDelay: '0.7s' }}>
            <div className="flex items-center gap-2 text-[9px] font-black uppercase tracking-[0.22em] text-stone-500">
              <Eye size={12} className="text-[#ff7f96]" />
              Cloud Cover
            </div>
            <div className="mt-3 text-2xl font-black font-mono text-white">
              {Number(lockedWeatherSnapshot.clouds || 0).toFixed(0)}%
            </div>
          </div>
          <div className={`weather-chip-float rounded-2xl bg-white/[0.035] p-4 ${liteMotion ? '' : 'shadow-[inset_0_1px_0_rgba(255,255,255,0.06)] backdrop-blur-md'}`} style={{ animationDelay: '1.05s' }}>
            <div className="flex items-center gap-2 text-[9px] font-black uppercase tracking-[0.22em] text-stone-500">
              <Droplets size={12} className="text-[#ff7f96]" />
              Precip Pulse
            </div>
            <div className="mt-3 text-2xl font-black font-mono text-white">
              {Number(lockedWeatherSnapshot.rain_1h ?? lockedWeatherSnapshot.rain_3h ?? 0).toFixed(1)} <span className="text-xs text-stone-500">mm</span>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
};

export default WeatherConsolePanel;
