import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Database, Download, Info, Radio, TrendingUp } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { apiUrl } from '../config/api';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { getCWCDataSourceMessage } from '../utils/cwcDataSource';
import { SkeletonLoader } from './SkeletonLoader';
import {
  ActionButton,
  ConsolePanel,
  EmptyState,
  InsetPanel,
  SectionHeader,
  StatusBadge,
  opsLabelClass,
} from './OpsPrimitives';

interface FloodLog {
  timestamp: string;
  location: string;
  peak_level: number;
  rainfall_7day: number;
  severity: string;
  confidence: number;
  alert: string;
  source: string;
}

interface FloodLogsPanelProps {
  onLogLoaded?: () => void;
  borderless?: boolean;
}

const getSeverityTone = (severity: string) => {
  if (severity === 'CRITICAL') return 'danger' as const;
  if (severity === 'SEVERE') return 'warning' as const;
  if (severity === 'MODERATE') return 'info' as const;
  return 'success' as const;
};

export const FloodLogsPanel: React.FC<FloodLogsPanelProps> = ({ onLogLoaded, borderless = false }) => {
  const { state, dispatch } = useAppState();
  const [logs, setLogs] = useState<FloodLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [historicalMode, setHistoricalMode] = useState<'REAL_DATASET' | 'NO_REAL_DATASET'>('NO_REAL_DATASET');
  const [datasetCity, setDatasetCity] = useState<string | null>(null);
  const [historicalMessage, setHistoricalMessage] = useState<string | null>(null);
  const [selectedLogKey, setSelectedLogKey] = useState<string | null>(null);
  const selectedCity = getSelectedRiverLocationLabel(
    state.prediction.selectedCity,
    state.form.data.station,
    state.prediction.selectedState,
  );
  const activeCityOrStation = state.form.data.station || state.prediction.selectedCity || '';
  const activeState = state.prediction.selectedState || state.form.data.state || '';
  const liveCWC = state.cwc.liveData;
  const isConnected = state.cwc.isConnected;
  const dataSourceMessage = getCWCDataSourceMessage({
    isConnected,
    liveSource: liveCWC.source,
    predictionSource: state.prediction.cwcDataSource,
    sourcePolicyMode: state.system.sourcePolicy.mode,
  });

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const logsRes = await fetch(apiUrl(`/historical-logs?city=${encodeURIComponent(selectedCity)}&limit=50`));
      const logsData = await logsRes.json();
      if (logsData.status === 'success') {
        setLogs(Array.isArray(logsData.records) ? logsData.records : []);
        setHistoricalMode(logsData.data_mode === 'REAL_DATASET' ? 'REAL_DATASET' : 'NO_REAL_DATASET');
        setDatasetCity(logsData.dataset_city || null);
        setHistoricalMessage(logsData.message || null);
      } else {
        setLogs([]);
        setHistoricalMode('NO_REAL_DATASET');
        setDatasetCity(null);
        setHistoricalMessage('Unable to load historical flood logs right now.');
      }
    } catch (error) {
      console.error('Error fetching logs:', error);
      setLogs([]);
      setHistoricalMode('NO_REAL_DATASET');
      setDatasetCity(null);
      setHistoricalMessage('Unable to load historical flood logs right now.');
    } finally {
      setLoading(false);
    }
  }, [selectedCity]);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void fetchLogs();
    }, 260);

    return () => window.clearTimeout(timeoutId);
  }, [fetchLogs]);

  const emptyState = useMemo(() => {
    if (logs.length > 0) {
      return null;
    }

    if (historicalMessage === 'Unable to load historical flood logs right now.') {
      return {
        title: 'Historical logs are temporarily unavailable',
        body: 'The archive request did not complete. Live telemetry and PostgreSQL-backed prediction history are still available while the logs reconnect.',
        note: 'Refresh the module in a moment if you need the historical table for this review session.',
      };
    }

    return {
      title: `No mapped historical dataset for ${selectedCity}`,
      body: `This location does not currently ship with packaged historical flood rows in the demo dataset, so the table stays intentionally empty instead of falling back to fake records.`,
      note: 'You can continue with live telemetry, review persisted prediction history, or switch to another region with a packaged archive sample.',
    };
  }, [historicalMessage, logs.length, selectedCity]);

  const exportLogs = () => {
    const csv = [
      ['Timestamp', 'Location', 'Peak Level (m)', 'Rainfall 7d (mm)', 'Severity', 'Confidence (%)', 'Alert', 'Source'].join(','),
      ...logs.map((log) =>
        [
          log.timestamp,
          log.location,
          log.peak_level,
          log.rainfall_7day,
          log.severity,
          log.confidence,
          log.alert,
          log.source,
        ].join(','),
      ),
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `flood_logs_${selectedCity}_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
  };

  const loadLogIntoInputs = (log: FloodLog) => {
    const rainfallTotal = Number(log.rainfall_7day || 0);
    const dailyBase = Math.round((rainfallTotal / 7) * 10) / 10;
    const dailyValues = Array.from({ length: 7 }, (_, index) => {
      if (index < 6) return dailyBase;
      return Math.round((rainfallTotal - dailyBase * 6) * 10) / 10;
    });
    const distribution = dailyValues.map((mm, index) => ({
      day: index + 1,
      mm,
    }));

    dispatch({
      type: 'SET_FORM_DATA',
      payload: {
        Peak_Flood_Level_m: Number(log.peak_level || 0),
        T1d: dailyValues[0],
        T2d: dailyValues[1],
        T3d: dailyValues[2],
        T4d: dailyValues[3],
        T5d: dailyValues[4],
        T6d: dailyValues[5],
        T7d: dailyValues[6],
      },
    });
    dispatch({
      type: 'UPDATE_RAINFALL_STATS',
      payload: {
        total: rainfallTotal,
        average: rainfallTotal / 7,
        distribution,
      },
    });

    setSelectedLogKey(`${log.timestamp}-${log.location}`);
    window.requestAnimationFrame(() => {
      onLogLoaded?.();
    });
  };

  return (
    <div className={`space-y-6 ${borderless ? 'md:space-y-7' : ''}`}>
      {loading && !liveCWC ? (
        <SkeletonLoader type="card" />
      ) : liveCWC ? (
        <ConsolePanel intensity="secondary" className={borderless ? '!bg-[color:var(--ops-surface-1)]' : ''}>
          <SectionHeader
            eyebrow="Live registry context"
            title={`CWC context for ${liveCWC.station || selectedCity}`}
            description="A compact live hydrology snapshot stays attached to the archives module so historical review always has current river context nearby."
            icon={TrendingUp}
            action={
              <>
                <StatusBadge tone={isConnected || liveCWC.source === 'TACTICAL_REGISTRY' ? 'success' : 'warning'} icon={Radio}>
                  {isConnected || liveCWC.source === 'TACTICAL_REGISTRY' ? 'Live registry' : 'Fallback context'}
                </StatusBadge>
                <StatusBadge tone="neutral">
                  {activeState || 'No state lock'}
                </StatusBadge>
              </>
            }
            className="mb-5"
          />

          <div className="grid gap-4 md:grid-cols-3">
            <InsetPanel variant="soft" className="space-y-2">
              <div className={opsLabelClass}>Current level</div>
              <div className="text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                {typeof liveCWC.currentLevel === 'number' || typeof liveCWC.kolhapurLevel === 'number'
                  ? `${(liveCWC.currentLevel ?? liveCWC.kolhapurLevel)?.toFixed(2)}m`
                  : '--'}
              </div>
              <div className="text-sm text-[color:var(--ops-text-soft)]">
                River {liveCWC.river || 'Active basin'}
              </div>
            </InsetPanel>

            <InsetPanel variant="soft" className="space-y-2">
              <div className={opsLabelClass}>Thresholds</div>
              <div className="text-lg font-semibold text-[color:var(--ops-text)]">
                Warning {typeof liveCWC.warningLevel === 'number' ? `${liveCWC.warningLevel.toFixed(2)}m` : '--'}
              </div>
              <div className="text-sm text-[color:var(--ops-text-soft)]">
                Danger {typeof liveCWC.dangerLevel === 'number' ? `${liveCWC.dangerLevel.toFixed(2)}m` : '--'}
              </div>
            </InsetPanel>

            <InsetPanel variant="soft" className="space-y-2">
              <div className={opsLabelClass}>Source</div>
              <div className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
                {dataSourceMessage}
              </div>
              <div className="text-xs text-[color:var(--ops-text-faint)]">
                Updated {state.cwc.lastFetchTime ? new Date(state.cwc.lastFetchTime).toLocaleString() : 'Awaiting sync'}
              </div>
            </InsetPanel>
          </div>
        </ConsolePanel>
      ) : null}

      <ConsolePanel intensity="primary" frameTone="neutral" className={borderless ? '!bg-[color:var(--ops-surface-1)]' : ''} padded={false}>
        <div className="px-5 py-5 sm:px-6 sm:py-6">
          <SectionHeader
            eyebrow="Historical logs"
            title={`Archives dataset for ${selectedCity}`}
            description="Review packaged historical flood records, export the current dataset view, or load a row back into the dashboard inputs for replay."
            icon={Database}
            action={
              <>
                <StatusBadge tone={historicalMode === 'REAL_DATASET' ? 'success' : 'neutral'}>
                  {historicalMode === 'REAL_DATASET' ? 'Real dataset' : 'Dataset unavailable'}
                </StatusBadge>
                {datasetCity ? <StatusBadge tone="neutral">Dataset {datasetCity}</StatusBadge> : null}
                <ActionButton onClick={exportLogs} disabled={logs.length === 0} icon={Download}>
                  Export CSV
                </ActionButton>
              </>
            }
          />

          <div className="mt-4 flex flex-wrap gap-2">
            {activeCityOrStation ? <StatusBadge tone="info">City {activeCityOrStation}</StatusBadge> : null}
            {activeState ? <StatusBadge tone="neutral">State {activeState}</StatusBadge> : null}
            {logs.length > 0 ? <StatusBadge tone="neutral">Select a row to load the scenario</StatusBadge> : null}
          </div>
        </div>

        {loading ? (
          <div className="p-5 sm:p-6">
            <SkeletonLoader type="table" />
          </div>
        ) : logs.length === 0 ? (
          <div className="p-5 sm:p-6">
            <EmptyState
              title={emptyState?.title || 'No historical logs available'}
              description={
                <>
                  <div>{emptyState?.body}</div>
                  <div className="mt-2 text-[color:var(--ops-text-faint)]">{emptyState?.note}</div>
                </>
              }
              icon={Info}
            />
          </div>
        ) : (
          <div className="max-h-[34rem] overflow-auto rounded-b-[1.1rem] bg-[rgba(8,12,16,0.4)] px-2 pb-2 pt-2 archives-scrollbar sm:px-3">
            <table className="w-full min-w-[760px] text-left">
              <thead className="sticky top-0 z-10 bg-[rgba(7,10,15,0.9)] backdrop-blur-md">
                <tr className="text-[10px] font-black uppercase tracking-[0.22em] text-[color:var(--ops-text-dim)]">
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Peak level</th>
                  <th className="px-4 py-3">Rainfall 7d</th>
                  <th className="px-4 py-3">Severity</th>
                  <th className="px-4 py-3">Confidence</th>
                  <th className="px-4 py-3">Source</th>
                  <th className="px-4 py-3 text-right">Replay</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log, idx) => {
                  const logKey = `${log.timestamp}-${log.location}`;
                  const isSelected = selectedLogKey === logKey;

                  return (
                    <tr
                      key={idx}
                      className={isSelected ? 'bg-white/[0.06]' : 'transition-colors hover:bg-white/[0.03]'}
                    >
                      <td className="px-4 py-4 text-sm text-[color:var(--ops-text-soft)]">
                        {new Date(log.timestamp).toLocaleDateString()}
                      </td>
                      <td className="px-4 py-4 text-sm font-semibold text-[color:var(--ops-text)]">
                        {log.peak_level.toFixed(1)}m
                      </td>
                      <td className="px-4 py-4 text-sm text-[color:var(--ops-text-soft)]">
                        {log.rainfall_7day.toFixed(0)}mm
                      </td>
                      <td className="px-4 py-4">
                        <StatusBadge tone={getSeverityTone(log.severity)}>{log.severity}</StatusBadge>
                      </td>
                      <td className="px-4 py-4 text-sm font-semibold text-[color:var(--ops-text)]">
                        {log.confidence.toFixed(0)}%
                      </td>
                      <td className="px-4 py-4 text-xs text-[color:var(--ops-text-faint)]">
                        {log.source}
                      </td>
                      <td className="px-4 py-4 text-right">
                        <ActionButton
                          onClick={() => loadLogIntoInputs(log)}
                          variant={isSelected ? 'primary' : 'secondary'}
                          className="min-h-[2.3rem] px-3 text-[10px]"
                        >
                          {isSelected ? 'Loaded' : 'Load into inputs'}
                        </ActionButton>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </ConsolePanel>
    </div>
  );
};
