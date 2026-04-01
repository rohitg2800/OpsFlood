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
    <div className="min-h-screen tech-grid text-stone-100 font-sans pb-20 antialiased selection:bg-[#c4b68d]/30">
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
      
      {/* PRE-HEADER STATUS BAR */}
      <div className="bg-gradient-to-r from-[#293226] via-[#3d4935] to-[#556446] py-1 text-center text-[9px] font-black uppercase tracking-[0.4em] text-[#e5ddc9] shadow-[0_10px_24px_rgba(0,0,0,0.18)]">
        Restricted Access // Tactical Operations Console // Encrypted Channel
      </div>

      {/* NAVIGATION */}
      <Navigation apiStatus={apiStatus} />

      {/* MAIN CONTENT */}
      <main className="mx-auto w-full px-6 mt-12">
        <Suspense
          fallback={
            <div className="mx-auto flex min-h-[55vh] max-w-7xl items-center justify-center px-6">
              <div className="rounded-md border border-[#ff0037]/30 bg-black/45 px-8 py-6 text-center shadow-[0_14px_40px_rgba(0,0,0,0.35)]">
                <div className="text-[10px] font-black uppercase tracking-[0.32em] text-[#ff9aaa]">Loading Command Surface</div>
                <div className="mt-3 text-sm font-mono uppercase tracking-[0.18em] text-stone-400">Hydrology modules syncing...</div>
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
      <footer className="fixed bottom-0 left-0 right-0 z-40 hidden bg-[#101711]/88 p-4 text-white shadow-[0_-18px_40px_rgba(0,0,0,0.3)] backdrop-blur-xl md:block">
         <div className="max-w-7xl mx-auto flex justify-between items-center text-[9px] font-black uppercase tracking-[0.3em] text-[#8f997d]">
            <div className="flex gap-10">
               <span className="flex items-center gap-2 text-[#94a078]"><Radio size={12} className="animate-pulse"/> Irwin Bridge: 8.2m (Stable)</span>
               <span className="flex items-center gap-2"><Radio size={12} className="text-[#c09a58]"/> Shirol Sector: 11.4m (Rising)</span>
               <span className="flex items-center gap-2"><Radio size={12} className="text-[#69735c]"/> Kagal Array: Online</span>
            </div>
            <div className="flex items-center gap-2 text-[#aab296]">
               Theater Engine v4.2 // Regional Flood Readiness <ChevronRight size={12}/>
            </div>
         </div>
      </footer>
    </div>
  );
}

export default App;
