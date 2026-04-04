import React, { useEffect, useMemo } from 'react';
import {
  ArrowDown,
  ArrowRight,
  ArrowUp,
  Clock,
  ExternalLink,
  Radio,
  RefreshCw,
  ShieldCheck,
  Waves,
} from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useCWCIntegration } from '../hooks/useAppOperations';
import { getSelectedRiverLocationLabel, scopeSensorsToSelectedLocation } from '../utils/regionReadings';
import { getCWCDataSourceMessage } from '../utils/cwcDataSource';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  InsetPanel,
  MetricTile,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from './OpsPrimitives';

type Tone = 'success' | 'info' | 'warning' | 'danger' | 'neutral';

const getStatusTone = (status?: string): Tone => {
  if (status === 'CRITICAL') return 'danger';
  if (status === 'WARNING') return 'warning';
  if (status === 'ACTIVE') return 'success';
  return 'neutral';
};

const getTrendMeta = (trend?: string) => {
  if (trend === 'RISING') {
    return { icon: ArrowUp, tone: 'warning' as Tone, label: 'Rising' };
  }
  if (trend === 'FALLING') {
    return { icon: ArrowDown, tone: 'success' as Tone, label: 'Falling' };
  }
  return { icon: ArrowRight, tone: 'neutral' as Tone, label: 'Steady' };
};

export function CWCLiveDataDisplay() {
  const { state } = useAppState();
  const { fetchCWCData, isConnected } = useCWCIntegration();
  const sourcePolicy = state.system.sourcePolicy;

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
  const dataSourceMessage = getCWCDataSourceMessage({
    isConnected,
    liveSource: source,
    predictionSource: state.prediction.cwcDataSource,
    sourcePolicyMode: sourcePolicy.mode,
  });

  const regionTelemetry = useMemo(() => {
    const scopedSensors = scopeSensorsToSelectedLocation(state.sensors.data || [], {
      selectedCity: state.prediction.selectedCity,
      station: state.form.data.station,
      selectedState: state.prediction.selectedState,
    });

    if (scopedSensors.length) return scopedSensors.slice(0, 4);

    return state.cwc.liveData.regionalData.slice(0, 4).map((node) => ({
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

  const fillWidth = typeof cwcLevel === 'number' ? Math.min((cwcLevel / dangerLevel) * 100, 100) : 0;
  const distanceToDanger = typeof cwcLevel === 'number' ? dangerLevel - cwcLevel : null;
  const thresholdLabel =
    distanceToDanger === null
      ? 'Threshold pending'
      : distanceToDanger <= 0
      ? `${Math.abs(distanceToDanger).toFixed(1)}m above danger`
      : `${distanceToDanger.toFixed(1)}m below danger`;
  const liveTone = getStatusTone(cwcStatus);
  const trendMeta = getTrendMeta(trend);
  const TrendIcon = trendMeta.icon;
  const refreshedAt = state.cwc.lastFetchTime
    ? new Date(state.cwc.lastFetchTime).toLocaleTimeString('en-US', { hour12: false })
    : 'Awaiting sync';

  return (
    <ConsolePanel intensity="primary" className="h-full" frameTone="cyan">
      <SectionHeader
        eyebrow="Telemetry snapshot"
        title="CWC hydrology feed"
        description={`Live river-level context for ${preferredStation} with scoped regional nodes and threshold proximity.`}
        icon={Waves}
        action={
          <>
            <StatusBadge tone={isConnected ? 'success' : 'warning'} icon={Radio}>
              {isConnected ? 'Live link active' : 'Context sync mode'}
            </StatusBadge>
            <ActionButton
              onClick={() => fetchCWCData({ force: true })}
              icon={RefreshCw}
              variant="secondary"
            >
              {sourcePolicy.allow_live_cwc_in_app ? 'Refresh CWC feed' : 'Refresh context'}
            </ActionButton>
          </>
        }
        className="mb-6"
      />

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_18rem]">
        <InsetPanel variant="soft" className="space-y-5">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="space-y-3">
              <div className={opsLabelClass}>Active station</div>
              <div className="text-2xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                {preferredStation}
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge tone={liveTone}>
                  {cwcStatus || 'No status'}
                </StatusBadge>
                <StatusBadge tone={trendMeta.tone} icon={TrendIcon}>
                  {trendMeta.label}
                </StatusBadge>
              </div>
              <div className="text-sm text-[color:var(--ops-text-soft)]">
                Basin {preferredRiver || 'Active basin'}
              </div>
            </div>

            <div className="grid w-full gap-3 sm:grid-cols-3 lg:w-auto lg:min-w-[22rem]">
              <MetricTile
                label="Current level"
                value={typeof cwcLevel === 'number' ? `${cwcLevel.toFixed(2)}m` : '--'}
                tone={liveTone}
                className="!p-4"
                framed
                frameTone={liveTone === 'danger' ? 'danger' : liveTone === 'warning' ? 'amber' : 'cyan'}
              />
              <MetricTile
                label="Warning level"
                value={typeof warningLevel === 'number' ? `${warningLevel.toFixed(2)}m` : '--'}
                tone="warning"
                className="!p-4"
              />
              <MetricTile
                label="Danger level"
                value={`${dangerLevel.toFixed(2)}m`}
                tone="danger"
                className="!p-4"
              />
            </div>
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between gap-3 text-sm">
              <div className="font-medium text-[color:var(--ops-text)]">Threshold proximity</div>
              <div className="font-mono text-[color:var(--ops-text-soft)]">{thresholdLabel}</div>
            </div>
            <div className="h-3 overflow-hidden rounded-full bg-black/35">
              <div
                className={
                  liveTone === 'danger'
                    ? 'h-full rounded-full bg-[linear-gradient(90deg,#c93a56,#f47a8f)]'
                    : liveTone === 'warning'
                    ? 'h-full rounded-full bg-[linear-gradient(90deg,#d97706,#fbbf24)]'
                    : 'h-full rounded-full bg-[linear-gradient(90deg,#4c7cff,#79a5ff)]'
                }
                style={{ width: `${Math.max(fillWidth, typeof cwcLevel === 'number' ? 4 : 0)}%` }}
              />
            </div>
          </div>
        </InsetPanel>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
          <MetricTile
            label="Last refresh"
            value={refreshedAt}
            hint={source || 'No source identified'}
            icon={Clock}
            tone="info"
          />

          <InsetPanel variant="soft" className="space-y-3">
            <div className="flex items-center justify-between gap-3">
              <div className={opsLabelClass}>Source policy</div>
              <StatusBadge tone="neutral">{sourcePolicy.mode}</StatusBadge>
            </div>
            <div className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
              {sourcePolicy.description}
            </div>
            <div className="rounded-xl bg-black/20 px-3 py-3 text-sm text-[color:var(--ops-text-soft)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
              {dataSourceMessage}
            </div>
          </InsetPanel>
        </div>
      </div>

      <div className="mt-6 space-y-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className={opsLabelClass}>Regional nodes</div>
            <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
              Nearby stations are sorted to keep the current location scope readable at a glance.
            </div>
          </div>
          <StatusBadge tone="neutral">
            {regionTelemetry.length} monitored nodes
          </StatusBadge>
        </div>

        {regionTelemetry.length ? (
          <div className="grid gap-3 md:grid-cols-2">
            {regionTelemetry.map((sensor) => {
              const sensorTone = getStatusTone(sensor.status);
              const sensorTrendMeta = getTrendMeta(sensor.trend);
              const SensorTrendIcon = sensorTrendMeta.icon;
              const sensorDangerLevel = Number(sensor.danger_level || dangerLevel || 0);
              const sensorLevel = Number(sensor.river_level || 0);
              const sensorFill = sensorDangerLevel > 0 ? Math.min((sensorLevel / sensorDangerLevel) * 100, 100) : 0;

              return (
                <InsetPanel key={`${sensor.station}-${sensor.river || 'river'}`} className="space-y-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="space-y-1">
                      <div className="text-base font-semibold text-[color:var(--ops-text)]">
                        {sensor.station}
                      </div>
                      <div className="text-sm text-[color:var(--ops-text-soft)]">
                        {sensor.river || 'Active basin'}
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-2">
                      <StatusBadge tone={sensorTone}>{sensor.status}</StatusBadge>
                      <StatusBadge tone={sensorTrendMeta.tone} icon={SensorTrendIcon}>
                        {sensorTrendMeta.label}
                      </StatusBadge>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-xl bg-black/20 p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                      <div className={opsLabelClass}>River level</div>
                      <div className="mt-2 text-2xl font-semibold text-[color:var(--ops-text)]">
                        {sensorLevel.toFixed(2)}m
                      </div>
                    </div>
                    <div className="rounded-xl bg-black/20 p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]">
                      <div className={opsLabelClass}>Rain 1H</div>
                      <div className="mt-2 text-2xl font-semibold text-[color:var(--ops-text)]">
                        {Number(sensor.rainfall_last_hour || 0).toFixed(1)}mm
                      </div>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between gap-2 text-xs text-[color:var(--ops-text-soft)]">
                      <span>Threshold proximity</span>
                      <span className="font-mono">{sensorDangerLevel.toFixed(1)}m danger mark</span>
                    </div>
                    <div className="h-2 overflow-hidden rounded-full bg-black/30">
                      <div
                        className={sensorTone === 'danger'
                          ? 'h-full rounded-full bg-[linear-gradient(90deg,#c93a56,#f47a8f)]'
                          : sensorTone === 'warning'
                          ? 'h-full rounded-full bg-[linear-gradient(90deg,#d97706,#fbbf24)]'
                          : 'h-full rounded-full bg-[linear-gradient(90deg,#2c9e77,#61d0a4)]'}
                        style={{ width: `${Math.max(sensorFill, 4)}%` }}
                      />
                    </div>
                  </div>

                  <div className="flex items-center justify-between gap-3 text-xs text-[color:var(--ops-text-faint)]">
                    <span>Updated {sensor.last_update ? new Date(sensor.last_update).toLocaleTimeString('en-US', { hour12: false }) : 'No timestamp'}</span>
                    <span>{sensor.source || source || 'Regional feed'}</span>
                  </div>
                </InsetPanel>
              );
            })}
          </div>
        ) : (
          <EmptyState
            title="No scoped telemetry nodes yet"
            description="Select a city, station, or state to narrow the feed. Until then, the panel keeps the main hydrology snapshot available without showing empty placeholder cards."
            icon={ShieldCheck}
          />
        )}
      </div>

      <div className="mt-6 space-y-4">
        <div>
          <div className={opsLabelClass}>Official public sources</div>
          <div className="mt-1 text-sm text-[color:var(--ops-text-soft)]">
            Use these references when you need a direct public source outside the in-app monitoring workflow.
          </div>
        </div>
        <div className="grid gap-3">
          {sourcePolicy.public_sources.map((sourceLink) => (
            <a
              key={sourceLink.url}
              href={sourceLink.url}
              target="_blank"
              rel="noreferrer"
              className="group flex items-center justify-between gap-4 rounded-2xl bg-[rgba(10,15,19,0.58)] px-4 py-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)] transition-all hover:bg-[rgba(255,255,255,0.06)]"
            >
              <div className="min-w-0 space-y-1">
                <div className={opsLabelClass}>{sourceLink.label}</div>
                <div className="truncate text-base font-medium text-[color:var(--ops-text)]">
                  {sourceLink.title}
                </div>
                <div className="text-sm text-[color:var(--ops-text-soft)]">
                  {sourceLink.usage}
                </div>
              </div>
              <span className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-black/20 text-[color:var(--ops-text-soft)] transition-colors group-hover:text-[color:var(--ops-text)]">
                <ExternalLink size={16} />
              </span>
            </a>
          ))}
        </div>
      </div>
    </ConsolePanel>
  );
}
