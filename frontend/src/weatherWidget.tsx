import React, { useState, useEffect } from 'react';
import { Wind, Droplets, ThermometerSun, MapPin, RefreshCw } from 'lucide-react';
import WeatherService from './weatherService'; // Import the WeatherService

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
  coordinates?: { lat: number; lon: number };
  autoRefresh?: boolean;
  refreshInterval?: number; // in minutes
  showLocationName?: boolean;
  showDetailedInfo?: boolean;
}

const WeatherWidget: React.FC<WeatherWidgetProps> = ({ 
  onWeatherSelect, 
  onLocationSelect,
  city = 'Kolhapur',
  coordinates,
  autoRefresh = true,
  refreshInterval = 10,
  showLocationName = true,
  showDetailedInfo = true
}) => {
  const [weather, setWeather] = useState<WeatherData | null>(null);
  const [location, setLocation] = useState<LocationData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchWeather = async () => {
    try {
      setLoading(true);
      setError(null);

      let weatherData: WeatherData;
      
      if (coordinates) {
        // Fetch weather by coordinates
        weatherData = await WeatherService.getWeatherByCoords(coordinates.lat, coordinates.lon);
        
        // Also get location name
        const locations = await WeatherService.searchLocations(`${coordinates.lat},${coordinates.lon}`);
        if (locations.length > 0) {
          setLocation(locations[0]);
          onLocationSelect?.(locations[0]);
        }
      } else {
        // Fetch weather by city
        weatherData = await WeatherService.getWeatherByCity(city);
        
        // Also get location coordinates
        const locations = await WeatherService.searchLocations(city);
        if (locations.length > 0) {
          setLocation(locations[0]);
          onLocationSelect?.(locations[0]);
        }
      }

      setWeather(weatherData);
      onWeatherSelect?.(weatherData);
      setLastUpdated(new Date());

    } catch (err) {
      console.error('Error fetching weather:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch weather data');
      
      // Use fallback data
      const fallbackData: WeatherData = {
        location: city,
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
        timezone: 0
      };
      
      setWeather(fallbackData);
      onWeatherSelect?.(fallbackData);
    } finally {
      setLoading(false);
    }
  };

  const getCurrentLocation = async () => {
    try {
      setLoading(true);
      const coords = await WeatherService.getCurrentLocation();
      coordinates = coords; // Update coordinates
      await fetchWeather();
    } catch (err) {
      console.error('Error getting current location:', err);
      setError('Failed to get current location');
    }
  };

  useEffect(() => {
    fetchWeather();
    
    // Set up auto-refresh if enabled
    let interval: NodeJS.Timeout | null = null;
    
    if (autoRefresh && refreshInterval > 0) {
      interval = setInterval(fetchWeather, refreshInterval * 60 * 1000);
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [city, coordinates, autoRefresh, refreshInterval]);

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
      <div className="animate-pulse bg-white/50 h-48 rounded-3xl backdrop-blur-md flex items-center justify-center">
        <RefreshCw className="w-8 h-8 text-blue-500 animate-spin" />
      </div>
    );
  }

  return (
    <div className="bg-white/40 backdrop-blur-xl border border-white/50 rounded-3xl p-6 shadow-xl flex flex-col lg:flex-row items-center justify-between gap-6 mb-8 transform transition hover:scale-[1.01]">
      {/* Error Banner */}
      {error && (
        <div className="w-full bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          <div className="flex items-center justify-between">
            <span className="font-medium">Error: {error}</span>
            <button 
              onClick={fetchWeather}
              className="text-red-700 hover:text-red-900"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* Main Weather Display */}
      <div className="flex items-center gap-4 flex-1">
        <div className="bg-gradient-to-br from-blue-400 to-blue-600 rounded-full p-3 shadow-lg">
          {weather?.icon.startsWith('http') ? (
            <img 
              src={weather.icon} 
              alt="Weather icon" 
              className="w-16 h-16 drop-shadow-md" 
              onError={(e) => {
                // Fallback to weather condition icon if URL fails
                const target = e.target as HTMLImageElement;
                const condition = weather?.weather_condition || 'clear';
                target.style.display = 'none';
                
                // Create a simple colored circle as fallback
                const fallback = document.createElement('div');
                fallback.className = 'w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-2xl';
                fallback.innerHTML = condition.charAt(0).toUpperCase();
                target.parentNode?.appendChild(fallback);
              }}
            />
          ) : (
            <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-2xl">
              {weather?.weather_condition.charAt(0).toUpperCase() || 'W'}
            </div>
          )}
        </div>
        <div className="flex-1">
          {showLocationName && (
            <h3 className="text-3xl font-black text-slate-800 flex items-center gap-2">
              {weather?.location || city}
              <button 
                onClick={getCurrentLocation}
                className="text-blue-500 hover:text-blue-700 transition-colors"
                title="Use current location"
              >
                <MapPin className="w-5 h-5" />
              </button>
            </h3>
          )}
          <p className="text-slate-600 capitalize font-medium text-lg mb-1">
            {weather?.description}
          </p>
          {lastUpdated && (
            <p className="text-xs text-slate-500">
              Updated: {lastUpdated.toLocaleTimeString()}
            </p>
          )}
        </div>
      </div>

      {/* Weather Metrics */}
      <div className="flex gap-4 lg:gap-6 text-slate-800 flex-wrap justify-center">
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm min-w-[80px]">
          <ThermometerSun className="w-6 h-6 text-orange-500 mb-1" />
          <span className="font-black text-2xl">{weather?.temperature}°C</span>
          <span className="text-xs text-slate-500 font-bold uppercase">Temp</span>
          {showDetailedInfo && (
            <span className="text-xs text-slate-400">Feels {weather?.feels_like}°C</span>
          )}
        </div>
        
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm min-w-[80px]">
          <Droplets className="w-6 h-6 text-blue-500 mb-1" />
          <span className="font-black text-2xl">{weather?.humidity}%</span>
          <span className="text-xs text-slate-500 font-bold uppercase">Humidity</span>
          {showDetailedInfo && weather?.rain_1h && (
            <span className="text-xs text-blue-400">Rain: {weather.rain_1h}mm</span>
          )}
        </div>
        
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm min-w-[80px]">
          <Wind className="w-6 h-6 text-teal-500 mb-1" />
          <span className="font-black text-2xl">{Math.round(weather?.wind_speed || 0)} <span className="text-sm">km/h</span></span>
          <span className="text-xs text-slate-500 font-bold uppercase">Wind</span>
          {showDetailedInfo && (
            <span className="text-xs text-slate-400">
              {getWindDirection(weather?.wind_direction || 0)}
            </span>
          )}
        </div>

        {showDetailedInfo && (
          <>
            <div className="flex flex-col items-center bg-white/60 px-3 py-3 rounded-2xl shadow-sm min-w-[70px]">
              <span className="font-bold text-lg text-slate-700">{weather?.pressure}</span>
              <span className="text-xs text-slate-500 font-bold uppercase">Pressure</span>
              <span className="text-xs text-slate-400">hPa</span>
            </div>

            <div className="flex flex-col items-center bg-white/60 px-3 py-3 rounded-2xl shadow-sm min-w-[70px]">
              <span className="font-bold text-lg text-slate-700">{weather?.clouds}%</span>
              <span className="text-xs text-slate-500 font-bold uppercase">Clouds</span>
              <span className="text-xs text-slate-400">Coverage</span>
            </div>

            <div className="flex flex-col items-center bg-white/60 px-3 py-3 rounded-2xl shadow-sm min-w-[80px]">
              <span className="font-bold text-sm text-slate-700">{formatTime(weather?.sunrise || 0)}</span>
              <span className="text-xs text-slate-500 font-bold uppercase">Sunrise</span>
              <span className="font-bold text-sm text-slate-700">{formatTime(weather?.sunset || 0)}</span>
              <span className="text-xs text-slate-500 font-bold uppercase">Sunset</span>
            </div>
          </>
        )}
      </div>

      {/* Refresh Button */}
      <div className="lg:ml-4">
        <button
          onClick={fetchWeather}
          disabled={loading}
          className="bg-blue-500 hover:bg-blue-600 disabled:bg-blue-300 text-white p-3 rounded-full shadow-lg transition-colors"
          title="Refresh weather data"
        >
          <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>
    </div>
  );
};

export default WeatherWidget;
