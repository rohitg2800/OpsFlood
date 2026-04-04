import React from 'react';
import { Layers3 } from 'lucide-react';
import { ConsolePanel, InsetPanel, SectionHeader, StatusBadge, opsLabelClass } from './OpsPrimitives';

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

const severityToneMap: Record<HeatmapSeverity, 'success' | 'info' | 'warning' | 'danger'> = {
  LOW: 'success',
  MODERATE: 'info',
  SEVERE: 'warning',
  CRITICAL: 'danger',
};

const barToneMap: Record<HeatmapSeverity, string> = {
  LOW: 'bg-[linear-gradient(90deg,#2c9e77,#61d0a4)]',
  MODERATE: 'bg-[linear-gradient(90deg,#4c7cff,#79a5ff)]',
  SEVERE: 'bg-[linear-gradient(90deg,#d97706,#fbbf24)]',
  CRITICAL: 'bg-[linear-gradient(90deg,#c93a56,#f47a8f)]',
};

export const FloodRiskHeatmap: React.FC<FloodRiskHeatmapProps> = ({
  data,
  title = 'State risk heatmap',
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
    <ConsolePanel>
      <SectionHeader
        eyebrow="Heatmap"
        title={title}
        description={caption}
        icon={Layers3}
        action={<StatusBadge tone="neutral">{items.length} active nodes</StatusBadge>}
        className="mb-6"
      />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((item) => (
          <InsetPanel key={item.id} className="space-y-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="truncate text-base font-semibold text-[color:var(--ops-text)]">
                  {item.label}
                </div>
                <div className="mt-1 truncate text-sm text-[color:var(--ops-text-soft)]">
                  {item.subLabel}
                </div>
              </div>
              <StatusBadge tone={severityToneMap[item.severity]}>
                {item.severity}
              </StatusBadge>
            </div>

            <div className="flex items-end justify-between gap-3">
              <div>
                <div className={opsLabelClass}>Risk score</div>
                <div className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-[color:var(--ops-text)]">
                  {item.risk}%
                </div>
              </div>
            </div>

            <div className="h-2.5 w-full overflow-hidden rounded-full bg-black/25">
              <div
                className={`h-full rounded-full ${barToneMap[item.severity]}`}
                style={{ width: `${Math.max(item.risk, 4)}%` }}
              />
            </div>
          </InsetPanel>
        ))}
      </div>
    </ConsolePanel>
  );
};

export default FloodRiskHeatmap;
