import React from 'react';
import clsx from 'clsx';
import type { LucideIcon } from 'lucide-react';

export type FrameTone = 'olive' | 'cyan' | 'amber' | 'danger' | 'neutral';
export type SurfaceIntensity = 'primary' | 'secondary' | 'tertiary';

const frameToneClass: Record<FrameTone, string> = {
  olive: 'frame-olive',
  cyan: 'frame-cyan',
  amber: 'frame-amber',
  danger: 'frame-danger',
  neutral: 'frame-neutral',
};

const opsSurfacePrimaryClass =
  'ops-frame rounded-[1.25rem] bg-[color:var(--ops-panel)] shadow-[0_22px_70px_rgba(0,0,0,0.38)] backdrop-blur-xl';

const opsElevatedSurfacePrimaryClass =
  'ops-frame rounded-[1.35rem] bg-[linear-gradient(180deg,rgba(16,22,28,0.96),rgba(16,22,28,0.88))] shadow-[0_26px_90px_rgba(0,0,0,0.48)] backdrop-blur-2xl';

const opsSurfaceSecondaryClass =
  'rounded-[1.15rem] bg-[color:var(--ops-surface-1)] shadow-[inset_0_1px_0_rgba(255,255,255,0.05),0_16px_42px_rgba(0,0,0,0.3)] backdrop-blur-xl';

const opsElevatedSurfaceSecondaryClass =
  'rounded-[1.2rem] bg-[linear-gradient(180deg,rgba(26,34,42,0.86),rgba(20,27,34,0.92))] shadow-[inset_0_1px_0_rgba(255,255,255,0.06),0_20px_56px_rgba(0,0,0,0.35)] backdrop-blur-2xl';

const opsSurfaceTertiaryClass =
  'rounded-[1rem] bg-[rgba(18,24,30,0.72)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]';

export const opsSurfaceClass = opsSurfacePrimaryClass;
export const opsElevatedSurfaceClass = opsElevatedSurfacePrimaryClass;

export const opsInsetClass =
  'rounded-[0.95rem] border border-[color:var(--ops-border)] bg-[color:var(--ops-surface-2)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]';

export const opsInsetQuietClass =
  'rounded-[0.95rem] bg-[rgba(14,20,25,0.56)] shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]';

export const opsLabelClass =
  'text-[10px] font-black uppercase tracking-[0.24em] text-[color:var(--ops-text-dim)]';

export const opsFieldClass =
  'w-full rounded-xl border border-[color:var(--ops-border)] bg-[color:var(--ops-surface-2)] px-4 py-3 text-sm font-semibold text-[color:var(--ops-text)] shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] outline-none transition-all placeholder:text-[color:var(--ops-text-faint)] focus:border-[color:var(--ops-border-accent)] focus:bg-[rgba(255,255,255,0.06)] focus:ring-4 focus:ring-[rgba(90,143,255,0.16)]';

export const opsMonoFieldClass =
  `${opsFieldClass} font-mono text-xs font-bold`;

type Tone = 'neutral' | 'info' | 'success' | 'warning' | 'danger';

const toneClasses: Record<Tone, string> = {
  neutral: 'border border-[color:var(--ops-border)] bg-[rgba(255,255,255,0.03)] text-[color:var(--ops-text-soft)]',
  info: 'border border-[color:var(--frame-accent-cyan)] bg-[rgba(91,164,199,0.14)] text-[color:var(--ops-text)]',
  success: 'border border-[rgba(111,141,102,0.8)] bg-[rgba(111,141,102,0.16)] text-[color:var(--ops-text)]',
  warning: 'border border-[color:var(--frame-accent-amber)] bg-[rgba(196,138,58,0.16)] text-[color:var(--ops-text)]',
  danger: 'border border-[color:var(--frame-accent-danger)] bg-[rgba(199,74,74,0.2)] text-[color:var(--ops-text)]',
};

const buttonClasses = {
  primary:
    'border border-[color:var(--frame-accent-olive)] bg-[linear-gradient(135deg,#6d7a42,#4d5635)] text-[color:var(--ops-text)] shadow-[0_18px_42px_rgba(0,0,0,0.34)] hover:brightness-110',
  secondary:
    'border border-[color:var(--ops-border-strong)] bg-[color:var(--ops-surface-2)] text-[color:var(--ops-text)] hover:border-[color:var(--frame-accent-olive)] hover:bg-[rgba(255,255,255,0.06)]',
  ghost:
    'border border-transparent bg-transparent text-[color:var(--ops-text-soft)] hover:border-[color:var(--ops-border)] hover:bg-[color:var(--ops-surface-2)] hover:text-[color:var(--ops-text)]',
};

export const getToneClass = (tone: Tone) => toneClasses[tone];

interface ConsolePanelProps {
  children: React.ReactNode;
  className?: string;
  padded?: boolean;
  elevated?: boolean;
  frameTone?: FrameTone;
  intensity?: SurfaceIntensity;
}

export function ConsolePanel({
  children,
  className,
  padded = true,
  elevated = false,
  frameTone = 'olive',
  intensity = 'secondary',
}: ConsolePanelProps) {
  const panelClass =
    intensity === 'primary'
      ? elevated
        ? opsElevatedSurfacePrimaryClass
        : opsSurfacePrimaryClass
      : intensity === 'tertiary'
      ? opsSurfaceTertiaryClass
      : elevated
      ? opsElevatedSurfaceSecondaryClass
      : opsSurfaceSecondaryClass;

  return (
    <section
      className={clsx(
        panelClass,
        intensity === 'primary' ? frameToneClass[frameTone] : '',
        padded ? 'p-5 sm:p-6 lg:p-7' : '',
        className,
      )}
    >
      {children}
    </section>
  );
}

interface InsetPanelProps {
  children: React.ReactNode;
  className?: string;
  frameTone?: FrameTone;
  variant?: 'quiet' | 'soft' | 'framed';
}

export function InsetPanel({
  children,
  className,
  frameTone = 'neutral',
  variant = 'quiet',
}: InsetPanelProps) {
  const insetClass =
    variant === 'framed'
      ? [opsInsetClass, 'ops-frame', frameToneClass[frameTone]]
      : variant === 'soft'
      ? opsInsetClass
      : opsInsetQuietClass;

  return (
    <div
      className={clsx(
        insetClass,
        'p-5 sm:p-5',
        className,
      )}
    >
      {children}
    </div>
  );
}

interface StatusBadgeProps {
  children: React.ReactNode;
  tone?: Tone;
  icon?: LucideIcon;
  className?: string;
}

export function StatusBadge({
  children,
  tone = 'neutral',
  icon: Icon,
  className,
}: StatusBadgeProps) {
  return (
    <span
      className={clsx(
        'inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-[10px] font-black uppercase tracking-[0.18em]',
        toneClasses[tone],
        className,
      )}
    >
      {Icon ? <Icon size={12} className="shrink-0" /> : null}
      {children}
    </span>
  );
}

interface ActionButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost';
  icon?: LucideIcon;
}

export function ActionButton({
  children,
  className,
  variant = 'secondary',
  icon: Icon,
  type = 'button',
  ...props
}: ActionButtonProps) {
  return (
    <button
      type={type}
      className={clsx(
        'inline-flex min-h-[2.85rem] items-center justify-center gap-2.5 rounded-xl px-5 py-3 text-[11px] font-black uppercase tracking-[0.2em] transition-all disabled:cursor-not-allowed disabled:opacity-45',
        buttonClasses[variant],
        className,
      )}
      {...props}
    >
      {Icon ? <Icon size={14} className="shrink-0" /> : null}
      {children}
    </button>
  );
}

interface SectionHeaderProps {
  eyebrow?: string;
  title: string;
  description?: React.ReactNode;
  icon?: LucideIcon;
  action?: React.ReactNode;
  className?: string;
  align?: 'start' | 'center';
}

export function SectionHeader({
  eyebrow,
  title,
  description,
  icon: Icon,
  action,
  className,
  align = 'start',
}: SectionHeaderProps) {
  return (
    <div
      className={clsx(
        'flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between',
        align === 'center' ? 'text-center sm:text-left' : '',
        className,
      )}
    >
      <div className="min-w-0 space-y-2">
        {eyebrow ? <div className={opsLabelClass}>{eyebrow}</div> : null}
        <div className="flex items-start gap-3">
          {Icon ? (
            <span className="mt-0.5 inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/[0.05] text-[color:var(--ops-text)]">
              <Icon size={18} />
            </span>
          ) : null}
          <div className="min-w-0 space-y-1">
            <h3 className="ops-red-header text-lg font-semibold tracking-[-0.02em]">
              {title}
            </h3>
            {description ? (
              <div className="max-w-3xl text-sm leading-relaxed text-[color:var(--ops-text-soft)]">
                {description}
              </div>
            ) : null}
          </div>
        </div>
      </div>
      {action ? <div className="flex shrink-0 flex-wrap items-center justify-center gap-3 sm:gap-4">{action}</div> : null}
    </div>
  );
}

interface MetricTileProps {
  label: string;
  value: React.ReactNode;
  hint?: React.ReactNode;
  icon?: LucideIcon;
  tone?: Tone;
  className?: string;
  framed?: boolean;
  frameTone?: FrameTone;
  mono?: boolean;
}

export function MetricTile({
  label,
  value,
  hint,
  icon: Icon,
  tone = 'neutral',
  className,
  framed = false,
  frameTone = 'neutral',
  mono = true,
}: MetricTileProps) {
  return (
    <div
      className={clsx(
        framed ? [opsInsetClass, 'ops-frame', frameToneClass[frameTone]] : opsInsetQuietClass,
        'flex h-full flex-col p-4 sm:p-5',
        className,
      )}
    >
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 flex-col justify-center space-y-1">
          <div className={opsLabelClass}>{label}</div>
          <div
            className={clsx(
              'text-2xl font-semibold leading-none tracking-[-0.03em] text-[color:var(--ops-text)] sm:text-3xl',
              mono ? 'font-mono tracking-[-0.02em]' : '',
            )}
          >
            {value}
          </div>
        </div>
        {Icon ? (
          <span className={clsx('inline-flex h-9 w-9 items-center justify-center rounded-xl border', toneClasses[tone])}>
            <Icon size={16} />
          </span>
        ) : null}
      </div>
      <div className="mt-auto">
        {hint ? <div className="mt-3 text-sm leading-relaxed text-[color:var(--ops-text-soft)]">{hint}</div> : null}
      </div>
    </div>
  );
}

interface EmptyStateProps {
  title: string;
  description: React.ReactNode;
  icon?: LucideIcon;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({
  title,
  description,
  icon: Icon,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div className={clsx(opsInsetQuietClass, 'flex flex-col items-start gap-4 p-5 sm:p-6', className)}>
      <div className="flex items-start gap-3">
        {Icon ? (
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.05] text-[color:var(--ops-text-soft)]">
            <Icon size={18} />
          </span>
        ) : null}
        <div className="space-y-1">
          <h4 className="text-base font-semibold text-[color:var(--ops-text)]">{title}</h4>
          <div className="text-sm leading-relaxed text-[color:var(--ops-text-soft)]">{description}</div>
        </div>
      </div>
      {action ? <div>{action}</div> : null}
    </div>
  );
}
