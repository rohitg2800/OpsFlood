import React from 'react';

interface WaterLevelGaugeProps {
  currentLevel: number;
  dangerLevel: number;
  maxLevel?: number;
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  showWaveAnimation?: boolean;
}

export const WaterLevelGauge: React.FC<WaterLevelGaugeProps> = ({
  currentLevel,
  dangerLevel,
  maxLevel = 20,
  severity = 'LOW',
  showWaveAnimation = true,
}) => {
  const percentage = Math.min((currentLevel / maxLevel) * 100, 100);
  const dangerPercentage = (dangerLevel / maxLevel) * 100;
  const isAboveDanger = currentLevel >= dangerLevel;

  const getWaterColor = () => {
    if (isAboveDanger) {
      switch (severity) {
        case 'CRITICAL':
          return 'rgb(255, 0, 55)';
        case 'SEVERE':
          return 'rgba(245, 158, 11, 0.8)';
        default:
          return 'rgba(255, 176, 0, 0.8)';
      }
    }
    return 'rgba(14, 165, 233, 0.6)';
  };

  const getWaveColor = () => {
    if (isAboveDanger) {
      switch (severity) {
        case 'CRITICAL':
          return 'rgba(255, 0, 55, 0.4)';
        case 'SEVERE':
          return 'rgba(245, 158, 11, 0.4)';
        default:
          return 'rgba(255, 176, 0, 0.4)';
      }
    }
    return 'rgba(14, 165, 233, 0.3)';
  };

  return (
    <div className="relative w-full h-48 bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl overflow-hidden">
      {/* Gauge Container */}
      <div className="absolute inset-0 flex items-center justify-center">
        {/* Outer Ring */}
        <div className="relative w-36 h-36">
          {/* Background Circle */}
          <svg className="w-full h-full transform -rotate-90">
            <circle
              cx="72"
              cy="72"
              r="66"
              fill="none"
              stroke="rgba(255, 255, 255, 0.1)"
              strokeWidth="10"
            />
            {/* Danger Level Indicator */}
            <circle
              cx="72"
              cy="72"
              r="66"
              fill="none"
              stroke="rgba(255, 0, 55, 0.3)"
              strokeWidth="10"
              strokeDasharray={`${(dangerPercentage / 100) * 415} 415`}
              strokeLinecap="round"
            />
            {/* Current Level */}
            <circle
              cx="72"
              cy="72"
              r="66"
              fill="none"
              stroke={getWaterColor()}
              strokeWidth="10"
              strokeDasharray={`${(percentage / 100) * 415} 415`}
              strokeLinecap="round"
              className="transition-all duration-1000 ease-out"
              style={{
                filter: isAboveDanger ? `drop-shadow(0 0 10px ${getWaterColor()})` : 'none',
              }}
            />
          </svg>

          {/* Center Content */}
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <div className="text-3xl font-black text-white font-mono">
              {currentLevel.toFixed(1)}
            </div>
            <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">
              meters
            </div>
            <div className={`mt-2 px-3 py-1 rounded-full text-[9px] font-black uppercase ${
              isAboveDanger
                ? 'bg-[#ff0037]/20 text-[#ff0037] border border-[#ff0037]/30'
                : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
            }`}>
              {isAboveDanger ? '⚠️ DANGER' : '✓ SAFE'}
            </div>
          </div>

          {/* Animated Water Fill */}
          {showWaveAnimation && (
            <div
              className="absolute bottom-0 left-0 right-0 overflow-hidden transition-all duration-1000 ease-out"
              style={{
                height: `${percentage}%`,
                background: `linear-gradient(to bottom, ${getWaterColor()}, ${getWaveColor()})`,
              }}
            >
              {/* Wave Animation */}
              <svg
                className="absolute top-0 left-0 w-full animate-wave"
                style={{ animationDuration: '3s' }}
                viewBox="0 0 1440 100"
                preserveAspectRatio="none"
              >
                <path
                  fill={getWaveColor()}
                  d="M0,50L48,45C96,40,192,30,288,35C384,40,480,60,576,65C672,70,768,60,864,50C960,40,1056,30,1152,35C1248,40,1344,60,1392,70L1440,80L1440,100L1392,100C1344,100,1248,100,1152,100C1056,100,960,100,864,100C768,100,672,100,576,100C480,100,384,100,288,100C192,100,96,100,48,100L0,100Z"
                />
              </svg>
              <svg
                className="absolute top-0 left-0 w-full animate-wave"
                style={{ animationDuration: '5s', animationDelay: '-2s' }}
                viewBox="0 0 1440 100"
                preserveAspectRatio="none"
              >
                <path
                  fill={getWaterColor()}
                  d="M0,60L48,55C96,50,192,40,288,45C384,50,480,70,576,75C672,80,768,70,864,60C960,50,1056,40,1152,45C1248,50,1344,70,1392,80L1440,90L1440,100L1392,100C1344,100,1248,100,1152,100C1056,100,960,100,864,100C768,100,672,100,576,100C480,100,384,100,288,100C192,100,96,100,48,100L0,100Z"
                />
              </svg>
            </div>
          )}
        </div>
      </div>

      {/* Level Labels */}
      <div className="absolute bottom-4 left-4 right-4 flex justify-between text-[9px] font-mono text-slate-500">
        <span>0m</span>
        <span className="text-[#ff0037]">Danger: {dangerLevel}m</span>
        <span>{maxLevel}m</span>
      </div>

      {/* Status Indicator */}
      <div className="absolute top-4 right-4">
        <div className={`w-3 h-3 rounded-full ${
          isAboveDanger
            ? 'bg-[#ff0037] animate-pulse-glow'
            : 'bg-emerald-500 animate-breathe'
        }`} />
      </div>
    </div>
  );
};

export default WaterLevelGauge;
