import React, { useMemo } from 'react';
import type { LucideIcon } from 'lucide-react';
import { isLiteMotionDevice } from '../utils/performance';
import { ConsolePanel, StatusBadge } from './OpsPrimitives';

interface PageShellProps {
  children: React.ReactNode;
  className?: string;
}

interface PageHeroProps {
  eyebrow: string;
  title: string;
  subtitle: string;
  icon: LucideIcon;
  action?: React.ReactNode;
  centered?: boolean;
}

interface PageCardProps {
  children: React.ReactNode;
  className?: string;
  padded?: boolean;
}

export const PageShell: React.FC<PageShellProps> = ({ children, className = '' }) => (
  <div className={`mx-auto w-full max-w-[1400px] space-y-6 pb-24 ${className}`}>
    {children}
  </div>
);

export const PageHero: React.FC<PageHeroProps> = ({
  eyebrow,
  title,
  subtitle,
  icon: Icon,
  action,
  centered = false,
}) => {
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);

  return (
    <ConsolePanel
      intensity="primary"
      frameTone="olive"
      elevated
      className={`${liteMotion ? '' : 'relative overflow-hidden'} ${centered ? 'text-center' : ''}`}
    >
      {!liteMotion ? (
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(176,168,120,0.22),transparent_36%),radial-gradient(circle_at_bottom_left,rgba(91,164,199,0.08),transparent_22%)]" />
      ) : null}
      <div className="relative z-10 flex flex-col gap-5">
        <div className={`flex gap-4 ${centered ? 'flex-col items-center' : 'flex-col sm:flex-row sm:items-start sm:justify-between'}`}>
          <div className={`flex gap-4 ${centered ? 'flex-col items-center text-center' : 'items-start'}`}>
            <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-[linear-gradient(135deg,rgba(109,122,66,0.7),rgba(44,52,35,0.92))] shadow-[inset_0_1px_0_rgba(255,255,255,0.14),0_14px_34px_rgba(0,0,0,0.3)]">
              <Icon size={24} className="text-[color:var(--ops-text)]" />
            </div>
            <div className={`space-y-2 ${centered ? 'text-center' : ''}`}>
              <StatusBadge tone="neutral" className="!rounded-lg !px-2.5 !py-1 !text-[9px]">
                {eyebrow}
              </StatusBadge>
              <h1 className="ops-red-header font-cinzel text-[2.1rem] font-semibold uppercase tracking-[0.08em] sm:text-[2.7rem]">
                {title}
              </h1>
              <p className="max-w-3xl text-sm leading-relaxed text-[color:var(--ops-text-soft)] sm:text-[15px]">
                {subtitle}
              </p>
            </div>
          </div>
          {action ? (
            <div className="flex w-full flex-wrap items-center justify-center gap-3 sm:gap-4">
              {action}
            </div>
          ) : null}
        </div>
      </div>
    </ConsolePanel>
  );
};

export const PageCard: React.FC<PageCardProps> = ({ children, className = '', padded = true }) => {
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);

  return (
    <ConsolePanel
      intensity={liteMotion ? 'secondary' : 'primary'}
      frameTone="neutral"
      elevated={!liteMotion}
      padded={padded}
      className={className}
    >
      {children}
    </ConsolePanel>
  );
};
