import React, { useCallback, useMemo } from 'react';
import { Database, Download, FileText } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { FloodLogsPanel } from '../components/FloodLogsPanel';
import { PageShell, PageHero } from '../components/PageShell';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  InsetPanel,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from '../components/OpsPrimitives';

function escapeCsvValue(value: string | number | null | undefined): string {
  const normalized = String(value ?? '');
  if (/[",\n]/.test(normalized)) {
    return `"${normalized.replace(/"/g, '""')}"`;
  }
  return normalized;
}

function createDownload(filename: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.URL.revokeObjectURL(url);
}

function slugifyArchiveLabel(value: string): string {
  return (
    value
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '') || 'region'
  );
}

export const ArchivesPage: React.FC = () => {
  const { state } = useAppState();
  const selectedRiverLocationLabel = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );
  const archiveRecords = state.prediction.history;
  const archiveFileBase = useMemo(() => {
    const region = slugifyArchiveLabel(selectedRiverLocationLabel);
    const date = new Date().toISOString().split('T')[0];
    return `neural_archives_${region}_${date}`;
  }, [selectedRiverLocationLabel]);
  const hasArchiveData = archiveRecords.length > 0;

  const exportArchiveCsv = useCallback(() => {
    if (!hasArchiveData) return;

    const csvRows = [
      [
        'Timestamp',
        'Selected State',
        'Selected City',
        'Peak Level (m)',
        'Rainfall (mm)',
        'Severity',
        'Confidence (%)',
        'Model Version',
        'Monitoring Level',
      ],
      ...archiveRecords.map((log) => [
        log.timestamp,
        state.prediction.selectedState,
        selectedRiverLocationLabel,
        log.peak_level,
        log.rainfall,
        log.severity,
        log.confidence,
        state.prediction.modelVersion,
        state.prediction.monitoringLevel,
      ]),
    ];

    const csv = csvRows
      .map((row) => row.map((cell) => escapeCsvValue(cell)).join(','))
      .join('\n');

    createDownload(`${archiveFileBase}.csv`, csv, 'text/csv;charset=utf-8');
  }, [
    archiveFileBase,
    archiveRecords,
    hasArchiveData,
    selectedRiverLocationLabel,
    state.prediction.modelVersion,
    state.prediction.monitoringLevel,
    state.prediction.selectedState,
  ]);

  const exportArchiveBundle = useCallback(() => {
    if (!hasArchiveData) return;

    const archiveBundle = {
      exported_at: new Date().toISOString(),
      archive_scope: {
        state: state.prediction.selectedState,
        city: state.prediction.selectedCity,
        station: state.form.data.station,
        selected_location: selectedRiverLocationLabel,
      },
      system: {
        api_status: state.system.apiStatus,
        api_version: state.system.apiVersion,
        model_version: state.prediction.modelVersion,
        total_predictions_made: state.prediction.totalPredictionsMade,
        last_prediction_time: state.prediction.lastPredictionTime,
      },
      monitoring: {
        level: state.prediction.monitoringLevel,
        action: state.prediction.monitoringAction,
        priority_zones: state.prediction.priorityZones,
      },
      records: archiveRecords.map((log, index) => ({
        archive_index: index + 1,
        id: log.id,
        timestamp: log.timestamp,
        peak_level_m: log.peak_level,
        rainfall_mm: log.rainfall,
        severity: log.severity,
        confidence_percent: log.confidence,
      })),
    };

    createDownload(
      `${archiveFileBase}.json`,
      JSON.stringify(archiveBundle, null, 2),
      'application/json;charset=utf-8',
    );
  }, [
    archiveFileBase,
    archiveRecords,
    hasArchiveData,
    selectedRiverLocationLabel,
    state.form.data.station,
    state.prediction.lastPredictionTime,
    state.prediction.modelVersion,
    state.prediction.monitoringAction,
    state.prediction.monitoringLevel,
    state.prediction.priorityZones,
    state.prediction.selectedCity,
    state.prediction.selectedState,
    state.prediction.totalPredictionsMade,
    state.system.apiStatus,
    state.system.apiVersion,
  ]);

  const getSeverityTone = (severity: string) => {
    if (severity === 'CRITICAL') return 'danger' as const;
    if (severity === 'SEVERE') return 'warning' as const;
    if (severity === 'MODERATE') return 'info' as const;
    return 'success' as const;
  };

  return (
    <PageShell className="space-y-6">
      <PageHero
        eyebrow="Operational Archive"
        title="Archives Vault"
        subtitle={`Government feeds, local inference history, and export-ready records for ${selectedRiverLocationLabel}.`}
        icon={FileText}
        action={
          <ActionButton
            onClick={exportArchiveBundle}
            disabled={!hasArchiveData}
            icon={Download}
            variant="secondary"
          >
            {hasArchiveData ? 'Export full dataset' : 'No archive data'}
          </ActionButton>
        }
      />

      <FloodLogsPanel borderless />

      <ConsolePanel intensity="primary" frameTone="neutral" padded={false}>
        <div className="px-5 py-5 sm:px-6 sm:py-6">
          <SectionHeader
            eyebrow="Local archive"
            title="Prediction history"
            description="Internal prediction runs are stored separately from packaged historical datasets so you can export scenario replay data and recent operator decisions."
            icon={Database}
            action={
              <>
                <StatusBadge tone="neutral">{archiveRecords.length} records</StatusBadge>
                <ActionButton
                  onClick={exportArchiveCsv}
                  disabled={!hasArchiveData}
                  icon={Download}
                  variant="secondary"
                >
                  Export CSV
                </ActionButton>
              </>
            }
          />
        </div>

        {state.prediction.history.length === 0 ? (
          <div className="p-5 sm:p-6">
            <EmptyState
              title="No prediction history yet"
              description="Run the model from the dashboard to create a local archive entry. Once available, each row here becomes exportable and easy to scan."
              icon={Database}
            />
          </div>
        ) : (
          <div className="space-y-4 p-5 sm:p-6">
            <div className="grid gap-4 md:grid-cols-3">
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Selected location</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {selectedRiverLocationLabel}
                </div>
              </InsetPanel>
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Model version</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {state.prediction.modelVersion}
                </div>
              </InsetPanel>
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Monitoring level</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {state.prediction.monitoringLevel || 'Pending'}
                </div>
              </InsetPanel>
            </div>

            <div className="max-h-[38rem] overflow-auto rounded-2xl bg-[rgba(8,12,16,0.46)] archives-scrollbar">
              <table className="w-full min-w-[760px] text-left">
                <thead className="sticky top-0 z-10 bg-[rgba(7,10,15,0.9)] backdrop-blur-md">
                  <tr className="text-[10px] font-black uppercase tracking-[0.22em] text-[color:var(--ops-text-dim)]">
                    <th className="px-5 py-4">Timestamp</th>
                    <th className="px-5 py-4">Environmental vector</th>
                    <th className="px-5 py-4">Verdict</th>
                    <th className="px-5 py-4 text-right">Confidence</th>
                  </tr>
                </thead>
                <tbody>
                  {state.prediction.history.map((log, idx) => (
                    <tr key={log.id || idx} className="transition-colors hover:bg-white/[0.03]">
                      <td className="px-5 py-5 text-sm text-[color:var(--ops-text-soft)]">
                        {new Date(log.timestamp).toLocaleString('en-IN', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                          second: '2-digit',
                        })}
                      </td>
                      <td className="px-5 py-5">
                        <div className="flex flex-wrap items-center gap-3 text-sm text-[color:var(--ops-text-soft)]">
                          <span>
                            Level <span className="font-semibold text-[color:var(--ops-text)]">{log.peak_level.toFixed(2)}m</span>
                          </span>
                          <span className="h-3 w-px bg-white/10" />
                          <span>
                            Rain <span className="font-semibold text-[color:var(--ops-text)]">{log.rainfall.toFixed(1)}mm</span>
                          </span>
                        </div>
                      </td>
                      <td className="px-5 py-5">
                        <StatusBadge tone={getSeverityTone(log.severity)}>{log.severity}</StatusBadge>
                      </td>
                      <td className="px-5 py-5 text-right">
                        <div className="inline-flex flex-col items-end">
                          <span className="text-base font-semibold text-[color:var(--ops-text)]">{log.confidence.toFixed(1)}%</span>
                          <div className="mt-2 h-1.5 w-20 overflow-hidden rounded-full bg-black/20">
                            <div
                              className="h-full rounded-full bg-[linear-gradient(90deg,#4c7cff,#79a5ff)]"
                              style={{ width: `${Math.max(4, log.confidence)}%` }}
                            />
                          </div>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </ConsolePanel>
    </PageShell>
  );
};
