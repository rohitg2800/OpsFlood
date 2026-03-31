import React from 'react';

interface WaterWaveBackgroundProps {
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  waveHeight?: number; // 0-100
}

export const WaterWaveBackground: React.FC<WaterWaveBackgroundProps> = ({
  severity = 'LOW',
  waveHeight = 30,
}) => {
  const getWaveColor = () => {
    switch (severity) {
      case 'CRITICAL':
        return 'rgba(255, 0, 55, 0.3)';
      case 'SEVERE':
        return 'rgba(245, 158, 11, 0.25)';
      case 'MODERATE':
        return 'rgba(255, 176, 0, 0.2)';
      default:
        return 'rgba(14, 165, 233, 0.15)';
    }
  };

  const getWaveColor2 = () => {
    switch (severity) {
      case 'CRITICAL':
        return 'rgba(176, 0, 32, 0.25)';
      case 'SEVERE':
        return 'rgba(245, 158, 11, 0.2)';
      case 'MODERATE':
        return 'rgba(255, 176, 0, 0.15)';
      default:
        return 'rgba(14, 165, 233, 0.1)';
    }
  };

  const getWaveColor3 = () => {
    switch (severity) {
      case 'CRITICAL':
        return 'rgba(107, 0, 15, 0.2)';
      case 'SEVERE':
        return 'rgba(176, 0, 32, 0.15)';
      case 'MODERATE':
        return 'rgba(245, 158, 11, 0.1)';
      default:
        return 'rgba(14, 165, 233, 0.05)';
    }
  };

  const height = `${waveHeight}%`;

  return (
    <div className="fixed bottom-0 left-0 right-0 pointer-events-none z-0 overflow-hidden" style={{ height }}>
      {/* Wave Layer 1 - Slowest */}
      <svg
        className="absolute bottom-0 left-0 w-full animate-wave"
        style={{ animationDuration: '7s', animationDelay: '0s' }}
        viewBox="0 0 1440 320"
        preserveAspectRatio="none"
        height={height}
      >
        <path
          fill={getWaveColor()}
          d="M0,192L48,197.3C96,203,192,213,288,229.3C384,245,480,267,576,250.7C672,235,768,181,864,181.3C960,181,1056,235,1152,234.7C1248,235,1344,181,1392,154.7L1440,128L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"
        />
      </svg>

      {/* Wave Layer 2 - Medium */}
      <svg
        className="absolute bottom-0 left-0 w-full animate-wave"
        style={{ animationDuration: '5s', animationDelay: '-2s' }}
        viewBox="0 0 1440 320"
        preserveAspectRatio="none"
        height={height}
      >
        <path
          fill={getWaveColor2()}
          d="M0,64L48,80C96,96,192,128,288,128C384,128,480,96,576,90.7C672,85,768,107,864,133.3C960,160,1056,192,1152,186.7C1248,181,1344,139,1392,117.3L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"
        />
      </svg>

      {/* Wave Layer 3 - Fastest */}
      <svg
        className="absolute bottom-0 left-0 w-full animate-wave"
        style={{ animationDuration: '3s', animationDelay: '-4s' }}
        viewBox="0 0 1440 320"
        preserveAspectRatio="none"
        height={height}
      >
        <path
          fill={getWaveColor3()}
          d="M0,256L48,240C96,224,192,192,288,181.3C384,171,480,181,576,186.7C672,192,768,192,864,176C960,160,1056,128,1152,133.3C1248,139,1344,181,1392,202.7L1440,224L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"
        />
      </svg>

      {/* Gradient overlay at top */}
      <div
        className="absolute top-0 left-0 right-0 h-32"
        style={{
          background: 'linear-gradient(to bottom, rgba(5, 4, 8, 0.8), transparent)',
        }}
      />
    </div>
  );
};

export default WaterWaveBackground;
