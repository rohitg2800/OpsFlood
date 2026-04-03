import React, { useCallback, useEffect, useState } from 'react';
import { Database, Download, TrendingUp } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { apiUrl } from '../config/api';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';
import { getCWCDataSourceMessage } from '../utils/cwcDataSource';
import { SkeletonLoader } from './SkeletonLoader';

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

  const exportLogs = () => {
    const csv = [
      ['Timestamp', 'Location', 'Peak Level (m)', 'Rainfall 7d (mm)', 'Severity', 'Confidence (%)', 'Alert', 'Source'].join(','),
      ...logs.map(log =>
        [
          log.timestamp,
          log.location,
          log.peak_level,
          log.rainfall_7day,
          log.severity,
          log.confidence,
          log.alert,
          log.source
        ].join(',')
      )
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
    <div className={`space-y-6 ${borderless ? 'md:space-y-8' : ''}`}>
      {/* CWC Live Data Card */}
      {loading && !liveCWC ? (
        <SkeletonLoader type="card" />
      ) : liveCWC ? (
        <div className={`rounded-[2rem] p-6 backdrop-blur-xl ${borderless ? 'bg-black/18 shadow-[0_20px_60px_rgba(0,0,0,0.18)]' : 'border ring-1 ring-white/5'} ${
          isConnected || liveCWC.source === 'TACTICAL_REGISTRY'
            ? `${borderless ? 'bg-amber-500/8' : 'bg-amber-500/10 border-amber-500/30'} shadow-[0_18px_60px_rgba(245,158,11,0.10)]`
            : `${borderless ? 'bg-[#ff0037]/8' : 'bg-[#ff0037]/10 border-[#ff0037]/30'} shadow-[0_18px_60px_rgba(255,0,55,0.12)]`
        }`}>
          <div className="flex items-center justify-between">
            <div>
              <h3 className="flex items-center gap-2 text-sm font-black text-white mb-2">
                <TrendingUp size={16} className={isConnected || liveCWC.source === 'TACTICAL_REGISTRY' ? 'text-amber-300' : 'text-[#ff0037]'} />
                CWC Live Data - {liveCWC.station || selectedCity}
              </h3>
              {(typeof liveCWC.currentLevel === 'number' || typeof liveCWC.kolhapurLevel === 'number') ? (
                <div className="space-y-1">
                  <p className="text-2xl font-black text-white">
                    {(liveCWC.currentLevel ?? liveCWC.kolhapurLevel)?.toFixed(2)}m
                  </p>
                  <p className="text-[10px] text-slate-300">
                    River: {liveCWC.river || 'Active Basin'} • Warning: {typeof liveCWC.warningLevel === 'number' ? `${liveCWC.warningLevel.toFixed(2)}m` : '--'} • Danger: {typeof liveCWC.dangerLevel === 'number' ? `${liveCWC.dangerLevel.toFixed(2)}m` : '--'}
                  </p>
                  <p className="text-[10px] text-slate-400">
                    Data Source: {dataSourceMessage}
                  </p>
                  <p className="text-[9px] text-slate-500">
                    Updated: {state.cwc.lastFetchTime ? new Date(state.cwc.lastFetchTime).toLocaleString() : 'Awaiting sync'}
                  </p>
                </div>
              ) : (
                <p className="text-red-300 text-sm font-bold">No live registry data available for {selectedCity}</p>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {/* Active Context */}
      <div className="flex flex-wrap gap-2">
        {activeCityOrStation ? (
          <span
            className={`rounded-full px-4 py-2 text-[10px] font-black uppercase tracking-[0.18em] ${
              borderless
                ? 'bg-gradient-to-r from-[#6b000f]/90 via-[#b00020]/90 to-[#f59e0b]/90 text-white shadow-[0_14px_40px_rgba(255,0,55,0.14)]'
                : 'border border-white/10 bg-gradient-to-r from-[#6b000f] via-[#b00020] to-[#f59e0b] text-white shadow-[0_14px_40px_rgba(255,0,55,0.14)]'
            }`}
          >
            City: {activeCityOrStation}
          </span>
        ) : null}
        {activeState ? (
          <span
            className={`rounded-full px-4 py-2 text-[10px] font-black uppercase tracking-[0.18em] ${
              borderless
                ? 'bg-white/[0.04] text-slate-300 shadow-[0_10px_30px_rgba(0,0,0,0.12)]'
                : 'border border-white/10 bg-white/5 text-slate-300'
            }`}
          >
            State: {activeState}
          </span>
        ) : null}
      </div>

      {/* Historical Logs Table */}
      <div className={`overflow-hidden rounded-[2rem] bg-black/25 backdrop-blur-xl ${borderless ? 'px-1 py-1 shadow-[0_24px_80px_rgba(0,0,0,0.2)]' : 'border border-white/10 ring-1 ring-white/5'}`}>
        <div className={`flex items-center justify-between bg-white/[0.02] ${borderless ? 'gap-6 px-8 py-7' : 'border-b border-white/10 p-6'}`}>
          <div className="space-y-2">
            <h3 className="flex items-center gap-2 text-sm font-black text-white">
              <Database size={16} className="text-[#ff0037]" /> Historical Flood Logs ({logs.length})
            </h3>
            <div className="flex flex-wrap items-center gap-2 text-[9px] font-black uppercase tracking-[0.18em]">
              <span
                className={`rounded-md px-2.5 py-1 ${
                  historicalMode === 'REAL_DATASET'
                    ? `${borderless ? 'bg-[#ff0037]/10 text-[#ff9eb1]' : 'border border-[#ff0037]/30 bg-[#ff0037]/10 text-[#ff9eb1]'}`
                    : `${borderless ? 'bg-white/[0.04] text-stone-400' : 'border border-white/10 bg-white/[0.04] text-stone-400'}`
                }`}
              >
                {historicalMode === 'REAL_DATASET' ? 'Real Dataset' : 'No Real Dataset'}
              </span>
              {datasetCity ? (
                <span className={`rounded-md bg-white/[0.03] px-2.5 py-1 text-stone-400 ${borderless ? '' : 'border border-white/10'}`}>
                  Dataset: {datasetCity}
                </span>
              ) : null}
              <span className={`rounded-md bg-white/[0.03] px-2.5 py-1 text-stone-400 ${borderless ? '' : 'border border-white/10'}`}>
                Select row -&gt; load CSV into input
              </span>
            </div>
          </div>
          <button
            onClick={exportLogs}
            disabled={logs.length === 0}
            className={`flex items-center gap-2 rounded-full px-4 py-2 text-[10px] font-black uppercase text-[#ff0037] transition-all shadow-[0_12px_30px_rgba(255,0,55,0.08)] enabled:hover:bg-[#ff0037] enabled:hover:text-white disabled:cursor-not-allowed disabled:opacity-40 ${borderless ? 'bg-white/[0.04]' : 'border border-white/10 bg-white/5'}`}
          >
            <Download size={14} /> Export
          </button>
        </div>

        {loading ? (
          <div className="p-6">
            <SkeletonLoader type="table" />
          </div>
        ) : logs.length === 0 ? (
          <div className="p-8 text-center text-slate-500">
            {historicalMessage || `No real historical logs available for ${selectedCity}`}
          </div>
        ) : (
          <div className={`max-h-[26rem] overflow-auto archives-scrollbar ${borderless ? 'px-2 pb-2' : ''}`}>
            <table className="w-full text-left text-xs">
              <thead className={`sticky top-0 z-10 backdrop-blur-md ${borderless ? 'bg-black/70' : 'bg-black/85'}`}>
                <tr className="text-slate-500 font-black uppercase text-[9px]">
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Peak Level</th>
                  <th className="px-4 py-3">Rainfall 7d</th>
                  <th className="px-4 py-3">Severity</th>
                  <th className="px-4 py-3">Confidence</th>
                  <th className="px-4 py-3">Source</th>
                  <th className="px-4 py-3 text-right">Input</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {logs.map((log, idx) => (
                  <tr
                    key={idx}
                    className={`transition-colors ${
                      selectedLogKey === `${log.timestamp}-${log.location}`
                        ? 'bg-[#ff0037]/8'
                        : 'hover:bg-white/[0.03]'
                    }`}
                  >
                    <td className="px-4 py-3 text-slate-400">
                      {new Date(log.timestamp).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3 font-black text-white">{log.peak_level.toFixed(1)}m</td>
                    <td className="px-4 py-3 text-slate-400">{log.rainfall_7day.toFixed(0)}mm</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 rounded text-[9px] font-black ${
                        log.severity === 'SEVERE'
                          ? 'bg-red-500/20 text-red-300'
                          : log.severity === 'MODERATE'
                          ? 'bg-yellow-500/20 text-yellow-300'
                          : 'bg-green-500/20 text-green-300'
                      }`}>
                        {log.severity}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-white font-black">{log.confidence.toFixed(0)}%</td>
                    <td className="px-4 py-3 text-[9px] text-slate-500">{log.source}</td>
                    <td className="px-4 py-3 text-right">
                      <button
                        type="button"
                        onClick={() => loadLogIntoInputs(log)}
                        className={`rounded-md px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.16em] transition-all ${
                          selectedLogKey === `${log.timestamp}-${log.location}`
                            ? `${borderless ? 'bg-[#ff0037]/14 text-[#ff9eb1]' : 'border border-[#ff0037]/38 bg-[#ff0037]/14 text-[#ff9eb1]'}`
                            : `${borderless ? 'bg-white/[0.03] text-stone-300 hover:bg-[#ff0037]/10 hover:text-white' : 'border border-white/10 bg-white/[0.03] text-stone-300 hover:border-[#ff0037]/35 hover:bg-[#ff0037]/10 hover:text-white'}`
                        }`}
                      >
                        {selectedLogKey === `${log.timestamp}-${log.location}` ? 'Loaded' : 'Load'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
