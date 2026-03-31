import React, { useState, useCallback, useMemo } from 'react';
import { 
  Palette, 
  Copy, 
  Download, 
  Plus, 
  Trash2, 
  RotateCcw,
  Check,
  Sliders
} from 'lucide-react';
import { PageShell, PageHero, PageCard } from '../components/PageShell';

// ==========================================
// TYPES
// ==========================================

interface ColorStop {
  id: string;
  color: string;
  position: number;
}

type GradientType = 'linear' | 'radial' | 'conic';
type RadialShape = 'circle' | 'ellipse';
type RadialPosition = 'center' | 'top' | 'bottom' | 'left' | 'right' | 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';

// ==========================================
// LUXE SUB-COMPONENTS
// ==========================================

const chipButtonClass =
  'px-4 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all whitespace-nowrap shadow-sm active:scale-95';

// ==========================================
// GRADIENT GENERATOR PAGE
// ==========================================

export const GradientGeneratorPage: React.FC = () => {
  // State (Updated defaults to match the new Luxe theme: Obsidian to Gold)
  const [gradientType, setGradientType] = useState<GradientType>('linear');
  const [angle, setAngle] = useState(135);
  const [colorStops, setColorStops] = useState<ColorStop[]>([
    { id: '1', color: '#060504', position: 0 },
    { id: '2', color: '#bc9437', position: 100 },
  ]);
  const [radialShape, setRadialShape] = useState<RadialShape>('circle');
  const [radialPosition, setRadialPosition] = useState<RadialPosition>('center');
  const [copied, setCopied] = useState(false);

  // Generate unique ID
  const generateId = () => Math.random().toString(36).substr(2, 9);

  // Add color stop
  const addColorStop = useCallback(() => {
    const newPosition = colorStops.length > 0 
      ? Math.min(100, colorStops[colorStops.length - 1].position + 20)
      : 0;
    setColorStops([
      ...colorStops,
      { id: generateId(), color: '#ffffff', position: newPosition }
    ]);
  }, [colorStops]);

  // Remove color stop
  const removeColorStop = useCallback((id: string) => {
    if (colorStops.length > 2) {
      setColorStops(colorStops.filter(stop => stop.id !== id));
    }
  }, [colorStops]);

  // Update color stop
  const updateColorStop = useCallback((id: string, field: 'color' | 'position', value: string | number) => {
    setColorStops(colorStops.map(stop => 
      stop.id === id ? { ...stop, [field]: value } : stop
    ));
  }, [colorStops]);

  // Reset to defaults
  const resetGradient = useCallback(() => {
    setGradientType('linear');
    setAngle(135);
    setColorStops([
      { id: generateId(), color: '#060504', position: 0 },
      { id: generateId(), color: '#bc9437', position: 100 },
    ]);
    setRadialShape('circle');
    setRadialPosition('center');
  }, []);

  // Get radial position CSS
  const getRadialPositionCSS = (position: RadialPosition): string => {
    const positions: Record<RadialPosition, string> = {
      'center': 'center',
      'top': 'top',
      'bottom': 'bottom',
      'left': 'left',
      'right': 'right',
      'top-left': 'top left',
      'top-right': 'top right',
      'bottom-left': 'bottom left',
      'bottom-right': 'bottom right',
    };
    return positions[position];
  };

  // Generate CSS gradient string
  const gradientCSS = useMemo(() => {
    const sortedStops = [...colorStops].sort((a, b) => a.position - b.position);
    const stopsString = sortedStops.map(stop => `${stop.color} ${stop.position}%`).join(', ');

    switch (gradientType) {
      case 'linear':
        return `linear-gradient(${angle}deg, ${stopsString})`;
      case 'radial':
        return `radial-gradient(${radialShape} at ${getRadialPositionCSS(radialPosition)}, ${stopsString})`;
      case 'conic':
        return `conic-gradient(from ${angle}deg at ${getRadialPositionCSS(radialPosition)}, ${stopsString})`;
      default:
        return `linear-gradient(${angle}deg, ${stopsString})`;
    }
  }, [gradientType, angle, colorStops, radialShape, radialPosition]);

  // Generate full CSS code
  const fullCSSCode = useMemo(() => {
    return `.tactical-gradient {
  background: ${gradientCSS};
  /* Fallback for older browsers */
  background-color: ${colorStops[0]?.color || '#060504'};
}

/* Gradient Type: ${gradientType} */
${gradientType === 'linear' ? `/* Angle: ${angle}deg */` : ''}
${gradientType === 'radial' ? `/* Shape: ${radialShape}, Position: ${radialPosition} */` : ''}
${gradientType === 'conic' ? `/* Starting Angle: ${angle}deg, Position: ${radialPosition} */` : ''}
/* Color Stops: ${colorStops.length} */
`;
  }, [gradientCSS, gradientType, angle, colorStops, radialShape, radialPosition]);

  // Copy to clipboard
  const copyToClipboard = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(fullCSSCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  }, [fullCSSCode]);

  // Download CSS file
  const downloadCSS = useCallback(() => {
    const blob = new Blob([fullCSSCode], { type: 'text/css' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'tactical-gradient.css';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, [fullCSSCode]);

  return (
    <PageShell>
      <style>{`
        .custom-range::-webkit-slider-thumb {
          appearance: none; width: 16px; height: 16px; background: #bc9437;
          border-radius: 50%; cursor: pointer; box-shadow: 0 0 10px rgba(188, 148, 55, 0.5);
        }
      `}</style>

      <PageHero
        eyebrow="Visual Style Matrix"
        title="Gradient Console"
        subtitle="Craft tactical gradients, preview output instantly, and export clean CSS from one page."
        icon={Palette}
      />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        
        {/* LEFT PANEL - CONTROLS */}
        <div className="lg:col-span-5 space-y-8">
          <PageCard className="!p-8">
            {/* Gradient Type Selector */}
            <div className="mb-10">
              <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] mb-5 flex items-center gap-3">
                <Sliders size={14} /> Matrix Topology
              </h3>
              <div className="grid grid-cols-3 gap-3">
                {(['linear', 'radial', 'conic'] as GradientType[]).map((type) => (
                  <button
                    key={type}
                    onClick={() => setGradientType(type)}
                    className={`${chipButtonClass} ${
                      gradientType === type
                        ? 'bg-[#bc9437] text-[#9c1733] border-transparent shadow-[0_10px_20px_rgba(188,148,55,0.2)]'
                        : 'bg-black/40 text-stone-400 border-white/10 hover:border-[#bc9437]/40 hover:text-white'
                    }`}
                  >
                    {type}
                  </button>
                ))}
              </div>
            </div>

            {/* Angle/Direction Control */}
            {(gradientType === 'linear' || gradientType === 'conic') && (
              <div className="mb-10 border-t border-white/5 pt-8">
                <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] mb-5">
                  {gradientType === 'linear' ? 'Vector Angle' : 'Origin Angle'}
                </h3>
                <div className="space-y-6">
                  <div className="flex items-center gap-5">
                    <input
                      type="range"
                      min="0"
                      max="360"
                      value={angle}
                      onChange={(e) => setAngle(Number(e.target.value))}
                      className="flex-1 h-1.5 bg-black/80 border border-white/10 rounded-full appearance-none cursor-pointer custom-range"
                    />
                    <div className="flex items-center gap-3 bg-black/60 border border-white/10 rounded-xl px-4 py-2 shadow-inner">
                      <input
                        type="number"
                        min="0"
                        max="360"
                        value={angle}
                        onChange={(e) => setAngle(Math.min(360, Math.max(0, Number(e.target.value))))}
                        className="w-12 bg-transparent text-white text-right text-sm font-mono font-bold focus:outline-none"
                      />
                      <span className="text-[#bc9437] text-xs font-black">DEG</span>
                    </div>
                  </div>
                  {/* Quick angle presets */}
                  <div className="flex flex-wrap gap-3">
                    {[0, 45, 90, 135, 180, 225, 270, 315].map((preset) => (
                      <button
                        key={preset}
                        onClick={() => setAngle(preset)}
                        className={`px-3 py-2 rounded-lg text-[10px] font-mono font-bold transition-all border ${
                          angle === preset
                            ? 'bg-[#bc9437]/10 text-[#bc9437] border-[#bc9437]/50'
                            : 'bg-black/40 text-stone-500 border-white/5 hover:text-white hover:border-[#bc9437]/30'
                        }`}
                      >
                        {preset}°
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Radial/Conic Position Controls */}
            {(gradientType === 'radial' || gradientType === 'conic') && (
              <div className="mb-10 border-t border-white/5 pt-8">
                <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] mb-5">
                  Focal Position
                </h3>
                <div className="grid grid-cols-3 gap-3">
                  {(['top-left', 'top', 'top-right', 'left', 'center', 'right', 'bottom-left', 'bottom', 'bottom-right'] as RadialPosition[]).map((pos) => (
                    <button
                      key={pos}
                      onClick={() => setRadialPosition(pos)}
                      className={`${chipButtonClass} ${
                        radialPosition === pos
                          ? 'bg-[#bc9437] text-[#9c1733] border-transparent shadow-[0_5px_15px_rgba(188,148,55,0.2)]'
                          : 'bg-black/40 text-stone-400 border-white/10 hover:border-[#bc9437]/40 hover:text-white'
                      }`}
                    >
                      {pos.replace('-', ' ')}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Radial Shape Selector */}
            {gradientType === 'radial' && (
              <div className="mb-10 border-t border-white/5 pt-8">
                <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] mb-5">
                  Morphology
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  {(['circle', 'ellipse'] as RadialShape[]).map((shape) => (
                    <button
                      key={shape}
                      onClick={() => setRadialShape(shape)}
                      className={`${chipButtonClass} ${
                        radialShape === shape
                          ? 'bg-[#bc9437] text-[#9c1733] border-transparent shadow-[0_5px_15px_rgba(188,148,55,0.2)]'
                          : 'bg-black/40 text-stone-400 border-white/10 hover:border-[#bc9437]/40 hover:text-white'
                      }`}
                    >
                      {shape}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </PageCard>

          {/* Color Stops */}
          <PageCard className="!p-8">
            <div className="flex items-center justify-between mb-8">
              <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] flex items-center gap-3">
                <Palette size={14} /> Color Nodes
              </h3>
              <button
                onClick={addColorStop}
                className="flex items-center gap-2 px-4 py-2 bg-[#bc9437]/10 text-[#bc9437] rounded-full text-[9px] uppercase tracking-widest font-black hover:bg-[#bc9437] hover:text-[#9c1733] transition-all border border-[#bc9437]/30"
              >
                <Plus size={12} /> Add Node
              </button>
            </div>
            
            <div className="space-y-4">
              {colorStops.map((stop, index) => (
                <div key={stop.id} className="flex items-center gap-4 p-4 bg-black/40 rounded-2xl border border-white/10 shadow-inner">
                  <div className="flex items-center gap-3">
                    <span className="text-[9px] text-[#bc9437] font-mono font-black uppercase">ND_{index + 1}</span>
                    <div className="relative w-10 h-10 rounded-xl overflow-hidden border border-white/20 shadow-md">
                      <input
                        type="color"
                        value={stop.color}
                        onChange={(e) => updateColorStop(stop.id, 'color', e.target.value)}
                        className="absolute -top-2 -left-2 w-16 h-16 cursor-pointer"
                      />
                    </div>
                  </div>
                  
                  <div className="flex-1 flex items-center gap-3">
                    <input
                      type="text"
                      value={stop.color}
                      onChange={(e) => updateColorStop(stop.id, 'color', e.target.value)}
                      className="flex-1 px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-[#bc9437]/50 uppercase"
                      placeholder="#FFFFFF"
                    />
                    <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-xl px-3 py-2">
                      <input
                        type="number"
                        min="0"
                        max="100"
                        value={stop.position}
                        onChange={(e) => updateColorStop(stop.id, 'position', Math.min(100, Math.max(0, Number(e.target.value))))}
                        className="w-10 bg-transparent text-white text-right text-xs font-mono font-bold focus:outline-none"
                      />
                      <span className="text-stone-500 text-[10px] font-black">%</span>
                    </div>
                  </div>
                  
                  {colorStops.length > 2 && (
                    <button
                      onClick={() => removeColorStop(stop.id)}
                      className="p-3 text-[#ff0037] hover:text-white hover:bg-[#ff0037] border border-transparent hover:border-[#ff0037]/50 rounded-xl transition-all"
                    >
                      <Trash2 size={14} />
                    </button>
                  )}
                </div>
              ))}
            </div>

            {/* Reset Button */}
            <button
              onClick={resetGradient}
              className="w-full mt-8 flex items-center justify-center gap-3 px-6 py-4 bg-black/40 border border-white/5 rounded-2xl text-[10px] uppercase tracking-widest font-black text-stone-500 hover:text-white hover:border-white/20 transition-all shadow-inner"
            >
              <RotateCcw size={14} /> Restore Default Parameters
            </button>
          </PageCard>
        </div>

        {/* RIGHT PANEL - PREVIEW & EXPORT */}
        <div className="lg:col-span-7 space-y-8">
          
          {/* Live Preview */}
          <PageCard className="!p-8">
            <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437] mb-6">
              Simulation Render
            </h3>
            <div 
              className="w-full h-80 rounded-3xl border border-white/10 shadow-[inset_0_0_100px_rgba(0,0,0,0.5)] transition-all duration-300 relative overflow-hidden"
            >
               <div className="absolute inset-0" style={{ background: gradientCSS }} />
               {/* Aesthetic overlays to make it look tactical */}
               <div className="absolute inset-0 bg-[url('https://api.mapbox.com/styles/v1/mapbox/dark-v10/static/')] opacity-5 mix-blend-overlay"></div>
               <div className="absolute top-4 left-4 text-[9px] font-mono text-white/50 tracking-widest">VISUAL_TEST_01</div>
            </div>
            
            {/* Mini previews (Swatches) */}
            <div className="grid grid-cols-4 gap-4 mt-6">
              {[0, 1, 2, 3].map((i) => (
                <div
                  key={i}
                  className="h-20 rounded-2xl border border-white/10 transition-all duration-300 relative overflow-hidden"
                >
                  <div className="absolute inset-0" style={{ background: gradientCSS, transform: `scale(${1 - i * 0.05})`, opacity: 1 - i * 0.15 }} />
                  <div className="absolute bottom-2 left-2 text-[8px] font-mono text-white/50">VAR_0{i+1}</div>
                </div>
              ))}
            </div>
          </PageCard>

          {/* CSS Code Output */}
          <PageCard className="!p-8">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-[#bc9437]">
                Compiled Output
              </h3>
              <div className="flex items-center gap-3">
                <button
                  onClick={copyToClipboard}
                  className={`flex items-center gap-2 px-5 py-2.5 rounded-full text-[9px] uppercase tracking-widest font-black transition-all border ${
                    copied
                      ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                      : 'bg-[#bc9437]/10 text-[#bc9437] hover:bg-[#bc9437] hover:text-[#9c1733] border-[#bc9437]/30'
                  }`}
                >
                  {copied ? <Check size={14} /> : <Copy size={14} />}
                  {copied ? 'Copied' : 'Copy Code'}
                </button>
                <button
                  onClick={downloadCSS}
                  className="flex items-center gap-2 px-5 py-2.5 bg-black/40 text-stone-300 rounded-full text-[9px] uppercase tracking-widest font-black hover:text-white hover:bg-white/10 transition-all border border-white/10"
                >
                  <Download size={14} /> Export .CSS
                </button>
              </div>
            </div>
            <pre className="bg-[#060504] rounded-2xl p-6 overflow-x-auto border border-white/5 shadow-inner">
              <code className="text-sm font-mono text-[#bc9437] whitespace-pre-wrap leading-relaxed">
                {fullCSSCode}
              </code>
            </pre>
          </PageCard>

          {/* Gradient Info */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
             <div className="bg-black/40 border border-white/5 p-5 rounded-2xl shadow-inner text-center">
                <div className="text-[9px] uppercase tracking-widest text-stone-500 font-black mb-2">Topology</div>
                <div className="text-sm font-mono text-white uppercase">{gradientType}</div>
             </div>
             {(gradientType === 'linear' || gradientType === 'conic') && (
               <div className="bg-black/40 border border-white/5 p-5 rounded-2xl shadow-inner text-center">
                  <div className="text-[9px] uppercase tracking-widest text-stone-500 font-black mb-2">Angle</div>
                  <div className="text-sm font-mono text-white uppercase">{angle}°</div>
               </div>
             )}
             {gradientType === 'radial' && (
               <div className="bg-black/40 border border-white/5 p-5 rounded-2xl shadow-inner text-center">
                  <div className="text-[9px] uppercase tracking-widest text-stone-500 font-black mb-2">Focal Pos</div>
                  <div className="text-sm font-mono text-white uppercase">{radialPosition.replace('-', ' ')}</div>
               </div>
             )}
             <div className="bg-black/40 border border-white/5 p-5 rounded-2xl shadow-inner text-center">
                <div className="text-[9px] uppercase tracking-widest text-stone-500 font-black mb-2">Active Nodes</div>
                <div className="text-sm font-mono text-white uppercase">{colorStops.length}</div>
             </div>
             <div className="bg-black/40 border border-white/5 p-5 rounded-2xl shadow-inner text-center">
                <div className="text-[9px] uppercase tracking-widest text-stone-500 font-black mb-2">String Length</div>
                <div className="text-sm font-mono text-[#bc9437] uppercase">{gradientCSS.length} Chars</div>
             </div>
          </div>
          
        </div>
      </div>
    </PageShell>
  );
};
