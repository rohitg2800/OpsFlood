import React, { useEffect, useCallback, useState, useMemo, useRef } from 'react';
import {
  Droplets, Activity, TrendingUp, TrendingDown, Minus,
  Clock, ShieldAlert, RefreshCw,
  Waves, Radio, Brain, Target, Network
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useEnhancedPrediction, useSystemInit, useAlertNotifications, useFormValidation, useSensorAPI } from '../hooks/useAppOperations';
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
import { getScopedSensorSelection, getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';
import type { SensorData } from '../types';
import { locationMatchesCandidate, resolveGeoCoordinate } from '../data/geoCoordinates';

// ==========================================
// DYNAMIC STATE GEOGRAPHY MAPPING
// ==========================================
const getStrategicLocations = (stateName: string) => {
  const s = (stateName || '').toLowerCase();
  if (s.includes('maharashtra')) return ['Shirol Sector', 'Irwin Bridge', 'Kagal High-Ground'];
  if (s.includes('bihar')) return ['Koshi Barrage', 'Darbhanga Sector', 'Patna Lowlands'];
  if (s.includes('assam')) return ['Majuli Island', 'Kaziranga Sector', 'Brahmaputra Banks'];
  if (s.includes('kerala')) return ['Kuttanad Region', 'Vembanad Lowlands', 'Periyar Banks'];
  if (s.includes('uttarakhand')) return ['Joshimath Sector', 'Rishikesh Ghats', 'Mandakini Basin'];
  if (s.includes('gujarat')) return ['Surat Lowlands', 'Ukai Dam Sector', 'Tapi River Banks'];
  if (s.includes('odisha') || s.includes('orissa')) return ['Mahanadi Delta', 'Cuttack Sector', 'Puri Coastal'];
  if (s.includes('west bengal')) return ['Sundarbans Delta', 'Hooghly Banks', 'Siliguri Sector'];
  if (s.includes('uttar pradesh')) return ['Varanasi Ghats', 'Prayagraj Lowlands', 'Ghaghara Basin'];
  if (s.includes('punjab')) return ['Sutlej Banks', 'Ludhiana Sector', 'Ravi Basin'];
  if (s.includes('tamil nadu')) return ['Chennai Lowlands', 'Kaveri Delta', 'Madurai Sector'];
  // Default Generic Fallback for unmapped states
  return ['Sector Alpha', 'Central Barrage', 'Low-Elevation Zones'];
};

// ==========================================
// LUXE SUB-COMPONENTS (EMS STYLED)
// ==========================================

const LuxeCard = ({ children, className = "" }: { children: React.ReactNode, className?: string }) => (
  <div className={`min-w-0 rounded-lg border border-[#ff0037]/26 bg-[#0B0A08]/58 p-10 shadow-[0_16px_42px_rgba(0,0,0,0.52)] backdrop-blur-xl transition-[transform,box-shadow,background-color] duration-300 ${className}`}>
    {children}
  </div>
);

const LuxeInput = ({
  label,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement> & { label: string }) => (
  <div className="space-y-2 group">
    <label className="block pl-2 text-left text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em] group-focus-within:text-white transition-colors">
      {label}
    </label>
    <div className="relative">
      <input 
        {...props} 
        className="w-full rounded-md border border-[#ff9b2f]/35 bg-[#f59e0b]/14 px-4 py-3.5 font-mono text-base font-bold text-white shadow-[inset_0_2px_4px_rgba(0,0,0,0.38)] outline-none transition-all focus:bg-[#f59e0b]/22 focus:ring-4 focus:ring-[#f59e0b]/18" 
      />
      <div className="absolute right-3 top-1/2 h-6 w-1 -translate-y-1/2 rounded-full bg-[#ffd18a]/40" />
    </div>
  </div>
);

const vectorFieldClass =
  'w-full rounded-md border border-[#ff9b2f]/35 bg-[#f59e0b]/14 px-3.5 py-2.5 font-mono text-xs font-bold text-white shadow-[inset_0_2px_4px_rgba(0,0,0,0.38)] outline-none transition-all focus:bg-[#f59e0b]/22 focus:ring-4 focus:ring-[#f59e0b]/18';

const chipButtonClass =
  'min-h-[2.5rem] whitespace-nowrap rounded-md border border-[#ff9b2f]/32 bg-[#f59e0b]/14 px-4 py-2 text-[9px] font-black uppercase tracking-[0.16em] shadow-sm transition-all active:scale-95';

const sectionShellClass =
  'space-y-4 rounded-md border border-[#ff0037]/18 bg-black/26 p-5 text-center shadow-[inset_0_1px_0_rgba(255,255,255,0.03)] backdrop-blur-lg';

const getTrendMeta = (trend?: string) => {
  if (trend === 'RISING') {
    return {
      icon: TrendingUp,
      tone: 'border-[#ff0037]/28 bg-[#ff0037]/10 text-[#ff9eb1]',
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
    tone: 'border-white/12 bg-white/[0.05] text-stone-300',
  };
};

const getSensorStatusTone = (status: string) => {
  if (status === 'CRITICAL') {
    return 'border-[#ff0037]/45 bg-[#ff0037]/12 text-[#ff0037]';
  }
  if (status === 'WARNING') {
    return 'border-[#ff0037]/28 bg-amber-500/12 text-amber-300';
  }
  return 'border-[#ff0037]/24 bg-emerald-500/12 text-emerald-400';
};

const RegionSensorCard = ({ sensor }: { sensor: SensorData }) => {
  const trendMeta = getTrendMeta(sensor.trend);
  const TrendIcon = trendMeta.icon;

  return (
    <div className="rounded-md border border-[#ff0037]/18 bg-black/35 p-5">
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Station</div>
          <div className="mt-2 text-sm font-black uppercase tracking-[0.14em] text-white">{sensor.station}</div>
          <div className="mt-3 flex flex-wrap gap-2">
            <div className="inline-flex max-w-full items-center gap-2 rounded-md border border-[#ff0037]/18 bg-white/[0.03] px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] text-stone-300">
              <Waves size={10} className="shrink-0 text-[#ff7f96]" />
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
        <div className="rounded-md border border-[#ff0037]/14 bg-white/[0.03] p-3">
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Water Level</div>
          <div className="mt-2 text-2xl font-black font-mono text-white">{Number(sensor.river_level || 0).toFixed(2)}m</div>
        </div>
        <div className="rounded-md border border-[#ff0037]/14 bg-white/[0.03] p-3">
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Rain 1H</div>
          <div className="mt-2 text-2xl font-black font-mono text-white">{Number(sensor.rainfall_last_hour || 0).toFixed(1)}mm</div>
        </div>
      </div>
      <div className="mt-3 text-[10px] font-mono uppercase tracking-[0.2em] text-stone-500">
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
  const verdictTone =
    matrixVerdict === 'CRITICAL' ? 'bg-[#ff0037]/12 text-[#ff0037]' :
    matrixVerdict === 'SEVERE' ? 'bg-amber-500/12 text-amber-300' :
    matrixVerdict === 'MODERATE' ? 'bg-[#bc9437]/12 text-[#bc9437]' :
    'bg-emerald-500/12 text-emerald-400';
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
    <LuxeCard className="mt-8">
      <div className="mb-8 pb-6">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="space-y-2">
            <h3 className="text-sm font-bold text-[#bc9437] flex items-center gap-3 uppercase tracking-widest font-cinzel">
              <Network size={18} /> Synaptic Inference Matrix
            </h3>
            <p className="text-xs text-stone-500">
              Preferred state: <span className="font-black text-white">{preferredState || 'Maharashtra'}</span>
              {matrixRegion ? <> {' '}| Region profile: <span className="font-black text-[#bc9437]">{matrixRegion}</span></> : null}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[9px] text-slate-500 font-mono tracking-widest uppercase">
              {matrixStatus === 'ready' ? 'State_Matrix_Linked' : matrixStatus === 'loading' ? 'Matrix_Syncing' : matrixStatus === 'error' ? 'Matrix_Link_Failed' : 'Node_Cluster_Active'}
            </span>
            <span className="rounded-md border border-[#ff0037]/20 bg-black/30 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.22em] text-stone-300">
              Lane_Sync: <span className={`${dominantConfig.tone} ml-1`}>{dominantLane}</span>
            </span>
            <span className={`rounded-md border border-[#ff0037]/28 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.22em] ${verdictTone}`}>
              {matrixVerdict || 'LOW'}
            </span>
          </div>
        </div>
      </div>
      <div className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Preferred State</div>
          <div className="mt-2 text-sm font-black text-white">{preferredState || 'Maharashtra'}</div>
        </div>
        <div className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Matrix Region</div>
          <div className="mt-2 text-sm font-black text-[#bc9437]">{matrixRegion || 'Awaiting profile'}</div>
        </div>
        <div className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
          <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Current Verdict</div>
          <div className="mt-2 text-sm font-black text-white">{matrixVerdict || 'LOW'}</div>
        </div>
      </div>
      <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {laneConfig.map((lane) => (
          <div key={lane.key} className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
            <div className="mb-3 flex items-center justify-between gap-3">
              <span className="text-[9px] font-black uppercase tracking-[0.22em] text-stone-500">{lane.label}</span>
              <span className={`text-[10px] font-black uppercase tracking-[0.14em] ${lane.tone}`}>{lane.value.toFixed(1)}%</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-white/[0.06]">
              <div
                className="h-full rounded-full transition-all duration-500"
                style={{
                  width: `${Math.max(4, lane.value)}%`,
                  backgroundColor: lane.fill,
                  boxShadow: `0 0 18px ${lane.fill}`,
                }}
              />
            </div>
          </div>
        ))}
      </div>
      <div className="flex justify-between items-center mb-4">
        <h4 className="text-[10px] font-black text-stone-400 uppercase tracking-[0.3em]">
          <Network size={18} /> Synaptic Inference Matrix
        </h4>
        <span className="text-[9px] text-slate-500 font-mono tracking-widest uppercase">Preferred_State_Nodes</span>
      </div>
      <div className="relative h-48 w-full flex justify-between px-14 items-center">
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
          className="absolute inset-0 blur-3xl -z-10 transition-all duration-500"
          style={{
            background: `linear-gradient(90deg, rgba(188,148,55,0.08), transparent, ${dominantConfig.fill}22)`,
          }}
        />
      </div>
    </LuxeCard>
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

export const DashboardPage: React.FC = () => {
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
  // -----------------------------------------------------
  // DYNAMIC STRATEGIC RESPONSE LOGIC
  // -----------------------------------------------------
  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  const dynamicLocations = getStrategicLocations(state.prediction.selectedState);
  
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

    if (focusedLocation) {
      return { lat: focusedLocation.lat, lon: focusedLocation.lon };
    }

    const focusTarget = state.prediction.selectedCity || state.form.data.station;
    if (focusTarget) {
      if (locationMatchesCandidate(currentLocationData, focusTarget) && currentLocationData) {
        return {
          lat: currentLocationData.lat,
          lon: currentLocationData.lon,
        };
      }

      return undefined;
    }

    const stateLocation = resolveGeoCoordinate(
      state.prediction.selectedState,
      state.form.data.state,
    );

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
  const dashboardDangerLevel =
    Number(leadRegionSensor?.danger_level || 0) ||
    Number(state.cwc.liveData.dangerLevel || 0) ||
    state.prediction.currentPrediction?.danger_level ||
    state.prediction.dangerLevel ||
    effectiveStateMatrix?.danger_level_m ||
    13.5;
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
      window.requestAnimationFrame(() => {
        setMonitoringAlertPulse(true);
        monitoringAlertPulseTimeoutRef.current = window.setTimeout(() => {
          setMonitoringAlertPulse(false);
          monitoringAlertPulseTimeoutRef.current = null;
        }, 1400);
      });
    });
  }, [state.prediction.currentPrediction, state.prediction.isLoading]);

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
      dispatch({
        type: 'ADD_PREDICTION_LOG',
        payload: {
          id: Date.now(),
          timestamp: new Date().toISOString(),
          peak_level: state.form.data.Peak_Flood_Level_m || 0,
          rainfall: rainfallTotalNow || 0,
          severity: result.severity,
          confidence: result.confidence_percent
        }
      });
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
    <PageShell className="tech-grid">
      <style>{`
        .font-cinzel { font-family: 'Cinzel', serif; }
        .tech-grid { background-image: radial-gradient(rgba(188, 148, 55, 0.05) 1px, transparent 1px); background-size: 40px 40px; }
        .monitoring-alert-shell {
          border-radius: 0.85rem;
          transition:
            background-color 240ms ease,
            box-shadow 240ms ease,
            outline-color 240ms ease;
        }
        .monitoring-alert-pulse {
          background-color: rgba(255, 0, 55, 0.04);
          box-shadow: 0 0 0 1px rgba(255, 0, 55, 0.32);
          outline: 1px solid rgba(255, 0, 55, 0.14);
          outline-offset: 4px;
        }
        @media (prefers-reduced-motion: reduce) {
          .monitoring-alert-shell {
            transition: none;
          }
        }
      `}</style>

      <PageHero
        eyebrow="Command Console"
        title="Dashboard"
        subtitle="Live flood inference, state matrix lookup, and response intelligence from one central workspace."
        icon={Target}
        centered
        action={
          <>
            <div className="rounded-md border border-[#ff0037]/26 bg-white/8 px-5 py-3 text-[10px] font-black uppercase tracking-[0.24em] text-slate-300 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]">
              API: {apiStatus}
            </div>
            <button
              type="button"
              onClick={reloadStateMatrixIndex}
              className="inline-flex items-center gap-3 rounded-md border border-[#ff0037]/35 bg-[#ff0037]/10 px-6 py-3 text-[10px] font-black uppercase tracking-[0.22em] text-[#ff7f96] transition-all hover:bg-[#ff0037] hover:text-white shadow-[0_0_15px_rgba(255,0,55,0.1)]"
            >
              <RefreshCw size={14} className={stateMatrixStatus === 'loading' ? 'animate-spin' : ''} />
              Refresh Matrices
            </button>
          </>
        }
      />

      {/* PREDICTION INPUT MODULE */}
      <div ref={predictionInputRef}>
        <LuxeCard className="relative overflow-hidden">
          <div className="absolute top-0 left-0 h-[2px] w-full animate-pulse bg-gradient-to-r from-transparent via-[#ff0037]/45 to-transparent" />
          
          <div className="mb-8 flex flex-col items-center justify-center gap-3 pb-6 text-center">
            <h2 className="text-sm font-black flex items-center gap-4 text-white font-cinzel tracking-[0.2em] justify-center">
              <Target className="text-[#bc9437]" size={22} /> VECTOR_INPUT_ARRAY
            </h2>
            <div className="rounded-md border border-[#ff0037]/20 bg-black/40 px-4 py-1.5 text-[10px] font-mono uppercase tracking-widest text-stone-500 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
              Protocol: Alpha_4.2
            </div>
          </div>
          
          <div className="space-y-7">
          <div className="mx-auto grid max-w-2xl grid-cols-1 gap-6">
            <LuxeInput 
              label="Peak River Level (m)" 
              type="number" 
              value={state.form.data.Peak_Flood_Level_m}
              onChange={(e: any) => {
                const v = parseFloat(e.target.value);
                dispatch({ type: 'SET_FORM_DATA', payload: { Peak_Flood_Level_m: Number.isFinite(v) ? v : 0 } });
              }}
            />
          </div>

          <div className="grid grid-cols-1 xl:grid-cols-2 gap-8 items-start">
            <div className={sectionShellClass}>
              <div className="space-y-2">
                <div className="text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">
                  State Matrix Binding
                </div>
                <p className="text-xs text-stone-500 leading-relaxed">
                  The dashboard uses the selected state's severity matrix for thresholds and verdicts.
                </p>
              </div>
              <StateSelector className="!space-y-4" />
              <div className="space-y-2 pt-1">
                <label className="block text-left text-[10px] font-black uppercase tracking-[0.24em] text-stone-400">
                  City / Station Input
                </label>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(0,1fr)_auto]">
                  <input
                    type="text"
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
                  <button
                    type="button"
                    onClick={applyCustomCity}
                    className="rounded-md border border-[#ff9b2f]/38 bg-[#f59e0b]/18 px-4 py-2 text-[10px] font-black uppercase tracking-[0.22em] text-[#ffd18a] transition-all hover:bg-[#f59e0b]/32 hover:text-white"
                  >
                    Lock City
                  </button>
                </div>
                <p className="text-left text-[9px] font-mono uppercase tracking-[0.18em] text-stone-500">
                  Active city: {(state.prediction.selectedCity || state.form.data.station || 'none').toUpperCase()}
                </p>
                {(state.prediction.selectedCity || state.form.data.station) ? (
                  <div className="rounded-md border border-[#ff0037]/18 bg-black/35 p-4 text-left">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="text-[10px] font-black uppercase tracking-[0.24em] text-[#ff9eb1]">
                        Nearby Water Sources
                      </div>
                      <div className="rounded-md border border-[#ff0037]/18 bg-white/[0.04] px-2.5 py-1 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300">
                        {selectedRegionSensorScope.mode === 'city_exact'
                          ? 'Exact Match'
                          : selectedRegionSensorScope.mode === 'city_nearby'
                          ? 'Nearby Network'
                          : selectedRegionSensorScope.mode === 'state'
                          ? 'State Network'
                          : 'Live Feed'}
                      </div>
                    </div>
                    <p className="mt-2 text-[10px] leading-relaxed text-stone-500">
                      {nearbyWaterSourcesNote}
                    </p>
                    <div className="mt-4 space-y-2">
                      {selectedRegionSensors.length ? (
                        selectedRegionSensors.slice(0, 4).map((sensor) => (
                          <div
                            key={`${sensor.station}-${sensor.river || 'river'}`}
                            className="flex items-center justify-between gap-3 rounded-md border border-[#ff0037]/12 bg-white/[0.03] px-3 py-2"
                          >
                            <div className="min-w-0">
                              <div className="truncate text-[10px] font-black uppercase tracking-[0.16em] text-white">
                                {sensor.station}
                              </div>
                              <div className="truncate text-[9px] font-mono uppercase tracking-[0.14em] text-stone-500">
                                {sensor.river || 'Active Basin'}
                              </div>
                            </div>
                            <div className="text-right">
                              <div className="text-sm font-black font-mono text-white">
                                {Number(sensor.river_level || 0).toFixed(2)}m
                              </div>
                              <div className="text-[8px] font-black uppercase tracking-[0.16em] text-stone-500">
                                {sensor.status}
                              </div>
                            </div>
                          </div>
                        ))
                      ) : (
                        <div className="rounded-md border border-[#ff0037]/12 bg-white/[0.03] px-3 py-3 text-[10px] text-stone-500">
                          Telemetry sync is still resolving nearby monitored water sources for this city.
                        </div>
                      )}
                    </div>
                  </div>
                ) : null}
              </div>
            </div>

            <div className={sectionShellClass}>
              <div className="flex flex-col items-center justify-center gap-1">
                <span className="text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">
                  Operational Timing
                </span>
                <span className="text-[9px] font-mono text-stone-600 tracking-widest uppercase">
                  Flood Event Shape
                </span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="space-y-2">
                  <label className="block text-left text-[10px] font-black text-stone-400 uppercase tracking-[0.24em]">
                    Event Days
                  </label>
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
                  <label className="block text-left text-[10px] font-black text-stone-400 uppercase tracking-[0.24em]">
                    Time To Peak
                  </label>
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
                  <label className="block text-left text-[10px] font-black text-stone-400 uppercase tracking-[0.24em]">
                    Recession Days
                  </label>
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
            </div>
          </div>

          <div className={sectionShellClass}>
            <div className="mb-2 flex flex-col items-center justify-center gap-1">
              <span className="text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">
                Daily Hydrology Inputs
              </span>
              <span className="text-[9px] font-mono text-stone-600 tracking-widest uppercase">
                Neural Feature Feed
              </span>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-7 gap-4">
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
                  <label className="block text-left text-[10px] font-black text-stone-400 uppercase tracking-[0.24em]">
                    {field.label}
                  </label>
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
          </div>

          {/* STATE MATRIX BROWSER */}
          <div className={sectionShellClass}>
            <div className="mb-1 flex flex-col items-center justify-center gap-3">
              <span className="text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">
                Regional Severity Matrix
              </span>
              <button
                type="button"
                onClick={reloadStateMatrixIndex}
                className="inline-flex items-center gap-2 rounded-md border border-[#ff0037]/35 bg-[#ff0037]/10 px-3 py-1.5 text-[9px] font-black uppercase text-[#ff7f96] transition-all hover:bg-[#ff0037] hover:text-white"
              >
                <RefreshCw size={12} className={stateMatrixStatus === 'loading' ? 'animate-spin' : ''} />
                Sync_Matrix
              </button>
            </div>

            <input
              value={stateFilter}
              onChange={(e) => setStateFilter(e.target.value)}
              placeholder="Search geographic sector..."
              className="mx-auto w-full max-w-2xl rounded-md border border-[#ff9b2f]/35 bg-[#f59e0b]/14 px-4 py-3 font-mono text-xs font-bold text-white shadow-[inset_0_2px_4px_rgba(0,0,0,0.35)] transition-all outline-none focus:bg-[#f59e0b]/22 focus:ring-4 focus:ring-[#f59e0b]/18"
            />

            {stateMatrixError ? (
              <p className="text-center text-[10px] font-mono uppercase tracking-[0.18em] text-[#ff9eb1]">
                {stateMatrixError}
              </p>
            ) : null}

            <div className="flex flex-wrap justify-center gap-3 max-h-52 overflow-auto pr-2 pb-2 custom-scrollbar">
              {filteredStateMatrixKeys.map((k) => {
                const displayName = stateKeyToDisplayName[k] || k;
                const active = selectedStateKey === k;
                return (
                  <button
                    key={k}
                    onClick={() => dispatch({ type: 'SET_SELECTED_STATE', payload: displayName })}
                    className={`${chipButtonClass} ${
                      active
                        ? 'border-[#ff4b6d]/60 bg-[#ff0037] text-white shadow-[0_10px_30px_rgba(255,0,55,0.22)]'
                        : 'bg-white/7 text-stone-400 hover:bg-[#ff0037]/10 hover:text-[#ffd7de]'
                    }`}
                  >
                    {displayName}
                  </button>
                );
              })}
            </div>
          </div>

          {/* SCENARIO QUICK-FILL */}
          <div className={sectionShellClass}>
            <div className="mb-2 flex flex-col items-center justify-center gap-1">
              <span className="text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">Vector Presets</span>
              <span className="text-[9px] font-mono text-stone-600 tracking-widest uppercase">Presets_V4.2</span>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              {scenarioPresets.map((s) => {
                const isSelected = selectedScenarioPreset === s.id;
                const presetTone =
                  s.id === 'dry'
                    ? {
                        shell: 'border-cyan-400/30 bg-gradient-to-br from-cyan-500/18 via-sky-500/12 to-emerald-500/10 shadow-[0_16px_34px_rgba(34,211,238,0.12)] hover:from-cyan-500/24 hover:via-sky-500/16 hover:to-emerald-500/14',
                        label: 'text-cyan-200',
                        accent: 'bg-cyan-300/90',
                      }
                    : s.id === 'monsoon'
                    ? {
                        shell: 'border-amber-400/34 bg-gradient-to-br from-[#f59e0b]/24 via-[#f97316]/16 to-[#dc2626]/10 shadow-[0_16px_34px_rgba(245,158,11,0.14)] hover:from-[#f59e0b]/30 hover:via-[#f97316]/20 hover:to-[#dc2626]/14',
                        label: 'text-amber-100',
                        accent: 'bg-amber-300/90',
                      }
                    : {
                        shell: 'border-[#ff4b6d]/38 bg-gradient-to-br from-[#6b000f]/76 via-[#b00020]/54 to-[#ff0037]/24 shadow-[0_18px_38px_rgba(255,0,55,0.18)] hover:from-[#7f0014]/82 hover:via-[#c00024]/58 hover:to-[#ff335b]/28',
                        label: 'text-[#ffd7de]',
                        accent: 'bg-[#ff7f96]',
                      };

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
                    className={`group relative overflow-hidden rounded-md border p-5 text-center transition-all duration-300 hover:-translate-y-0.5 hover:brightness-110 ${presetTone.shell} ${
                      isSelected
                        ? 'scale-[1.02] ring-2 ring-white/18 shadow-[0_0_0_1px_rgba(255,255,255,0.08),0_18px_40px_rgba(255,0,55,0.18)]'
                        : ''
                    }`}
                  >
                    <div className={`absolute inset-x-4 top-0 h-[2px] ${presetTone.accent}`} />
                    <div className="flex items-start justify-between gap-3">
                      <div className={`text-[9px] font-black uppercase tracking-widest text-left transition-colors ${presetTone.label}`}>{s.label}</div>
                      {isSelected ? (
                        <span className="rounded-full bg-white/16 px-2 py-1 text-[8px] font-black uppercase tracking-[0.18em] text-white">
                          Active
                        </span>
                      ) : null}
                    </div>
                    <div className="mt-2 text-sm font-black text-white font-mono">
                      {s.peak.toFixed(1)}m <span className="text-white/30">/</span> {s.rainTotal}mm
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

            <div className="pt-2 flex justify-center">
              <button 
                onClick={handlePredict}
                disabled={state.prediction.isLoading}
                className="group flex w-full max-w-xl items-center justify-center gap-3 rounded-md border border-[#ff4b6d]/55 bg-gradient-to-br from-[#ff0037] to-[#a10624] py-4 font-black text-white shadow-[0_20px_60px_rgba(255,0,55,0.18)] transition-all hover:from-[#ff335b] hover:to-[#c20f33] active:scale-[0.98]"
              >
                {state.prediction.isLoading ? <RefreshCw className="animate-spin" size={18} /> : <Brain size={20} />}
                <span className="uppercase tracking-[0.28em] text-xs">Execute Neural Inference</span>
              </button>
            </div>
          </div>
        </LuxeCard>
      </div>

      {/* TELEMETRY READOUTS */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
         <LuxeCard className="!p-10 text-center">
            <Activity size={30} className="text-[#bc9437] mx-auto mb-5"/>
            <div className="text-5xl font-black text-white font-mono tracking-tighter">{state.prediction.accuracy.toFixed(1)}%</div>
            <div className="text-[11px] uppercase font-black text-stone-500 tracking-[0.4em] mt-3">Model_Fidelity</div>
         </LuxeCard>
         <LuxeCard className="!p-10 text-center">
            <Clock size={30} className="text-[#bc9437] mx-auto mb-5"/>
            <div className="text-5xl font-black text-white font-mono tracking-tighter">{Math.round(state.prediction.latency / 10)}ms</div>
            <div className="text-[11px] uppercase font-black text-stone-500 tracking-[0.4em] mt-3">Inference_Latency</div>
         </LuxeCard>
      </div>

      <div className="space-y-4">
        {state.prediction.currentPrediction ? (
          <div
            ref={monitoringAlertRef}
            className={`monitoring-alert-shell ${monitoringAlertPulse ? 'monitoring-alert-pulse' : ''}`}
          >
            <MonitoringProtocolAlert />
          </div>
        ) : null}

        <WeatherConsolePanel
          target={dashboardWeatherTarget}
          coordinates={dashboardWeatherCoordinates}
          subtitle={
            state.prediction.currentPrediction
              ? `Atmospheric conditions for ${selectedRiverLocationLabel} synchronized beneath the active monitoring protocol.`
              : `Atmospheric conditions for ${selectedRiverLocationLabel} feeding the active dashboard view.`
          }
          className="bg-[#080707]/70"
        />
      </div>

      <LuxeCard>
        <div className="mb-8 flex flex-col gap-4 border-b border-[#ff0037]/18 pb-6 md:flex-row md:items-center md:justify-between">
          <div className="space-y-2">
            <h3 className="flex items-center gap-3 text-xs font-black uppercase tracking-[0.3em] text-[#ff7f96]">
              <Droplets size={18} /> Selected Region Water Levels
            </h3>
            <p className="text-sm text-stone-500">
              {selectedRegionSensorScope.mode === 'city_nearby'
                ? (
                    <>
                      Nearby monitored water sources for <span className="font-black text-white">{selectedRiverLocationLabel}</span>, ranked from the active regional network.
                    </>
                  )
                : (
                    <>
                      Live gauge levels for <span className="font-black text-white">{selectedRiverLocationLabel}</span> and linked regional stations only.
                    </>
                  )}
            </p>
          </div>
          <div className="inline-flex w-fit items-center gap-2 rounded-md border border-[#ff0037]/26 bg-[#ff0037]/10 px-4 py-2 text-[10px] font-black uppercase tracking-[0.22em] text-[#ff9eb1]">
            <Radio size={14} className={sensorsLoading ? 'animate-pulse' : ''} />
            {sensorsLoading ? 'Syncing Levels' : `Region Nodes: ${selectedRegionSensors.length}`}
          </div>
        </div>

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
              <div className="rounded-md border border-[#ff0037]/18 bg-black/35 p-4">
                <div className="text-[10px] font-black uppercase tracking-[0.22em] text-stone-500">Lead Station</div>
                <div className="mt-2 text-lg font-black uppercase tracking-[0.12em] text-white">{leadRegionSensor.station}</div>
                <div className="mt-3 flex flex-wrap gap-2">
                  <div className="inline-flex max-w-full items-center gap-2 rounded-md border border-[#ff0037]/18 bg-white/[0.03] px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] text-stone-300">
                    <Waves size={10} className="shrink-0 text-[#ff7f96]" />
                    <span className="truncate">{leadRegionSensor.river || 'Active Basin'}</span>
                  </div>
                  <div className={`inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] ${leadTrendMeta?.tone || 'border-white/12 bg-white/[0.05] text-stone-300'}`}>
                    <LeadTrendIcon size={10} className="shrink-0" />
                    <span>{leadRegionSensor.trend || 'STEADY'}</span>
                  </div>
                </div>
                <div className="mt-3 flex items-center justify-between text-xs text-stone-400">
                  <span>Danger Level</span>
                  <span className="font-mono text-white">{dashboardDangerLevel.toFixed(1)}m</span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              {selectedRegionSensors.slice(0, 4).map((sensor) => (
                <RegionSensorCard key={sensor.station} sensor={sensor} />
              ))}
            </div>
          </div>
        ) : (
          <div className="rounded-md border border-[#ff0037]/18 bg-black/30 p-8 text-center">
            <div className="text-sm font-black uppercase tracking-[0.22em] text-white">No Selected Region Water Levels</div>
            <p className="mt-3 text-sm text-stone-500">
              Pick a state or city and the dashboard will load live water levels only for that selected region.
            </p>
          </div>
        )}
      </LuxeCard>

      {/* CORE DATA VISUALS */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
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

      {/* ANALYTICS HUD */}
      {state.prediction.currentPrediction && (
        <div className="grid grid-cols-1 gap-10 xl:grid-cols-2">
          <LuxeCard>
            <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <h3 className="text-xs font-black text-[#bc9437] uppercase tracking-[0.3em] flex items-center gap-3">
                <Activity size={18} /> Probability Lanes
              </h3>
              <div className="flex flex-wrap gap-2">
                <span className="rounded-md border border-[#ff0037]/18 bg-black/35 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300">
                  Dominant: <span className="ml-1 text-white">{dominantProbabilityLane[0]}</span>
                </span>
                <span className="rounded-md border border-[#ff0037]/18 bg-black/35 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300">
                  Peak: <span className="ml-1 text-white">{dominantProbabilityLane[1].toFixed(1)}%</span>
                </span>
              </div>
            </div>
            <div className="mb-6 flex flex-wrap gap-2">
              {[
                { key: 'low', label: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1' },
                { key: 'moderate', label: 'MODERATE', value: probabilityLanes.moderate, fill: '#bc9437' },
                { key: 'severe', label: 'SEVERE', value: probabilityLanes.severe, fill: '#ff8a5b' },
                { key: 'critical', label: 'CRITICAL', value: probabilityLanes.critical, fill: '#ff0037' },
              ].map((lane) => (
                <span
                  key={lane.key}
                  className="inline-flex items-center gap-2 rounded-md border border-[#ff0037]/18 bg-black/35 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300"
                >
                  <span className="h-2 w-2 rounded-full" style={{ backgroundColor: lane.fill }} />
                  {lane.label}
                </span>
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

          <LuxeCard>
            <h3 className="text-xs font-black text-[#ff0037] uppercase tracking-[0.3em] mb-10 flex items-center gap-3">
              <ShieldAlert size={18} /> Strategic Response
            </h3>
            <div className="space-y-5">
              {strategicResponses.map((item, i) => (
                <div key={i} className="flex items-center justify-between rounded-md border border-[#ff0037]/18 bg-black/40 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                  <span className="text-[11px] font-bold text-stone-400 tracking-widest">{item.area}</span>
                  <span className={`text-[11px] font-black ${item.color} tracking-[0.2em]`}>{item.status}</span>
                </div>
              ))}
            </div>
          </LuxeCard>
        </div>
      )}

      <FloodRiskHeatmap
        data={heatmapData}
        title={isCityHotspotView ? 'City Hotspot Heatmap' : 'State Risk Heatmap'}
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
