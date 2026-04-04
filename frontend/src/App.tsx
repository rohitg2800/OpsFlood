import React, { Suspense, lazy, useEffect } from 'react';
import { Routes, Route, useLocation } from 'react-router-dom';
import { Radio, ChevronRight } from 'lucide-react';
import { useAppState } from './context/AppContext';
import { Navigation } from './components/Navigation';
import { AnimatedBackground } from './components/AnimatedBackground';
import { WaterWaveBackground } from './components/WaterWaveBackground';
import './index.css'; // Import global styles

const DashboardPage = lazy(() => import('./pages/DashboardPage').then((module) => ({ default: module.DashboardPage })));
const GeoSpatialPage = lazy(() => import('./pages/GeoSpatialPage').then((module) => ({ default: module.GeoSpatialPage })));
const TelemetryPage = lazy(() => import('./pages/TelemetryPage').then((module) => ({ default: module.TelemetryPage })));
const ArchivesPage = lazy(() => import('./pages/ArchivesPage').then((module) => ({ default: module.ArchivesPage })));

// ==========================================
// MAIN APPLICATION
// ==========================================

function App() {
  // Use centralized state management
  const { state } = useAppState();
  const location = useLocation();
  const apiStatus = state.system.apiStatus;
  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  const backgroundRainIntensity = severity === 'CRITICAL' ? 36 : severity === 'SEVERE' ? 24 : 12;
  const backgroundWaveHeight = severity === 'CRITICAL' ? 42 : severity === 'SEVERE' ? 30 : 18;

  useEffect(() => {
    document.title = 'INDIA_FLOODS OPS';
  }, [location.pathname]);

  return (
    <div className="min-h-screen tech-grid pb-28 font-sans text-stone-100 antialiased selection:bg-[#c4b68d]/30 lg:pb-16">
      {/* ANIMATED BACKGROUND */}
      <AnimatedBackground 
        severity={severity}
        rainIntensity={backgroundRainIntensity}
        showLightning={severity === 'CRITICAL'}
      />
      <WaterWaveBackground 
        severity={severity}
        waveHeight={backgroundWaveHeight}
      />

      {/* NAVIGATION */}
      <Navigation apiStatus={apiStatus} />

      {/* MAIN CONTENT */}
      <main className="mx-auto w-full px-4 pt-6 sm:px-6 lg:px-8">
        <Suspense
          fallback={
            <div className="mx-auto flex min-h-[55vh] max-w-[1400px] items-center justify-center px-4 sm:px-6">
              <div className="rounded-[1.35rem] border border-[color:var(--ops-border)] bg-[color:var(--ops-surface-1)] px-8 py-7 text-center shadow-[0_20px_60px_rgba(0,0,0,0.3)]">
                <div className="text-[10px] font-black uppercase tracking-[0.28em] text-[color:var(--ops-danger-soft)]">
                  Loading command surface
                </div>
                <div className="mt-3 text-sm font-mono uppercase tracking-[0.16em] text-[color:var(--ops-text-soft)]">
                  Hydrology modules syncing...
                </div>
              </div>
            </div>
          }
        >
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/geo" element={<GeoSpatialPage />} />
            <Route path="/telemetry" element={<TelemetryPage />} />
            <Route path="/archives" element={<ArchivesPage />} />
          </Routes>
        </Suspense>
      </main>

      {/* TACTICAL FOOTER */}
      <footer className="fixed bottom-0 left-0 right-0 z-40 hidden border-t border-[color:var(--ops-border)] bg-[rgba(10,15,22,0.78)] px-4 py-3 text-white shadow-[0_-18px_48px_rgba(0,0,0,0.2)] backdrop-blur-xl lg:block">
         <div className="mx-auto flex max-w-[1400px] items-center justify-between text-[10px] font-semibold text-[color:var(--ops-text-soft)]">
            <div className="flex items-center gap-6">
               <span className="inline-flex items-center gap-2"><Radio size={12} className="animate-pulse text-[color:var(--ops-info)]"/> Irwin Bridge stable</span>
               <span className="inline-flex items-center gap-2"><Radio size={12} className="text-[color:var(--ops-warning)]"/> Shirol rising</span>
               <span className="inline-flex items-center gap-2"><Radio size={12} className="text-[color:var(--ops-success)]"/> Kagal network online</span>
            </div>
            <div className="flex items-center gap-2 text-[color:var(--ops-text-dim)]">
               Theatre engine v4.2 <ChevronRight size={12}/> Regional flood readiness
            </div>
         </div>
      </footer>
    </div>
  );
}

export default App;
