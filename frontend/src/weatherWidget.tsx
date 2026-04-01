import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Wind, Droplets, ThermometerSun, MapPin, RefreshCw } from 'lucide-react';
import WeatherService from './weatherService'; // Import the WeatherService
import { isLiteMotionDevice } from './utils/performance';

export interface WeatherData {
  location: string;
  temperature: number;
  feels_like: number;
  humidity: number;
  pressure: number;
  wind_speed: number;
  wind_direction: number;
  description: string;
  icon: string;
  sunrise: number;
  sunset: number;
  visibility: number;
  clouds: number;
  rain_1h?: number;
  rain_3h?: number;
  snow_1h?: number;
  weather_condition: string;
  timestamp: number;
  timezone: number;
}

export interface LocationData {
  name: string;
  lat: number;
  lon: number;
  country: string;
  state?: string;
}

export interface WeatherWidgetProps {
  onWeatherSelect?: (weatherData: WeatherData) => void;
  onLocationSelect?: (location: LocationData) => void;
  city?: string;
  displayLocation?: string;
  coordinates?: { lat: number; lon: number };
  autoRefresh?: boolean;
  refreshInterval?: number; // in minutes
  showLocationName?: boolean;
  showDetailedInfo?: boolean;
  showMetaStrip?: boolean;
  showRefreshButton?: boolean;
}

type WeatherScene = 'sunny' | 'clouds' | 'night' | 'rain';
const PLACEHOLDER_LOCATION_KEYS = new Set(['selected region', 'awaiting input', 'active region']);

const normalizeLocationLabel = (value: string) =>
  (value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const isPlaceholderLocation = (value: string) => PLACEHOLDER_LOCATION_KEYS.has(normalizeLocationLabel(value));

const formatDisplayLocation = (value: string | null | undefined) => {
  const trimmed = (value || '').trim();
  return trimmed || null;
};

const buildFallbackWeatherData = (target: string): WeatherData => ({
  location: target || 'Selected Region',
  temperature: 28,
  feels_like: 32,
  humidity: 75,
  pressure: 1013,
  wind_speed: 8,
  wind_direction: 180,
  description: 'Partly cloudy',
  icon: 'https://openweathermap.org/img/wn/02d@2x.png',
  sunrise: Date.now() / 1000 - 3600,
  sunset: Date.now() / 1000 + 36000,
  visibility: 10000,
  clouds: 40,
  weather_condition: 'clouds',
  timestamp: Date.now() / 1000,
  timezone: 0,
});

const getReadableWeatherError = (error: unknown, target: string) => {
  const rawMessage = error instanceof Error ? error.message : 'Failed to fetch weather data';
  if (rawMessage.includes('"city not found"') || rawMessage.includes('404')) {
    return `Live weather unavailable for ${target}; showing fallback conditions.`;
  }
  return rawMessage;
};

const isNightSnapshot = (weather: WeatherData | null) => {
  if (!weather) return false;
  const current = Number(weather.timestamp || 0);
  const sunrise = Number(weather.sunrise || 0);
  const sunset = Number(weather.sunset || 0);

  if (!current || !sunrise || !sunset) return false;
  return current < sunrise || current > sunset;
};

const getWeatherScene = (weather: WeatherData | null): WeatherScene => {
  if (!weather) return 'clouds';

  const condition = String(weather.weather_condition || '').toLowerCase();
  const cloudCover = Number(weather.clouds || 0);

  if (/(rain|drizzle|thunderstorm)/.test(condition) || Number(weather.rain_1h ?? weather.rain_3h ?? 0) > 0) {
    return 'rain';
  }

  if (isNightSnapshot(weather)) {
    return 'night';
  }

  if (/(cloud|mist|fog|haze|smoke|dust|sand|ash|squall|tornado)/.test(condition) || cloudCover >= 35) {
    return 'clouds';
  }

  return 'sunny';
};

const scenePalette: Record<WeatherScene, { shell: string; glow: string; badge: string }> = {
  sunny: {
    shell: 'from-[#2a1200]/95 via-[#6b1b02]/90 to-[#f59e0b]/35',
    glow: 'bg-[radial-gradient(circle_at_82%_18%,rgba(245,158,11,0.35),transparent_22%),radial-gradient(circle_at_15%_85%,rgba(255,90,31,0.16),transparent_30%)]',
    badge: 'bg-[#f59e0b]/15 text-[#ffd18a] border-[#f59e0b]/30',
  },
  clouds: {
    shell: 'from-[#10191d]/96 via-[#1e2a32]/92 to-[#556672]/32',
    glow: 'bg-[radial-gradient(circle_at_80%_15%,rgba(196,208,216,0.14),transparent_22%),radial-gradient(circle_at_20%_80%,rgba(92,115,128,0.16),transparent_32%)]',
    badge: 'bg-[#9fb5c6]/12 text-[#dfeaf0] border-[#9fb5c6]/26',
  },
  night: {
    shell: 'from-[#030611]/98 via-[#0f1730]/96 to-[#18244e]/38',
    glow: 'bg-[radial-gradient(circle_at_82%_18%,rgba(197,218,255,0.18),transparent_20%),radial-gradient(circle_at_18%_78%,rgba(96,132,255,0.1),transparent_28%)]',
    badge: 'bg-[#8eb2ff]/12 text-[#dce7ff] border-[#8eb2ff]/28',
  },
  rain: {
    shell: 'from-[#070d14]/98 via-[#15202d]/96 to-[#20384c]/42',
    glow: 'bg-[radial-gradient(circle_at_80%_15%,rgba(123,174,255,0.12),transparent_20%),radial-gradient(circle_at_16%_82%,rgba(53,116,184,0.12),transparent_28%)]',
    badge: 'bg-[#73b9ff]/12 text-[#d8ecff] border-[#73b9ff]/28',
  },
};

const WeatherSceneBackdrop = React.memo(({
  scene,
  showNightSky,
  liteMotion,
}: {
  scene: WeatherScene;
  showNightSky: boolean;
  liteMotion: boolean;
}) => {
  const sunRays = useMemo(
    () => Array.from({ length: liteMotion ? 4 : 8 }, (_, index) => index),
    [liteMotion],
  );
  const cloudLayers = useMemo(
    () =>
      liteMotion
        ? [
            { top: '18%', left: '10%', scale: 1, delay: '0s', opacity: 0.82 },
            { top: '28%', left: '48%', scale: 0.9, delay: '-2.6s', opacity: 0.68 },
          ]
        : [
            { top: '16%', left: '8%', scale: 1.05, delay: '0s', opacity: 0.9 },
            { top: '30%', left: '34%', scale: 0.88, delay: '-2.2s', opacity: 0.76 },
            { top: '14%', left: '62%', scale: 1.15, delay: '-3.5s', opacity: 0.72 },
          ],
    [liteMotion],
  );
  const rainColumns = useMemo(
    () => Array.from({ length: liteMotion ? 12 : 28 }, (_, index) => index),
    [liteMotion],
  );
  const starSlots = useMemo(
    () => Array.from({ length: liteMotion ? 14 : 34 }, (_, index) => index),
    [liteMotion],
  );

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.03),transparent_32%,rgba(0,0,0,0.28))]" />
      {scene === 'sunny' ? (
        <>
          <div className={`weather-sun absolute right-10 top-6 ${liteMotion ? 'h-16 w-16' : 'h-20 w-20'} rounded-full bg-[radial-gradient(circle,#ffe7a6_0%,#f59e0b_38%,rgba(245,158,11,0.18)_70%,transparent_100%)]`} />
          <div className={`weather-sun-ring absolute ${liteMotion ? 'right-7 top-3 h-[5.75rem] w-[5.75rem]' : 'right-5 top-1 h-[7.5rem] w-[7.5rem]'} rounded-full border border-[#f59e0b]/18`} />
          {sunRays.map((index) => (
            <span
              key={`sun-ray-${index}`}
              className="weather-ray absolute left-0 top-0 h-[2px] w-10 rounded-full bg-gradient-to-r from-[#ffd18a] to-transparent"
              style={{
                top: `calc(${liteMotion ? '3rem' : '3.5rem'} + ${Math.sin((index / sunRays.length) * Math.PI * 2) * (liteMotion ? 1.9 : 2.5)}rem)`,
                left: `calc(78% + ${Math.cos((index / sunRays.length) * Math.PI * 2) * (liteMotion ? 1.9 : 2.5)}rem)`,
                transform: `rotate(${index * (360 / sunRays.length)}deg)`,
                animationDelay: `${index * 0.18}s`,
              }}
            />
          ))}
        </>
      ) : null}

      {scene === 'clouds' || scene === 'rain' ? (
        <>
          {cloudLayers.map((cloud, index) => (
            <div
              key={`cloud-${index}`}
              className="weather-cloud absolute h-16 w-28"
              style={
                {
                  top: cloud.top,
                  left: cloud.left,
                  opacity: cloud.opacity,
                  animationDelay: cloud.delay,
                  '--cloud-scale': cloud.scale,
                } as React.CSSProperties & { '--cloud-scale': number }
              }
            >
              <span className="absolute bottom-0 left-5 h-9 w-16 rounded-full bg-white/14 blur-[0.5px]" />
              <span className="absolute bottom-2 left-1 h-10 w-10 rounded-full bg-white/18" />
              <span className="absolute bottom-4 left-8 h-12 w-12 rounded-full bg-white/18" />
              <span className="absolute bottom-2 right-2 h-9 w-9 rounded-full bg-white/16" />
            </div>
          ))}
        </>
      ) : null}

      {scene === 'rain' ? (
        <div className="absolute inset-0">
          {rainColumns.map((index) => (
            <span
              key={`rain-${index}`}
              className="weather-rain absolute top-[-18%] h-12 w-[1.5px] rounded-full bg-gradient-to-b from-[#dff0ff]/0 via-[#dff0ff]/85 to-[#73b9ff]/0"
              style={{
                left: `${4 + (index * 3.35) % 96}%`,
                animationDelay: `${(index % 11) * 0.18}s`,
                animationDuration: `${0.75 + (index % 5) * 0.12}s`,
                opacity: 0.45 + (index % 4) * 0.12,
              }}
            />
          ))}
        </div>
      ) : null}

      {showNightSky && scene !== 'rain' ? (
        <>
          <div
            className="absolute inset-0 opacity-70"
            style={{
              backgroundImage: [
                'radial-gradient(circle at 8% 46%, rgba(255,255,255,0.95) 0 1.2px, transparent 2.4px)',
                'radial-gradient(circle at 14% 62%, rgba(255,255,255,0.82) 0 1px, transparent 2px)',
                'radial-gradient(circle at 18% 78%, rgba(255,255,255,0.9) 0 1.4px, transparent 2.8px)',
                'radial-gradient(circle at 80% 20%, rgba(255,255,255,0.88) 0 1.2px, transparent 2.4px)',
                'radial-gradient(circle at 90% 30%, rgba(255,255,255,0.94) 0 1px, transparent 2.2px)',
                'radial-gradient(circle at 84% 66%, rgba(255,255,255,0.84) 0 1.1px, transparent 2.4px)',
                'radial-gradient(circle at 92% 78%, rgba(255,255,255,0.72) 0 1px, transparent 2.1px)',
                'radial-gradient(circle at 10% 86%, rgba(255,255,255,0.7) 0 1px, transparent 2.1px)',
              ].join(', '),
            }}
          />
          <div className="absolute left-10 top-8 h-16 w-16 rounded-full bg-[radial-gradient(circle,#f8fbff_0%,#d7e6ff_48%,rgba(215,230,255,0.18)_72%,transparent_100%)] shadow-[0_0_34px_rgba(180,210,255,0.34)]" />
          <div className="absolute left-14 top-6 h-16 w-16 rounded-full bg-[#0b1430]" />
          {starSlots.map((index) => {
            const size = index % 6 === 0 ? 4 : index % 3 === 0 ? 3.5 : 3;
            const leftBand =
              index % 4 === 0
                ? 4 + (index * 7) % 16
                : index % 4 === 1
                ? 80 + (index * 5) % 14
                : index % 4 === 2
                ? 8 + (index * 9) % 14
                : 78 + (index * 11) % 16;
            const topBand =
              index % 4 === 0
                ? 34 + (index * 6) % 18
                : index % 4 === 1
                ? 18 + (index * 5) % 16
                : index % 4 === 2
                ? 58 + (index * 7) % 18
                : 62 + (index * 6) % 16;
            return (
              <span
                key={`star-${index}`}
                className="weather-star absolute rounded-full bg-white mix-blend-screen shadow-[0_0_10px_rgba(255,255,255,0.6)]"
                style={{
                  width: `${size}px`,
                  height: `${size}px`,
                  top: `${topBand}%`,
                  left: `${leftBand}%`,
                  animationDelay: `${index * 0.22}s`,
                  opacity: 0.78 + (index % 3) * 0.07,
                }}
              />
            );
          })}
        </>
      ) : null}
    </div>
  );
});

WeatherSceneBackdrop.displayName = 'WeatherSceneBackdrop';

const WeatherWidget: React.FC<WeatherWidgetProps> = ({ 
  onWeatherSelect, 
  onLocationSelect,
  city = 'Selected Region',
  displayLocation,
  coordinates,
  autoRefresh = true,
  refreshInterval = 10,
  showLocationName = true,
  showDetailedInfo = true,
  showMetaStrip = true,
  showRefreshButton = false,
}) => {
  const [weather, setWeather] = useState<WeatherData | null>(null);
  const [, setLocation] = useState<LocationData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [coords, setCoords] = useState<typeof coordinates | null>(coordinates || null);
  const [iconLoadFailed, setIconLoadFailed] = useState(false);
  const requestIdRef = useRef(0);
  const mountedRef = useRef(true);
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);
  const showNightSky = useMemo(() => isNightSnapshot(weather), [weather]);
  const weatherScene = useMemo(() => getWeatherScene(weather), [weather]);
  const palette = scenePalette[weatherScene];
  const allowDeviceLocationOverride = !displayLocation;
  const incomingLat = coordinates?.lat ?? null;
  const incomingLon = coordinates?.lon ?? null;
  const resolvedCoordLat = coords?.lat ?? incomingLat;
  const resolvedCoordLon = coords?.lon ?? incomingLon;
  const weatherIconSrc = useMemo(() => {
    if (!weather?.icon) {
      return null;
    }

    return weather.icon.startsWith('http')
      ? weather.icon
      : `https://openweathermap.org/img/wn/${weather.icon}@2x.png`;
  }, [weather?.icon]);
  const lockedDisplayLocation = useMemo(
    () => formatDisplayLocation(displayLocation) || formatDisplayLocation(city),
    [city, displayLocation],
  );
  const visibleLocationLabel = lockedDisplayLocation || weather?.location || city;

  // Sync internal coords when prop changes
  useEffect(() => {
    setCoords((current) => {
      const nextCoords =
        incomingLat !== null && incomingLon !== null
          ? { lat: incomingLat, lon: incomingLon }
          : null;

      if (
        current?.lat === nextCoords?.lat &&
        current?.lon === nextCoords?.lon
      ) {
        return current;
      }

      return nextCoords;
    });
  }, [incomingLat, incomingLon]);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      requestIdRef.current += 1;
    };
  }, []);

  useEffect(() => {
    setIconLoadFailed(false);
  }, [weatherIconSrc]);

  const fetchWeather = useCallback(async (coordsOverride?: { lat: number; lon: number } | null) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    const isActiveRequest = () => mountedRef.current && requestIdRef.current === requestId;

    try {
      setLoading(true);
      setError(null);

      let weatherData: WeatherData;
      let selectedLocation: LocationData | null = null;
      const activeCoords =
        coordsOverride ||
        (resolvedCoordLat !== null && resolvedCoordLon !== null
          ? { lat: resolvedCoordLat, lon: resolvedCoordLon }
          : null);

      if (!activeCoords && isPlaceholderLocation(city)) {
        weatherData = buildFallbackWeatherData(lockedDisplayLocation || city);
        if (!isActiveRequest()) {
          return;
        }
        setWeather(weatherData);
        onWeatherSelect?.(weatherData);
        setLastUpdated(new Date());
        return;
      }

      if (activeCoords) {
        // Fetch weather by coordinates
        weatherData = await WeatherService.getWeatherByCoords(activeCoords.lat, activeCoords.lon);

        if (lockedDisplayLocation) {
          selectedLocation = {
            name: lockedDisplayLocation,
            lat: activeCoords.lat,
            lon: activeCoords.lon,
            country: 'IN',
          };
          if (!isActiveRequest()) {
            return;
          }
          setLocation(selectedLocation);
          onLocationSelect?.(selectedLocation);
        } else {
          // Also get location name when the UI doesn't already have a locked destination label.
          const locations = await WeatherService.searchLocations(`${activeCoords.lat},${activeCoords.lon}`);
          if (locations.length > 0) {
            selectedLocation = locations[0];
            if (!isActiveRequest()) {
              return;
            }
            setLocation(selectedLocation);
            onLocationSelect?.(selectedLocation);
          }
        }
      } else {
        const resolvedLocation = await WeatherService.resolveLocation(city);

        if (resolvedLocation) {
          selectedLocation = resolvedLocation;
          weatherData = await WeatherService.getWeatherByCoords(resolvedLocation.lat, resolvedLocation.lon);
          if (!isActiveRequest()) {
            return;
          }
          setLocation(resolvedLocation);
          onLocationSelect?.(resolvedLocation);
        } else {
          // Final fallback: try the raw city string if no better match was found
          weatherData = await WeatherService.getWeatherByCity(city);

          const locations = await WeatherService.searchLocations(city);
          if (locations.length > 0) {
            selectedLocation = locations[0];
            if (!isActiveRequest()) {
              return;
            }
            setLocation(selectedLocation);
            onLocationSelect?.(selectedLocation);
          }
        }
      }

      if (!isActiveRequest()) {
        return;
      }
      const normalizedWeather = {
        ...weatherData,
        location:
          lockedDisplayLocation ||
          selectedLocation?.name ||
          formatDisplayLocation(weatherData.location) ||
          city,
      };

      setWeather(normalizedWeather);
      onWeatherSelect?.(normalizedWeather);
      setLastUpdated(new Date());

    } catch (err) {
      console.error('Error fetching weather:', err);
      if (!isActiveRequest()) {
        return;
      }
      setError(getReadableWeatherError(err, lockedDisplayLocation || city || 'this target'));
      
      // Use fallback data
      const fallbackData = buildFallbackWeatherData(lockedDisplayLocation || city);
      
      setWeather(fallbackData);
      onWeatherSelect?.(fallbackData);
    } finally {
      if (isActiveRequest()) {
        setLoading(false);
      }
    }
  }, [city, lockedDisplayLocation, onLocationSelect, onWeatherSelect, resolvedCoordLat, resolvedCoordLon]);

  const getCurrentLocation = async () => {
    try {
      setLoading(true);
      setError(null);
      const nextCoords = await WeatherService.getCurrentLocation();
      setCoords(nextCoords);
      await fetchWeather(nextCoords);
    } catch (err) {
      console.error('Error getting current location:', err);
      setError(err instanceof Error ? err.message : 'Failed to get current location');
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWeather();
    
    // Set up auto-refresh if enabled
    let interval: NodeJS.Timeout | null = null;
    
    if (autoRefresh && refreshInterval > 0) {
      interval = setInterval(() => {
        void fetchWeather();
      }, refreshInterval * 60 * 1000);
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [autoRefresh, fetchWeather, refreshInterval]);

  const formatTime = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  };

  const getWindDirection = (degrees: number) => {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 
                       'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    return directions[Math.round(degrees / 22.5) % 16];
  };

  if (loading && !weather) {
    return (
      <div className={`animate-pulse bg-black/25 h-36 rounded-md flex items-center justify-center ${liteMotion ? '' : 'backdrop-blur-xl'}`}>
        <RefreshCw className="w-6 h-6 text-[#ff0037] animate-spin" />
      </div>
    );
  }

  return (
    <div className={`${liteMotion ? 'weather-widget-lite' : ''} weather-widget-shell relative overflow-hidden rounded-[1.5rem] border-0 bg-gradient-to-br ${palette.shell} p-5 pt-6 ${liteMotion ? 'shadow-[0_12px_28px_rgba(0,0,0,0.2)] backdrop-blur-sm' : 'shadow-[0_18px_60px_rgba(0,0,0,0.34)] backdrop-blur-[18px]'} sm:p-6 sm:pt-7`}>
      <style>{`
        @keyframes weather-cloud-drift {
          0% { transform: translateX(-4%) scale(var(--cloud-scale, 1)); }
          50% { transform: translateX(4%) scale(calc(var(--cloud-scale, 1) * 1.02)); }
          100% { transform: translateX(-4%) scale(var(--cloud-scale, 1)); }
        }
        @keyframes weather-rain-fall {
          0% { transform: translate3d(0, -10%, 0); opacity: 0; }
          12% { opacity: 0.85; }
          100% { transform: translate3d(-12px, 155px, 0); opacity: 0; }
        }
        @keyframes weather-sun-pulse {
          0%, 100% { transform: scale(1); opacity: 0.9; }
          50% { transform: scale(1.06); opacity: 1; }
        }
        @keyframes weather-ray-flicker {
          0%, 100% { opacity: 0.28; }
          50% { opacity: 0.72; }
        }
        @keyframes weather-star-twinkle {
          0%, 100% { opacity: 0.45; transform: scale(1); }
          50% { opacity: 1; transform: scale(1.85); }
        }
        @keyframes weather-widget-drift {
          0%, 100% { transform: translate3d(0, 0, 0); }
          50% { transform: translate3d(0, -3px, 0); }
        }
        @keyframes weather-widget-shimmer {
          0% { transform: translateX(-125%); opacity: 0; }
          18% { opacity: 0.32; }
          100% { transform: translateX(125%); opacity: 0; }
        }
        @keyframes weather-metric-float {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-3px); }
        }
        .weather-widget-shell::before {
          content: '';
          position: absolute;
          inset: 0;
          background:
            radial-gradient(circle at 14% 20%, rgba(255,255,255,0.08), transparent 24%),
            radial-gradient(circle at 86% 18%, rgba(255,255,255,0.06), transparent 20%),
            linear-gradient(180deg, rgba(255,255,255,0.045), transparent 26%, rgba(255,255,255,0.025) 72%, transparent);
          pointer-events: none;
        }
        .weather-widget-shell::after {
          content: '';
          position: absolute;
          top: 0;
          bottom: 0;
          width: 26%;
          background: linear-gradient(90deg, transparent, rgba(255,255,255,0.12), transparent);
          filter: blur(14px);
          animation: weather-widget-shimmer 9.5s linear infinite;
          pointer-events: none;
        }
        .weather-widget-float {
          animation: weather-widget-drift 8s ease-in-out infinite;
        }
        .weather-metric-card {
          animation: weather-metric-float 5.6s ease-in-out infinite;
        }
        .weather-cloud { animation: weather-cloud-drift 9s ease-in-out infinite; }
        .weather-rain { animation: weather-rain-fall linear infinite; }
        .weather-sun { animation: weather-sun-pulse 5s ease-in-out infinite; }
        .weather-sun-ring { animation: weather-sun-pulse 6.5s ease-in-out infinite; opacity: 0.45; }
        .weather-ray { animation: weather-ray-flicker 2.8s ease-in-out infinite; transform-origin: left center; }
        .weather-star { animation: weather-star-twinkle 2.4s ease-in-out infinite; }
        .weather-widget-lite::after {
          display: none;
        }
        .weather-widget-lite .weather-cloud,
        .weather-widget-lite .weather-rain,
        .weather-widget-lite .weather-sun,
        .weather-widget-lite .weather-sun-ring,
        .weather-widget-lite .weather-ray,
        .weather-widget-lite .weather-star,
        .weather-widget-lite .weather-widget-float,
        .weather-widget-lite .weather-metric-card {
          animation: none !important;
        }
        @media (prefers-reduced-motion: reduce) {
          .weather-cloud,
          .weather-rain,
          .weather-sun,
          .weather-sun-ring,
          .weather-ray,
          .weather-star,
          .weather-widget-shell::after,
          .weather-widget-float,
          .weather-metric-card {
            animation: none !important;
          }
        }
      `}</style>

      <div className={`absolute inset-0 opacity-75 ${palette.glow}`} />
      <WeatherSceneBackdrop scene={weatherScene} showNightSky={showNightSky} liteMotion={liteMotion} />
      <div className="absolute inset-0 bg-[linear-gradient(135deg,rgba(0,0,0,0.08),rgba(0,0,0,0.26))]" />

      <div className="weather-widget-float relative z-10 text-center">
        {error && (
          <div className={`mb-3 w-full rounded-xl bg-[#ff0037]/8 px-3 py-2 text-[#ff8ea0] ${liteMotion ? '' : 'backdrop-blur-md'}`}>
            <div className="flex items-center justify-between">
              <span className="font-medium">Error: {error}</span>
              <button
                onClick={() => {
                  void fetchWeather();
                }}
                className="text-[#ff8ea0] hover:text-white"
              >
                <RefreshCw className="h-4 w-4" />
              </button>
            </div>
          </div>
        )}

        {showMetaStrip ? (
          <div className="mb-4 flex flex-wrap items-center justify-center gap-3">
            <span className={`rounded-md px-3 py-1.5 text-[9px] font-black uppercase tracking-[0.22em] ${palette.badge.replace(/border-[^ ]+ /g, '')}`}>
              {weatherScene}
            </span>
            {lastUpdated ? (
              <span className="text-[10px] font-mono text-white/55">
                Updated {lastUpdated.toLocaleTimeString()}
              </span>
            ) : null}
          </div>
        ) : null}

        <div className="flex flex-col items-center justify-center gap-5">
          <div className="flex flex-col items-center gap-4 self-stretch">
            <div className={`rounded-md bg-gradient-to-br from-[#6b000f] via-[#b00020] to-[#f59e0b] p-2 ${liteMotion ? 'shadow-[0_10px_24px_rgba(255,0,55,0.12)]' : 'shadow-[0_18px_60px_rgba(255,0,55,0.18)]'}`}>
              {weatherIconSrc && !iconLoadFailed ? (
                <img
                  src={weatherIconSrc}
                  alt="Weather icon"
                  className="h-12 w-12 drop-shadow-md"
                  onError={() => {
                    setIconLoadFailed(true);
                  }}
                />
              ) : (
                <div className="flex h-12 w-12 items-center justify-center rounded-md bg-black/30 text-xl font-bold uppercase text-white">
                  {weather?.weather_condition.charAt(0).toUpperCase() || 'W'}
                </div>
              )}
            </div>
            <div className="flex-1 text-center">
              {showLocationName && (
                <h3 className="flex flex-wrap items-center justify-center gap-2 text-2xl font-black tracking-tight text-white">
                  <span>{visibleLocationLabel}</span>
                  {allowDeviceLocationOverride ? (
                    <button
                      onClick={getCurrentLocation}
                      className="text-[#f59e0b] transition-colors hover:text-white"
                      title="Use current location"
                    >
                      <MapPin className="h-4 w-4" />
                    </button>
                  ) : null}
                </h3>
              )}
              <p className="mb-1 text-base font-bold capitalize text-slate-200">
                {weather?.description}
              </p>
              <p className="text-[10px] font-mono uppercase tracking-[0.18em] text-white/45">
                {weatherScene === 'rain'
                  ? 'Dense precipitation field active'
                  : weatherScene === 'night'
                  ? 'Night cycle atmospheric profile'
                  : weatherScene === 'clouds'
                  ? 'Cloud cover drift across sector'
                  : 'Clear solar weather window'}
              </p>
            </div>
          </div>

          <div className="flex flex-wrap justify-center gap-3 text-slate-200 lg:gap-4">
            <div className={`weather-metric-card flex min-w-[80px] flex-col items-center rounded-2xl bg-black/14 px-4 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`}>
              <ThermometerSun className="mb-1 h-5 w-5 text-[#f59e0b]" />
              <span className="font-mono text-xl font-black">{weather?.temperature}°C</span>
              <span className="text-[10px] font-black uppercase tracking-widest text-slate-400">Temp</span>
              {showDetailedInfo ? (
                <span className="text-xs font-mono text-slate-500">Feels {weather?.feels_like}°C</span>
              ) : null}
            </div>

            <div className={`weather-metric-card flex min-w-[80px] flex-col items-center rounded-2xl bg-black/14 px-4 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`} style={{ animationDelay: '0.3s' }}>
              <Droplets className="mb-1 h-5 w-5 text-[#73b9ff]" />
              <span className="font-mono text-xl font-black">{weather?.humidity}%</span>
              <span className="text-[10px] font-black uppercase tracking-widest text-slate-400">Humidity</span>
              {showDetailedInfo && weather?.rain_1h ? (
                <span className="text-xs font-mono text-slate-500">Rain: {weather.rain_1h}mm</span>
              ) : null}
            </div>

            <div className={`weather-metric-card flex min-w-[80px] flex-col items-center rounded-2xl bg-black/14 px-4 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`} style={{ animationDelay: '0.6s' }}>
              <Wind className="mb-1 h-5 w-5 text-slate-200" />
              <span className="font-mono text-xl font-black">
                {Math.round(weather?.wind_speed || 0)} <span className="text-xs text-slate-400">km/h</span>
              </span>
              <span className="text-[10px] font-black uppercase tracking-widest text-slate-400">Wind</span>
              {showDetailedInfo ? (
                <span className="text-xs font-mono text-slate-500">
                  {getWindDirection(weather?.wind_direction || 0)}
                </span>
              ) : null}
            </div>

            {showDetailedInfo && (
              <>
                <div className={`weather-metric-card flex min-w-[60px] flex-col items-center rounded-2xl bg-black/14 px-2 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`} style={{ animationDelay: '0.9s' }}>
                  <span className="text-base font-bold text-white">{weather?.pressure}</span>
                  <span className="text-[10px] font-bold uppercase text-slate-400">Pressure</span>
                  <span className="text-[10px] text-slate-500">hPa</span>
                </div>

                <div className={`weather-metric-card flex min-w-[60px] flex-col items-center rounded-2xl bg-black/14 px-2 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`} style={{ animationDelay: '1.2s' }}>
                  <span className="text-base font-bold text-white">{weather?.clouds}%</span>
                  <span className="text-[10px] font-bold uppercase text-slate-400">Clouds</span>
                  <span className="text-[10px] text-slate-500">Coverage</span>
                </div>

                <div className={`weather-metric-card flex min-w-[70px] flex-col items-center rounded-2xl bg-black/14 px-2 py-2 ${liteMotion ? '' : 'backdrop-blur-md shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]'}`} style={{ animationDelay: '1.5s' }}>
                  <span className="text-xs font-bold text-white">{formatTime(weather?.sunrise || 0)}</span>
                  <span className="text-[10px] font-bold uppercase text-slate-400">Sunrise</span>
                  <span className="text-xs font-bold text-white">{formatTime(weather?.sunset || 0)}</span>
                  <span className="text-[10px] font-bold uppercase text-slate-400">Sunset</span>
                </div>
              </>
            )}
          </div>

          {showRefreshButton ? (
            <div className="flex justify-center">
              <button
                onClick={() => {
                  void fetchWeather();
                }}
                disabled={loading}
                className={`rounded-full bg-black/14 p-2 text-white ${liteMotion ? 'shadow-[0_8px_18px_rgba(255,0,55,0.1)]' : 'shadow-[0_18px_60px_rgba(255,0,55,0.12)] backdrop-blur-md'} transition-colors hover:bg-[#ff0037]/28 disabled:opacity-60`}
                title="Refresh weather data"
              >
                <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              </button>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
};

export default WeatherWidget;
