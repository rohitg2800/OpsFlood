import React, { useEffect, useMemo } from 'react';
import {
  Activity,
  ArrowDown,
  ArrowRight,
  ArrowUp,
  Radio,
  RefreshCw,
  SignalHigh,
  Waves,
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useSensorAPI } from '../hooks/useAppOperations';
import { PageShell, PageHero } from '../components/PageShell';
import { NeuralOperationsGraph } from '../components/NeuralOperationsGraph';
import { getScopedSensorSelection, getSelectedRiverLocationLabel } from '../utils/regionReadings';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  InsetPanel,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from '../components/OpsPrimitives';

const TelemetryPage: React.FC = () => {
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

  const getStatusTone = (status: string) => {
    if (status === 'CRITICAL') return 'danger' as const;
    if (status === 'WARNING') return 'warning' as const;
    if (status === 'ACTIVE') return 'success' as const;
    return 'neutral' as const;
  };

  const getTrendMeta = (trend?: string) => {
    if (trend === 'RISING') {
      return { icon: ArrowUp, tone: 'warning' as const, label: 'Rising' };
    }
    if (trend === 'FALLING') {
      return { icon: ArrowDown, tone: 'success' as const, label: 'Falling' };
    }
    return { icon: ArrowRight, tone: 'neutral' as const, label: 'Steady' };
  };

  return (
    <PageShell>
      <PageHero
        eyebrow="Live Sensor Telemetry"
        title="Telemetry Feed"
        subtitle={telemetrySubtitle}
        icon={SignalHigh}
        action={
          <ActionButton
            type="button"
            onClick={() => fetchSensors({ force: true })}
            disabled={sensorsLoading}
            icon={RefreshCw}
            variant="secondary"
          >
            {sensorsLoading ? 'Syncing nodes' : 'Sync nodes'}
          </ActionButton>
        }
      />

      <NeuralOperationsGraph />

      <ConsolePanel intensity="primary" frameTone="cyan">
        <SectionHeader
          eyebrow="Field telemetry"
          title="Sensor array"
          description={`Live field node health, river levels, and rainfall packets for ${selectedRiverLocationLabel}.`}
          icon={Radio}
          action={
            <>
              <StatusBadge tone={sensorsLoading ? 'warning' : 'success'}>
                {sensorsLoading ? 'Refreshing' : 'Feed ready'}
              </StatusBadge>
              <StatusBadge tone="neutral">
                {scopedSensors.length} active nodes
              </StatusBadge>
            </>
          }
          className="mb-6"
        />

        {scopedSensors.length === 0 ? (
          <EmptyState
            title={`No telemetry nodes are scoped to ${selectedRiverLocationLabel} yet`}
            description="Select a city, station, or state in the dashboard to focus the telemetry feed. The page keeps the route active without filling the screen with empty diagnostics."
            icon={SignalHigh}
          />
        ) : (
          <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
            {scopedSensors.map((sensor) => {
              const trendMeta = getTrendMeta(sensor.trend);
              const TrendIcon = trendMeta.icon;

              return (
                <InsetPanel key={sensor.station} variant="soft" className="space-y-4">
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 space-y-2">
                      <div className={opsLabelClass}>Station</div>
                      <div className="truncate text-xl font-semibold uppercase tracking-[0.08em] text-[color:var(--ops-text)]">
                        {sensor.station}
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <StatusBadge tone={getStatusTone(sensor.status)}>{sensor.status}</StatusBadge>
                        <StatusBadge tone={trendMeta.tone} icon={TrendIcon}>
                          {trendMeta.label}
                        </StatusBadge>
                      </div>
                    </div>
                    <div className="text-right text-sm text-[color:var(--ops-text-soft)]">
                      <div className="font-medium text-[color:var(--ops-text)]">{sensor.river || 'Active basin'}</div>
                      <div className="mt-1">Updated {sensor.last_update ? new Date(sensor.last_update).toLocaleTimeString('en-US', { hour12: false }) : 'No data'}</div>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-xl bg-black/20 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                      <div className={opsLabelClass}>River level</div>
                      <div className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                        {Number(sensor.river_level || 0).toFixed(2)}m
                      </div>
                    </div>
                    <div className="rounded-xl bg-black/20 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                      <div className={opsLabelClass}>Rain 1H</div>
                      <div className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                        {Number(sensor.rainfall_last_hour || 0).toFixed(1)}mm
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between gap-3 text-sm text-[color:var(--ops-text-soft)]">
                    <span className="inline-flex items-center gap-2">
                      <Waves size={14} className="text-[color:var(--ops-info)]" />
                      {sensor.river || 'Active basin'}
                    </span>
                    <span>{sensor.state || selectedRiverLocationLabel}</span>
                  </div>
                </InsetPanel>
              );
            })}
          </div>
        )}

        <div className="mt-6 flex items-center justify-between gap-3 rounded-xl bg-[rgba(8,12,16,0.46)] px-4 py-3 text-sm text-[color:var(--ops-text-faint)]">
          <span>
            River location {selectedRiverLocationLabel}
            {scopedSensorContext.mode === 'city_nearby' ? ' / nearby sources' : ''}
          </span>
          <span>{scopedSensors.length} nodes in scope</span>
        </div>
      </ConsolePanel>
    </PageShell>
  );
};

export default TelemetryPage;
