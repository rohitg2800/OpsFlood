import React, { useEffect, useCallback, useState, useMemo, useRef } from 'react';
import {
  Droplets, Activity, TrendingUp, TrendingDown, Minus,
  Clock, ShieldAlert, RefreshCw,
  Waves, Radio, Brain, Target, Network
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useEnhancedPrediction, useSystemInit, useAlertNotifications, useFormValidation, useSensorAPI, useAutoRefresh, useCWCIntegration } from '../hooks/useAppOperations';
import { StateSelector } from '../components/StateSelector';
import { CWCLiveDataDisplay } from '../components/CWCLiveDataDisplay';
import { MonitoringProtocolAlert } from '../components/MonitoringProtocolAlert';
import { FloodLogsPanel } from '../components/FloodLogsPanel';
import { NeuralOperationsGraph } from '../components/NeuralOperationsGraph';
import { WaterLevelGauge } from '../components/WaterLevelGauge';
import { FloodRiskHeatmap } from '../components/FloodRiskHeatmap';
import { ProbabilityHeartbeatGraph } from '../components/ProbabilityLaneHeartbeat';
import { ToastNotification, Toast } from '../components/ToastNotification';
import { SkeletonLoader } from '../components/SkeletonLoader';
import { WeatherConsolePanel } from '../components/WeatherConsolePanel';
import { apiUrl } from '../config/api';
import { PageShell, PageHero } from '../components/PageShell';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  type FrameTone,
  type SurfaceIntensity,
  InsetPanel,
  MetricTile,
  SectionHeader,
  StatusBadge,
  opsFieldClass,
  opsInsetClass,
  opsLabelClass,
} from '../components/OpsPrimitives';
import { getScopedSensorSelection, getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';
import type { SensorData } from '../types';
import { locationMatchesCandidate, normalizeGeoKey, resolveGeoCoordinate } from '../data/geoCoordinates';
import { getFloodProneLocations, getHydrologyBasinsForState } from '../data/hydrologyRegistry';

// ==========================================
// DYNAMIC STATE GEOGRAPHY MAPPING
// ==========================================
const getStrategicLocations = (stateName: string) => {
  const basins = getHydrologyBasinsForState(stateName || '');
  const stationLabels = Array.from(
    new Set(
      (basins || [])
        .map((entry) => String(entry.st || '').trim())
        .filter(Boolean),
    ),
  );
  if (stationLabels.length) {
    return stationLabels.slice(0, 3);
  }
  return ['Sector Alpha', 'Central Barrage', 'Low-Elevation Zones'];
};

// ==========================================
// LUXE SUB-COMPONENTS
// ==========================================

const LuxeCard = ({
  children,
  className = '',
  frameTone = 'neutral',
  intensity = 'secondary',
}: {
  children: React.ReactNode;
  className?: string;
  frameTone?: FrameTone;
  intensity?: SurfaceIntensity;
}) => (
  <ConsolePanel intensity={intensity} frameTone={frameTone} className={className}>
    {children}
  </ConsolePanel>
);

const LuxeInput = ({
  label,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement> & { label: string }) => (
  <div className="space-y-2 group">
    <label className={`block pl-2 text-left group-focus-within:text-white transition-colors ${opsLabelClass}`}>
      {label}
    </label>
    <div className="relative">
      <input
        {...props}
        className={`${opsFieldClass} font-mono text-base font-bold`}
      />
      <div className="absolute right-3 top-1/2 h-6 w-1 -translate-y-1/2 rounded-full bg-[color:var(--ops-primary)]/50" />
    </div>
  </div>
);

const vectorFieldClass =
  `${opsFieldClass} font-mono text-xs font-bold`;

const chipButtonClass =
  'min-h-[2.75rem] whitespace-nowrap rounded-xl bg-[rgba(11,16,21,0.62)] px-4 py-2 text-[10px] font-black uppercase tracking-[0.16em] text-[color:var(--ops-text-soft)] shadow-[inset_0_1px_0_rgba(255,255,255,0.05)] transition-all hover:bg-[rgba(255,255,255,0.06)] hover:text-[color:var(--ops-text)] active:scale-95';

const getTrendMeta = (trend?: string) => {
  if (trend === 'RISING') {
    return { icon: TrendingUp, tone: 'border-sky-400/28 bg-sky-400/10 text-sky-200' };
  }
  if (trend === 'FALLING') {
    return { icon: TrendingDown, tone: 'border-emerald-500/25 bg-emerald-500/10 text-emerald-300' };
  }
  return { icon: Minus, tone: 'border-white/12 bg-white/[0.05] text-[color:var(--ops-text-soft)]' };
};

const getSensorStatusTone = (status: string) => {
  if (status === 'CRITICAL') return 'border-[rgba(255,110,133,0.35)] bg-[rgba(255,110,133,0.12)] text-[color:var(--ops-danger-soft)]';
  if (status === 'WARNING') return 'border-amber-400/28 bg-amber-400/10 text-amber-100';
  return 'border-emerald-400/28 bg-emerald-400/10 text-emerald-200';
};

const RegionSensorCard = ({ sensor }: { sensor: SensorData }) => {
  const trendMeta = getTrendMeta(sensor.trend);
  const TrendIcon = trendMeta.icon;
  return (
    <div className="space-y-4 rounded-[1rem] bg-[rgba(11,16,21,0.62)] p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.06)]">
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <div className={opsLabelClass}>Station</div>
          <div className="mt-2 text-sm font-semibold uppercase tracking-[0.12em] text-[color:var(--ops-text)]">{sensor.station}</div>
          <div className="mt-3 flex flex-wrap gap-2">
            <div className="inline-flex max-w-full items-center gap-2 rounded-md border border-white/10 bg-black/20 px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.16em] text-[color:var(--ops-text-soft)]">
              <Waves size={10} className="shrink-0 text-[color:var(--ops-info)]" />
              <span className="truncate">{sensor.river || 'Active Basin'}</span>
            </div>
            <div className={`inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] ${trendMeta.tone}`}>
              <TrendIcon size={10} className="shrink-0" />
              <span>{sensor.trend || 'STEADY'}</span>
            </div>
          </div>
        </div>
        <span className={`rounded-md border px-3 py-1 text-[9px] font-black uppercase tracking-[0.2em] ${getSensorStatusTone(sensor.status)}`}>
          {sensor.status}
        </span>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-xl bg-black/20 p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
          <div className={opsLabelClass}>Water level</div>
          <div className="mt-2 text-2xl font-semibold font-mono text-[color:var(--ops-text)]">{Number(sensor.river_level || 0).toFixed(2)}m</div>
        </div>
        <div className="rounded-xl bg-black/20 p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
          <div className={opsLabelClass}>Rain 1H</div>
          <div className="mt-2 text-2xl font-semibold font-mono text-[color:var(--ops-text)]">{Number(sensor.rainfall_last_hour || 0).toFixed(1)}mm</div>
        </div>
      </div>
      <div className="text-[10px] font-mono uppercase tracking-[0.18em] text-[color:var(--ops-text-faint)]">
        Last Sync: {sensor.last_update ? new Date(sensor.last_update).toLocaleTimeString('en-US', { hour12: false }) : 'NO_DATA'}
      </div>
    </div>
  );
};

interface NeuralNetworkGraphProps {
  preferredState: string;
  matrixRegion?: string;
  matrixVerdict?: string | null;
  matrixStatus: 'idle' | 'loading' | 'ready' | 'error';
  probabilityLanes: { low: number; moderate: number; severe: number; critical: number };
  // FIX #5: dominantLane is a string (we pass dominantProbabilityLane[0] at call site)
  dominantLane: string;
}

const NeuralNetworkGraph: React.FC<NeuralNetworkGraphProps> = ({
  preferredState,
  matrixRegion,
  matrixVerdict,
  matrixStatus,
  probabilityLanes,
  dominantLane,
}) => {
  const layers = [6, 9, 7, 1];
  const laneConfig = [
    { key: 'low', label: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1', tone: 'text-emerald-300' },
    { key: 'moderate', label: 'MODERATE', value: probabilityLanes.moderate, fill: '#bc9437', tone: 'text-[#dcb978]' },
    { key: 'severe', label: 'SEVERE', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'text-[#ffb08e]' },
    { key: 'critical', label: 'CRITICAL', value: probabilityLanes.critical, fill: '#ff0037', tone: 'text-[#ff8ea0]' },
  ] as const;
  const dominantConfig = laneConfig.find((lane) => lane.label === dominantLane) || laneConfig[0];
  const averageSignal = (probabilityLanes.low + probabilityLanes.moderate + probabilityLanes.severe + probabilityLanes.critical) / 4;
  const hiddenNodeOpacity = Math.min(0.75, 0.18 + averageSignal / 140);

  return (
    <ConsolePanel className="h-full">
      <SectionHeader
        eyebrow="Model matrix"
        title="Synaptic inference matrix"
        description={
          <>
            Preferred state <span className="font-semibold text-[color:var(--ops-text)]">{preferredState || 'Maharashtra'}</span>
            {matrixRegion ? <> linked to <span className="font-semibold text-[color:var(--ops-text)]">{matrixRegion}</span></> : null}
          </>
        }
        icon={Network}
        action={
          <>
            <StatusBadge tone={matrixStatus === 'ready' ? 'success' : matrixStatus === 'error' ? 'danger' : 'warning'}>
              {matrixStatus === 'ready' ? 'Matrix linked' : matrixStatus === 'loading' ? 'Matrix syncing' : matrixStatus === 'error' ? 'Matrix error' : 'Matrix standby'}
            </StatusBadge>
            <StatusBadge tone="info">Lane {dominantLane}</StatusBadge>
            <StatusBadge tone={matrixVerdict === 'CRITICAL' ? 'danger' : matrixVerdict === 'SEVERE' ? 'warning' : matrixVerdict === 'MODERATE' ? 'info' : 'success'}>
              {matrixVerdict || 'LOW'}
            </StatusBadge>
          </>
        }
        className="mb-6"
      />

      <div className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <InsetPanel>
          <div className={opsLabelClass}>Preferred state</div>
          <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{preferredState || 'Maharashtra'}</div>
        </InsetPanel>
        <InsetPanel>
          <div className={opsLabelClass}>Matrix region</div>
          <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{matrixRegion || 'Awaiting profile'}</div>
        </InsetPanel>
        <InsetPanel>
          <div className={opsLabelClass}>Current verdict</div>
          <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{matrixVerdict || 'LOW'}</div>
        </InsetPanel>
      </div>

      <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {laneConfig.map((lane) => (
          <InsetPanel key={lane.key} className="space-y-3">
            <div className="flex items-center justify-between gap-3">
              <span className={opsLabelClass}>{lane.label}</span>
              <span className={`text-[11px] font-black uppercase tracking-[0.14em] ${lane.tone}`}>{lane.value.toFixed(1)}%</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-black/30">
              <div
                className="h-full rounded-full transition-all duration-500"
                style={{ width: `${Math.max(4, lane.value)}%`, backgroundColor: lane.fill }}
              />
            </div>
          </InsetPanel>
        ))}
      </div>

      <div className="mb-4 flex items-center justify-between gap-3">
        <div className={opsLabelClass}>Preferred-state nodes</div>
        <div className="text-xs text-[color:var(--ops-text-faint)]">Mean signal {averageSignal.toFixed(1)}%</div>
      </div>

      <div className="relative flex h-48 w-full items-center justify-between rounded-[1rem] bg-black/20 px-10 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]">
        {layers.map((count, lIdx) => (
          <div key={lIdx} className="flex flex-col gap-2 z-10">
            {Array.from({ length: count }).map((_, nIdx) => (
              <div
                key={nIdx}
                className={`w-2.5 h-2.5 rounded-full transition-all hover:scale-150 ${
                  lIdx === 0 ? 'bg-[#bc9437]' : lIdx === 3 ? '' : 'bg-white/20'
                }`}
                style={
                  lIdx === 0
                    ? { boxShadow: '0 0 15px #bc9437' }
                    : lIdx === 3
                    ? {
                        backgroundColor: dominantConfig.fill,
                        boxShadow: `0 0 ${16 + dominantConfig.value / 6}px ${dominantConfig.fill}`,
                        transform: `scale(${0.95 + dominantConfig.value / 260})`,
                      }
                    : {
                        opacity: hiddenNodeOpacity,
                        boxShadow: `0 0 ${6 + averageSignal / 12}px rgba(255,255,255,0.08)`,
                      }
                }
              />
            ))}
          </div>
        ))}
        <div
          className="absolute inset-0 -z-10 blur-3xl transition-all duration-500"
          style={{ background: `linear-gradient(90deg, rgba(90,143,255,0.08), transparent, ${dominantConfig.fill}22)` }}
        />
      </div>
    </ConsolePanel>
  );
};

function normalizeStateKey(stateName: string): string {
  const key = (stateName || '').trim().toLowerCase();
  if (key === 'orissa') return 'odisha';
  if (key === 'nct of delhi' || key === 'new delhi') return 'delhi';
  return key;
}

// ==========================================
// DASHBOARD PAGE COMPONENT
// ==========================================

const DashboardPage: React.FC = () => {
  const { state, dispatch } = useAppState();
  const { predictWithFullModel } = useEnhancedPrediction();
  const { notifyUser } = useAlertNotifications();
  const { validateAllFields } = useFormValidation(state.form.data);
  const { fetchSensors, isLoading: sensorsLoading } = useSensorAPI();
  const { fetchCWCData } = useCWCIntegration();
  const apiStatus = state.system.apiStatus;

  const [stateFilter, setStateFilter] = useState('');
  const [customCity, setCustomCity] = useState('');
  const [selectedScenarioPreset, setSelectedScenarioPreset] = useState<string | null>(null);
  const [stateMatrixIndex, setStateMatrixIndex] = useState<Record<string, any>>({});
  const [stateMatrixStatus, setStateMatrixStatus] = useState<'idle' | 'loading' | 'ready' | 'error'>('idle');
  const [stateMatrixError, setStateMatrixError] = useState<string | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const predictionInputRef = useRef<HTMLDivElement | null>(null);
  const monitoringAlertRef = useRef<HTMLDivElement | null>(null);
  const pendingMonitoringScrollRef = useRef(false);
  const monitoringAlertPulseTimeoutRef = useRef<number | null>(null);
  const [monitoringAlertPulse, setMonitoringAlertPulse] = useState(false);
  const lastStateTelemetrySyncRef = useRef('');

  const pushToast = useCallback((toast: Omit<Toast, 'id'>) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    setToasts((prev) => [...prev, { ...toast, id }]);
  }, []);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const stateKeyToDisplayName = useMemo(() => {
    const map: Record<string, string> = {};
    for (const name of state.models.availableStates || []) {
      map[normalizeStateKey(name)] = name;
    }
    return map;
  }, [state.models.availableStates]);

  const reloadStateMatrixIndex = useCallback(async () => {
    setStateMatrixStatus('loading');
    setStateMatrixError(null);
    try {
      const res = await fetch(apiUrl('/state-severity-matrix'), { method: 'GET' });
      const data = await res.json();
      if (data?.status === 'success' && data?.states && typeof data.states === 'object') {
        setStateMatrixIndex(data.states);
        setStateMatrixStatus('ready');
      } else {
        setStateMatrixStatus('error');
        setStateMatrixError('Failed to load state matrix index.');
      }
    } catch (err) {
      setStateMatrixStatus('error');
      setStateMatrixError(err instanceof Error ? err.message : 'Failed to load state matrix index.');
    }
  }, []);

  const scenarioPresets = [
    { id: 'dry', label: 'Dry', peak: 8.5, rainTotal: 80 },
    { id: 'monsoon', label: 'Monsoon', peak: 11.8, rainTotal: 360 },
    { id: 'extreme', label: 'Extreme', peak: 13.8, rainTotal: 650 },
  ] as const;

  const rainfallTotalNow = [
    state.form.data.T1d, state.form.data.T2d, state.form.data.T3d, state.form.data.T4d,
    state.form.data.T5d, state.form.data.T6d, state.form.data.T7d,
  ].reduce((a, b) => a + (Number(b) || 0), 0);

  const selectedStateKey = normalizeStateKey(state.prediction.selectedState);
  const selectedStateMatrix = stateMatrixIndex[selectedStateKey] || null;
  const effectiveStateMatrix = selectedStateMatrix || state.prediction.currentPrediction?.state_matrix || null;

  const stateMatrixKeys = useMemo(() => {
    const keys = Object.keys(stateMatrixIndex || {});
    keys.sort((a, b) => a.localeCompare(b));
    return keys;
  }, [stateMatrixIndex]);

  const filteredStateMatrixKeys = useMemo(() => {
    const q = (stateFilter || '').trim().toLowerCase();
    if (!q) return stateMatrixKeys;
    return stateMatrixKeys.filter((k) => {
      const dn = (stateKeyToDisplayName[k] || k).toLowerCase();
      return dn.includes(q) || k.includes(q);
    });
  }, [stateFilter, stateMatrixKeys, stateKeyToDisplayName]);

  const isCityHotspotView = useMemo(() => {
    return Boolean(state.prediction.selectedCity || state.form.data.station);
  }, [state.prediction.selectedCity, state.form.data.station]);

  const matrixVerdict = (() => {
    if (!effectiveStateMatrix) return null;
    const peak = Number(state.form.data.Peak_Flood_Level_m || 0);
    const rain = Number(rainfallTotalNow || 0);
    if (peak >= effectiveStateMatrix.peak_level_m.critical || rain >= effectiveStateMatrix.rainfall_7d_mm.critical) return 'CRITICAL';
    if (peak >= effectiveStateMatrix.peak_level_m.severe || rain >= effectiveStateMatrix.rainfall_7d_mm.severe) return 'SEVERE';
    if (peak >= effectiveStateMatrix.peak_level_m.moderate || rain >= effectiveStateMatrix.rainfall_7d_mm.moderate) return 'MODERATE';
    return 'LOW';
  })();

  const probabilityLanes = useMemo(() => deriveProbabilityLanes(state.prediction.currentPrediction), [state.prediction.currentPrediction]);
  // FIX #5 & #8: getDominantProbabilityLane returns [string, number]. Extract [0] for string label.
  const dominantProbabilityLaneTuple = useMemo(() => getDominantProbabilityLane(probabilityLanes), [probabilityLanes]);
  const dominantProbabilityLane = dominantProbabilityLaneTuple[0]; // string only

  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  const shouldEmphasizeMonitoringAlert = severity === 'CRITICAL' || severity === 'SEVERE';
  const currentConfidence = Number(state.prediction.currentPrediction?.confidence_percent || 0);
  const currentRiskScore = Number(state.prediction.currentPrediction?.risk_score || 0);
  const monitoringTone =
    severity === 'CRITICAL' ? 'danger' :
    severity === 'SEVERE' ? 'warning' :
    severity === 'MODERATE' ? 'info' : 'success';

  const dynamicLocations = getStrategicLocations(state.prediction.selectedState);

  const floodProneLocationSuggestions = useMemo(() => {
    const scopedState = state.prediction.selectedState || state.form.data.state || '';
    const scoped = getFloodProneLocations(scopedState);
    if (scoped.length) return scoped.slice(0, 180);
    return getFloodProneLocations().slice(0, 180);
  }, [state.form.data.state, state.prediction.selectedState]);

  const strategicResponses = dynamicLocations.map((area, index) => {
    if (severity === 'CRITICAL' || severity === 'SEVERE') {
      return {
        area,
        status: index === 0 ? 'EVACUATE' : index === 1 ? 'CRITICAL' : 'STAGING',
        color: index === 0 ? 'text-[#ff0037]' : index === 1 ? 'text-orange-500' : 'text-blue-500',
      };
    }
    if (severity === 'MODERATE') {
      return {
        area,
        status: index === 0 ? 'WARNING' : index === 1 ? 'MONITOR' : 'PREPARE',
        color: index === 0 ? 'text-amber-500' : index === 1 ? 'text-amber-400' : 'text-blue-400',
      };
    }
    return { area, status: 'SECURE', color: 'text-emerald-500' };
  });

  const selectedRegionSensorScope = useMemo(() => {
    return getScopedSensorSelection(state.sensors.data || [], {
      selectedCity: state.prediction.selectedCity,
      station: state.form.data.station,
      selectedState: state.prediction.selectedState,
    });
  }, [state.form.data.station, state.prediction.selectedCity, state.prediction.selectedState, state.sensors.data]);

  const selectedRegionSensors = selectedRegionSensorScope.sensors;
  const leadRegionSensor = selectedRegionSensors[0] || null;
  const leadTrendMeta = leadRegionSensor ? getTrendMeta(leadRegionSensor.trend) : null;
  const LeadTrendIcon = leadTrendMeta?.icon ?? Minus;
  const selectedRiverLocationLabel = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );
  const dashboardWeatherTarget = selectedRiverLocationLabel || state.form.data.state || 'Selected Region';

  const currentLocationData = useMemo(
    () =>
      state.data.locationData?.lat && state.data.locationData?.lon
        ? {
            name: state.data.locationData.name,
            state: state.data.locationData.state,
            lat: state.data.locationData.lat,
            lon: state.data.locationData.lon,
          }
        : null,
    [
      state.data.locationData?.lat,
      state.data.locationData?.lon,
      state.data.locationData?.name,
      state.data.locationData?.state,
    ],
  );

  const dashboardWeatherCoordinates = useMemo(() => {
    const focusedLocation = resolveGeoCoordinate(state.prediction.selectedCity, state.form.data.station);
    const stateLocation = resolveGeoCoordinate(state.prediction.selectedState, state.form.data.state);
    const focusTarget = state.prediction.selectedCity || state.form.data.station;
    const focusLocationMatchesState = Boolean(
      !focusTarget ||
      !focusedLocation ||
      !stateLocation?.state ||
      !focusedLocation.state ||
      normalizeGeoKey(focusedLocation.state) === normalizeGeoKey(stateLocation.state),
    );
    if (focusedLocation && focusLocationMatchesState) {
      return { lat: focusedLocation.lat, lon: focusedLocation.lon };
    }
    if (focusTarget) {
      if (focusLocationMatchesState && locationMatchesCandidate(currentLocationData, focusTarget) && currentLocationData) {
        return { lat: currentLocationData.lat, lon: currentLocationData.lon };
      }
      if (stateLocation) return { lat: stateLocation.lat, lon: stateLocation.lon };
      return undefined;
    }
    if (stateLocation) return { lat: stateLocation.lat, lon: stateLocation.lon };
    if (currentLocationData) return { lat: currentLocationData.lat, lon: currentLocationData.lon };
    return undefined;
  }, [
    currentLocationData,
    state.form.data.state,
    state.form.data.station,
    state.prediction.selectedCity,
    state.prediction.selectedState,
  ]);

  const liveDangerLevel =
    Number(leadRegionSensor?.danger_level || 0) ||
    Number(state.cwc.liveData.dangerLevel || 0) ||
    0;

  const dashboardDangerLevel: number | null =
    liveDangerLevel ||
    (state.prediction.currentPrediction?.danger_level ? Number(state.prediction.currentPrediction.danger_level) : null) ||
    (state.prediction.dangerLevel ? Number(state.prediction.dangerLevel) : null) ||
    (effectiveStateMatrix?.danger_level_m ? Number(effectiveStateMatrix.danger_level_m) : null);

  const dangerLevelSourceLabel = liveDangerLevel
    ? `Live CWC · ${leadRegionSensor?.station || state.cwc.liveData.station || selectedRiverLocationLabel}`
    : effectiveStateMatrix
    ? 'State matrix threshold'
    : 'Model baseline threshold';

  const nearbyWaterSourcesNote =
    selectedRegionSensorScope.mode === 'city_exact'
      ? `Direct station match found for ${selectedRiverLocationLabel}.`
      : selectedRegionSensorScope.mode === 'city_nearby'
      ? `No exact station match for ${selectedRiverLocationLabel}. Showing the closest monitored sources from the active regional network.`
      : selectedRegionSensorScope.mode === 'state'
      ? `Showing monitored sources across ${state.prediction.selectedState || state.form.data.state || 'the selected state'}.`
      : 'Showing the best available monitored sources from the current telemetry feed.';

  const heatmapData = useMemo(() => {
    const cityFocused = Boolean(state.prediction.selectedCity || state.form.data.station);
    const effectiveDanger = dashboardDangerLevel ?? 13.5;
    if (cityFocused && selectedRegionSensors.length) {
      return selectedRegionSensors.slice(0, 6).map((sensor) => {
        const level = Number(sensor.river_level || 0);
        const rain = Number(sensor.rainfall_last_hour || 0);
        const risk = Math.min(
          100,
          Math.round(
            (effectiveDanger > 0 ? (level / effectiveDanger) * 68 : 0) +
              Math.min(rain * 4, 18) +
              (sensor.status === 'CRITICAL' ? 18 : sensor.status === 'WARNING' ? 8 : 0),
          ),
        );
        const severityBand = risk >= 80 ? 'CRITICAL' : risk >= 60 ? 'SEVERE' : risk >= 40 ? 'MODERATE' : 'LOW';
        return {
          label: sensor.station,
          subLabel: selectedRiverLocationLabel,
          risk,
          severity: severityBand as 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL',
        };
      });
    }
    const baseRisk = severity === 'CRITICAL' ? 88 : severity === 'SEVERE' ? 70 : severity === 'MODERATE' ? 52 : 26;
    return dynamicLocations.slice(0, 6).map((area, index) => {
      const risk = Math.max(12, Math.min(100, baseRisk - index * 8));
      const severityBand = risk >= 80 ? 'CRITICAL' : risk >= 60 ? 'SEVERE' : risk >= 40 ? 'MODERATE' : 'LOW';
      return {
        label: area,
        subLabel: state.prediction.selectedState,
        risk,
        severity: severityBand as 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL',
      };
    });
  }, [
    dashboardDangerLevel,
    dynamicLocations,
    selectedRegionSensors,
    selectedRiverLocationLabel,
    severity,
    state.form.data.station,
    state.prediction.selectedCity,
    state.prediction.selectedState,
  ]);

  useSystemInit();

  useEffect(() => {
    if (stateMatrixStatus === 'idle') reloadStateMatrixIndex();
  }, [reloadStateMatrixIndex, stateMatrixStatus]);

  useEffect(() => {
    if (apiStatus === 'ONLINE' && stateMatrixStatus === 'error') reloadStateMatrixIndex();
  }, [apiStatus, reloadStateMatrixIndex, stateMatrixStatus]);

  useEffect(() => {
    setCustomCity(state.prediction.selectedCity || state.form.data.station || '');
  }, [state.form.data.station, state.prediction.selectedCity]);

  useEffect(() => {
    const selectedState = (state.prediction.selectedState || state.form.data.state || '').trim();
    if (!selectedState) { lastStateTelemetrySyncRef.current = ''; return; }
    if (apiStatus === 'OFFLINE' || apiStatus === 'INITIALIZING') return;
    if (lastStateTelemetrySyncRef.current === selectedState) return;

    lastStateTelemetrySyncRef.current = selectedState;
    let cancelled = false;
    const timeoutId = window.setTimeout(() => {
      void (async () => {
        try {
          const [cwcNode, sensorList] = await Promise.all([
            fetchCWCData({ force: true }),
            fetchSensors({ force: true }),
          ]);
          if (cancelled) return;

          const targetKey = (state.prediction.selectedCity || state.form.data.station || '').trim().toLowerCase();
          const sensors: any[] = Array.isArray(sensorList) ? sensorList : [];
          const leadSensor = targetKey
            ? sensors.find((s: any) =>
                (s.station || '').toLowerCase().includes(targetKey) ||
                (s.river || '').toLowerCase().includes(targetKey)
              ) ?? sensors[0]
            : sensors[0];

          const liveSensorDanger = leadSensor?.danger_level ? Number(leadSensor.danger_level) : null;
          if (liveSensorDanger && liveSensorDanger > 0) {
            // FIX #1: SET_DANGER_LEVEL doesn't exist. Use SET_FORM_DATA to update Peak_Flood_Level_m.
            dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: liveSensorDanger } });
          }
          if (!state.form.isDirty) {
            if (liveSensorDanger && liveSensorDanger > 0) {
              dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: liveSensorDanger } });
            } else if (typeof cwcNode?.currentLevel === 'number') {
              dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: cwcNode.currentLevel } });
            }
          }
        } catch {
          // Keep dashboard usable even when upstream telemetry is delayed.
        }
      })();
    }, 120);

    return () => { cancelled = true; window.clearTimeout(timeoutId); };
  }, [
    apiStatus, dispatch, fetchCWCData, fetchSensors,
    state.form.data.state, state.form.data.station, state.form.isDirty,
    state.prediction.selectedCity, state.prediction.selectedState,
  ]);

  useEffect(() => {
    if (apiStatus === 'OFFLINE' || apiStatus === 'INITIALIZING') return;
    const timeoutId = window.setTimeout(() => { void fetchSensors(); }, 180);
    return () => window.clearTimeout(timeoutId);
  }, [apiStatus, fetchSensors]);

  const refreshDashboardTelemetry = useCallback(() => {
    if (apiStatus === 'OFFLINE' || apiStatus === 'INITIALIZING') return;
    void fetchSensors({ force: true });
  }, [apiStatus, fetchSensors]);

  useAutoRefresh(refreshDashboardTelemetry);

  useEffect(() => {
    if (!pendingMonitoringScrollRef.current) return;
    if (state.prediction.isLoading) return;
    if (!state.prediction.currentPrediction) return;

    pendingMonitoringScrollRef.current = false;
    window.requestAnimationFrame(() => {
      const alertNode = monitoringAlertRef.current;
      if (!alertNode) return;
      const rect = alertNode.getBoundingClientRect();
      const isOutsideViewport = rect.top < 96 || rect.bottom > window.innerHeight - 96;
      if (isOutsideViewport) alertNode.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

      if (monitoringAlertPulseTimeoutRef.current !== null) {
        window.clearTimeout(monitoringAlertPulseTimeoutRef.current);
      }
      setMonitoringAlertPulse(false);
      if (shouldEmphasizeMonitoringAlert) {
        window.requestAnimationFrame(() => {
          setMonitoringAlertPulse(true);
          monitoringAlertPulseTimeoutRef.current = window.setTimeout(() => {
            setMonitoringAlertPulse(false);
            monitoringAlertPulseTimeoutRef.current = null;
          }, 1400);
        });
      }
    });
  }, [shouldEmphasizeMonitoringAlert, state.prediction.currentPrediction, state.prediction.isLoading]);

  useEffect(() => {
    return () => {
      if (monitoringAlertPulseTimeoutRef.current !== null) {
        window.clearTimeout(monitoringAlertPulseTimeoutRef.current);
      }
    };
  }, []);

  const applyCustomCity = useCallback(() => {
    const nextCity = customCity.trim();
    if (!nextCity) return;
    if (
      nextCity === (state.prediction.selectedCity || '').trim() &&
      nextCity === (state.form.data.station || '').trim()
    ) return;
    lastStateTelemetrySyncRef.current = '';
    dispatch({ type: 'SET_FORM_DATA', payload: { station: nextCity } });
    dispatch({ type: 'SET_SELECTED_CITY', payload: nextCity });
  }, [customCity, dispatch, state.form.data.station, state.prediction.selectedCity]);

  const scrollToPredictionInput = useCallback(() => {
    window.requestAnimationFrame(() => {
      predictionInputRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }, []);

  const handlePredict = useCallback(async () => {
    const isValid = validateAllFields();
    if (!isValid) {
      const validationSummary = Object.values(state.form.errors || {}).filter(Boolean).join(' ');
      const message = validationSummary || 'Please fix input errors before inference.';
      dispatch({ type: 'SET_ERROR', payload: message });
      pushToast({ type: 'warning', title: 'Validation required', message, duration: 4800 });
      return;
    }
    pendingMonitoringScrollRef.current = true;
    const startTime = performance.now();
    try {
      const result = await predictWithFullModel();
      const latency = Math.round(performance.now() - startTime);
      dispatch({ type: 'SET_LATENCY', payload: latency });
      if (result.severity === 'CRITICAL' || result.severity === 'SEVERE') {
        notifyUser({
          title: `⚠️ ${result.severity} FLOOD ALERT`,
          message: result.alert,
          type: result.severity === 'CRITICAL' ? 'critical' : 'warning',
        });
      }
    } catch (error) {
      pendingMonitoringScrollRef.current = false;
      const latency = Math.round(performance.now() - startTime);
      dispatch({ type: 'SET_LATENCY', payload: latency });
      const errorMessage = error instanceof Error ? error.message : 'Prediction failed.';
      dispatch({ type: 'SET_ERROR', payload: `Prediction failed: ${errorMessage}` });
      pushToast({ type: 'error', title: 'Execution failed', message: errorMessage, duration: 5500 });
    }
  }, [state.form.data, state.form.errors, predictWithFullModel, dispatch, notifyUser, validateAllFields, pushToast]);

  return (
    <PageShell>
      <PageHero
        eyebrow="Command Console"
        title="Dashboard"
        subtitle="Live flood inference, state matrix lookup, and response intelligence from one central workspace."
        icon={Target}
        centered
        action={
          <>
            <ActionButton
              onClick={handlePredict}
              disabled={state.prediction.isLoading}
              icon={state.prediction.isLoading ? RefreshCw : Brain}
              variant="primary"
              className="min-w-[12rem]"
            >
              {state.prediction.isLoading ? 'Running inference' : 'Execute inference'}
            </ActionButton>
            <StatusBadge tone={monitoringTone}>Active severity {severity}</StatusBadge>
            <ActionButton
              onClick={reloadStateMatrixIndex}
              icon={RefreshCw}
              className={stateMatrixStatus === 'loading' ? 'opacity-80' : ''}
            >
              {stateMatrixStatus === 'loading' ? 'Refreshing matrix' : 'Refresh matrices'}
            </ActionButton>
          </>
        }
      />

      {state.system.errorMessage ? (
        <ConsolePanel intensity="tertiary" className="mt-4 border border-[rgba(255,110,133,0.32)] bg-[rgba(255,110,133,0.1)]">
          <div className="text-xs font-semibold uppercase tracking-[0.12em] text-[color:var(--ops-danger-soft)]">
            {state.system.errorMessage}
          </div>
        </ConsolePanel>
      ) : null}

      {/* Status strip */}
      <ConsolePanel intensity="primary" frameTone="olive" className="reveal-seq">
        <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_auto] xl:items-center">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <InsetPanel className="space-y-1">
              <div className={opsLabelClass}>Command scope</div>
              <div className="font-cinzel text-lg uppercase tracking-[0.08em] text-[color:var(--ops-text)]">
                {state.prediction.selectedState || 'State pending'}
              </div>
            </InsetPanel>
            <InsetPanel className="space-y-1">
              <div className={opsLabelClass}>Location lock</div>
              <div className="text-base font-semibold text-[color:var(--ops-text)]">{selectedRiverLocationLabel}</div>
            </InsetPanel>
            <InsetPanel className="space-y-1">
              <div className={opsLabelClass}>Source policy</div>
              <div className="text-sm font-semibold uppercase tracking-[0.08em] text-[color:var(--ops-text)]">
                {state.system.sourcePolicy.mode}
              </div>
            </InsetPanel>
            <InsetPanel className="space-y-1">
              <div className={opsLabelClass}>Monitoring posture</div>
              <StatusBadge tone={monitoringTone} className="w-fit">
                {state.prediction.monitoringLevel || 'Pending'}
              </StatusBadge>
            </InsetPanel>
          </div>
          <ActionButton
            onClick={handlePredict}
            disabled={state.prediction.isLoading}
            icon={state.prediction.isLoading ? RefreshCw : Brain}
            variant="primary"
            className="min-h-[3.25rem] min-w-[15rem] text-xs tracking-[0.22em]"
          >
            {state.prediction.isLoading ? 'Running inference' : 'Execute model inference'}
          </ActionButton>
        </div>
      </ConsolePanel>

      {/* State + location lock panel */}
      <ConsolePanel intensity="secondary" className="space-y-5">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className={opsLabelClass}>State and location lock</div>
            <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
              The dashboard uses the selected state matrix for thresholds and the city or station lock for scoped telemetry.
            </div>
          </div>
          <StatusBadge tone="neutral">
            {selectedRegionSensorScope.mode === 'city_exact'
              ? 'Exact match'
              : selectedRegionSensorScope.mode === 'city_nearby'
              ? 'Nearby network'
              : selectedRegionSensorScope.mode === 'state'
              ? 'State network'
              : 'Live feed'}
          </StatusBadge>
        </div>

        <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]">
          {/* LEFT: state selector + city input */}
          <div className="space-y-4">
            <StateSelector className="!space-y-4" />

            <div className="space-y-2">
              <label className={`block text-left ${opsLabelClass}`}>City or station</label>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(0,1fr)_auto]">
                <input
                  type="text"
                  list="flood-prone-location-options"
                  value={customCity}
                  onChange={(e) => setCustomCity(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') { e.preventDefault(); applyCustomCity(); }
                  }}
                  placeholder="Enter city or station"
                  className={vectorFieldClass}
                />
                <ActionButton onClick={applyCustomCity} variant="secondary">
                  Lock target
                </ActionButton>
              </div>
              {/* FIX #2 & #3: FloodProneLocation is an object. Use loc.station for key and value. */}
              <datalist id="flood-prone-location-options">
                {floodProneLocationSuggestions.map((loc) => (
                  <option key={loc.station} value={loc.station} />
                ))}
              </datalist>
            </div>
          </div>

          {/* RIGHT: matrix sidebar */}
          <div className="space-y-3">
            <InsetPanel className="space-y-2">
              <div className={opsLabelClass}>Active state matrix</div>
              <div className="text-sm font-semibold text-[color:var(--ops-text)]">
                {selectedStateKey || 'None selected'}
              </div>
              {effectiveStateMatrix ? (
                <div className="space-y-1 text-[10px] font-mono text-[color:var(--ops-text-soft)]">
                  <div>Moderate ≥ {effectiveStateMatrix.peak_level_m?.moderate}m / {effectiveStateMatrix.rainfall_7d_mm?.moderate}mm</div>
                  <div>Severe ≥ {effectiveStateMatrix.peak_level_m?.severe}m / {effectiveStateMatrix.rainfall_7d_mm?.severe}mm</div>
                  <div>Critical ≥ {effectiveStateMatrix.peak_level_m?.critical}m / {effectiveStateMatrix.rainfall_7d_mm?.critical}mm</div>
                </div>
              ) : (
                <div className="text-[10px] text-[color:var(--ops-text-faint)]">Select a state to load matrix</div>
              )}
            </InsetPanel>

            <InsetPanel className="space-y-2">
              <div className={opsLabelClass}>Matrix verdict</div>
              <StatusBadge tone={
                matrixVerdict === 'CRITICAL' ? 'danger' :
                matrixVerdict === 'SEVERE' ? 'warning' :
                matrixVerdict === 'MODERATE' ? 'info' : 'success'
              }>
                {matrixVerdict || 'LOW'}
              </StatusBadge>
            </InsetPanel>

            <InsetPanel className="space-y-2">
              <div className={opsLabelClass}>Danger level</div>
              <div className="text-lg font-mono font-semibold text-[color:var(--ops-text)]">
                {dashboardDangerLevel != null ? `${dashboardDangerLevel.toFixed(2)}m` : '--'}
              </div>
              <div className="text-[9px] font-mono uppercase tracking-[0.14em] text-[color:var(--ops-text-faint)]">
                {dangerLevelSourceLabel}
              </div>
            </InsetPanel>
          </div>
        </div>
      </ConsolePanel>

      {/* State matrix index */}
      <ConsolePanel intensity="secondary" className="space-y-4">
        <SectionHeader
          eyebrow="State matrix index"
          title="Regional threshold matrix"
          description="Heuristic calibration thresholds per state. Select a state row to apply its matrix to the dashboard."
          icon={ShieldAlert}
        />
        <div className="space-y-2">
          <input
            type="text"
            value={stateFilter}
            onChange={(e) => setStateFilter(e.target.value)}
            placeholder="Filter states…"
            className={vectorFieldClass}
          />
        </div>
        {stateMatrixStatus === 'loading' ? (
          // FIX #4: SkeletonLoader uses `count`, not `rows`
          <SkeletonLoader count={4} />
        ) : stateMatrixStatus === 'error' ? (
          <EmptyState
            title="Matrix unavailable"
            description={stateMatrixError || 'Could not load state matrix.'}
            action={<ActionButton onClick={reloadStateMatrixIndex} icon={RefreshCw}>Retry</ActionButton>}
          />
        ) : (
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {filteredStateMatrixKeys.map((key) => {
              const entry = stateMatrixIndex[key];
              const displayName = stateKeyToDisplayName[key] || key;
              const isActive = key === selectedStateKey;
              return (
                <button
                  key={key}
                  onClick={() => {
                    dispatch({ type: 'SET_SELECTED_STATE', payload: displayName });
                    dispatch({ type: 'SET_FORM_DATA', payload: { state: displayName } });
                  }}
                  className={`rounded-xl border px-4 py-3 text-left text-xs transition-all hover:bg-white/[0.06] ${
                    isActive
                      ? 'border-[color:var(--ops-primary)] bg-[color:var(--ops-primary)]/10 text-[color:var(--ops-text)]'
                      : 'border-white/10 bg-black/20 text-[color:var(--ops-text-soft)]'
                  }`}
                >
                  <div className="font-semibold uppercase tracking-[0.1em]">{displayName}</div>
                  <div className="mt-1 font-mono text-[9px] text-[color:var(--ops-text-faint)]">
                    {entry?.region} · danger {entry?.danger_level_m}m
                  </div>
                </button>
              );
            })}
          </div>
        )}
      </ConsolePanel>

      {/* Metric tiles */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricTile
          label="Severity"
          value={severity}
          tone={severity === 'CRITICAL' ? 'danger' : severity === 'SEVERE' ? 'warning' : severity === 'MODERATE' ? 'info' : 'success'}
          icon={ShieldAlert}
        />
        <MetricTile label="Confidence" value={`${currentConfidence.toFixed(1)}%`} icon={Target} />
        <MetricTile label="Risk score" value={currentRiskScore} icon={Activity} />
        <MetricTile label="Rainfall total" value={`${rainfallTotalNow.toFixed(0)}mm`} icon={Droplets} />
      </div>

      {/* Neural graph + water level gauge */}
      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,20rem)]">
        {/* FIX #5: pass dominantProbabilityLane (string), not the tuple */}
        <NeuralNetworkGraph
          preferredState={state.prediction.selectedState || 'Maharashtra'}
          matrixRegion={effectiveStateMatrix?.region}
          matrixVerdict={matrixVerdict}
          matrixStatus={stateMatrixStatus}
          probabilityLanes={probabilityLanes}
          dominantLane={dominantProbabilityLane}
        />
        <ConsolePanel className="flex flex-col gap-4">
          <SectionHeader eyebrow="Gauge" title="Water level" icon={Waves} />
          {/* FIX #6: WaterLevelGauge has no warningLevel prop — removed */}
          <WaterLevelGauge
            currentLevel={Number(state.form.data.Peak_Flood_Level_m || 0)}
            dangerLevel={dashboardDangerLevel ?? 13.5}
          />
          {leadRegionSensor && (
            <InsetPanel className="space-y-1">
              <div className={opsLabelClass}>Lead station</div>
              <div className="flex items-center gap-2">
                <LeadTrendIcon
                  size={12}
                  className={leadTrendMeta?.tone?.split(' ').find((c) => c.startsWith('text-')) || ''}
                />
                <span className="text-sm font-semibold text-[color:var(--ops-text)]">{leadRegionSensor.station}</span>
              </div>
            </InsetPanel>
          )}
        </ConsolePanel>
      </div>

      {/* FIX #8: ProbabilityHeartbeatGraph expects lanes array + dominantLane string */}
      <ProbabilityHeartbeatGraph
        lanes={[
          { key: 'low', label: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1', tone: 'text-emerald-300' },
          { key: 'moderate', label: 'MODERATE', value: probabilityLanes.moderate, fill: '#4c7cff', tone: 'text-sky-300' },
          { key: 'severe', label: 'SEVERE', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'text-orange-200' },
          { key: 'critical', label: 'CRITICAL', value: probabilityLanes.critical, fill: '#ff5f7e', tone: 'text-rose-200' },
        ]}
        dominantLane={dominantProbabilityLane}
      />

      {/* Heatmap */}
      <FloodRiskHeatmap data={heatmapData} />

      {/* FIX #7: MonitoringProtocolAlert reads from context — no props needed */}
      <div ref={monitoringAlertRef}>
        <MonitoringProtocolAlert />
      </div>

      {/* Sensor grid */}
      <ConsolePanel intensity="secondary" className="space-y-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <SectionHeader eyebrow="Regional network" title={nearbyWaterSourcesNote} icon={Radio} />
          <div className="flex items-center gap-2">
            <StatusBadge tone={sensorsLoading ? 'warning' : 'success'}>
              {sensorsLoading ? 'Syncing' : `${selectedRegionSensors.length} nodes`}
            </StatusBadge>
            <ActionButton onClick={refreshDashboardTelemetry} icon={RefreshCw}>Refresh</ActionButton>
          </div>
        </div>
        {sensorsLoading && !selectedRegionSensors.length ? (
          // FIX #9: use count not rows
          <SkeletonLoader count={3} />
        ) : selectedRegionSensors.length === 0 ? (
          <EmptyState title="No sensor data" description="No telemetry nodes available for this selection." />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {selectedRegionSensors.slice(0, 6).map((sensor) => (
              <RegionSensorCard key={sensor.station} sensor={sensor} />
            ))}
          </div>
        )}
      </ConsolePanel>

      {/* CWC live data */}
      <CWCLiveDataDisplay />

      {/* Prediction input form */}
      <div ref={predictionInputRef}>
        <ConsolePanel intensity="secondary" className="space-y-5">
          <SectionHeader
            eyebrow="Inference engine"
            title="Manual flood input"
            description="Override live telemetry with custom scenario inputs for model inference."
            icon={Brain}
            action={
              <ActionButton
                onClick={handlePredict}
                disabled={state.prediction.isLoading}
                icon={state.prediction.isLoading ? RefreshCw : Brain}
                variant="primary"
              >
                {state.prediction.isLoading ? 'Running' : 'Run inference'}
              </ActionButton>
            }
          />
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <LuxeInput
              label="Peak flood level (m)"
              type="number"
              step="0.01"
              value={state.form.data.Peak_Flood_Level_m ?? ''}
              onChange={(e) => dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: parseFloat(e.target.value) } })}
            />
            <LuxeInput
              label="Event duration (days)"
              type="number"
              step="1"
              value={state.form.data.Event_Duration_days ?? ''}
              onChange={(e) => dispatch({ type: 'SET_FORM_DATA', payload: { Event_Duration_days: parseFloat(e.target.value) } })}
            />
            <LuxeInput
              label="Time to peak (days)"
              type="number"
              step="0.5"
              value={state.form.data.Time_to_Peak_days ?? ''}
              onChange={(e) => dispatch({ type: 'SET_FORM_DATA', payload: { Time_to_Peak_days: parseFloat(e.target.value) } })}
            />
            <LuxeInput
              label="Recession time (days)"
              type="number"
              step="0.5"
              value={state.form.data.Recession_Time_day ?? ''}
              onChange={(e) => dispatch({ type: 'SET_FORM_DATA', payload: { Recession_Time_day: parseFloat(e.target.value) } })}
            />
            {(['T1d', 'T2d', 'T3d', 'T4d', 'T5d', 'T6d', 'T7d'] as const).map((key, i) => (
              <LuxeInput
                key={key}
                label={`Day ${i + 1} rainfall (mm)`}
                type="number"
                step="0.1"
                value={state.form.data[key] ?? ''}
                onChange={(e) => dispatch({ type: 'SET_FORM_DATA', payload: { [key]: parseFloat(e.target.value) } })}
              />
            ))}
          </div>

          {/* Scenario presets */}
          <div className="flex flex-wrap gap-2">
            {scenarioPresets.map((preset) => (
              <button
                key={preset.id}
                onClick={() => {
                  setSelectedScenarioPreset(preset.id);
                  const perDay = preset.rainTotal / 7;
                  dispatch({
                    type: 'SET_FORM_DATA',
                    payload: {
                      Peak_Flood_Level_m: preset.peak,
                      T1d: perDay, T2d: perDay, T3d: perDay,
                      T4d: perDay, T5d: perDay, T6d: perDay, T7d: perDay,
                    },
                  });
                }}
                className={`${chipButtonClass} ${selectedScenarioPreset === preset.id ? 'border border-[color:var(--ops-primary)] text-[color:var(--ops-text)]' : ''}`}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </ConsolePanel>
      </div>

      {/* Flood logs + weather */}
      <div className="grid gap-4 xl:grid-cols-2">
        <FloodLogsPanel />
        {/* FIX #10: WeatherConsolePanel prop is `target`, not `weatherTarget` */}
        <WeatherConsolePanel
          target={dashboardWeatherTarget}
          coordinates={dashboardWeatherCoordinates}
        />
      </div>

      {/* FIX #11: NeuralOperationsGraph reads from context — no prediction/isLoading props */}
      <NeuralOperationsGraph />

      {/* FIX #12: ToastNotification takes `toasts` array + `onRemove`, not single `toast` + `onDismiss` */}
      <ToastNotification toasts={toasts} onRemove={removeToast} />
    </PageShell>
  );
};

export default DashboardPage;