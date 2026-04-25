import React, { useEffect, useMemo } from 'react';
/// <reference types="react" />
import { Crosshair, Map as MapIcon, MapPin, Navigation2, Radar, Waves } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { PageShell, PageHero } from '../components/PageShell';
import { CWCLiveDataDisplay } from '../components/CWCLiveDataDisplay';
import { locationMatchesCandidate, normalizeGeoKey, resolveGeoCoordinate } from '../data/geoCoordinates';
import { WeatherConsolePanel } from '../components/WeatherConsolePanel';
import { LayeredNeuralGraph } from '../components/LayeredNeuralGraph';
import { ProbabilityHeartbeatSparkline } from '../components/ProbabilityLaneHeartbeat';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  InsetPanel,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from '../components/OpsPrimitives';

type LaneConfig = {
  key: string;
  label: string;
  shortLabel: string;
  value: number;
  fill: string;
  tone: 'success' | 'info' | 'warning' | 'danger';
};

const clampCoordinate = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const buildOpenStreetMapEmbed = (lat: number, lon: number) => {
  const latDelta = 0.16;
  const lonDelta = 0.22;
  const minLon = clampCoordinate(lon - lonDelta, -180, 180);
  const minLat = clampCoordinate(lat - latDelta, -90, 90);
  const maxLon = clampCoordinate(lon + lonDelta, -180, 180);
  const maxLat = clampCoordinate(lat + latDelta, -90, 90);

  return `https://www.openstreetmap.org/export/embed.html?bbox=${minLon}%2C${minLat}%2C${maxLon}%2C${maxLat}&layer=mapnik&marker=${lat}%2C${lon}`;
};

const buildOpenStreetMapLaunchHref = (lat: number, lon: number) =>
  `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lon}#map=11/${lat}/${lon}`;

export const GeoSpatialPage: React.FC = () => {
  const { state, dispatch } = useAppState();

  const lockedMatrixState =
    state.prediction.selectedState ||
    state.form.data.state ||
    'Awaiting input';
  const rawStationFocus = state.prediction.selectedCity || state.form.data.station || '';
  const stateMappedLocation = useMemo(
    () =>
      resolveGeoCoordinate(
        state.prediction.selectedState,
        state.form.data.state,
      ),
    [state.form.data.state, state.prediction.selectedState],
  );
  const focusedStationLocation = useMemo(
    () => resolveGeoCoordinate(state.prediction.selectedCity, state.form.data.station),
    [state.form.data.station, state.prediction.selectedCity],
  );
  const stationFocus = useMemo(() => {
    if (!rawStationFocus || !focusedStationLocation) {
      return '';
    }

    if (!stateMappedLocation?.state || !focusedStationLocation.state) {
      return rawStationFocus;
    }

    return normalizeGeoKey(focusedStationLocation.state) === normalizeGeoKey(stateMappedLocation.state)
      ? rawStationFocus
      : '';
  }, [focusedStationLocation, rawStationFocus, stateMappedLocation?.state]);
  const inputLocationLabel =
    stationFocus ||
    lockedMatrixState ||
    'Awaiting input';
  const targetLocationLabel = stationFocus || inputLocationLabel;

  const resolvedLocation = useMemo(() => {
    if (stationFocus && focusedStationLocation) {
      return focusedStationLocation;
    }

    if (rawStationFocus && locationMatchesCandidate(state.data.locationData, rawStationFocus)) {
      const currentLocationState = normalizeGeoKey(state.data.locationData?.state || '');
      const mappedState = normalizeGeoKey(stateMappedLocation?.state || '');
      if (!mappedState || !currentLocationState || mappedState === currentLocationState) {
        return state.data.locationData;
      }
    }

    if (stateMappedLocation) return stateMappedLocation;

    if (state.data.locationData?.lat && state.data.locationData?.lon) {
      return state.data.locationData;
    }

    return null;
  }, [
    state.data.locationData,
    state.form.data.state,
    state.form.data.station,
    state.prediction.selectedCity,
    state.prediction.selectedState,
    focusedStationLocation,
    rawStationFocus,
    stateMappedLocation,
    stationFocus,
  ]);

  useEffect(() => {
    if (!resolvedLocation) return;
    const current = state.data.locationData;
    if (
      current?.lat === resolvedLocation.lat &&
      current?.lon === resolvedLocation.lon &&
      current?.name === resolvedLocation.name
    ) {
      return;
    }

    dispatch({ type: 'SET_LOCATION_DATA', payload: resolvedLocation });
  }, [dispatch, resolvedLocation, state.data.locationData]);

  const lat = resolvedLocation?.lat;
  const lon = resolvedLocation?.lon;
  const hasMapTarget = Boolean(targetLocationLabel && targetLocationLabel !== 'Awaiting input');
  const weatherTarget = targetLocationLabel || lockedMatrixState || 'Selected Region';
  const hasResolvedCoordinates = typeof lat === 'number' && typeof lon === 'number';
  const weatherCoordinates = useMemo(
    () => (hasResolvedCoordinates ? { lat: lat as number, lon: lon as number } : undefined),
    [hasResolvedCoordinates, lat, lon],
  );
  const mapQuery = stationFocus
    ? `${stationFocus}${lockedMatrixState && lockedMatrixState !== 'Awaiting input' ? `, ${lockedMatrixState}` : ''}`
    : resolvedLocation
    ? `${resolvedLocation.name}${resolvedLocation.state ? `, ${resolvedLocation.state}` : ''}`
    : lockedMatrixState;
  const mapEmbedSrc = hasResolvedCoordinates ? buildOpenStreetMapEmbed(lat as number, lon as number) : null;
  const mapLaunchHref = hasResolvedCoordinates
    ? buildOpenStreetMapLaunchHref(lat as number, lon as number)
    : `https://www.openstreetmap.org/search?query=${encodeURIComponent(mapQuery)}`;
  const probabilityLanes = useMemo(() => deriveProbabilityLanes(state.prediction.currentPrediction), [state.prediction.currentPrediction]);
  const dominantProbabilityLane = useMemo(() => getDominantProbabilityLane(probabilityLanes), [probabilityLanes]);
  const laneConfig = useMemo(() => ([
    { key: 'low', label: 'LOW', shortLabel: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1', tone: 'success' as const },
    { key: 'moderate', label: 'MODERATE', shortLabel: 'MOD', value: probabilityLanes.moderate, fill: '#4c7cff', tone: 'info' as const },
    { key: 'severe', label: 'SEVERE', shortLabel: 'SEV', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'warning' as const },
    { key: 'critical', label: 'CRITICAL', shortLabel: 'CRT', value: probabilityLanes.critical, fill: '#ff5f7e', tone: 'danger' as const },
  ]), [probabilityLanes]);
  const dominantLaneConfig = laneConfig.find((lane) => lane.label === dominantProbabilityLane[0]) || laneConfig[0];

  return (
    <PageShell>
      <PageHero
        eyebrow="Tactical Mapping Console"
        title="Geo-Spatial Console"
        subtitle="The selected state matrix is the primary geographic lock here, with optional station focus layered on top."
        icon={Navigation2}
        action={<StatusBadge tone="info">Sector lock {lockedMatrixState}</StatusBadge>}
      />

      <WeatherConsolePanel
        target={weatherTarget}
        coordinates={weatherCoordinates}
        subtitle={`Atmospheric conditions for ${weatherTarget} linked to the current geo lock.`}
      />

      <div className="grid gap-6 lg:grid-cols-12">
        <div className="space-y-6 lg:col-span-4">
          <ConsolePanel intensity="secondary">
            <SectionHeader
              eyebrow="Position"
              title={targetLocationLabel}
              description="The geo console reflects the active state lock first, then narrows to a city or station focus when one is present."
              icon={Crosshair}
              action={<StatusBadge tone="neutral">{resolvedLocation?.state || lockedMatrixState}</StatusBadge>}
              className="mb-5"
            />

            <div className="grid gap-4">
              <InsetPanel>
                <div className={opsLabelClass}>Latitude</div>
                <div className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                  {typeof lat === 'number' ? `${lat.toFixed(4)}°` : '--'}
                </div>
              </InsetPanel>
              <InsetPanel>
                <div className={opsLabelClass}>Longitude</div>
                <div className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                  {typeof lon === 'number' ? `${lon.toFixed(4)}°` : '--'}
                </div>
              </InsetPanel>
              {stationFocus ? (
                <InsetPanel>
                  <div className={opsLabelClass}>Station focus</div>
                  <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                    {stationFocus}
                  </div>
                </InsetPanel>
              ) : null}

              <ActionButton
                onClick={() => window.open(mapLaunchHref, '_blank', 'noreferrer')}
                icon={MapPin}
                variant="primary"
                className="w-full"
              >
                Open external map
              </ActionButton>
            </div>
          </ConsolePanel>

          <ConsolePanel intensity="secondary">
            <SectionHeader
              eyebrow="Probability lanes"
              title="Geo-linked lane profile"
              description={`Lane weighting for ${targetLocationLabel} within the active geographic lock.`}
              icon={Radar}
              action={<StatusBadge tone={dominantLaneConfig.tone}>Preferred {dominantProbabilityLane[0]}</StatusBadge>}
              className="mb-5"
            />

            <div className="grid gap-4">
              <InsetPanel className="px-1 py-2">
                <LayeredNeuralGraph
                  lanes={laneConfig}
                  preferredLabel={dominantProbabilityLane[0]}
                  compact
                  className="h-[13rem] w-full"
                />
              </InsetPanel>

              <div className="grid grid-cols-2 gap-3">
                {laneConfig.map((lane) => (
                  <InsetPanel key={lane.key}>
                    <div className="mb-2 flex items-center justify-between gap-2">
                      <StatusBadge tone={lane.tone}>{lane.label}</StatusBadge>
                      <span className="text-sm font-semibold text-[color:var(--ops-text)]">{lane.value.toFixed(1)}%</span>
                    </div>
                    <ProbabilityHeartbeatSparkline
                      lane={lane}
                      highlighted={lane.label === dominantProbabilityLane[0]}
                      className="h-9 w-full"
                    />
                  </InsetPanel>
                ))}
              </div>
            </div>
          </ConsolePanel>
        </div>

        <div className="lg:col-span-8">
          <ConsolePanel padded={false} intensity="primary" frameTone="cyan" className="overflow-hidden">
            <div className="px-5 py-5 sm:px-6">
              <SectionHeader
                eyebrow="Map"
                title="Regional overlay"
                description="OSM is used as the tactical base map, with the current region lock and map target pinned in the shell."
                icon={MapIcon}
                action={
                  <>
                    <StatusBadge tone="neutral">{lockedMatrixState}</StatusBadge>
                    <StatusBadge tone={hasResolvedCoordinates ? 'success' : 'warning'}>{hasResolvedCoordinates ? 'Resolved' : 'Pending'}</StatusBadge>
                  </>
                }
              />
            </div>

            <div className="relative min-h-[340px] bg-black/20 sm:min-h-[420px]">
              {hasMapTarget ? (
                <>
                  {mapEmbedSrc ? (
                    <iframe
                      title="Live geo-spatial feed"
                      width="100%"
                      height="100%"
                      style={{ border: 0, filter: 'invert(100%) hue-rotate(180deg) brightness(92%) contrast(112%) sepia(10%)' }}
                      className="absolute inset-0"
                      loading="lazy"
                      allowFullScreen
                      referrerPolicy="no-referrer-when-downgrade"
                      src={mapEmbedSrc}
                    />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center bg-[radial-gradient(circle_at_center,rgba(90,143,255,0.12),transparent_52%),linear-gradient(180deg,rgba(6,10,15,0.96),rgba(6,10,15,0.82))] p-6">
                      <EmptyState
                        title="Coordinate lock unavailable"
                        description="The geo console has a regional target, but no coordinate-grade lock yet. Use the external map view while the station resolver syncs."
                        icon={MapPin}
                        className="max-w-md"
                      />
                    </div>
                  )}

                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(90,143,255,0.12),transparent_30%),radial-gradient(circle_at_bottom_left,rgba(201,74,97,0.12),transparent_24%)]" />

                  <div className="pointer-events-none absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center justify-center">
                    <Crosshair size={34} className="text-[color:var(--ops-danger-soft)] opacity-80" />
                  </div>

                  <div className="pointer-events-none absolute left-4 top-4 z-10 max-w-[min(22rem,calc(100%-2rem))]">
                    <InsetPanel variant="soft" className="bg-[rgba(7,10,15,0.86)]">
                      <div className={opsLabelClass}>Geo readout</div>
                      <div className="mt-2 grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-2 text-sm">
                        <span className="text-[color:var(--ops-text-faint)]">Target</span>
                        <span className="font-medium text-[color:var(--ops-text)]">{targetLocationLabel}</span>
                        <span className="text-[color:var(--ops-text-faint)]">Matrix</span>
                        <span className="text-[color:var(--ops-text)]">{lockedMatrixState}</span>
                        <span className="text-[color:var(--ops-text-faint)]">Basemap</span>
                        <span className="text-[color:var(--ops-text)]">OpenStreetMap tactical relay</span>
                      </div>
                    </InsetPanel>
                  </div>

                  <div className="pointer-events-none absolute bottom-4 right-4">
                    <StatusBadge tone={hasResolvedCoordinates ? 'success' : 'warning'}>
                      {hasResolvedCoordinates
                        ? `${lat?.toFixed(4)} / ${lon?.toFixed(4)}`
                        : mapQuery}
                    </StatusBadge>
                  </div>
                </>
              ) : (
                <div className="flex min-h-[340px] items-center justify-center p-6">
                  <EmptyState
                    title="Awaiting geographic vectors"
                    description="Initiate a state, city, or station lock in the dashboard to establish a usable geo-spatial target."
                    icon={MapPin}
                  />
                </div>
              )}
            </div>
          </ConsolePanel>
        </div>
      </div>

      <div>
        <div className="mb-4">
          <StatusBadge tone="info" icon={Waves}>Live CWC context for {lockedMatrixState}</StatusBadge>
        </div>
        <CWCLiveDataDisplay />
      </div>
    </PageShell>
  );
};

export default GeoSpatialPage;
