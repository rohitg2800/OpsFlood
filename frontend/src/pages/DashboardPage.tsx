import React, { useEffect, useCallback, useState, useMemo, useRef } from 'react';
import {
  Droplets, Activity, TrendingUp, TrendingDown, Minus,
  Clock, ShieldAlert, RefreshCw,
  Waves, Radio, Brain, Target, Network
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useEnhancedPrediction, useSystemInit, useAlertNotifications, useFormValidation, useSensorAPI, useAutoRefresh } from '../hooks/useAppOperations';
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
// LUXE SUB-COMPONENTS (EMS STYLED)
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
    return {
      icon: TrendingUp,
      tone: 'border-sky-400/28 bg-sky-400/10 text-sky-200',
    };
  }
  if (trend === 'FALLING') {
    return {
      icon: TrendingDown,
      tone: 'border-emerald-500/25 bg-emerald-500/10 text-emerald-300',
    };
  }
  return {
    icon: Minus,
    tone: 'border-white/12 bg-white/[0.05] text-[color:var(--ops-text-soft)]',
  };
};

const getSensorStatusTone = (status: string) => {
  if (status === 'CRITICAL') {
    return 'border-[rgba(255,110,133,0.35)] bg-[rgba(255,110,133,0.12)] text-[color:var(--ops-danger-soft)]';
  }
  if (status === 'WARNING') {
    return 'border-amber-400/28 bg-amber-400/10 text-amber-100';
  }
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
  probabilityLanes: {
    low: number;
    moderate: number;
    severe: number;
    critical: number;
  };
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
              {matrixStatus === 'ready'
                ? 'Matrix linked'
                : matrixStatus === 'loading'
                ? 'Matrix syncing'
                : matrixStatus === 'error'
                ? 'Matrix error'
                : 'Matrix standby'}
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
                style={{
                  width: `${Math.max(4, lane.value)}%`,
                  backgroundColor: lane.fill,
                }}
              />
            </div>
          </InsetPanel>
        ))}
      </div>

      <div className="mb-4 flex items-center justify-between gap-3">
        <div className={opsLabelClass}>Preferred-state nodes</div>
        <div className="text-xs text-[color:var(--ops-text-faint)]">
          Mean signal {averageSignal.toFixed(1)}%
        </div>
      </div>

      <div className="relative flex h-48 w-full items-center justify-between rounded-[1rem] bg-black/20 px-10 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]">
        {layers.map((count, lIdx) => (
          <div key={lIdx} className="flex flex-col gap-2 z-10">
            {Array.from({length: count}).map((_, nIdx) => (
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
          style={{
            background: `linear-gradient(90deg, rgba(90,143,255,0.08), transparent, ${dominantConfig.fill}22)`,
          }}
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
  // HOOKS PRESERVED
  const { state, dispatch } = useAppState();
  const { predictWithFullModel } = useEnhancedPrediction();
  const { notifyUser } = useAlertNotifications();
  const { validateAllFields } = useFormValidation(state.form.data);
  const { fetchSensors, isLoading: sensorsLoading } = useSensorAPI();
  const apiStatus = state.system.apiStatus;

  // STATE MANAGEMENT PRESERVED
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

  const removeToast = useCallback((id: string) => {
    setToasts(prev => prev.filter(t => t.id !== id));
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
    state.form.data.T5d, state.form.data.T6d, state.form.data.T7d
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
  const dominantProbabilityLane = useMemo(() => getDominantProbabilityLane(probabilityLanes), [probabilityLanes]);
  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  const shouldEmphasizeMonitoringAlert = severity === 'CRITICAL' || severity === 'SEVERE';
  const currentConfidence = Number(state.prediction.currentPrediction?.confidence_percent || 0);
  const currentRiskScore = Number(state.prediction.currentPrediction?.risk_score || 0);
  const monitoringTone =
    severity === 'CRITICAL'
      ? 'danger'
      : severity === 'SEVERE'
      ? 'warning'
      : severity === 'MODERATE'
      ? 'info'
      : 'success';
  // -----------------------------------------------------
  // DYNAMIC STRATEGIC RESPONSE LOGIC
  // -----------------------------------------------------
  const dynamicLocations = getStrategicLocations(state.prediction.selectedState);
  const floodProneLocationSuggestions = useMemo(() => {
    const scopedState = state.prediction.selectedState || state.form.data.state || '';
    const scoped = getFloodProneLocations(scopedState);
    if (scoped.length) {
      return scoped.slice(0, 180);
    }
    return getFloodProneLocations().slice(0, 180);
  }, [state.form.data.state, state.prediction.selectedState]);
  
  const strategicResponses = dynamicLocations.map((area, index) => {
    if (severity === 'CRITICAL' || severity === 'SEVERE') {
      return {
        area,
        status: index === 0 ? 'EVACUATE' : index === 1 ? 'CRITICAL' : 'STAGING',
        color: index === 0 ? 'text-[#ff0037]' : index === 1 ? 'text-orange-500' : 'text-blue-500'
      };
    }
    if (severity === 'MODERATE') {
      return {
        area,
        status: index === 0 ? 'WARNING' : index === 1 ? 'MONITOR' : 'PREPARE',
        color: index === 0 ? 'text-amber-500' : index === 1 ? 'text-amber-400' : 'text-blue-400'
      };
    }
    return {
      area,
      status: 'SECURE',
      color: 'text-emerald-500'
    };
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
    const focusedLocation = resolveGeoCoordinate(
      state.prediction.selectedCity,
      state.form.data.station,
    );
    const stateLocation = resolveGeoCoordinate(
      state.prediction.selectedState,
      state.form.data.state,
    );

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
      if (
        focusLocationMatchesState &&
        locationMatchesCandidate(currentLocationData, focusTarget) &&
        currentLocationData
      ) {
        return {
          lat: currentLocationData.lat,
          lon: currentLocationData.lon,
        };
      }

      if (stateLocation) {
        return { lat: stateLocation.lat, lon: stateLocation.lon };
      }

      return undefined;
    }

    if (stateLocation) {
      return { lat: stateLocation.lat, lon: stateLocation.lon };
    }

    if (currentLocationData) {
      return {
        lat: currentLocationData.lat,
        lon: currentLocationData.lon,
      };
    }

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
  const dashboardDangerLevel =
    liveDangerLevel ||
    state.prediction.currentPrediction?.danger_level ||
    state.prediction.dangerLevel ||
    effectiveStateMatrix?.danger_level_m ||
    13.5;
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

    if (cityFocused && selectedRegionSensors.length) {
      return selectedRegionSensors.slice(0, 6).map((sensor) => {
        const level = Number(sensor.river_level || 0);
        const rain = Number(sensor.rainfall_last_hour || 0);
        const risk = Math.min(
          100,
          Math.round(
            (dashboardDangerLevel > 0 ? (level / dashboardDangerLevel) * 68 : 0) +
              Math.min(rain * 4, 18) +
              (sensor.status === 'CRITICAL' ? 18 : sensor.status === 'WARNING' ? 8 : 0),
          ),
        );

        const severityBand =
          risk >= 80 ? 'CRITICAL' :
          risk >= 60 ? 'SEVERE' :
          risk >= 40 ? 'MODERATE' :
          'LOW';

        return {
          label: sensor.station,
          subLabel: selectedRiverLocationLabel,
          risk,
          severity: severityBand as 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL',
        };
      });
    }

    const baseRisk =
      severity === 'CRITICAL' ? 88 :
      severity === 'SEVERE' ? 70 :
      severity === 'MODERATE' ? 52 :
      26;

    return dynamicLocations.slice(0, 6).map((area, index) => {
      const risk = Math.max(12, Math.min(100, baseRisk - index * 8));
      const severityBand =
        risk >= 80 ? 'CRITICAL' :
        risk >= 60 ? 'SEVERE' :
        risk >= 40 ? 'MODERATE' :
        'LOW';

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
    if (apiStatus === 'ONLINE' && stateMatrixStatus === 'error') {
      reloadStateMatrixIndex();
    }
  }, [apiStatus, reloadStateMatrixIndex, stateMatrixStatus]);

  useEffect(() => {
    setCustomCity(state.prediction.selectedCity || state.form.data.station || '');
  }, [state.form.data.station, state.prediction.selectedCity]);

  useEffect(() => {
    if (apiStatus === 'OFFLINE' || apiStatus === 'INITIALIZING') return;

    const timeoutId = window.setTimeout(() => {
      void fetchSensors();
    }, 180);

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
      const isOutsideViewport =
        rect.top < 96 || rect.bottom > window.innerHeight - 96;

      if (isOutsideViewport) {
        alertNode.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest',
        });
      }

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
    ) {
      return;
    }
    dispatch({ type: 'SET_FORM_DATA', payload: { station: nextCity } });
    dispatch({ type: 'SET_SELECTED_CITY', payload: nextCity });
  }, [customCity, dispatch, state.form.data.station, state.prediction.selectedCity]);

  const scrollToPredictionInput = useCallback(() => {
    window.requestAnimationFrame(() => {
      predictionInputRef.current?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      });
    });
  }, []);

  const handlePredict = useCallback(async () => {
    const isValid = validateAllFields();
    if (!isValid) {
      dispatch({ type: 'SET_ERROR', payload: 'Please fix input errors before inference.' });
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
          type: result.severity === 'CRITICAL' ? 'critical' : 'warning'
        });
      }
    } catch (error) {
      pendingMonitoringScrollRef.current = false;
      const latency = Math.round(performance.now() - startTime);
      dispatch({ type: 'SET_LATENCY', payload: latency });
      const errorMessage = error instanceof Error ? error.message : 'Prediction failed.';
      dispatch({ type: 'SET_ERROR', payload: `Prediction failed: ${errorMessage}` });
    }
  }, [state.form.data, predictWithFullModel, dispatch, notifyUser, validateAllFields, rainfallTotalNow]);


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
            <StatusBadge tone={monitoringTone}>
              Active severity {severity}
            </StatusBadge>
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
              <div className="text-base font-semibold text-[color:var(--ops-text)]">
                {selectedRiverLocationLabel}
              </div>
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
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      applyCustomCity();
                    }
                  }}
                  placeholder="Enter city or station"
                  className={vectorFieldClass}
                />
                <ActionButton onClick={applyCustomCity} variant="secondary">
                  Lock target
                </ActionButton>
              </div>
              <datalist id="flood-prone-location-options">
                {floodProneLocationSuggestions.map((location) => (
                  <option
                    key={`${location.state}-${location.station}-${location.river}`}
                    value={location.station}
                    label={`${location.station} · ${location.river} · ${location.state}`}
                  />
                ))}
              </datalist>
              <div className="flex flex-wrap gap-2">
                <StatusBadge tone="info">
                  Active target {(state.prediction.selectedCity || state.form.data.station || 'None').toUpperCase()}
                </StatusBadge>
                <StatusBadge tone="neutral">
                  {floodProneLocationSuggestions.length} flood-prone nodes indexed
                </StatusBadge>
              </div>
            </div>
          </div>

          {(state.prediction.selectedCity || state.form.data.station) ? (
            <InsetPanel variant="soft" className="space-y-3">
              <div className={opsLabelClass}>Nearby water sources</div>
              <p className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
                {nearbyWaterSourcesNote}
              </p>
              <div className="space-y-2">
                {selectedRegionSensors.length ? (
                  selectedRegionSensors.slice(0, 4).map((sensor) => (
                    <div
                      key={`${sensor.station}-${sensor.river || 'river'}`}
                      className="flex items-center justify-between gap-3 rounded-xl bg-black/20 px-3 py-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]"
                    >
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold uppercase tracking-[0.08em] text-[color:var(--ops-text)]">
                          {sensor.station}
                        </div>
                        <div className="truncate text-xs text-[color:var(--ops-text-faint)]">
                          {sensor.river || 'Active basin'}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-sm font-semibold font-mono text-[color:var(--ops-text)]">
                          {Number(sensor.river_level || 0).toFixed(2)}m
                        </div>
                        <div className="text-[10px] uppercase tracking-[0.14em] text-[color:var(--ops-text-faint)]">
                          {sensor.status}
                        </div>
                      </div>
                    </div>
                  ))
                ) : (
                  <EmptyState
                    title="Telemetry nodes are still resolving"
                    description="The city lock is active, but the nearby monitored sources have not been returned yet. The dashboard will keep the location lock intact while those nodes sync."
                    icon={Radio}
                    className="!p-4"
                  />
                )}
              </div>
            </InsetPanel>
          ) : (
            <InsetPanel variant="soft" className="flex items-center justify-center">
              <div className="text-sm text-[color:var(--ops-text-soft)]">
                Lock a city or station to pin nearby monitored sources.
              </div>
            </InsetPanel>
          )}
        </div>
      </ConsolePanel>

      <div className="reveal-seq grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MetricTile
          label="System state"
          value={apiStatus}
          hint={state.system.sourcePolicy.label}
          icon={Activity}
          tone={apiStatus === 'ONLINE' ? 'success' : apiStatus === 'DEGRADED' ? 'warning' : apiStatus === 'OFFLINE' ? 'danger' : 'neutral'}
          framed
          frameTone={apiStatus === 'ONLINE' ? 'olive' : apiStatus === 'DEGRADED' ? 'amber' : apiStatus === 'OFFLINE' ? 'danger' : 'neutral'}
        />
        <MetricTile
          label="Current severity"
          value={severity}
          hint={state.prediction.monitoringAction || 'Run inference to generate the current operating posture.'}
          icon={ShieldAlert}
          tone={monitoringTone}
          framed
          frameTone={monitoringTone === 'danger' ? 'danger' : monitoringTone === 'warning' ? 'amber' : monitoringTone === 'info' ? 'cyan' : 'olive'}
        />
        <MetricTile
          label="Confidence"
          value={`${currentConfidence.toFixed(1)}%`}
          hint={state.prediction.currentPrediction ? `Dominant lane ${dominantProbabilityLane[0]}` : 'Awaiting inference output'}
          icon={Brain}
          tone="info"
        />
        <MetricTile
          label="Risk score"
          value={state.prediction.currentPrediction ? currentRiskScore : '--'}
          hint={`Danger level ${dashboardDangerLevel.toFixed(1)}m · ${dangerLevelSourceLabel}`}
          icon={Droplets}
          tone={monitoringTone}
          mono={false}
        />
      </div>

      <div ref={predictionInputRef}>
        <LuxeCard className="space-y-6" intensity="primary" frameTone="olive">
          <SectionHeader
            eyebrow="Prediction controls"
            title="Run flood-risk inference"
            description="Configure the current scenario, lock the geographic context, and execute the model with live telemetry and state-matrix guidance."
            icon={Target}
            action={
              <>
                <StatusBadge tone="info">Model profile Alpha 4.2</StatusBadge>
                <StatusBadge tone={stateMatrixStatus === 'ready' ? 'success' : stateMatrixStatus === 'error' ? 'danger' : 'warning'}>
                  Matrix {stateMatrixStatus}
                </StatusBadge>
                <StatusBadge tone={liveDangerLevel ? 'warning' : 'neutral'}>
                  {liveDangerLevel ? `Live danger ${dashboardDangerLevel.toFixed(2)}m` : `Danger ${dashboardDangerLevel.toFixed(2)}m`}
                </StatusBadge>
              </>
            }
            className="mb-8"
          />
          <div className="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_23rem]">
            <div className="space-y-6">
              <div className="grid gap-4 md:grid-cols-2">
                <LuxeInput
                  label="Peak River Level (m)"
                  type="number"
                  value={state.form.data.Peak_Flood_Level_m}
                  onChange={(e: any) => {
                    const v = parseFloat(e.target.value);
                    dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: Number.isFinite(v) ? v : 0 } });
                  }}
                />
                <InsetPanel className="flex flex-col justify-between gap-4">
                  <div>
                    <div className={opsLabelClass}>Inference context</div>
                    <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">
                      {selectedRiverLocationLabel}
                    </div>
                    <div className="mt-1 text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
                      7-day rainfall total {rainfallTotalNow.toFixed(1)}mm across the active scenario.
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div className={`${opsInsetClass} p-3`}>
                      <div className={opsLabelClass}>Verdict</div>
                      <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">{matrixVerdict || 'LOW'}</div>
                    </div>
                    <div className={`${opsInsetClass} p-3`}>
                      <div className={opsLabelClass}>Nodes</div>
                      <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">{selectedRegionSensors.length}</div>
                    </div>
                  </div>
                </InsetPanel>
              </div>

              <InsetPanel className="space-y-5">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className={opsLabelClass}>Event timing</div>
                    <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                      Shape the event window so the dashboard can interpret peak timing and recovery more cleanly.
                    </div>
                  </div>
                  <StatusBadge tone="neutral">Hydrology timing</StatusBadge>
                </div>

                <div className="grid gap-4 sm:grid-cols-3">
                  <div className="space-y-2">
                    <label className={`block text-left ${opsLabelClass}`}>Event days</label>
                    <input
                      type="number"
                      value={state.form.data.Event_Duration_days}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value);
                        dispatch({ type: 'SET_FORM_DATA', payload: { Event_Duration_days: Number.isFinite(v) ? v : 0 } });
                      }}
                      className={vectorFieldClass}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className={`block text-left ${opsLabelClass}`}>Time to peak</label>
                    <input
                      type="number"
                      value={state.form.data.Time_to_Peak_days}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value);
                        dispatch({ type: 'SET_FORM_DATA', payload: { Time_to_Peak_days: Number.isFinite(v) ? v : 0 } });
                      }}
                      className={vectorFieldClass}
                    />
                  </div>
                  <div className="space-y-2">
                    <label className={`block text-left ${opsLabelClass}`}>Recession days</label>
                    <input
                      type="number"
                      value={state.form.data.Recession_Time_day}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value);
                        dispatch({ type: 'SET_FORM_DATA', payload: { Recession_Time_day: Number.isFinite(v) ? v : 0 } });
                      }}
                      className={vectorFieldClass}
                    />
                  </div>
                </div>
              </InsetPanel>

              <InsetPanel className="space-y-5">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className={opsLabelClass}>Daily hydrology inputs</div>
                    <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                      Enter rainfall distribution across the last 7 days for the current scenario.
                    </div>
                  </div>
                  <StatusBadge tone="info">{rainfallTotalNow.toFixed(1)}mm total</StatusBadge>
                </div>

                <div className="grid grid-cols-2 gap-4 md:grid-cols-4 xl:grid-cols-7">
                  {[
                    { key: 'T1d', label: 'Day 1' },
                    { key: 'T2d', label: 'Day 2' },
                    { key: 'T3d', label: 'Day 3' },
                    { key: 'T4d', label: 'Day 4' },
                    { key: 'T5d', label: 'Day 5' },
                    { key: 'T6d', label: 'Day 6' },
                    { key: 'T7d', label: 'Day 7' },
                  ].map((field) => (
                    <div key={field.key} className="space-y-2 min-w-0">
                      <label className={`block text-left ${opsLabelClass}`}>{field.label}</label>
                      <input
                        type="number"
                        value={(state.form.data as any)[field.key]}
                        onChange={(e) => {
                          const v = parseFloat(e.target.value);
                          const nextValue = Number.isFinite(v) ? v : 0;
                          const nextData = { [field.key]: nextValue } as any;
                          const rainfall = {
                            T1d: field.key === 'T1d' ? nextValue : state.form.data.T1d || 0,
                            T2d: field.key === 'T2d' ? nextValue : state.form.data.T2d || 0,
                            T3d: field.key === 'T3d' ? nextValue : state.form.data.T3d || 0,
                            T4d: field.key === 'T4d' ? nextValue : state.form.data.T4d || 0,
                            T5d: field.key === 'T5d' ? nextValue : state.form.data.T5d || 0,
                            T6d: field.key === 'T6d' ? nextValue : state.form.data.T6d || 0,
                            T7d: field.key === 'T7d' ? nextValue : state.form.data.T7d || 0,
                          };
                          const total = Object.values(rainfall).reduce((sum, item) => sum + Number(item || 0), 0);
                          const distribution = Object.values(rainfall).map((mm, idx) => ({
                            day: idx + 1,
                            mm: Math.round(Number(mm) * 10) / 10,
                          }));
                          dispatch({ type: 'SET_FORM_DATA', payload: nextData });
                          dispatch({
                            type: 'UPDATE_RAINFALL_STATS',
                            payload: {
                              total,
                              average: total / 7,
                              distribution,
                            }
                          });
                        }}
                        className={vectorFieldClass}
                      />
                    </div>
                  ))}
                </div>
              </InsetPanel>

              <InsetPanel className="space-y-5">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className={opsLabelClass}>Scenario presets</div>
                    <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                      Start from a dry, monsoon, or extreme profile and then fine-tune the numbers if needed.
                    </div>
                  </div>
                  <StatusBadge tone="neutral">Preset vectors</StatusBadge>
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                  {scenarioPresets.map((s) => {
                    const isSelected = selectedScenarioPreset === s.id;
                    const presetTone =
                      s.id === 'dry'
                        ? 'border-sky-400/24 bg-sky-400/10'
                        : s.id === 'monsoon'
                        ? 'border-amber-400/24 bg-amber-400/10'
                        : 'border-[rgba(255,110,133,0.3)] bg-[rgba(255,110,133,0.1)]';

                    return (
                      <button
                        key={s.id}
                        onClick={() => {
                          const daily = s.rainTotal / 7;
                          const distribution = Array.from({ length: 7 }).map((_, idx) => ({ day: idx + 1, mm: Math.round(daily * 10) / 10 }));
                          dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: s.peak, T1d: daily, T2d: daily, T3d: daily, T4d: daily, T5d: daily, T6d: daily, T7d: daily } });
                          dispatch({ type: 'UPDATE_RAINFALL_STATS', payload: { total: s.rainTotal, average: daily, distribution } });
                          setSelectedScenarioPreset(s.id);
                        }}
                        className={`rounded-2xl border p-5 text-left transition-all hover:-translate-y-0.5 ${presetTone} ${
                          isSelected ? 'ring-1 ring-[color:var(--ops-border-strong)] shadow-[0_18px_36px_rgba(0,0,0,0.22)]' : 'hover:border-[color:var(--ops-border-strong)]'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className={opsLabelClass}>{s.label}</div>
                          {isSelected ? <StatusBadge tone="neutral" className="!px-2 !py-1">Active</StatusBadge> : null}
                        </div>
                        <div className="mt-3 text-xl font-semibold text-[color:var(--ops-text)]">
                          {s.peak.toFixed(1)}m
                        </div>
                        <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                          {s.rainTotal}mm over 7 days
                        </div>
                      </button>
                    );
                  })}
                </div>
              </InsetPanel>
            </div>

            <div className="space-y-6">
              <InsetPanel className="space-y-5">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className={opsLabelClass}>Regional severity matrix</div>
                    <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                      Search and bind a state profile when you need to switch threshold behavior quickly.
                    </div>
                  </div>
                  <ActionButton
                    onClick={reloadStateMatrixIndex}
                    icon={RefreshCw}
                    variant="ghost"
                    className={stateMatrixStatus === 'loading' ? 'opacity-70' : ''}
                  >
                    {stateMatrixStatus === 'loading' ? 'Syncing' : 'Sync'}
                  </ActionButton>
                </div>

                <input
                  value={stateFilter}
                  onChange={(e) => setStateFilter(e.target.value)}
                  placeholder="Search state matrix..."
                  className={opsFieldClass}
                />

                {stateMatrixError ? (
                  <div className="rounded-xl border border-[rgba(255,110,133,0.35)] bg-[rgba(255,110,133,0.12)] px-4 py-3 text-sm text-[color:var(--ops-danger-soft)]">
                    {stateMatrixError}
                  </div>
                ) : null}

                <div className="flex max-h-64 flex-wrap gap-2 overflow-auto pr-1">
                  {filteredStateMatrixKeys.map((k) => {
                    const displayName = stateKeyToDisplayName[k] || k;
                    const active = selectedStateKey === k;

                    return (
                      <button
                        key={k}
                        onClick={() => dispatch({ type: 'SET_SELECTED_STATE', payload: displayName })}
                        className={`${chipButtonClass} ${active ? 'border-[color:var(--ops-border-accent)] bg-[rgba(90,143,255,0.12)] text-[color:var(--ops-text)]' : ''}`}
                      >
                        {displayName}
                      </button>
                    );
                  })}
                </div>
              </InsetPanel>

              <InsetPanel className="space-y-5">
                <div>
                  <div className={opsLabelClass}>Inference summary</div>
                  <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
                    The current run uses the selected state matrix, rainfall distribution, and the latest telemetry context.
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className={`${opsInsetClass} p-3`}>
                    <div className={opsLabelClass}>Selected state</div>
                    <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{state.prediction.selectedState || 'Not selected'}</div>
                  </div>
                  <div className={`${opsInsetClass} p-3`}>
                    <div className={opsLabelClass}>Matrix verdict</div>
                    <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{matrixVerdict || 'LOW'}</div>
                  </div>
                  <div className={`${opsInsetClass} p-3`}>
                    <div className={opsLabelClass}>Danger level</div>
                    <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{dashboardDangerLevel.toFixed(1)}m</div>
                  </div>
                  <div className={`${opsInsetClass} p-3`}>
                    <div className={opsLabelClass}>Telemetry nodes</div>
                    <div className="mt-2 text-base font-semibold text-[color:var(--ops-text)]">{selectedRegionSensors.length}</div>
                  </div>
                </div>

                <ActionButton
                  onClick={handlePredict}
                  disabled={state.prediction.isLoading}
                  icon={state.prediction.isLoading ? RefreshCw : Brain}
                  variant="primary"
                  className="min-h-[3.5rem] w-full text-xs tracking-[0.2em]"
                >
                  {state.prediction.isLoading ? 'Running inference' : 'Execute model inference'}
                </ActionButton>
              </InsetPanel>
            </div>
          </div>
        </LuxeCard>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <MetricTile
          label="Model fidelity"
          value={`${state.prediction.accuracy.toFixed(1)}%`}
          hint="Observed prediction accuracy for the current workspace profile."
          icon={Activity}
          tone="info"
          framed
          frameTone="cyan"
        />
        <MetricTile
          label="Inference latency"
          value={`${Math.max(0, Math.round(state.prediction.latency / 10))}ms`}
          hint="Latest end-to-end inference turnaround."
          icon={Clock}
          tone="neutral"
        />
        <MetricTile
          label="Scoped nodes"
          value={selectedRegionSensors.length}
          hint={selectedRiverLocationLabel}
          icon={Radio}
          tone="success"
          mono={false}
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        {state.prediction.currentPrediction ? (
          <div
            ref={monitoringAlertRef}
            className={`rounded-2xl transition-all ${monitoringAlertPulse ? 'ring-1 ring-[rgba(255,110,133,0.32)]' : ''}`}
          >
            <MonitoringProtocolAlert />
          </div>
        ) : (
          <EmptyState
            title="Monitoring protocol will appear after inference"
            description="Run the model to generate a severity-specific operating posture, recommended action, and prioritized zones."
            icon={ShieldAlert}
          />
        )}

        <WeatherConsolePanel
          target={dashboardWeatherTarget}
          coordinates={dashboardWeatherCoordinates}
          subtitle={
            state.prediction.currentPrediction
              ? `Atmospheric conditions for ${selectedRiverLocationLabel} aligned with the current monitoring level.`
              : `Atmospheric conditions for ${selectedRiverLocationLabel} feeding the active dashboard view.`
          }
        />
      </div>

      <LuxeCard intensity="primary" frameTone="cyan">
        <SectionHeader
          eyebrow="Telemetry snapshot"
          title="Selected region water levels"
          description={
            selectedRegionSensorScope.mode === 'city_nearby'
              ? `Nearby monitored water sources for ${selectedRiverLocationLabel}, ranked from the active regional network.`
              : `Live gauge levels for ${selectedRiverLocationLabel} and linked regional stations only.`
          }
          icon={Droplets}
          action={
            <StatusBadge tone={sensorsLoading ? 'warning' : 'info'} icon={Radio}>
              {sensorsLoading ? 'Syncing levels' : `${selectedRegionSensors.length} region nodes`}
            </StatusBadge>
          }
          className="mb-6"
        />

        {sensorsLoading && !leadRegionSensor ? (
          <div className="grid grid-cols-1 gap-8 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
            <SkeletonLoader type="gauge" />
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <SkeletonLoader type="card" count={4} />
            </div>
          </div>
        ) : leadRegionSensor ? (
          <div className="grid grid-cols-1 gap-8 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
            <div className="space-y-4">
              <WaterLevelGauge
                currentLevel={Number(leadRegionSensor.river_level || 0)}
                dangerLevel={Number(dashboardDangerLevel || 13.5)}
                maxLevel={Math.max(Number(dashboardDangerLevel || 13.5) + 4, Number(leadRegionSensor.river_level || 0) + 2, 18)}
                severity={severity}
              />
              <InsetPanel className="space-y-4">
                <div>
                  <div className={opsLabelClass}>Lead station</div>
                  <div className="mt-2 text-lg font-semibold uppercase tracking-[0.08em] text-[color:var(--ops-text)]">{leadRegionSensor.station}</div>
                </div>
                <div className="mt-3 flex flex-wrap gap-2">
                  <div className="inline-flex max-w-full items-center gap-2 rounded-md border border-white/10 bg-black/20 px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.16em] text-[color:var(--ops-text-soft)]">
                    <Waves size={10} className="shrink-0 text-[color:var(--ops-info)]" />
                    <span className="truncate">{leadRegionSensor.river || 'Active Basin'}</span>
                  </div>
                  <div className={`inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] ${leadTrendMeta?.tone || 'border-white/12 bg-white/[0.05] text-[color:var(--ops-text-soft)]'}`}>
                    <LeadTrendIcon size={10} className="shrink-0" />
                    <span>{leadRegionSensor.trend || 'STEADY'}</span>
                  </div>
                </div>
                <div className="flex items-center justify-between text-sm text-[color:var(--ops-text-soft)]">
                  <span>Danger Level</span>
                  <span className="font-mono text-[color:var(--ops-text)]">{dashboardDangerLevel.toFixed(1)}m</span>
                </div>
              </InsetPanel>
            </div>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              {selectedRegionSensors.slice(0, 4).map((sensor) => (
                <RegionSensorCard key={sensor.station} sensor={sensor} />
              ))}
            </div>
          </div>
        ) : (
          <EmptyState
            title="No selected region water levels yet"
            description="Pick a state or city and the dashboard will load live water levels only for that selected region."
            icon={Droplets}
          />
        )}
      </LuxeCard>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="lg:col-span-7">
          <NeuralNetworkGraph
            preferredState={state.prediction.selectedState}
            matrixRegion={effectiveStateMatrix?.region}
            matrixVerdict={matrixVerdict}
            matrixStatus={stateMatrixStatus}
            probabilityLanes={probabilityLanes}
            dominantLane={dominantProbabilityLane[0]}
          />
        </div>
        <div className="lg:col-span-5"><CWCLiveDataDisplay /></div>
      </div>

      <NeuralOperationsGraph />

      {state.prediction.currentPrediction && (
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
          <LuxeCard frameTone="amber">
            <SectionHeader
              eyebrow="Probability lanes"
              title="Risk lane heartbeat"
              description="The current distribution shows how the model is weighting low, moderate, severe, and critical outputs."
              icon={Activity}
              action={
                <>
                  <StatusBadge tone="info">Dominant {dominantProbabilityLane[0]}</StatusBadge>
                  <StatusBadge tone="neutral">Peak {dominantProbabilityLane[1].toFixed(1)}%</StatusBadge>
                </>
              }
              className="mb-6"
            />
            <div className="mb-5 flex flex-wrap gap-2">
              {[
                { key: 'low', label: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1' },
                { key: 'moderate', label: 'MODERATE', value: probabilityLanes.moderate, fill: '#bc9437' },
                { key: 'severe', label: 'SEVERE', value: probabilityLanes.severe, fill: '#ff8a5b' },
                { key: 'critical', label: 'CRITICAL', value: probabilityLanes.critical, fill: '#ff0037' },
              ].map((lane) => (
                <StatusBadge key={lane.key} tone="neutral" className="!rounded-xl !px-3 !py-2">
                  <span className="mr-1 inline-block h-2 w-2 rounded-full" style={{ backgroundColor: lane.fill }} />
                  {lane.label} {lane.value.toFixed(1)}%
                </StatusBadge>
              ))}
            </div>
            <div className="h-44 min-h-[11rem] min-w-0">
              <ProbabilityHeartbeatGraph
                dominantLane={dominantProbabilityLane[0]}
                lanes={[
                  { key: 'low', label: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1' },
                  { key: 'moderate', label: 'MODERATE', value: probabilityLanes.moderate, fill: '#bc9437' },
                  { key: 'severe', label: 'SEVERE', value: probabilityLanes.severe, fill: '#ff8a5b' },
                  { key: 'critical', label: 'CRITICAL', value: probabilityLanes.critical, fill: '#ff0037' },
                ]}
                className="h-full w-full"
              />
            </div>
          </LuxeCard>

          <LuxeCard frameTone="olive">
            <SectionHeader
              eyebrow="Strategic response"
              title="Priority action by zone"
              description="These zone directives are derived from the active severity and the configured strategic location map."
              icon={ShieldAlert}
              className="mb-6"
            />
            <div className="space-y-5">
              {strategicResponses.map((item, i) => (
                <InsetPanel key={i} className="flex items-center justify-between gap-3">
                  <span className="text-sm font-medium text-[color:var(--ops-text-soft)]">{item.area}</span>
                  <StatusBadge tone={item.status === 'EVACUATE' || item.status === 'CRITICAL' ? 'danger' : item.status === 'WARNING' || item.status === 'PREPARE' || item.status === 'STAGING' ? 'warning' : item.status === 'MONITOR' ? 'info' : 'success'}>
                    {item.status}
                  </StatusBadge>
                </InsetPanel>
              ))}
            </div>
          </LuxeCard>
        </div>
      )}

      <FloodRiskHeatmap
        data={heatmapData}
        title={isCityHotspotView ? 'City hotspot heatmap' : 'State risk heatmap'}
        caption={
          isCityHotspotView
            ? `Linked hotspots for ${selectedRiverLocationLabel}`
            : `Sector-linked hotspots for ${state.prediction.selectedState || 'active state'}`
        }
      />

      <FloodLogsPanel onLogLoaded={scrollToPredictionInput} borderless />

      <ToastNotification toasts={toasts} onRemove={removeToast} />
    </PageShell>
  );
};

export default DashboardPage;
