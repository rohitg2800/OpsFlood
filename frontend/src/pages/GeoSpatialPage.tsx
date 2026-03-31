import React, { useEffect, useMemo } from 'react';
import { MapPin, Map as MapIcon, Crosshair, Radar, Navigation2, Waves } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { PageShell, PageHero, PageCard } from '../components/PageShell';
import { CWCLiveDataDisplay } from '../components/CWCLiveDataDisplay';
import { locationMatchesCandidate, resolveGeoCoordinate } from '../data/geoCoordinates';
import { WeatherConsolePanel } from '../components/WeatherConsolePanel';
import { LayeredNeuralGraph } from '../components/LayeredNeuralGraph';
import { ProbabilityHeartbeatSparkline } from '../components/ProbabilityLaneHeartbeat';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';

// ==========================================
// GEO-SPATIAL PAGE COMPONENT
// ==========================================

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

  const inputLocationLabel =
    state.prediction.selectedCity ||
    state.form.data.station ||
    state.prediction.selectedState ||
    state.form.data.state ||
    'AWAITING INPUT';
  const lockedMatrixState =
    state.prediction.selectedState ||
    state.form.data.state ||
    'AWAITING INPUT';
  const stationFocus = state.prediction.selectedCity || state.form.data.station || '';
  const targetLocationLabel = stationFocus || inputLocationLabel;

  const resolvedLocation = useMemo(() => {
    const focusedLocation = resolveGeoCoordinate(state.prediction.selectedCity, state.form.data.station);
    if (focusedLocation) return focusedLocation;

    if (stationFocus) {
      if (locationMatchesCandidate(state.data.locationData, stationFocus)) {
        return state.data.locationData;
      }

      return null;
    }

    const mappedLocation = resolveGeoCoordinate(
      state.prediction.selectedState,
      state.form.data.state,
    );

    if (mappedLocation) return mappedLocation;

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
  const hasMapTarget = Boolean(targetLocationLabel && targetLocationLabel !== 'AWAITING INPUT');
  const weatherTarget = targetLocationLabel || lockedMatrixState || 'Selected Region';
  const hasResolvedCoordinates = typeof lat === 'number' && typeof lon === 'number';
  const mapQuery = stationFocus
    ? `${stationFocus}${lockedMatrixState && lockedMatrixState !== 'AWAITING INPUT' ? `, ${lockedMatrixState}` : ''}`
    : resolvedLocation
    ? `${resolvedLocation.name}${resolvedLocation.state ? `, ${resolvedLocation.state}` : ''}`
    : lockedMatrixState;
  const mapEmbedSrc = hasResolvedCoordinates ? buildOpenStreetMapEmbed(lat, lon) : null;
  const mapLaunchHref = hasResolvedCoordinates
    ? buildOpenStreetMapLaunchHref(lat, lon)
    : `https://www.openstreetmap.org/search?query=${encodeURIComponent(mapQuery)}`;
  const probabilityLanes = useMemo(() => deriveProbabilityLanes(state.prediction.currentPrediction), [state.prediction.currentPrediction]);
  const dominantProbabilityLane = useMemo(() => getDominantProbabilityLane(probabilityLanes), [probabilityLanes]);
  const laneConfig = useMemo(() => ([
    { key: 'low', label: 'LOW', shortLabel: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1', tone: 'text-emerald-300' },
    { key: 'moderate', label: 'MODERATE', shortLabel: 'MOD', value: probabilityLanes.moderate, fill: '#bc9437', tone: 'text-[#dcb978]' },
    { key: 'severe', label: 'SEVERE', shortLabel: 'SEV', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'text-[#ffb08e]' },
    { key: 'critical', label: 'CRITICAL', shortLabel: 'CRT', value: probabilityLanes.critical, fill: '#ff0037', tone: 'text-[#ff8ea0]' },
  ]), [probabilityLanes]);
  const dominantLaneConfig = laneConfig.find((lane) => lane.label === dominantProbabilityLane[0]) || laneConfig[0];

  return (
    <PageShell>
      <style>{`
        .radar-sweep {
          position: absolute;
          width: 50%;
          height: 50%;
          top: 0;
          left: 50%;
          transform-origin: 0 100%;
          background: linear-gradient(90deg, rgba(188,148,55,0.2) 0%, transparent 100%);
          animation: sweep 4s infinite linear;
          pointer-events: none;
        }
        @keyframes sweep {
          to { transform: rotate(360deg); }
        }
        /* Tactical Dark Mode Map Filter */
        .tactical-map-filter {
          filter: invert(100%) hue-rotate(180deg) brightness(85%) contrast(120%) sepia(20%);
        }
      `}</style>

      <PageHero
        eyebrow="Tactical Mapping Console"
        title="Geo-Spatial Console"
        subtitle="The selected state matrix is the primary geographic lock here, with optional station focus layered on top."
        icon={Navigation2}
        action={
          <div className="rounded-md border border-[#ff0037]/45 bg-[#ff0037]/12 px-5 py-3 text-[10px] font-black uppercase tracking-[0.24em] text-[#ff6b85] shadow-[0_12px_30px_rgba(255,0,55,0.14)]">
            Sector Lock: {lockedMatrixState}
          </div>
        }
      />

      <WeatherConsolePanel
        target={weatherTarget}
        coordinates={resolvedLocation ? { lat: resolvedLocation.lat, lon: resolvedLocation.lon } : undefined}
        subtitle={`Atmospheric conditions for ${weatherTarget} linked to the current geo lock.`}
      />

      <PageCard className="relative !p-0 overflow-hidden">
        {/* Decorative Top Scan-line */}
        <div className="absolute top-0 left-0 h-[1px] w-full bg-gradient-to-r from-transparent via-[#ff0037]/45 to-transparent" />

        {/* COMMAND HEADER */}
        <div className="flex flex-col items-start justify-between gap-6 bg-white/[0.02] p-6 sm:p-8 lg:flex-row lg:items-center lg:p-10">
          <div className="space-y-1">
            <h2 className="flex items-center gap-4 text-xl font-black uppercase tracking-widest text-white font-cinzel sm:text-2xl">
              <MapIcon className="text-[#bc9437]" size={28} /> Global Positioning
            </h2>
            <p className="ml-11 text-[10px] font-bold uppercase tracking-[0.2em] text-stone-500">
              Sat_Link_Active // Topographical_Data_Stream
            </p>
          </div>
          
          <div className="rounded-md border border-[#ff4b6d]/60 bg-[#ff0037] px-6 py-3 text-[10px] font-mono font-black uppercase tracking-widest text-white shadow-[0_10px_24px_rgba(255,0,55,0.22)]">
            Matrix_Lock: {lockedMatrixState}
          </div>
        </div>

        <div className="p-6 sm:p-8 lg:p-10">
          {hasMapTarget ? (
            <div className="grid grid-cols-1 gap-8 lg:grid-cols-12">
              
              {/* LEFT: COORDINATES & DATA */}
              <div className="lg:col-span-4 space-y-6">
                <div className="rounded-lg border border-[#ff0037]/28 bg-black/45 p-6 shadow-[0_20px_50px_rgba(255,0,55,0.08)] sm:p-8">
                  <div className="flex items-center justify-between mb-4">
                     <span className="rounded-md border border-[#ff0037]/35 bg-[#ff0037]/10 px-3 py-1 text-[10px] font-black uppercase tracking-[0.3em] text-[#ff7f96]">Coordinates</span>
                     <Crosshair size={14} className="text-[#ff4b6d]" />
                  </div>
                  
                  <div className="space-y-2">
                    <div className="text-3xl font-black text-white font-mono tracking-tighter sm:text-4xl">
                      {typeof lat === 'number' ? `${Number(lat).toFixed(4)}°` : 'CITY LOCK'}
                    </div>
                    <div className="text-3xl font-black text-white font-mono tracking-tighter opacity-70 sm:text-4xl">
                      {typeof lon === 'number' ? `${Number(lon).toFixed(4)}°` : targetLocationLabel.toUpperCase()}
                    </div>
                  </div>

                  <div className="mt-8 pt-6">
                    <div className="mb-1 text-[11px] font-black uppercase tracking-widest text-[#ff7f96]">Target Identified</div>
                    <div className="text-lg text-white font-bold font-cinzel tracking-widest">
                      {targetLocationLabel}
                      <span className="block text-sm text-stone-400 mt-1">
                         {(resolvedLocation?.state || lockedMatrixState) ? `[ ${(resolvedLocation?.state || lockedMatrixState).toUpperCase()} ]` : ''}
                      </span>
                      {stationFocus ? (
                        <span className="mt-3 block rounded-md border border-[#ff0037]/22 bg-[#ff0037]/8 px-3 py-2 text-[10px] font-mono uppercase tracking-[0.18em] text-[#ff9eb1]">
                          Station Focus: {stationFocus}
                        </span>
                      ) : null}
                    </div>
                  </div>

                  <a
                    className="mt-8 flex items-center justify-center gap-3 rounded-md border border-[#ff4b6d]/55 bg-gradient-to-r from-[#ff0037] to-[#a10624] px-6 py-4 text-[10px] font-black uppercase text-white shadow-[0_14px_34px_rgba(255,0,55,0.2)] transition-all group hover:from-[#ff335b] hover:to-[#c20f33] active:scale-95"
                    href={mapLaunchHref}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <MapPin size={16} className="group-hover:-translate-y-1 transition-transform" /> 
                    Launch Ext_Map_View
                  </a>
                </div>

                <div className="rounded-lg border border-[#ff0037]/28 bg-black/45 p-5 shadow-[0_20px_50px_rgba(255,0,55,0.08)] sm:p-6">
                  <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <div className="text-[10px] font-black uppercase tracking-[0.28em] text-[#ff7f96]">
                        Probability Lanes Geo-Graph
                      </div>
                      <div className="mt-2 text-[10px] font-mono uppercase tracking-[0.18em] text-stone-500">
                        Geo lock: {targetLocationLabel}
                      </div>
                    </div>
                    <div className="rounded-md border border-[#ff0037]/24 bg-[#ff0037]/10 px-3 py-2 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300">
                      Preferred: <span className={`ml-1 ${dominantLaneConfig.tone}`}>{dominantProbabilityLane[0]}</span>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 items-center gap-4 lg:grid-cols-[17rem_minmax(0,1fr)]">
                    <div className="rounded-md border border-[#ff0037]/16 bg-black/35 p-2">
                      <LayeredNeuralGraph
                        lanes={laneConfig}
                        preferredLabel={dominantProbabilityLane[0]}
                        compact
                        className="h-[13rem] w-full"
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-2">
                      {laneConfig.map((lane) => {
                        const isPreferredLane = lane.label === dominantProbabilityLane[0];
                        return (
                          <div
                            key={lane.key}
                            className={`rounded-md border px-3 py-2 text-[9px] font-black uppercase tracking-[0.16em] ${
                              isPreferredLane ? 'border-[#ff0037]/30 bg-[#ff0037]/10' : 'border-[#ff0037]/16 bg-black/35'
                            }`}
                          >
                            <div className="mb-2 flex items-center justify-between gap-2">
                              <span className="inline-flex items-center gap-2 text-stone-300">
                                <span className="h-2 w-2 rounded-full" style={{ backgroundColor: lane.fill, boxShadow: `0 0 8px ${lane.fill}` }} />
                                {lane.label}
                              </span>
                              <span className={lane.tone}>{lane.value.toFixed(1)}%</span>
                            </div>
                            <ProbabilityHeartbeatSparkline
                              lane={lane}
                              highlighted={isPreferredLane}
                              className="h-9 w-full"
                            />
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>
              </div>

              {/* RIGHT: TACTICAL GIS OVERLAY */}
              <div className="lg:col-span-8">
                <div className="relative min-h-[320px] overflow-hidden rounded-lg border border-[#ff0037]/28 bg-[#060504] shadow-[0_24px_60px_rgba(255,0,55,0.08)] sm:min-h-[380px] lg:h-full lg:min-h-[450px]">
                  
                  {mapEmbedSrc ? (
                    <iframe
                      title="Live GIS Tactical Feed"
                      width="100%"
                      height="100%"
                      style={{ border: 0 }}
                      className="absolute inset-0 tactical-map-filter"
                      loading="lazy"
                      allowFullScreen
                      referrerPolicy="no-referrer-when-downgrade"
                      src={mapEmbedSrc}
                    />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center bg-[radial-gradient(circle_at_center,rgba(255,0,55,0.12),transparent_52%),linear-gradient(180deg,rgba(6,5,4,0.95),rgba(6,5,4,0.82))]">
                      <div className="mx-6 max-w-md rounded-lg border border-[#ff0037]/24 bg-black/60 p-6 text-center shadow-[0_20px_50px_rgba(255,0,55,0.08)] backdrop-blur-md">
                        <div className="text-[10px] font-black uppercase tracking-[0.28em] text-[#ff7f96]">
                          Map Feed Standby
                        </div>
                        <div className="mt-3 text-2xl font-black text-white font-cinzel">
                          Coordinate lock unavailable
                        </div>
                        <p className="mt-3 text-sm text-stone-400">
                          The geo console has a regional target, but no coordinate-grade lock yet. Use the external map link while the station resolver syncs.
                        </p>
                      </div>
                    </div>
                  )}
                  
                  {/* OVERLAYS: Topological Background Elements (pointer-events-none so you can still drag the map) */}
                  <div className="absolute inset-0 opacity-20 pointer-events-none mix-blend-overlay" style={{ 
                      backgroundImage: 'radial-gradient(circle at 30% 40%, rgba(255,0,55,0.4), transparent 60%), radial-gradient(circle at 70% 60%, rgba(255,72,72,0.22), transparent 60%)' 
                  }} />

                  {/* Concentric Radar Rings */}
                  <div className="pointer-events-none absolute left-1/2 top-1/2 h-[220px] w-[220px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(circle,transparent_62%,rgba(188,148,55,0.18)_63%,transparent_66%)] sm:h-[300px] sm:w-[300px]" />
                  <div className="pointer-events-none absolute left-1/2 top-1/2 h-[110px] w-[110px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(circle,transparent_58%,rgba(188,148,55,0.3)_60%,transparent_64%)] sm:h-[150px] sm:w-[150px]" />
                  
                  {/* Radar Sweep */}
                  <div className="radar-sweep" />

                  {/* Center Crosshair Lock */}
                  <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center justify-center pointer-events-none">
                    <Crosshair size={40} className="text-[#ff0037] opacity-70 animate-pulse" />
                  </div>

                  {/* Overlay Data Readouts */}
                  <div className="pointer-events-none absolute left-20 top-4 z-10 w-[min(22rem,calc(100%-6.5rem))] sm:left-24 sm:top-6">
                     <div className="rounded-md border border-[#ff0037]/35 bg-black/82 px-4 py-3 shadow-[0_10px_24px_rgba(255,0,55,0.16)] backdrop-blur-md">
                        <div className="mb-3 flex items-center gap-3">
                           <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md border border-[#ff0037]/35 bg-black/80 shadow-[0_10px_24px_rgba(255,0,55,0.16)]">
                              <Radar className="text-[#ff5b79]" size={16} />
                           </div>
                           <div className="min-w-0">
                              <div className="text-[8px] font-black uppercase tracking-[0.28em] text-stone-400">Geo Readout</div>
                              <div className="mt-1 text-[11px] font-black uppercase tracking-[0.14em] text-[#ff9eb1]">
                                 Tactical Map Overlay
                              </div>
                           </div>
                        </div>

                        <div className="grid grid-cols-[auto_minmax(0,1fr)] items-start gap-x-3 gap-y-2">
                           <span className="text-[8px] font-black uppercase tracking-[0.26em] text-stone-500">Station</span>
                           <span className="min-w-0 whitespace-normal break-words text-[11px] font-black uppercase tracking-[0.08em] text-[#ff9eb1]">
                              {targetLocationLabel}
                           </span>

                           <span className="text-[8px] font-black uppercase tracking-[0.26em] text-stone-500">Matrix</span>
                           <span className="min-w-0 whitespace-normal break-words text-[10px] font-mono uppercase tracking-[0.08em] text-stone-200">
                              {lockedMatrixState}
                           </span>

                           <span className="text-[8px] font-black uppercase tracking-[0.26em] text-stone-500">Basemap</span>
                           <span className="min-w-0 whitespace-normal break-words text-[10px] font-mono uppercase tracking-[0.08em] text-stone-300">
                              OSM Tactical Relay
                           </span>
                        </div>
                     </div>
                  </div>

                  <div className="pointer-events-none absolute bottom-4 right-4 max-w-[calc(100%-2rem)] rounded-md border border-[#ff0037]/35 bg-black/80 px-4 py-3 text-right shadow-lg backdrop-blur-md sm:bottom-6 sm:right-6 sm:max-w-[18rem] sm:px-5">
                     <div className="mb-1 text-[10px] font-mono font-black text-[#ff7f96]">{hasResolvedCoordinates ? 'LAT/LON: RESOLVED' : 'CITY: DIRECT LOCK'}</div>
                     <div className="truncate text-[8px] font-mono text-stone-400 uppercase tracking-widest">
                       {typeof lat === 'number' && typeof lon === 'number'
                         ? `${Number(lat).toFixed(4)} / ${Number(lon).toFixed(4)}`
                         : mapQuery}
                     </div>
                  </div>

                </div>
              </div>

              <div className="lg:col-span-12">
                <div className="mb-4 flex items-center gap-3 rounded-md border border-[#ff0037]/22 bg-[#ff0037]/8 px-4 py-3 text-[10px] font-black uppercase tracking-[0.22em] text-[#ff9eb1]">
                  <Waves size={14} className="shrink-0" />
                  Live CWC Combined For {lockedMatrixState}
                </div>
                <CWCLiveDataDisplay />
              </div>
            </div>
          ) : (
            <div className="py-24 flex flex-col items-center justify-center text-center">
              <div className="mb-6 flex h-24 w-24 items-center justify-center rounded-lg border border-[#ff0037]/30 bg-[#ff0037]/10 shadow-[0_16px_40px_rgba(255,0,55,0.12)] animate-pulse">
                 <MapPin className="text-[#ff5b79]" size={32} />
              </div>
              <h3 className="text-xl font-black text-white font-cinzel mb-2 tracking-widest">Awaiting Geographic Vectors</h3>
              <p className="text-sm text-stone-500 font-mono tracking-widest uppercase">
                Initiate site lock in the Command Console to establish Sat_Link.
              </p>
            </div>
          )}
        </div>
      </PageCard>
    </PageShell>
  );
};
