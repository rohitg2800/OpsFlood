import React, { useState, useEffect } from 'react';
import { Wind, Droplets, ThermometerSun } from 'lucide-react';
import axios from 'axios';

export interface WeatherData {
  temp: number;
  humidity: number;
  windSpeed: number;
  description: string;
  icon: string;
  pressure?: number;
}

export interface LocationData {
  name: string;
  lat: number;
  lon: number;
  country: string;
  state?: string;
}

export interface WeatherWidgetProps {
  onWeatherSelect: (weatherData: WeatherData) => void;
  onLocationSelect: (location: LocationData) => void;
}

const WeatherWidget: React.FC<WeatherWidgetProps> = ({ 
  onWeatherSelect, 
  onLocationSelect 
}) => {
  const [weather, setWeather] = useState<WeatherData | null>(null);
  const [loading, setLoading] = useState(true);

  // Free API Key from OpenWeatherMap
  const API_KEY = 'b435f0df4bcc5fd08ef7b8ef517ba504'; 
  const CITY = 'Kolhapur';

  useEffect(() => {
    const fetchWeather = async () => {
      try {
        const res = await axios.get(
          `https://api.openweathermap.org/data/2.5/weather?lat=16.6993&lon=74.2403&appid=${API_KEY}&units=metric`
        );
        const weatherData: WeatherData = {
          temp: Math.round(res.data.main.temp),
          humidity: res.data.main.humidity,
          windSpeed: Math.round(res.data.wind.speed * 3.6), // m/s to km/h
          description: res.data.weather[0].description,
          icon: `https://openweathermap.org/img/wn/${res.data.weather[0].icon}@2x.png`
        };
        setWeather(weatherData);
        onWeatherSelect(weatherData);  // Call callback with weather data
      } catch (error) {
        console.error("Error fetching live weather", error);
        // Fallback mock data
        const fallbackData: WeatherData = {
          temp: 29,
          humidity: 78,
          windSpeed: 15,
          description: "moderate rain",
          icon: "https://openweathermap.org/img/wn/10d@2x.png"
        };
        setWeather(fallbackData);
        onWeatherSelect(fallbackData);
      } finally {
        setLoading(false);
      }
    };

    fetchWeather();
    // Refresh every 10 minutes
    const interval = setInterval(fetchWeather, 600000); 
    return () => clearInterval(interval);
  }, [onWeatherSelect]);

  if (loading) {
    return <div className="animate-pulse bg-white/50 h-32 rounded-3xl backdrop-blur-md"></div>;
  }

  return (
    <div className="bg-white/40 backdrop-blur-xl border border-white/50 rounded-3xl p-6 shadow-xl flex flex-col md:flex-row items-center justify-between gap-6 mb-8 transform transition hover:scale-[1.01]">
      <div className="flex items-center gap-4">
        <div className="bg-gradient-to-br from-blue-400 to-blue-600 rounded-full p-3 shadow-lg">
          <img src={weather?.icon} alt="Weather icon" className="w-16 h-16 drop-shadow-md" />
        </div>
        <div>
          <h3 className="text-3xl font-black text-slate-800">{CITY}</h3>
          <p className="text-slate-600 capitalize font-medium text-lg">{weather?.description}</p>
        </div>
      </div>

      <div className="flex gap-6 text-slate-800">
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm">
          <ThermometerSun className="w-6 h-6 text-orange-500 mb-1" />
          <span className="font-black text-2xl">{weather?.temp}°C</span>
          <span className="text-xs text-slate-500 font-bold uppercase">Temp</span>
        </div>
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm">
          <Droplets className="w-6 h-6 text-blue-500 mb-1" />
          <span className="font-black text-2xl">{weather?.humidity}%</span>
          <span className="text-xs text-slate-500 font-bold uppercase">Humidity</span>
        </div>
        <div className="flex flex-col items-center bg-white/60 px-5 py-3 rounded-2xl shadow-sm">
          <Wind className="w-6 h-6 text-teal-500 mb-1" />
          <span className="font-black text-2xl">{weather?.windSpeed} <span className="text-sm">km/h</span></span>
          <span className="text-xs text-slate-500 font-bold uppercase">Wind</span>
        </div>
      </div>
    </div>
  );
};

export default WeatherWidget;