import React from 'react';
import { Layers3 } from 'lucide-react';

type HeatmapSeverity = 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';

interface HeatmapItem {
  label?: string;
  subLabel?: string;
  state?: string;
  risk: number;
  severity: HeatmapSeverity;
}

interface FloodRiskHeatmapProps {
  data: HeatmapItem[];
  title?: string;
  caption?: string;
}

const severityToneMap: Record<HeatmapSeverity, string> = {
  LOW: 'from-emerald-500/30 via-emerald-500/12 to-transparent text-emerald-200',
  MODERATE: 'from-amber-500/30 via-amber-500/12 to-transparent text-amber-100',
  SEVERE: 'from-orange-500/34 via-orange-500/14 to-transparent text-orange-100',
  CRITICAL: 'from-[#ff0037]/34 via-[#ff0037]/14 to-transparent text-white',
};

const barToneMap: Record<HeatmapSeverity, string> = {
  LOW: 'bg-emerald-500',
  MODERATE: 'bg-amber-500',
  SEVERE: 'bg-orange-500',
  CRITICAL: 'bg-[#ff0037]',
};

const glowToneMap: Record<HeatmapSeverity, string> = {
  LOW: 'shadow-[0_0_18px_rgba(16,185,129,0.18)]',
  MODERATE: 'shadow-[0_0_18px_rgba(245,158,11,0.18)]',
  SEVERE: 'shadow-[0_0_20px_rgba(249,115,22,0.22)]',
  CRITICAL: 'shadow-[0_0_24px_rgba(255,0,55,0.24)]',
};

export const FloodRiskHeatmap: React.FC<FloodRiskHeatmapProps> = ({
  data,
  title = 'State Risk Heatmap',
  caption = 'Severity-linked hotspots for the active flood matrix.',
}) => {
  const items = data.slice(0, 6).map((item, index) => ({
    id: `${item.label || item.state || 'heatmap'}-${index}`,
    label: item.label || item.state || `Sector ${index + 1}`,
    subLabel: item.subLabel || 'Linked region',
    risk: Math.max(0, Math.min(100, Number(item.risk || 0))),
    severity: item.severity,
  }));

  return (
    <div className="overflow-hidden rounded-md border border-[#ff0037]/24 bg-[linear-gradient(135deg,rgba(28,12,12,0.95),rgba(10,10,8,0.92))] p-5 shadow-[0_18px_60px_rgba(0,0,0,0.4)]">
      <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-[#ff0037]/12 text-[#ff0037]">
              <Layers3 size={16} strokeWidth={2.2} />
            </span>
            <div className="min-w-0">
              <h3 className="text-[11px] font-black uppercase tracking-[0.24em] text-[#ff0037]">
                {title}
              </h3>
              <p className="mt-1 text-[10px] font-medium text-stone-400">
                {caption}
              </p>
            </div>
          </div>
        </div>
        <div className="shrink-0 rounded-md bg-[#ff0037]/10 px-3 py-2 text-[9px] font-black uppercase tracking-[0.24em] text-[#ff9aa9]">
          {items.length} active nodes
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((item) => (
          <div
            key={item.id}
            className={`rounded-md border border-white/8 bg-gradient-to-br ${severityToneMap[item.severity]} p-4 ${glowToneMap[item.severity]}`}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="truncate text-[10px] font-black uppercase tracking-[0.22em] text-white">
                  {item.label}
                </div>
                <div className="mt-1 truncate text-[9px] uppercase tracking-[0.16em] text-white/55">
                  {item.subLabel}
                </div>
              </div>
              <span className="shrink-0 rounded-md bg-black/30 px-2 py-1 text-[8px] font-black uppercase tracking-[0.18em] text-white/80">
                {item.severity}
              </span>
            </div>

            <div className="mt-4 flex items-end justify-between gap-3">
              <div>
                <div className="text-2xl font-black leading-none text-white">
                  {item.risk}%
                </div>
                <div className="mt-1 text-[9px] uppercase tracking-[0.18em] text-white/55">
                  Risk score
                </div>
              </div>
            </div>

            <div className="mt-4 h-2 w-full overflow-hidden rounded-full bg-white/10">
              <div
                className={`h-full rounded-full ${barToneMap[item.severity]}`}
                style={{ width: `${item.risk}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default FloodRiskHeatmap;
