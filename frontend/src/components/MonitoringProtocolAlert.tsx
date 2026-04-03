import React, { useMemo } from 'react';
import { AlertTriangle, AlertCircle, Shield } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { getCWCDataSourceMessage } from '../utils/cwcDataSource';
import { isLiteMotionDevice } from '../utils/performance';

export function MonitoringProtocolAlert() {
  const { state } = useAppState();
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);
  const monitoring = state.prediction.monitoringLevel;
  const action = state.prediction.monitoringAction;
  const zones = state.prediction.priorityZones;
  const dataSourceMessage = getCWCDataSourceMessage({
    isConnected: state.cwc.isConnected,
    liveSource: state.cwc.liveData.source,
    predictionSource: state.prediction.cwcDataSource,
  });

  if (!monitoring || !state.prediction.currentPrediction) {
    return null;
  }

  const getAlertStyle = (level: string) => {
    const panelBase = liteMotion ? 'bg-black/18 ring-0' : 'bg-black/25 backdrop-blur-xl ring-1 ring-white/5';
    switch (level) {
      case 'CRITICAL':
        return {
          panel: panelBase,
          border: 'border-[#ff0037]/35',
          icon: AlertTriangle,
          color: 'text-[#ff0037]',
          badge: 'bg-[#ff0037] text-white',
          glow: liteMotion ? 'shadow-[0_10px_24px_rgba(255,0,55,0.12)]' : 'shadow-[0_20px_70px_rgba(255,0,55,0.16)]',
        };
      case 'ELEVATED':
        return {
          panel: panelBase,
          border: 'border-amber-500/30',
          icon: AlertCircle,
          color: 'text-amber-300',
          badge: 'border border-amber-500/35 bg-amber-500/12 text-[#ffb3c1]',
          glow: liteMotion ? 'shadow-[0_10px_24px_rgba(245,158,11,0.08)]' : 'shadow-[0_20px_70px_rgba(245,158,11,0.10)]',
        };
      default:
        return {
          panel: panelBase,
          border: 'border-amber-500/25',
          icon: Shield,
          color: 'text-amber-200',
          badge: 'border border-amber-400/30 bg-amber-400/10 text-[#ffc4cf]',
          glow: liteMotion ? 'shadow-[0_10px_24px_rgba(245,158,11,0.08)]' : 'shadow-[0_20px_70px_rgba(245,158,11,0.10)]',
        };
    }
  };

  const style = getAlertStyle(monitoring);
  const Icon = style.icon;
  const monitoringLabel =
    monitoring === 'CRITICAL'
      ? 'CRITICAL PROTOCOL'
      : monitoring === 'ELEVATED'
      ? 'ELEVATED ALERT'
      : 'STANDARD SURVEILLANCE';

  return (
    <div className={`w-full rounded-[2rem] border p-7 ${style.panel} ${style.border} ${style.glow || ''}`}>
      <div className="flex items-start gap-4">
        <Icon className={`w-6 h-6 ${style.color} flex-shrink-0 mt-0.5`} />

        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <h3 className={`text-lg font-black ${style.color} tracking-tight`}>
              {monitoringLabel}
            </h3>
            <span className={`px-3 py-1 rounded-full text-xs font-semibold ${style.badge}`}>
              {state.prediction.currentPrediction?.severity}
            </span>
          </div>

          <p className="text-sm font-bold text-slate-200 mb-4">
            {action}
          </p>

          {zones && zones.length > 0 && (
            <div>
              <p className="text-xs font-black text-slate-400 uppercase tracking-widest mb-2">
                Priority Zones:
              </p>
              <div className="flex flex-wrap gap-2">
                {zones.map((zone, idx) => (
                  <span
                    key={idx}
                    className="px-3 py-1 rounded-xl text-xs font-bold bg-white/5 border border-white/10 text-slate-200"
                  >
                    {zone}
                  </span>
                ))}
              </div>
            </div>
          )}

          <div className="mt-5 pt-5 border-t border-white/10">
            <p className="text-xs text-slate-400">
              Confidence: {state.prediction.currentPrediction?.confidence_percent}%
              <br />
              Risk Score: {state.prediction.currentPrediction?.risk_score}
              <br />
              Data Source: {dataSourceMessage}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
