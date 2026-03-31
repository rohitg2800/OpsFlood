import React, { useCallback, useMemo } from 'react';
import { Database, Download, FileText, ChevronRight } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { FloodLogsPanel } from '../components/FloodLogsPanel';
import { PageShell, PageHero, PageCard } from '../components/PageShell';
import { getSelectedRiverLocationLabel } from '../utils/regionReadings';

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

// ==========================================
// ARCHIVES PAGE COMPONENT
// ==========================================

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

  return (
    <PageShell className="space-y-10">
      <PageHero
        eyebrow="External Telemetry Logs"
        title="Archives Vault"
        subtitle={`Government feeds, local inference history, and export-ready records for ${selectedRiverLocationLabel}.`}
        icon={FileText}
        action={
          <button
            onClick={exportArchiveBundle}
            disabled={!hasArchiveData}
            className="inline-flex items-center gap-3 rounded-md bg-white/[0.06] px-6 py-3 text-[10px] font-black uppercase tracking-[0.22em] text-[#ffb36a] transition-all enabled:hover:bg-[#ff0037] enabled:hover:text-white disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Download size={16} />
            {hasArchiveData ? 'Export Full Dataset' : 'No Archive Data'}
          </button>
        }
      />

      {/* CWC & GOVERNMENT FLOOD LOGS - INTEGRATED SHELL */}
      <section className="relative pt-2">
        <FloodLogsPanel borderless />
      </section>

      {/* LOCAL PREDICTION HISTORY - PREMIUM VAULT STYLE */}
      <PageCard className="relative !border-0 !bg-[#121812]/78 !p-0 !shadow-[0_28px_90px_rgba(0,0,0,0.28)]">
        <div className="flex flex-col items-start justify-between gap-8 bg-white/[0.02] px-10 py-12 md:flex-row md:items-center md:px-12">
          <div className="space-y-1">
            <h2 className="text-2xl font-black flex items-center gap-4 text-white font-cinzel tracking-widest uppercase">
              <Database className="text-[#ff5b79]" size={28} /> Neural Archives
            </h2>
            <p className="text-[10px] text-stone-500 uppercase tracking-[0.2em] font-bold ml-11">
              Internal_Prediction_Database // Encrypted_Storage
            </p>
          </div>
          
          <button
            onClick={exportArchiveCsv}
            disabled={!hasArchiveData}
            className="group flex items-center gap-3 rounded-md bg-[#ff0037]/10 px-8 py-3 text-[10px] font-black uppercase text-[#ff9eb1] shadow-[0_15px_40px_rgba(255,0,55,0.1)] transition-all active:scale-95 enabled:hover:bg-[#ff0037] enabled:hover:text-white disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Download size={16} className="group-hover:-translate-y-0.5 transition-transform" /> 
            {hasArchiveData ? 'Export_Archive_CSV' : 'No_Archives_Found'}
          </button>
        </div>

        <div className="px-4 pb-4 md:px-6 md:pb-6">
          <div className="max-h-[38rem] overflow-auto rounded-[1.5rem] archives-scrollbar">
          <table className="w-full text-left border-collapse">
            <thead className="sticky top-0 z-10 bg-black/88 backdrop-blur-md text-[10px] uppercase font-black text-stone-500 tracking-[0.3em]">
              <tr>
                <th className="px-8 py-6 md:px-10">Timestamp</th>
                <th className="px-8 py-6 md:px-10">Environmental Vector</th>
                <th className="px-8 py-6 md:px-10">System Verdict</th>
                <th className="px-8 py-6 text-right md:px-10">Fidelity_Index</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/[0.04] font-mono">
              {state.prediction.history.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-10 py-24 text-center">
                    <div className="flex flex-col items-center gap-4 opacity-20">
                      <Database size={48} />
                      <p className="text-xs font-black uppercase tracking-[0.4em]">No_Archives_Found</p>
                    </div>
                  </td>
                </tr>
              ) : (
                state.prediction.history.map((log, idx) => (
                  <tr key={log.id || idx} className="group transition-colors hover:bg-white/[0.03]">
                    <td className="px-8 py-8 text-xs font-bold uppercase tracking-tighter text-stone-400 md:px-10">
                      {new Date(log.timestamp).toLocaleString('en-IN', {
                        day: '2-digit', month: 'short', year: 'numeric',
                        hour: '2-digit', minute: '2-digit', second: '2-digit'
                      })}
                    </td>
                    <td className="px-8 py-8 text-xs md:px-10">
                      <div className="flex items-center gap-4">
                        <div className="flex items-center gap-2">
                          <span className="text-[#bc9437]/50 font-black tracking-widest text-[9px]">LVL:</span>
                          <span className="text-white font-black">{log.peak_level.toFixed(2)}m</span>
                        </div>
                        <div className="w-[1px] h-3 bg-white/10" />
                        <div className="flex items-center gap-2">
                          <span className="text-blue-500/50 font-black tracking-widest text-[9px]">PRECIP:</span>
                          <span className="text-white font-black">{log.rainfall.toFixed(1)}mm</span>
                        </div>
                      </div>
                    </td>
                    <td className="px-8 py-8 md:px-10">
                      <div className="flex items-center gap-3">
                        <span className={`rounded-md border px-4 py-1.5 text-[9px] font-black uppercase ${
                          log.severity === 'SEVERE' || log.severity === 'CRITICAL'
                            ? 'bg-[#ff0037]/10 text-[#ff0037] border-[#ff0037]/30 shadow-[0_0_15px_rgba(255,0,55,0.1)]' 
                            : log.severity === 'MODERATE'
                            ? 'bg-amber-500/10 text-amber-400 border-[#ff0037]/24'
                            : 'bg-emerald-500/10 text-emerald-400 border-[#ff0037]/24'
                        }`}>
                          {log.severity}
                        </span>
                        {(log.severity === 'SEVERE' || log.severity === 'CRITICAL') && (
                          <ChevronRight size={14} className="text-[#ff0037] animate-pulse" />
                        )}
                      </div>
                    </td>
                    <td className="px-8 py-8 text-right md:px-10">
                       <div className="inline-flex flex-col items-end">
                          <span className="text-sm font-black text-white">{log.confidence.toFixed(1)}%</span>
                          <div className="w-16 h-1 bg-white/5 rounded-full mt-1 overflow-hidden">
                             <div 
                               className="h-full bg-[#bc9437]" 
                               style={{ width: `${log.confidence}%` }}
                             />
                          </div>
                       </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          </div>
        </div>
        
        {/* Tactical Footer for Table */}
        <div className="flex items-center justify-between bg-black/32 px-8 py-6 text-[9px] font-black uppercase tracking-[0.3em] text-stone-600 md:px-10">
           <span>Database_Sync: Standard</span>
           <span>Total_Records: {state.prediction.history.length}</span>
        </div>
      </PageCard>
    </PageShell>
  );
};
