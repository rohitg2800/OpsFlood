import React, { useEffect, useMemo } from 'react';
import {
  Waves,
  RefreshCw,
  AlertTriangle,
  ShieldCheck,
  Clock,
  Radio,
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useCWCIntegration } from '../hooks/useAppOperations';
import { getSelectedRiverLocationLabel, scopeSensorsToSelectedLocation } from '../utils/regionReadings';

const LuxeCard = ({ children, className = '' }: { children: React.ReactNode; className?: string }) => (
  <div className={`flex h-full flex-col overflow-hidden rounded-lg border border-[#ff0037]/28 bg-[#0B0A08]/60 p-8 shadow-[0_25px_80px_rgba(0,0,0,0.8)] backdrop-blur-3xl ${className}`}>
    {children}
  </div>
);

const getStatusTone = (status: string) => {
  switch (status) {
    case 'CRITICAL':
      return 'border-[#ff0037]/45 bg-[#ff0037]/12 text-[#ff0037]';
    case 'WARNING':
      return 'border-[#ff0037]/28 bg-amber-500/12 text-amber-300';
    case 'ACTIVE':
      return 'border-[#ff0037]/24 bg-emerald-500/12 text-emerald-400';
    default:
      return 'border-[#ff0037]/22 bg-white/8 text-stone-300';
  }
};

export function CWCLiveDataDisplay() {
  const { state } = useAppState();
  const { fetchCWCData, isConnected } = useCWCIntegration();

  const selectedStation = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );

  const dangerLevel =
    state.cwc.liveData.dangerLevel ||
    state.prediction.currentPrediction?.danger_level ||
    state.prediction.dangerLevel ||
    13.5;

  const cwcLevel = state.cwc.liveData.currentLevel ?? state.cwc.liveData.kolhapurLevel;
  const cwcStatus = state.cwc.liveData.status ?? state.cwc.liveData.kolhapurStatus;
  const source = state.cwc.liveData.source;
  const preferredRiver = state.cwc.liveData.river;
  const warningLevel = state.cwc.liveData.warningLevel;
  const preferredStation = state.cwc.liveData.station || selectedStation;
  const trend = state.cwc.liveData.trend;

  const regionTelemetry = useMemo(() => {
    const scopedSensors = scopeSensorsToSelectedLocation(state.sensors.data || [], {
      selectedCity: state.prediction.selectedCity,
      station: state.form.data.station,
      selectedState: state.prediction.selectedState,
    });

    if (scopedSensors.length) return scopedSensors.slice(0, 3);

    return state.cwc.liveData.regionalData.slice(0, 3).map((node) => ({
      station: node.station,
      river_level: node.currentLevel,
      flow_rate: Number((node.currentLevel * 12.4).toFixed(1)),
      rainfall_last_hour: node.rainfallLastHour ?? 0,
      status: node.status,
      last_update: node.updateTime,
      river: node.river,
      warning_level: node.warningLevel,
      danger_level: node.dangerLevel,
      trend: node.trend,
      state: node.state,
      source: node.source,
    }));
  }, [state.cwc.liveData.regionalData, state.form.data.station, state.prediction.selectedCity, state.prediction.selectedState, state.sensors.data]);

  useEffect(() => {
    if (state.system.apiStatus === 'OFFLINE' || state.system.apiStatus === 'INITIALIZING') return;

    const timeoutId = window.setTimeout(() => {
      void fetchCWCData();
    }, 220);

    return () => window.clearTimeout(timeoutId);
  }, [fetchCWCData, state.system.apiStatus]);

  const fillWidth = cwcLevel ? Math.min((cwcLevel / dangerLevel) * 100, 100) : 0;
  const distanceToDanger = typeof cwcLevel === 'number' ? (dangerLevel - cwcLevel).toFixed(1) : null;

  return (
    <LuxeCard>
      <div className="mb-8 flex items-start justify-between gap-4 border-b border-[#ff0037]/18 pb-6">
        <div className="space-y-2">
          <h3 className="flex items-center gap-3 text-sm font-bold uppercase tracking-widest text-[#ff7f96] font-cinzel">
            <span className="flex h-5 w-5 items-center justify-center">
              <Waves size={18} className="shrink-0" />
            </span>
            <span>CWC Hydrology Feed</span>
          </h3>
          <div className="flex items-center gap-2 text-[10px] font-mono uppercase tracking-[0.2em] text-stone-500">
            <span className={`block h-1.5 w-1.5 shrink-0 rounded-full ${isConnected ? 'bg-emerald-500 animate-pulse' : 'bg-[#ff0037]'}`} />
            <span>Live Link: {preferredStation.toUpperCase()}</span>
          </div>
        </div>
        <button
          onClick={() => fetchCWCData({ force: true })}
          className="inline-flex items-center gap-2 rounded-md border border-[#ff0037]/35 bg-[#ff0037]/10 px-4 py-2 text-[9px] font-black uppercase leading-none text-[#ff9eb1] transition-all hover:bg-[#ff0037] hover:text-white"
        >
          <span className="flex h-3.5 w-3.5 items-center justify-center">
            <RefreshCw size={12} className="shrink-0" />
          </span>
          <span>Sync_CWC</span>
        </button>
      </div>

      <div className="mb-5 rounded-md border border-[#ff0037]/22 bg-black/35 p-5">
        <div className="mb-3 flex items-center justify-between gap-4">
          <div>
            <div className="text-[10px] font-black uppercase tracking-[0.24em] text-stone-500">
              Preferred Station
            </div>
            <div className="mt-2 text-lg font-black uppercase tracking-[0.14em] text-white">
              {preferredStation}
            </div>
            <div className="mt-2 text-[10px] font-mono uppercase tracking-[0.16em] text-stone-500">
              Basin: <span className="text-[#ff9eb1]">{preferredRiver || 'Active Basin'}</span>
            </div>
          </div>
          <div className={`inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-[9px] font-black uppercase leading-none tracking-[0.2em] ${getStatusTone(cwcStatus)}`}>
            <span className="flex h-3.5 w-3.5 items-center justify-center">
              {cwcStatus === 'CRITICAL' || cwcStatus === 'WARNING' ? (
                <AlertTriangle size={12} className="shrink-0" />
              ) : (
                <ShieldCheck size={12} className="shrink-0" />
              )}
            </span>
            <span>{cwcStatus}</span>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="rounded-md border border-[#ff0037]/18 bg-white/[0.03] p-4">
            <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Current Level</div>
            <div className="mt-2 text-4xl font-black font-mono text-white">
              {typeof cwcLevel === 'number' ? cwcLevel.toFixed(2) : '--'}
              <span className="ml-1 text-lg text-stone-600">m</span>
            </div>
          </div>
          <div className="rounded-md border border-[#ff0037]/18 bg-white/[0.03] p-4">
            <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Warning / Danger</div>
            <div className="mt-2 text-4xl font-black font-mono text-white">
              {typeof warningLevel === 'number' ? warningLevel.toFixed(2) : '--'}
              <span className="mx-1 text-lg text-stone-600">/</span>
              {dangerLevel.toFixed(2)}
            </div>
            <div className="mt-2 text-[10px] uppercase tracking-[0.18em] text-stone-500">
              Trend: <span className="text-white">{trend}</span>
            </div>
          </div>
        </div>
      </div>

      <div className="mb-5 rounded-md border border-[#ff0037]/18 bg-black/30 p-4">
        <div className="mb-2 flex items-center justify-between text-sm">
          <span className="font-black text-stone-300">Threshold Progress</span>
          <span className="font-mono text-white">
            {distanceToDanger === null ? '--' : Number(distanceToDanger) <= 0 ? 'Above danger' : `${distanceToDanger}m remaining`}
          </span>
        </div>
        <div className="h-2 overflow-hidden rounded-md bg-black/50">
          <div
            className={`h-full transition-all ${typeof cwcLevel === 'number' && cwcLevel >= dangerLevel ? 'bg-[#ff0037]' : 'bg-amber-500'}`}
            style={{ width: `${fillWidth}%` }}
          />
        </div>
        <div className="mt-3 flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-stone-500">
          <span className="flex h-3.5 w-3.5 items-center justify-center">
            <Clock size={12} className="shrink-0" />
          </span>
          <span>Updated {state.cwc.lastFetchTime ? new Date(state.cwc.lastFetchTime).toLocaleTimeString('en-US', { hour12: false }) : 'Never'}</span>
        </div>
      </div>

      <div className="mb-5 flex-1 space-y-3">
        <div className="text-[10px] font-black uppercase tracking-[0.24em] text-[#ff7f96]">
          Regional Water Nodes
        </div>
        {regionTelemetry.length ? (
          regionTelemetry.map((sensor) => (
            <div key={sensor.station} className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4">
              <div className="mb-3 flex items-start justify-between gap-4">
                <div>
                  <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Station</div>
                  <div className="mt-1 text-sm font-black uppercase tracking-[0.12em] text-white">{sensor.station}</div>
                </div>
                <div className="inline-flex items-center gap-2 rounded-md border border-[#ff0037]/24 bg-white/[0.04] px-3 py-1 text-[9px] font-black uppercase leading-none tracking-[0.18em] text-stone-300">
                  <span className="flex h-3.5 w-3.5 items-center justify-center">
                    <Radio size={10} className="shrink-0 text-[#ff7f96]" />
                  </span>
                  <span>{sensor.status}</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div className="rounded-md border border-[#ff0037]/12 bg-white/[0.03] p-3">
                  <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Level</div>
                  <div className="mt-2 text-2xl font-black font-mono text-white">{Number(sensor.river_level || 0).toFixed(2)}m</div>
                </div>
                <div className="rounded-md border border-[#ff0037]/12 bg-white/[0.03] p-3">
                  <div className="text-[9px] font-black uppercase tracking-[0.24em] text-stone-500">Rain 1H</div>
                  <div className="mt-2 text-2xl font-black font-mono text-white">{Number(sensor.rainfall_last_hour || 0).toFixed(1)}mm</div>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="rounded-md border border-[#ff0037]/18 bg-black/30 p-4 text-sm text-stone-500">
            No matching regional nodes yet. Select a city/station to scope the feed.
          </div>
        )}
      </div>

      <div className="rounded-md border border-[#ff0037]/18 bg-black/35 p-4 text-xs text-stone-300">
        <span className="font-black uppercase tracking-[0.2em] text-stone-500">Data Source</span>
        <div className="mt-2">
          {isConnected
            ? `${source} • Live CWC station query`
            : 'Fallback mode • using manual threshold context until CWC responds'}
        </div>
      </div>
    </LuxeCard>
  );
}
