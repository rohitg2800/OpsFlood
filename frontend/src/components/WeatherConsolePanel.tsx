import React, { Suspense, lazy, useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  CloudRain,
  Droplets,
  Eye,
  Gauge,
  Radio,
  RefreshCw,
  ShieldCheck,
  Thermometer,
  Wind,
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import type { LocationData, WeatherData } from '../weatherWidget';
import { apiUrl } from '../config/api';
import { normalizeGeoKey, resolveGeoCoordinate } from '../data/geoCoordinates';
import WeatherService from '../weatherService';
import { formatTemperatureScale } from '../utils/temperature';
import {
  ConsolePanel,
  EmptyState,
  InsetPanel,
  MetricTile,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from './OpsPrimitives';

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

const describeCloudCover = (value: number): string => {
  if (value <= 10) return 'Open sky window';
  if (value <= 35) return 'Light cloud layer';
  if (value <= 70) return 'Partial overcast';
  return 'Dense cloud canopy';
};

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
  const specificLocationLock = (state.prediction.selectedCity || state.form.data.station || '').trim();
  const resolvedSpecificLocationLock = useMemo(
    () => resolveGeoCoordinate(state.prediction.selectedCity, state.form.data.station),
    [state.form.data.station, state.prediction.selectedCity],
  );
  const resolvedStateLock = useMemo(
    () => resolveGeoCoordinate(state.prediction.selectedState, state.form.data.state),
    [state.form.data.state, state.prediction.selectedState],
  );
  const shouldUseSpecificLocationLock = useMemo(() => {
    if (!specificLocationLock || !resolvedSpecificLocationLock) {
      return false;
    }

    if (!resolvedStateLock?.state || !resolvedSpecificLocationLock.state) {
      return true;
    }

    return normalizeGeoKey(resolvedSpecificLocationLock.state) === normalizeGeoKey(resolvedStateLock.state);
  }, [resolvedSpecificLocationLock, resolvedStateLock?.state, specificLocationLock]);
  const destinationCandidates = useMemo(
    () =>
      [
        shouldUseSpecificLocationLock ? specificLocationLock : '',
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
      shouldUseSpecificLocationLock,
      specificLocationLock,
      target,
    ],
  );
  const lockedDestination = (destinationCandidates[0] || target || 'Selected Region').trim();
  const hasSpecificLocationLock = shouldUseSpecificLocationLock;
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
  const showResolvedNodeLabel =
    Boolean(resolvedNodeLabel) &&
    normalizedResolvedNodeLabel !== lockedDestination.toLowerCase();
  const widgetResetKey = `${lockedDestination}|${effectiveCoordinates?.lat ?? 'na'}|${effectiveCoordinates?.lon ?? 'na'}`;
  const feelsLikeScale = useMemo(
    () =>
      formatTemperatureScale(
        lockedWeatherSnapshot?.feels_like ?? lockedWeatherSnapshot?.temperature,
      ),
    [lockedWeatherSnapshot?.feels_like, lockedWeatherSnapshot?.temperature],
  );
  const minTemperatureScale = useMemo(
    () => formatTemperatureScale(lockedWeatherSnapshot?.temp_min ?? lockedWeatherSnapshot?.temperature),
    [lockedWeatherSnapshot?.temp_min, lockedWeatherSnapshot?.temperature],
  );
  const maxTemperatureScale = useMemo(
    () => formatTemperatureScale(lockedWeatherSnapshot?.temp_max ?? lockedWeatherSnapshot?.temperature),
    [lockedWeatherSnapshot?.temp_max, lockedWeatherSnapshot?.temperature],
  );
  const cloudCoverPercent = useMemo(
    () => Math.max(0, Math.min(100, Math.round(Number(lockedWeatherSnapshot?.clouds ?? 0)))),
    [lockedWeatherSnapshot?.clouds],
  );
  const cloudCoverLabel = useMemo(
    () => describeCloudCover(cloudCoverPercent),
    [cloudCoverPercent],
  );

  useEffect(() => {
    let cancelled = false;

    const fetchStatus = async () => {
      try {
        const response = await fetch(apiUrl('/weather/status'));
        if (!response.ok) {
          throw new Error('Weather status unavailable');
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

    void fetchStatus();

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
          label: 'Weather API secure',
          tone: 'success' as const,
        }
      : proxyStatus === 'DEGRADED'
      ? {
          icon: AlertTriangle,
          label: 'Weather API degraded',
          tone: 'warning' as const,
        }
      : proxyStatus === 'MISSING_KEY'
      ? {
          icon: AlertTriangle,
          label: 'Weather key missing',
          tone: 'warning' as const,
        }
      : proxyStatus === 'OFFLINE'
      ? {
          icon: AlertTriangle,
          label: 'Weather API offline',
          tone: 'danger' as const,
        }
      : {
          icon: Radio,
          label: 'Weather API checking',
          tone: 'neutral' as const,
        };
  const StatusIcon = statusMeta.icon;

  return (
    <ConsolePanel intensity="secondary" className={className}>
      <SectionHeader
        eyebrow="Weather context"
        title="Regional weather console"
        description={
          subtitle || `Atmospheric conditions for ${lockedDestination} aligned with the active operating scope.`
        }
        icon={CloudRain}
        action={
          <>
            <StatusBadge tone={statusMeta.tone} icon={StatusIcon}>
              {statusMeta.label}
            </StatusBadge>
            <StatusBadge tone="neutral" icon={Wind}>
              {state.data.weatherLastUpdate
                ? `Updated ${new Date(state.data.weatherLastUpdate).toLocaleTimeString('en-US', { hour12: false })}`
                : 'Awaiting weather sync'}
            </StatusBadge>
          </>
        }
        className="mb-6"
      />

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_20rem]">
        <InsetPanel variant="soft" className="overflow-hidden p-0">
          <div className="px-5 py-4">
            <div className={opsLabelClass}>Locked location</div>
            <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
              {lockedDestination}
            </div>
            <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
              {showResolvedNodeLabel
                ? `Weather node resolved to ${resolvedNodeLabel}.`
                : 'Weather data is pinned to the current command scope.'}
            </div>
          </div>

          <div className="p-4 sm:p-5">
            <Suspense
              fallback={
                <div className="flex h-40 items-center justify-center rounded-2xl bg-black/20 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                  <RefreshCw className="h-5 w-5 animate-spin text-[color:var(--ops-info)]" />
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
          </div>
        </InsetPanel>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
          <MetricTile
            label="Resolved node"
            value={resolvedDestination?.name || lockedDestination}
            hint={
              resolvedDestination?.state
                ? `${resolvedDestination.state}, ${resolvedDestination.country || 'IN'}`
                : 'Using the selected regional target'
            }
            tone="info"
            framed
            frameTone="cyan"
          />

          <InsetPanel variant="soft" className="space-y-3">
            <div className={opsLabelClass}>Context notes</div>
            <div className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
              {hasSpecificLocationLock
                ? 'A direct city or station lock is active, so weather resolution favors the exact operational target first.'
                : 'No station-level lock is active, so the panel is using the broader regional context to keep supporting weather visible.'}
            </div>
            {effectiveCoordinates ? (
              <div className="rounded-xl bg-black/20 px-3 py-3 text-sm text-[color:var(--ops-text-soft)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                Coordinates {effectiveCoordinates.lat.toFixed(4)}, {effectiveCoordinates.lon.toFixed(4)}
              </div>
            ) : null}
          </InsetPanel>
        </div>
      </div>

      {lockedWeatherSnapshot ? (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <MetricTile
            label="Feels like"
            value={feelsLikeScale.celsius}
            hint={feelsLikeScale.fahrenheit}
            icon={Thermometer}
            tone="info"
          />
          <MetricTile
            label="Min / max"
            value={`${minTemperatureScale.celsius} / ${maxTemperatureScale.celsius}`}
            hint={`${minTemperatureScale.fahrenheit} / ${maxTemperatureScale.fahrenheit}`}
            icon={Thermometer}
            tone="neutral"
          />
          <MetricTile
            label="Pressure"
            value={`${Number(lockedWeatherSnapshot.pressure || 0).toFixed(0)} hPa`}
            hint={String(lockedWeatherSnapshot.weather_condition || 'Atmospheric reading')}
            icon={Gauge}
            tone="neutral"
          />
          <MetricTile
            label="Cloud cover"
            value={`${cloudCoverPercent}%`}
            hint={cloudCoverLabel}
            icon={Eye}
            tone="info"
          />
          <MetricTile
            label="Precipitation"
            value={`${Number(lockedWeatherSnapshot.rain_1h ?? lockedWeatherSnapshot.rain_3h ?? 0).toFixed(1)} mm`}
            hint="Rolling rainfall signal"
            icon={Droplets}
            tone={Number(lockedWeatherSnapshot.rain_1h ?? lockedWeatherSnapshot.rain_3h ?? 0) > 0 ? 'warning' : 'neutral'}
          />
          <MetricTile
            label="Wind"
            value={`${Number(lockedWeatherSnapshot.wind_speed || 0).toFixed(1)} m/s`}
            hint={String(lockedWeatherSnapshot.location || lockedDestination)}
            icon={Wind}
            tone="neutral"
          />
        </div>
      ) : (
        <div className="mt-6">
          <EmptyState
            title="Weather detail is still resolving"
            description="The panel can still keep the location lock and weather service status visible while the detailed snapshot hydrates. This avoids dropping into an unexplained empty panel."
            icon={CloudRain}
          />
        </div>
      )}
    </ConsolePanel>
  );
};

export default WeatherConsolePanel;
