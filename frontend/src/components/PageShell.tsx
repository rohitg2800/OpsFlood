import React, { useMemo } from 'react';
import type { LucideIcon } from 'lucide-react';
import { isLiteMotionDevice } from '../utils/performance';

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
  <div className={`mx-auto w-full max-w-7xl space-y-8 pb-20 ${className}`}>
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
    <div className={`flex flex-col gap-5 rounded-lg border border-[#ff0037]/30 bg-[#151d16]/88 px-6 py-6 ${liteMotion ? 'backdrop-blur-md shadow-[0_12px_32px_rgba(0,0,0,0.22)]' : 'backdrop-blur-2xl shadow-[0_20px_60px_rgba(0,0,0,0.35)]'} sm:px-8`}>
      <div className={`flex gap-3 ${centered ? 'flex-col items-center text-center' : 'items-center'}`}>
        <div className={`flex h-12 w-12 items-center justify-center rounded-md border border-[#ff0037]/35 bg-gradient-to-br from-[#2f171b] via-[#571a26] to-[#9c2438] ${liteMotion ? 'shadow-[0_8px_18px_rgba(255,0,55,0.1)]' : 'shadow-[0_12px_30px_rgba(255,0,55,0.16)]'}`}>
          <Icon size={22} className="text-white" />
        </div>
        <div className={`space-y-1 ${centered ? 'text-center' : ''}`}>
          <div className="text-[10px] font-black uppercase tracking-[0.38em] text-[#87907a]">
            {eyebrow}
          </div>
          <h1 className="text-2xl font-black tracking-tight text-[#ece4ce] font-cinzel sm:text-3xl">
            {title}
          </h1>
          <p className="text-sm font-medium text-[#a3aa94]">
            {subtitle}
          </p>
        </div>
      </div>
      {action ? (
        <div className={`flex flex-col gap-3 ${centered ? 'items-center' : 'sm:flex-row sm:items-center sm:justify-between'}`}>
          {!centered ? <div className="hidden sm:block" /> : null}
          <div className={`flex flex-wrap gap-3 ${centered ? 'justify-center' : ''}`}>
            {action}
          </div>
        </div>
      ) : null}
    </div>
  );
};

export const PageCard: React.FC<PageCardProps> = ({ children, className = '', padded = true }) => {
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);

  return (
    <div
      className={`overflow-hidden rounded-lg border border-[#ff0037]/28 bg-[#121812]/90 ${liteMotion ? 'backdrop-blur-md shadow-[0_14px_36px_rgba(0,0,0,0.24)]' : 'backdrop-blur-3xl shadow-[0_24px_80px_rgba(0,0,0,0.45)]'} ${padded ? 'p-8 sm:p-10' : ''} ${className}`}
    >
      {children}
    </div>
  );
};
