import React from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { Activity, MapIcon, Radio, Database, ShieldCheck, AlertTriangle, Server, Waves } from 'lucide-react';
import clsx from 'clsx';
import { useAppState } from '../context/AppContext';
import { StatusBadge } from './OpsPrimitives';

interface NavigationProps {
  apiStatus: 'ONLINE' | 'DEGRADED' | 'OFFLINE' | 'INITIALIZING';
}

export const Navigation: React.FC<NavigationProps> = ({ apiStatus }) => {
  const { state } = useAppState();
  const location = useLocation();
  const apiDotColor =
    apiStatus === 'ONLINE' ? 'bg-emerald-500' :
    apiStatus === 'DEGRADED' ? 'bg-amber-500' :
    apiStatus === 'OFFLINE' ? 'bg-red-500' :
    'bg-slate-500';

  const apiValueTone =
    apiStatus === 'ONLINE' ? 'text-emerald-100' :
    apiStatus === 'DEGRADED' ? 'text-amber-100' :
    apiStatus === 'OFFLINE' ? 'text-rose-100' :
    'text-slate-200';
  const apiTone =
    apiStatus === 'ONLINE' ? 'success' :
    apiStatus === 'DEGRADED' ? 'warning' :
    apiStatus === 'OFFLINE' ? 'danger' :
    'neutral';
  const sourcePolicy = state.system.sourcePolicy;

  const navItems = [
    { id: 'dash', label: 'Dashboard', icon: Activity, path: '/' },
    { id: 'geo', label: 'Geo-Spatial', icon: MapIcon, path: '/geo' },
    { id: 'telemetry', label: 'Telemetry', icon: Radio, path: '/telemetry' },
    { id: 'archives', label: 'Archives', icon: Database, path: '/archives' },
  ];
  const currentSeverity = state.prediction.currentPrediction?.severity || 'LOW';
  const severityTone =
    currentSeverity === 'CRITICAL' ? 'danger' :
    currentSeverity === 'SEVERE' ? 'warning' :
    currentSeverity === 'MODERATE' ? 'info' :
    'success';
  const routeLabel = navItems.find((item) => item.path === location.pathname)?.label || 'Dashboard';

  return (
    <>
      <header className="sticky top-0 z-50 px-3 pt-3 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-[1400px] rounded-[1.35rem] ops-frame frame-olive bg-[rgba(12,17,24,0.93)] px-4 py-4 shadow-[0_26px_88px_rgba(0,0,0,0.46)] backdrop-blur-xl sm:px-5">
          <div className="flex flex-col items-center gap-4 xl:flex-row xl:items-center xl:justify-between">
            <div className="min-w-0">
              <div className="flex items-center justify-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[linear-gradient(135deg,rgba(108,122,65,0.34),rgba(41,53,34,0.76))] shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_10px_24px_rgba(0,0,0,0.3)]">
                  <Waves size={18} className="text-[color:var(--ops-text)]" />
                </div>
                <div className="min-w-0">
                  <div className="font-cinzel text-xl font-semibold uppercase tracking-[0.16em] text-[color:var(--ops-text)]">
                    INDIA_FLOODS OPS
                  </div>
                  <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-[color:var(--ops-text-faint)]">
                    Flood Operations Command Console
                  </div>
                </div>
              </div>
            </div>

            <div className="hidden w-full items-center justify-center gap-3 lg:flex xl:w-auto xl:justify-end xl:gap-4">
              <StatusBadge tone={apiTone} icon={Server}>
                <span className="inline-flex items-center gap-2">
                  <span className={clsx('h-1.5 w-1.5 rounded-full', apiDotColor)} />
                  API {apiStatus}
                </span>
              </StatusBadge>
              <StatusBadge tone="neutral">{sourcePolicy.label || `Policy ${sourcePolicy.mode}`}</StatusBadge>
              <StatusBadge tone={severityTone} icon={currentSeverity === 'LOW' ? ShieldCheck : AlertTriangle}>
                Severity {currentSeverity}
              </StatusBadge>
              <div className="rounded-xl bg-[rgba(10,14,19,0.58)] px-3 py-2 text-right shadow-[inset_0_1px_0_rgba(255,255,255,0.06)]">
                <div className="text-[9px] font-black uppercase tracking-[0.2em] text-[color:var(--ops-text-faint)]">
                  Workspace
                </div>
                <div className="text-sm font-semibold text-[color:var(--ops-text)]">{routeLabel}</div>
              </div>
            </div>
          </div>

          <nav className="mt-5 hidden grid-cols-4 gap-3 rounded-xl bg-[rgba(9,13,18,0.48)] p-2.5 lg:grid">
            {navItems.map((item) => (
              <NavLink
                key={item.id}
                to={item.path}
                className={({ isActive }) =>
                  clsx(
                    'relative flex min-h-[3.35rem] items-center justify-center gap-2.5 rounded-lg px-5 py-2.5 text-[11px] font-black uppercase tracking-[0.16em] transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--ops-border-accent)]',
                    isActive
                      ? 'bg-[linear-gradient(140deg,rgba(109,122,66,0.78),rgba(57,67,42,0.88))] text-[color:var(--ops-text)] shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_12px_22px_rgba(0,0,0,0.34)]'
                      : 'text-[color:var(--ops-text-soft)] hover:bg-[rgba(255,255,255,0.06)] hover:text-[color:var(--ops-text)]',
                  )
                }
              >
                <item.icon size={13} />
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div className="mt-4 flex items-center justify-center gap-3 overflow-x-auto lg:hidden">
            <StatusBadge tone={apiTone} icon={Server} className="whitespace-nowrap">
              <span className={apiValueTone}>API {apiStatus}</span>
            </StatusBadge>
            <StatusBadge tone="neutral" className="whitespace-nowrap">
              {sourcePolicy.label || `Policy ${sourcePolicy.mode}`}
            </StatusBadge>
            <StatusBadge tone={severityTone} className="whitespace-nowrap">
              Current {currentSeverity}
            </StatusBadge>
          </div>
        </div>
      </header>

      <nav className="fixed inset-x-3 bottom-3 z-50 rounded-[1.35rem] ops-frame frame-neutral border-0 bg-[rgba(12,17,24,0.96)] px-2.5 pt-2.5 pb-[calc(env(safe-area-inset-bottom)+10px)] shadow-[0_26px_80px_rgba(0,0,0,0.42)] backdrop-blur-xl lg:hidden">
        <div className="grid grid-cols-4 gap-3">
          {navItems.map((item) => (
            <NavLink
              key={item.id}
              to={item.path}
              className={({ isActive }) =>
                clsx(
                  'flex min-h-[3.95rem] flex-col items-center justify-center gap-1.5 rounded-xl px-2.5 py-2.5 text-center transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--ops-border-accent)] focus-visible:ring-offset-0',
                  isActive
                    ? 'bg-[linear-gradient(135deg,rgba(109,122,66,0.78),rgba(57,67,42,0.88))] text-[color:var(--ops-text)]'
                    : 'text-[color:var(--ops-text-faint)] hover:bg-[color:var(--ops-surface-2)] hover:text-[color:var(--ops-text)]',
                )
              }
            >
              {({ isActive }) => (
                <>
                  <item.icon size={18} className={isActive ? 'text-[#dfe5c8]' : 'text-[color:var(--ops-text-faint)]'} />
                  <span className="text-[11px] font-black uppercase tracking-[0.14em]">
                    {item.label}
                  </span>
                </>
              )}
            </NavLink>
          ))}
        </div>
      </nav>
    </>
  );
};
