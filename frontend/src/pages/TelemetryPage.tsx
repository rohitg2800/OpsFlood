import React, { useEffect, useMemo } from 'react';
import { Radio, RefreshCw, Activity, Cpu, SignalHigh, Waves, TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useSensorAPI } from '../hooks/useAppOperations';
import { PageShell, PageHero, PageCard } from '../components/PageShell';
import { NeuralOperationsGraph } from '../components/NeuralOperationsGraph';
import { getScopedSensorSelection, getSelectedRiverLocationLabel } from '../utils/regionReadings';

// ==========================================
// TELEMETRY PAGE COMPONENT
// ==========================================

export const TelemetryPage: React.FC = () => {
  const { state } = useAppState();
  const { fetchSensors, isLoading: sensorsLoading } = useSensorAPI();
  const selectedRiverLocationLabel = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );
  const scopedSensorContext = useMemo(() => {
    return getScopedSensorSelection(state.sensors.data || [], {
      selectedCity: state.prediction.selectedCity,
      station: state.form.data.station,
      selectedState: state.prediction.selectedState,
    });
  }, [state.form.data.station, state.prediction.selectedCity, state.prediction.selectedState, state.sensors.data]);
  const scopedSensors = scopedSensorContext.sensors;
  const telemetrySubtitle =
    scopedSensorContext.mode === 'city_nearby'
      ? `Field nodes, river levels, and nearby monitored water sources for ${selectedRiverLocationLabel}.`
      : `Field nodes, river levels, and rainfall packets scoped to ${selectedRiverLocationLabel}.`;

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void fetchSensors();
    }, 180);

    return () => window.clearTimeout(timeoutId);
  }, [fetchSensors]);

  // Helper for tactical status styling
  const getStatusStyles = (status: string) => {
    switch (status) {
      case 'CRITICAL':
        return 'border border-[#ff0037]/45 bg-[#ff0037]/12 text-[#ff0037] shadow-[0_0_20px_rgba(255,0,55,0.2)] animate-pulse';
      case 'WARNING':
        return 'border border-[#ff0037]/35 bg-amber-500/12 text-amber-400';
      case 'ACTIVE':
        return 'border border-[#ff0037]/35 bg-emerald-500/12 text-emerald-400';
      default:
        return 'border border-[#ff0037]/25 bg-white/8 text-stone-500';
    }
  };

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

  return (
    <PageShell>
      <PageHero
        eyebrow="Live Sensor Telemetry"
        title="Telemetry Feed"
        subtitle={telemetrySubtitle}
        icon={SignalHigh}
        action={
          <button
            type="button"
            onClick={() => fetchSensors({ force: true })}
            disabled={sensorsLoading}
            className="inline-flex items-center gap-3 rounded-md border border-[#ff0037]/40 bg-white/8 px-6 py-3 text-[10px] font-black uppercase tracking-[0.22em] text-[#ffb36a] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] transition-all hover:bg-[#ff0037] hover:text-white disabled:opacity-50"
          >
            <RefreshCw size={16} className={sensorsLoading ? 'animate-spin' : ''} />
            Sync Nodes
          </button>
        }
      />

      <NeuralOperationsGraph />

      <PageCard className="relative !p-0">
        {/* Decorative Top Scan-line */}
        <div className="absolute top-0 left-0 h-[1px] w-full bg-gradient-to-r from-transparent via-[#ff0037]/45 to-transparent" />

        {/* COMMAND HEADER */}
        <div className="flex flex-col items-start justify-between gap-6 bg-white/[0.02] p-6 sm:p-8 lg:flex-row lg:items-center lg:p-10">
          <div className="space-y-1">
            <h2 className="text-2xl font-black flex items-center gap-4 text-white font-cinzel tracking-widest uppercase">
              <Radio className="text-[#ff5b79]" size={28} /> Hardware Array
            </h2>
            <p className="text-[10px] text-stone-500 uppercase tracking-[0.2em] font-bold ml-11">
              Field_Telemetry // Live_Data_Ingestion
            </p>
          </div>
          
          <div className="rounded-md border border-[#ff0037]/38 bg-[#ff0037]/10 px-5 py-3 text-[10px] font-black uppercase tracking-[0.24em] text-[#ff9eb1] shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]">
            Node Count: {scopedSensors.length}
          </div>
        </div>

        {/* SENSOR GRID */}
        <div
          className="min-h-[400px] p-6 sm:p-8 lg:p-10"
          style={{
            backgroundImage: 'radial-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px)',
            backgroundSize: '20px 20px',
          }}
        >
          {scopedSensors.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 opacity-40">
              <Cpu size={48} className="text-[#bc9437] mb-4 animate-pulse" />
              <div className="text-[10px] font-mono text-stone-400 tracking-[0.3em] uppercase">
                Awaiting Telemetry Handshake For {selectedRiverLocationLabel}...
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
              {scopedSensors.map((s) => {
                const trendMeta = getTrendMeta(s.trend);
                const TrendIcon = trendMeta.icon;

                return (
                  <div
                    key={s.station}
                    className="group relative overflow-hidden rounded-lg border border-[#ff0037]/26 bg-[#060504]/80 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)] transition-all sm:p-6"
                  >
                  {/* Subtle background glow based on status */}
                  <div className={`absolute -right-20 -top-20 w-48 h-48 rounded-full blur-3xl opacity-10 pointer-events-none transition-all group-hover:opacity-20 ${
                    s.status === 'CRITICAL' ? 'bg-[#ff0037]' : s.status === 'WARNING' ? 'bg-amber-500' : 'bg-[#ff5b79]'
                  }`} />

                  {/* Top: Station Info & Status */}
                  <div className="mb-5 grid grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-start">
                    <div className="rounded-md border border-[#ff0037]/24 bg-white/[0.04] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                      <div className="mb-2 inline-flex items-center gap-2 rounded-md border border-[#ff0037]/24 bg-black/40 px-3 py-1 text-[9px] font-black uppercase tracking-[0.3em] text-stone-500">
                        <Activity size={10} className="text-[#ff5b79]" />
                        Station_ID
                      </div>
                      <div className="break-words text-xl font-black uppercase tracking-[0.12em] text-white font-cinzel sm:text-2xl">
                        {s.station}
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2">
                        <div className="inline-flex max-w-full items-center gap-2 rounded-md border border-[#ff0037]/20 bg-black/45 px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] text-stone-300">
                          <Waves size={10} className="shrink-0 text-[#ff5b79]" />
                          <span className="truncate">{s.river || 'Active Basin'}</span>
                        </div>
                        <div className={`inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.18em] ${trendMeta.tone}`}>
                          <TrendIcon size={10} className="shrink-0" />
                          <span>{s.trend || 'STEADY'}</span>
                        </div>
                      </div>
                      <div className="mt-3 inline-flex max-w-full rounded-md border border-[#ff0037]/20 bg-black/45 px-3 py-1.5 text-[9px] font-mono uppercase tracking-[0.22em] text-stone-400">
                        Last_Sync: {s.last_update ? new Date(s.last_update).toLocaleTimeString('en-US', { hour12: false }) : 'NO_DATA'}
                      </div>
                    </div>
                    <div className={`inline-flex w-fit rounded-full px-4 py-2 text-[9px] font-black uppercase tracking-[0.2em] ${getStatusStyles(s.status)}`}>
                      {s.status}
                    </div>
                  </div>

                  {/* Bottom: Telemetry Readouts */}
                  <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <div className="relative overflow-hidden rounded-md border border-[#ff0037]/22 bg-white/[0.04] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] sm:p-5">
                      <div className="mb-3 inline-flex rounded-md border border-[#ff0037]/20 bg-black/40 px-3 py-1 text-[9px] font-black uppercase tracking-[0.3em] text-stone-500">Level_M</div>
                      <div className="text-2xl font-black tracking-tighter text-white font-mono sm:text-3xl">
                        {Number(s.river_level || 0).toFixed(2)}<span className="text-stone-600 text-lg">m</span>
                      </div>
                    </div>
                    <div className="relative overflow-hidden rounded-md border border-[#ff0037]/22 bg-white/[0.04] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] sm:p-5">
                      <div className="mb-3 inline-flex rounded-md border border-[#ff0037]/20 bg-black/40 px-3 py-1 text-[9px] font-black uppercase tracking-[0.3em] text-stone-500">Precip_1H</div>
                      <div className="text-2xl font-black tracking-tighter text-white font-mono sm:text-3xl">
                        {Number(s.rainfall_last_hour || 0).toFixed(1)}<span className="text-stone-600 text-lg">mm</span>
                      </div>
                    </div>
                  </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* TACTICAL FOOTER */}
        <div className="flex items-center justify-between border-t border-[#ff0037]/20 bg-black/40 p-6 text-[9px] font-black uppercase tracking-[0.3em] text-stone-600">
           <span>
             River_Location: {selectedRiverLocationLabel}
             {scopedSensorContext.mode === 'city_nearby' ? ' // Nearby_Sources' : ''}
           </span>
           <span>Active_Nodes: {scopedSensors.length}</span>
        </div>
      </PageCard>
    </PageShell>
  );
};
