import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Database, Download, FileText } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { FloodLogsPanel } from '../components/FloodLogsPanel';
import { PageShell, PageHero } from '../components/PageShell';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { apiUrl } from '../config/api';
import type { AuditLogRecord, StoredPredictionRecord, TelemetrySnapshotRecord } from '../types';
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

interface PredictionHistoryResponse {
  status: string;
  storage?: {
    backend?: string;
    configured?: boolean;
    ready?: boolean;
    message?: string;
  };
  total_records?: number;
  records?: StoredPredictionRecord[];
}

interface TelemetrySnapshotResponse {
  status: string;
  total_records?: number;
  records?: TelemetrySnapshotRecord[];
}

interface AuditLogResponse {
  status: string;
  total_records?: number;
  records?: AuditLogRecord[];
}

const ArchivesPage: React.FC = () => {
  const { state } = useAppState();
  const [archiveRecords, setArchiveRecords] = useState<StoredPredictionRecord[]>([]);
  const [telemetrySnapshots, setTelemetrySnapshots] = useState<TelemetrySnapshotRecord[]>([]);
  const [auditLogs, setAuditLogs] = useState<AuditLogRecord[]>([]);
  const [isLoadingArchive, setIsLoadingArchive] = useState(true);
  const [archiveError, setArchiveError] = useState<string | null>(null);
  const [storageStatus, setStorageStatus] = useState<PredictionHistoryResponse['storage'] | null>(null);
  const selectedRiverLocationLabel = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );
  const selectedStation = state.form.data.station || state.prediction.selectedCity || '';
  const archiveFileBase = useMemo(() => {
    const region = slugifyArchiveLabel(selectedRiverLocationLabel);
    const date = new Date().toISOString().split('T')[0];
    return `neural_archives_${region}_${date}`;
  }, [selectedRiverLocationLabel]);
  const hasArchiveData = archiveRecords.length > 0;

  useEffect(() => {
    const controller = new AbortController();

    const loadArchiveData = async () => {
      setIsLoadingArchive(true);
      setArchiveError(null);

      const params = new URLSearchParams({
        state: state.prediction.selectedState,
        limit: '100',
      });
      if (selectedStation) {
        params.set('station', selectedStation);
      }

      const sharedQuery = params.toString();

      try {
        const [predictionRes, telemetryRes, auditRes] = await Promise.all([
          fetch(apiUrl(`/prediction-history?${sharedQuery}`), { signal: controller.signal }),
          fetch(apiUrl(`/telemetry-snapshots?${sharedQuery}`), { signal: controller.signal }),
          fetch(apiUrl('/audit-logs?limit=25'), { signal: controller.signal }),
        ]);

        if (!predictionRes.ok || !telemetryRes.ok || !auditRes.ok) {
          throw new Error('Archive services did not respond successfully.');
        }

        const predictionPayload = (await predictionRes.json()) as PredictionHistoryResponse;
        const telemetryPayload = (await telemetryRes.json()) as TelemetrySnapshotResponse;
        const auditPayload = (await auditRes.json()) as AuditLogResponse;

        setArchiveRecords(Array.isArray(predictionPayload.records) ? predictionPayload.records : []);
        setTelemetrySnapshots(Array.isArray(telemetryPayload.records) ? telemetryPayload.records : []);
        setAuditLogs(Array.isArray(auditPayload.records) ? auditPayload.records : []);
        setStorageStatus(predictionPayload.storage || null);
      } catch (error) {
        if (controller.signal.aborted) return;
        setArchiveRecords([]);
        setTelemetrySnapshots([]);
        setAuditLogs([]);
        setStorageStatus(null);
        setArchiveError(error instanceof Error ? error.message : 'Unable to load PostgreSQL archive data right now.');
      } finally {
        if (!controller.signal.aborted) {
          setIsLoadingArchive(false);
        }
      }
    };

    loadArchiveData();
    return () => controller.abort();
  }, [selectedStation, state.prediction.selectedState]);

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
        log.model_version || state.prediction.modelVersion,
        log.monitoring_level || state.prediction.monitoringLevel,
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
        model_version: archiveRecords[0]?.model_version || state.prediction.modelVersion,
        total_predictions_made: archiveRecords.length,
        last_prediction_time: archiveRecords[0]?.timestamp || null,
        storage_backend: storageStatus?.backend || 'postgresql',
        storage_ready: storageStatus?.ready ?? false,
      },
      monitoring: {
        level: state.prediction.monitoringLevel,
        action: state.prediction.monitoringAction,
        priority_zones: state.prediction.priorityZones,
      },
      telemetry_snapshots: telemetrySnapshots.map((snapshot) => ({
        id: snapshot.id,
        timestamp: snapshot.timestamp,
        state: snapshot.state,
        station: snapshot.station,
        snapshot_status: snapshot.snapshot_status,
        node_count: snapshot.node_count,
        data_source: snapshot.data_source,
      })),
      audit_trail: auditLogs.map((entry) => ({
        id: entry.id,
        timestamp: entry.timestamp,
        event_type: entry.event_type,
        route: entry.route,
        event_status: entry.event_status,
        severity: entry.severity,
      })),
      records: archiveRecords.map((log, index) => ({
        archive_index: index + 1,
        id: log.id,
        timestamp: log.timestamp,
        peak_level_m: log.peak_level,
        rainfall_mm: log.rainfall,
        severity: log.severity,
        confidence_percent: log.confidence,
        state: log.state,
        station: log.station,
        model_version: log.model_version,
        monitoring_level: log.monitoring_level,
        data_source: log.data_source,
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
    state.prediction.modelVersion,
    state.prediction.monitoringAction,
    state.prediction.monitoringLevel,
    state.prediction.priorityZones,
    state.prediction.selectedCity,
    state.prediction.selectedState,
    state.system.apiStatus,
    state.system.apiVersion,
    storageStatus?.backend,
    storageStatus?.ready,
    telemetrySnapshots,
    auditLogs,
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
        subtitle={`Government feeds, PostgreSQL-backed prediction history, telemetry snapshots, and audit activity for ${selectedRiverLocationLabel}.`}
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
            eyebrow="PostgreSQL archive"
            title="Prediction history"
            description="Prediction runs now load from backend PostgreSQL tables so export bundles reflect persisted decisions, persisted telemetry context, and server-side audit activity."
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

        {isLoadingArchive ? (
          <div className="p-5 sm:p-6">
            <EmptyState
              title="Loading persisted archives"
              description="Fetching prediction history, telemetry snapshots, and audit activity from PostgreSQL."
              icon={Database}
            />
          </div>
        ) : archiveError ? (
          <div className="p-5 sm:p-6">
            <EmptyState
              title="Archive sync unavailable"
              description={archiveError}
              icon={Database}
            />
          </div>
        ) : !hasArchiveData ? (
          <div className="p-5 sm:p-6">
            <EmptyState
              title="No persisted prediction history yet"
              description={
                storageStatus?.configured
                  ? 'Run the model from the dashboard to create PostgreSQL-backed archive entries. Once persisted, each row here becomes exportable and easy to scan.'
                  : 'Set DATABASE_URL for the backend to enable PostgreSQL archive storage for predictions, telemetry snapshots, and audit logs.'
              }
              icon={Database}
            />
          </div>
        ) : (
          <div className="space-y-4 p-5 sm:p-6">
            <div className="grid gap-4 md:grid-cols-4">
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Selected location</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {selectedRiverLocationLabel}
                </div>
              </InsetPanel>
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Storage backend</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {(storageStatus?.backend || 'postgresql').toUpperCase()}
                </div>
              </InsetPanel>
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Telemetry snapshots</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {telemetrySnapshots.length}
                </div>
              </InsetPanel>
              <InsetPanel variant="soft">
                <div className={opsLabelClass}>Audit events</div>
                <div className="mt-2 text-lg font-semibold text-[color:var(--ops-text)]">
                  {auditLogs.length}
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
                  {archiveRecords.map((log, idx) => (
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

export default ArchivesPage;
