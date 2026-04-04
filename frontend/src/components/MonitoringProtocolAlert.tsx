import React from 'react';
import { AlertTriangle, Shield, Siren, Target } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { getCWCDataSourceMessage } from '../utils/cwcDataSource';
import {
  ConsolePanel,
  InsetPanel,
  MetricTile,
  SectionHeader,
  StatusBadge,
} from './OpsPrimitives';

type AlertTone = 'success' | 'info' | 'warning' | 'danger';

const severityMeta: Record<
  string,
  {
    tone: AlertTone;
    icon: typeof Shield;
    title: string;
    summary: string;
    headlinePrefix: string;
  }
> = {
  CRITICAL: {
    tone: 'danger',
    icon: Siren,
    title: 'Critical response protocol',
    summary: 'Immediate coordination is recommended for exposed zones and high-probability overflow corridors.',
    headlinePrefix: 'Immediate field coordination',
  },
  SEVERE: {
    tone: 'warning',
    icon: AlertTriangle,
    title: 'Elevated response protocol',
    summary: 'Teams should stay on heightened watch while telemetry and weather signals remain elevated.',
    headlinePrefix: 'Escalated readiness',
  },
  MODERATE: {
    tone: 'info',
    icon: AlertTriangle,
    title: 'Focused monitoring protocol',
    summary: 'Conditions justify structured monitoring, threshold checks, and local contingency readiness.',
    headlinePrefix: 'Focused monitoring',
  },
  LOW: {
    tone: 'success',
    icon: Shield,
    title: 'Routine monitoring protocol',
    summary: 'Current signals remain within normal operating tolerance, with routine observation still advised.',
    headlinePrefix: 'Routine monitoring',
  },
};

const recommendedSteps: Record<string, string[]> = {
  CRITICAL: [
    'Initiate field coordination with highest-priority zones.',
    'Escalate evacuation and public comms if gauges rise further.',
    'Pin live telemetry and weather to the active room.',
  ],
  SEVERE: [
    'Place response crews on heightened standby.',
    'Validate upstream gauge sync and confirm danger thresholds.',
    'Prepare evacuation messaging but hold release.',
  ],
  MODERATE: [
    'Increase observation cadence on key stations.',
    'Verify rainfall distribution versus state matrix thresholds.',
    'Pre-position pumps and medical support as needed.',
  ],
  LOW: [
    'Maintain routine monitoring cadence.',
    'Keep telemetry heartbeat and weather sync active.',
  ],
};

const monitoringLabels: Record<string, string> = {
  CRITICAL: 'Critical response',
  ELEVATED: 'Heightened monitoring',
  NORMAL: 'Routine monitoring',
};

export function MonitoringProtocolAlert() {
  const { state } = useAppState();
  const monitoring = state.prediction.monitoringLevel;
  const action = state.prediction.monitoringAction;
  const zones = state.prediction.priorityZones;
  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  const confidence = Number(state.prediction.currentPrediction?.confidence_percent || 0);
  const riskScore = Number(state.prediction.currentPrediction?.risk_score || 0);
  const dataSourceMessage = getCWCDataSourceMessage({
    isConnected: state.cwc.isConnected,
    liveSource: state.cwc.liveData.source,
    predictionSource: state.prediction.cwcDataSource,
    sourcePolicyMode: state.system.sourcePolicy.mode,
  });
  const steps = recommendedSteps[severity] || recommendedSteps.LOW;

  if (!monitoring || !state.prediction.currentPrediction) {
    return null;
  }

  const meta = severityMeta[severity] || severityMeta.LOW;
  const frameTone = meta.tone === 'danger' ? 'danger' : meta.tone === 'warning' ? 'amber' : meta.tone === 'info' ? 'cyan' : 'olive';
  const Icon = meta.icon;
  const monitoringLabel = monitoringLabels[monitoring] || monitoring;

  return (
    <ConsolePanel intensity="primary" elevated frameTone={frameTone} className="relative overflow-hidden">
      <div
        className="pointer-events-none absolute inset-0"
        aria-hidden="true"
        style={{
          background:
            meta.tone === 'danger'
              ? 'radial-gradient(circle at top right, rgba(201,58,86,0.18), transparent 34%)'
              : meta.tone === 'warning'
              ? 'radial-gradient(circle at top right, rgba(245,158,11,0.16), transparent 34%)'
              : meta.tone === 'info'
              ? 'radial-gradient(circle at top right, rgba(90,143,255,0.14), transparent 34%)'
              : 'radial-gradient(circle at top right, rgba(16,185,129,0.14), transparent 34%)',
        }}
      />

      <SectionHeader
        eyebrow="Monitoring alert"
        title={meta.title}
        description={meta.summary}
        icon={Icon}
        action={
          <>
            <StatusBadge tone={meta.tone}>Severity {severity}</StatusBadge>
            <StatusBadge tone="neutral">{monitoringLabel}</StatusBadge>
          </>
        }
        className="relative z-10 mb-6"
      />

      <div className="relative z-10 grid gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <InsetPanel variant="soft" className="space-y-6">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2">
              <StatusBadge tone={meta.tone} icon={Target}>
                {meta.headlinePrefix}
              </StatusBadge>
              <StatusBadge tone="info">
                Risk score {riskScore.toFixed(0)}
              </StatusBadge>
            </div>

            <div className="font-cinzel text-2xl font-semibold uppercase tracking-[0.06em] text-[color:var(--ops-text)]">
              {action}
            </div>

            <p className="max-w-3xl text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
              This recommendation combines the active model verdict, current telemetry context, and configured source policy.
            </p>
          </div>

          <div className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.24em] text-[color:var(--ops-text-dim)]">
              Priority zones
            </div>
            <div className="flex flex-wrap gap-2">
              {zones && zones.length > 0 ? (
                zones.map((zone, idx) => (
                  <StatusBadge key={`${zone}-${idx}`} tone="neutral" className="!rounded-xl !px-3 !py-2 !text-[10px]">
                    {zone}
                  </StatusBadge>
                ))
              ) : (
                <div className="text-sm text-[color:var(--ops-text-soft)]">
                  No specific zones are pinned yet for this run. The current recommendation applies to the active region scope.
                </div>
              )}
            </div>
          </div>

          {steps.length ? (
            <div className="space-y-3">
              <div className="text-[10px] font-black uppercase tracking-[0.24em] text-[color:var(--ops-text-dim)]">
                Recommended next actions
              </div>
              <div className="space-y-2">
                {steps.map((step, idx) => (
                  <div
                    key={idx}
                    className="flex items-start gap-3 rounded-xl bg-[rgba(7,11,14,0.46)] px-3 py-2.5 text-sm text-[color:var(--ops-text-soft)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]"
                  >
                    <span className="mt-0.5 h-8 w-1 shrink-0 rounded-full bg-[color:var(--ops-primary)]/80" />
                    <span className="leading-relaxed">{step}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </InsetPanel>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
          <MetricTile
            label="Risk score"
            value={riskScore.toFixed(0)}
            hint="Composite risk derived from matrix, rainfall, and telemetry context."
            tone={meta.tone}
            framed
            frameTone={frameTone}
          />
          <MetricTile
            label="Confidence"
            value={`${confidence.toFixed(1)}%`}
            hint="Model confidence for the current operating posture."
            tone="info"
          />
          <InsetPanel variant="soft" className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.24em] text-[color:var(--ops-text-dim)]">
              Data source
            </div>
            <div className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
              {dataSourceMessage}
            </div>
          </InsetPanel>
        </div>
      </div>
    </ConsolePanel>
  );
}
