import React from 'react';
import { NavLink } from 'react-router-dom';
import { Activity, MapIcon, Radio, Database } from 'lucide-react';

interface NavigationProps {
  apiStatus: 'ONLINE' | 'DEGRADED' | 'OFFLINE' | 'INITIALIZING';
}

export const Navigation: React.FC<NavigationProps> = ({ apiStatus }) => {
  const apiDotColor =
    apiStatus === 'ONLINE' ? 'bg-emerald-500' :
    apiStatus === 'DEGRADED' ? 'bg-amber-500' :
    apiStatus === 'OFFLINE' ? 'bg-red-500' :
    'bg-slate-500';

  const apiValueTone =
    apiStatus === 'ONLINE' ? 'text-[#fff2f4]' :
    apiStatus === 'DEGRADED' ? 'text-[#ffd3a1]' :
    apiStatus === 'OFFLINE' ? 'text-[#ff8ea0]' :
    'text-[#d7c1c7]';

  const navItems = [
    { id: 'dash', label: 'Dashboard', icon: Activity, path: '/' },
    { id: 'geo', label: 'Geo-Spatial', icon: MapIcon, path: '/geo' },
    { id: 'telemetry', label: 'Telemetry', icon: Radio, path: '/telemetry' },
    { id: 'archives', label: 'Archives', icon: Database, path: '/archives' },
  ];

  return (
    <header className="sticky top-0 z-50 bg-[#101711]/82 p-6 shadow-[0_18px_40px_rgba(0,0,0,0.28)] backdrop-blur-md">
      <div className="mx-auto flex max-w-7xl flex-col items-center gap-5">
        {/* Logo */}
        <div className="flex items-center justify-center text-center">
          <div>
            <h1 className="font-cinzel text-[2.15rem] font-black uppercase tracking-[0.08em] text-[#ff6b7d] drop-shadow-[0_0_16px_rgba(255,63,91,0.45)] sm:text-[2.75rem]">
              INDIA_FLOODS <span className="text-[#ffd7dd] drop-shadow-[0_0_20px_rgba(255,151,167,0.28)]">OPS</span>
            </h1>
            <p className="mt-1 text-[10px] font-bold uppercase tracking-[0.45em] text-[#ff9aaa] sm:text-[11px]">
              Flood Readiness Command
            </p>
          </div>
        </div>

        <div className="flex w-full flex-col items-center gap-4">
          {/* Navigation Buttons */}
          <nav className="hidden rounded-full bg-[#1a2219]/90 p-1.5 shadow-[0_12px_40px_rgba(0,0,0,0.25)] lg:flex">
            {navItems.map((item) => (
              <NavLink
                key={item.id}
                to={item.path}
                className={({ isActive }) =>
                  `px-6 py-2 rounded-full text-[10px] font-black uppercase transition-all flex items-center gap-2 ${
                    isActive
                      ? 'bg-gradient-to-r from-[#6b1a26] via-[#a32136] to-[#ff6b7d] text-[#fff1f4] shadow-lg shadow-[#ff5e78]/20'
                      : 'text-[#d6a4ad] hover:text-[#fff0f3] hover:bg-[#2a3228]'
                  }`
                }
              >
                <item.icon size={12} />
                {item.label}
              </NavLink>
            ))}
          </nav>

          {/* API Status */}
          <div className="flex items-center gap-6">
            <div className="flex flex-col items-center">
              <div className="inline-flex items-center gap-3 rounded-md border border-[#ff0037]/35 bg-gradient-to-r from-[#321015]/90 via-[#4e1520]/85 to-[#6b1a26]/80 px-5 py-2.5 shadow-[0_12px_30px_rgba(255,0,55,0.12)]">
                <span className="text-[9px] font-black uppercase tracking-[0.32em] text-[#ff9aaa]">API Status</span>
                <span className={`inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.2em] ${apiValueTone}`}>
                  <div className={`h-1.5 w-1.5 rounded-full ${apiDotColor} animate-pulse`}></div>
                  {apiStatus}
                </span>
              </div>
              <span className="text-[10px] font-bold text-[#b88992]">Command Build 4.2</span>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Navigation */}
      <div className="lg:hidden mt-4">
        <div className="flex justify-center gap-2">
          {navItems.map((item) => (
            <NavLink
              key={item.id}
              to={item.path}
              className={({ isActive }) =>
                `flex-1 flex flex-col items-center justify-center gap-1 rounded-2xl py-2 transition-all ${
                  isActive
                    ? 'bg-gradient-to-r from-[#6b1a26] via-[#a32136] to-[#ff6b7d] text-[#fff1f4] shadow-[0_14px_40px_rgba(255,94,120,0.18)]'
                    : 'bg-[#1a2219]/90 text-[#f0bcc6] hover:bg-[#2b171c] hover:text-[#fff0f3]'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <item.icon size={16} className={isActive ? 'text-[#fff1f4]' : 'text-[#ff8ea0]'} />
                  <span className="text-[9px] font-black uppercase tracking-[0.2em]">{item.label}</span>
                </>
              )}
            </NavLink>
          ))}
        </div>
      </div>
    </header>
  );
};
