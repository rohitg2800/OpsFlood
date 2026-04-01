import React, { useMemo } from 'react';
import { Brain, Network } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { PageCard } from './PageShell';
import { LayeredNeuralGraph } from './LayeredNeuralGraph';
import { ProbabilityHeartbeatSparkline } from './ProbabilityLaneHeartbeat';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';

interface NeuralOperationsGraphProps {
  className?: string;
}

export const NeuralOperationsGraph: React.FC<NeuralOperationsGraphProps> = ({ className = '' }) => {
  const { state } = useAppState();

  const selectedRiverLocationLabel = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );

  const probabilityLanes = useMemo(() => deriveProbabilityLanes(state.prediction.currentPrediction), [state.prediction.currentPrediction]);
  const dominantProbabilityEntry = useMemo(() => getDominantProbabilityLane(probabilityLanes), [probabilityLanes]);

  const laneConfig = useMemo(() => ([
    { key: 'low', label: 'LOW', shortLabel: 'LOW', value: probabilityLanes.low, fill: '#8ff0c1', tone: 'text-emerald-300' },
    { key: 'moderate', label: 'MODERATE', shortLabel: 'MOD', value: probabilityLanes.moderate, fill: '#bc9437', tone: 'text-[#dcb978]' },
    { key: 'severe', label: 'SEVERE', shortLabel: 'SEV', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'text-[#ffb08e]' },
    { key: 'critical', label: 'CRITICAL', shortLabel: 'CRT', value: probabilityLanes.critical, fill: '#ff0037', tone: 'text-[#ff8ea0]' },
  ]), [probabilityLanes]);

  const dominantConfig = laneConfig.find((lane) => lane.label === dominantProbabilityEntry[0]) || laneConfig[0];

  const compactMetrics = useMemo(() => ([
    { label: 'Preferred', value: dominantProbabilityEntry[0], tone: dominantConfig.tone },
    { label: 'Confidence', value: `${Number(state.prediction.currentPrediction?.confidence_percent || 0).toFixed(0)}%`, tone: 'text-[#fff1f4]' },
    { label: 'Latency', value: `${Math.max(0, Number(state.prediction.latency || 0))}ms`, tone: 'text-[#fff1f4]' },
  ]), [
    dominantConfig.tone,
    dominantProbabilityEntry,
    state.prediction.currentPrediction?.confidence_percent,
    state.prediction.latency,
  ]);

  return (
    <PageCard className={`space-y-4 ${className}`.trim()}>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-1">
          <div className="inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.24em] text-[#ff8ea0]">
            <Brain size={14} className="text-[#ff5b79]" />
            Neural Operations Graph
          </div>
          <p className="text-xs text-stone-500">
            Dense neural thread map for {selectedRiverLocationLabel}.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {compactMetrics.map((metric) => (
            <span
              key={metric.label}
              className="rounded-md border border-[#ff0037]/18 bg-black/35 px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.18em] text-stone-300"
            >
              {metric.label}: <span className={`ml-1 ${metric.tone}`}>{metric.value}</span>
            </span>
          ))}
        </div>
      </div>

      <div className="rounded-md border border-[#ff0037]/18 bg-[#060504]/78 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] lg:p-5">
        <div className="mb-3 flex items-center justify-between gap-3">
          <div className="inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.22em] text-stone-400">
            <Network size={13} className="text-[#ff5b79]" />
            Layered_Network
          </div>
          <div className="text-[9px] font-mono uppercase tracking-[0.16em] text-stone-500">
            Preferred output: {dominantProbabilityEntry[0]}
          </div>
        </div>

        <div className="grid items-center gap-5 xl:grid-cols-[24.5rem_minmax(0,1fr)]">
          <div className="rounded-md border border-[#ff0037]/14 bg-black/35 px-2 py-3">
            <LayeredNeuralGraph
              lanes={laneConfig}
              preferredLabel={dominantProbabilityEntry[0]}
              compact
              className="h-[16rem] w-full"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            {laneConfig.map((lane) => {
              const isPreferredLane = lane.label === dominantProbabilityEntry[0];
              return (
                <div
                  key={lane.key}
                  className={`rounded-md border px-3 py-2.5 text-[9px] font-black uppercase tracking-[0.16em] ${
                    isPreferredLane
                      ? 'border-[#ff0037]/32 bg-[#ff0037]/10'
                      : 'border-[#ff0037]/14 bg-black/35'
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
    </PageCard>
  );
};
