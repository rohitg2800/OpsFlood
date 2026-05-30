import React, { useMemo } from 'react';
import { Brain, Network } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { PageCard } from './PageShell';
import { LayeredNeuralGraph } from './LayeredNeuralGraph';
import { ProbabilityHeartbeatSparkline } from './ProbabilityLaneHeartbeat';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { deriveProbabilityLanes, getDominantProbabilityLane } from '../utils/probabilityLanes';
import { InsetPanel, SectionHeader, StatusBadge, opsLabelClass } from './OpsPrimitives';

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
    { key: 'moderate', label: 'MODERATE', shortLabel: 'MOD', value: probabilityLanes.moderate, fill: '#4c7cff', tone: 'text-sky-300' },
    { key: 'severe', label: 'SEVERE', shortLabel: 'SEV', value: probabilityLanes.severe, fill: '#ff8a5b', tone: 'text-orange-200' },
    { key: 'critical', label: 'CRITICAL', shortLabel: 'CRT', value: probabilityLanes.critical, fill: '#ff5f7e', tone: 'text-rose-200' },
  ]), [probabilityLanes]);

  const dominantConfig = laneConfig.find((lane) => lane.label === dominantProbabilityEntry[0]) || laneConfig[0];

  return (
    <PageCard className={`space-y-4 ${className}`.trim()}>
      <SectionHeader
        eyebrow="Model graph"
        title="Neural operations graph"
        description={`Layered neural signal map for ${selectedRiverLocationLabel}.`}
        icon={Brain}
        action={
          <>
            <StatusBadge tone="info">Preferred {dominantProbabilityEntry[0]}</StatusBadge>
            <StatusBadge tone="neutral">
              Confidence {Number(state.prediction.currentPrediction?.confidence_percent || 0).toFixed(0)}%
            </StatusBadge>
            <StatusBadge tone="neutral">
              Latency {Math.max(0, Number(state.prediction.latency || 0))}ms
            </StatusBadge>
          </>
        }
      />

      <div className="grid items-center gap-5 xl:grid-cols-[24.5rem_minmax(0,1fr)]">
        <InsetPanel className="px-2 py-3">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div className={opsLabelClass}>Layered network</div>
            <div className="text-xs text-[color:var(--ops-text-faint)]">
              Preferred output {dominantProbabilityEntry[0]}
            </div>
          </div>

          <LayeredNeuralGraph
            lanes={laneConfig}
            preferredLabel={dominantProbabilityEntry[0]}
            compact
            className="h-[16rem] w-full"
          />
        </InsetPanel>

        <div className="grid grid-cols-2 gap-3">
          {laneConfig.map((lane) => {
            const isPreferredLane = lane.label === dominantProbabilityEntry[0];

            return (
              <InsetPanel key={lane.key} className={isPreferredLane ? 'ring-1 ring-white/10' : ''}>
                <div className="mb-3 flex items-center justify-between gap-2">
                  <span className="inline-flex items-center gap-2 text-sm font-medium text-[color:var(--ops-text)]">
                    <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: lane.fill }} />
                    {lane.label}
                  </span>
                  <span className={lane.tone}>{lane.value.toFixed(1)}%</span>
                </div>
                <ProbabilityHeartbeatSparkline
                  lane={lane}
                  highlighted={isPreferredLane}
                  className="h-9 w-full"
                />
              </InsetPanel>
            );
          })}
        </div>
      </div>
    </PageCard>
  );
};
