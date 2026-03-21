

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

export interface ForecastData {
  date: string;
  temp_min: number;
  temp_max: number;
  humidity: number;
  pressure: number;
  wind_speed: number;
  description: string;
  icon: string;
  rain_chance: number;
  rain_amount?: number;
}

export interface AirQualityData {
  aqi: number;
  pm2_5: number;
  pm10: number;
  no2: number;
  so2: number;
  o3: number;
  co: number;
}

export interface LocationData {
  name: string;
  lat: number;
  lon: number;
  country: string;
  state?: string;
}

class WeatherService {
  private openWeatherApiKey = '***REMOVED***'; // Replace with your API key
  // private visualCrossingApiKey = 'YOUR_VISUAL_CROSSING_API_KEY'; // Optional
  // private weatherApiKey = 'YOUR_WEATHERAPI_KEY'; // Optional

  // List of major Indian cities for quick selection
  readonly indianCities: LocationData[] = [
    { name: "Kolhapur", lat: 16.705, lon: 74.243, country: "IN", state: "Maharashtra" },
    { name: "Mumbai", lat: 19.076, lon: 72.877, country: "IN", state: "Maharashtra" },
    { name: "Delhi", lat: 28.613, lon: 77.209, country: "IN", state: "Delhi" },
    { name: "Bangalore", lat: 12.971, lon: 77.594, country: "IN", state: "Karnataka" },
    { name: "Chennai", lat: 13.082, lon: 80.270, country: "IN", state: "Tamil Nadu" },
    { name: "Kolkata", lat: 22.572, lon: 88.363, country: "IN", state: "West Bengal" },
    { name: "Hyderabad", lat: 17.385, lon: 78.486, country: "IN", state: "Telangana" },
    { name: "Pune", lat: 18.520, lon: 73.856, country: "IN", state: "Maharashtra" },
    { name: "Ahmedabad", lat: 23.022, lon: 72.571, country: "IN", state: "Gujarat" },
    { name: "Jaipur", lat: 26.912, lon: 75.787, country: "IN", state: "Rajasthan" },
    { name: "Lucknow", lat: 26.846, lon: 80.946, country: "IN", state: "Uttar Pradesh" },
    { name: "Kanpur", lat: 26.449, lon: 80.331, country: "IN", state: "Uttar Pradesh" },
    { name: "Nagpur", lat: 21.145, lon: 79.088, country: "IN", state: "Maharashtra" },
    { name: "Indore", lat: 22.719, lon: 75.857, country: "IN", state: "Madhya Pradesh" },
    { name: "Thane", lat: 19.218, lon: 72.978, country: "IN", state: "Maharashtra" },
    { name: "Bhopal", lat: 23.259, lon: 77.412, country: "IN", state: "Madhya Pradesh" },
    { name: "Visakhapatnam", lat: 17.686, lon: 83.218, country: "IN", state: "Andhra Pradesh" },
    { name: "Patna", lat: 25.594, lon: 85.137, country: "IN", state: "Bihar" },
    { name: "Vadodara", lat: 22.307, lon: 73.181, country: "IN", state: "Gujarat" },
    { name: "Ghaziabad", lat: 28.669, lon: 77.453, country: "IN", state: "Uttar Pradesh" },
    { name: "Ludhiana", lat: 30.901, lon: 75.857, country: "IN", state: "Punjab" },
    { name: "Agra", lat: 27.176, lon: 78.042, country: "IN", state: "Uttar Pradesh" },
    { name: "Nashik", lat: 19.997, lon: 73.789, country: "IN", state: "Maharashtra" },
    { name: "Faridabad", lat: 28.408, lon: 77.317, country: "IN", state: "Haryana" },
    { name: "Meerut", lat: 28.984, lon: 77.706, country: "IN", state: "Uttar Pradesh" },
    { name: "Rajkot", lat: 22.303, lon: 70.802, country: "IN", state: "Gujarat" },
    { name: "Kalyan-Dombivli", lat: 19.235, lon: 73.129, country: "IN", state: "Maharashtra" },
    { name: "Vasai-Virar", lat: 19.425, lon: 72.822, country: "IN", state: "Maharashtra" },
    { name: "Varanasi", lat: 25.317, lon: 82.973, country: "IN", state: "Uttar Pradesh" },
    { name: "Srinagar", lat: 34.083, lon: 74.797, country: "IN", state: "Jammu and Kashmir" },
    { name: "Aurangabad", lat: 19.876, lon: 75.343, country: "IN", state: "Maharashtra" },
    { name: "Dhanbad", lat: 23.795, lon: 86.430, country: "IN", state: "Jharkhand" },
    { name: "Amritsar", lat: 31.634, lon: 74.872, country: "IN", state: "Punjab" },
    { name: "Navi Mumbai", lat: 19.033, lon: 73.029, country: "IN", state: "Maharashtra" },
    { name: "Allahabad", lat: 25.435, lon: 81.846, country: "IN", state: "Uttar Pradesh" },
    { name: "Ranchi", lat: 23.344, lon: 85.309, country: "IN", state: "Jharkhand" },
    { name: "Howrah", lat: 22.595, lon: 88.263, country: "IN", state: "West Bengal" },
    { name: "Coimbatore", lat: 11.016, lon: 76.955, country: "IN", state: "Tamil Nadu" },
    { name: "Jabalpur", lat: 23.181, lon: 79.986, country: "IN", state: "Madhya Pradesh" },
    { name: "Gwalior", lat: 26.218, lon: 78.182, country: "IN", state: "Madhya Pradesh" },
    { name: "Vijayawada", lat: 16.506, lon: 80.648, country: "IN", state: "Andhra Pradesh" },
    { name: "Jodhpur", lat: 26.238, lon: 73.024, country: "IN", state: "Rajasthan" },
    { name: "Madurai", lat: 9.925, lon: 78.119, country: "IN", state: "Tamil Nadu" },
    { name: "Raipur", lat: 21.251, lon: 81.629, country: "IN", state: "Chhattisgarh" },
    { name: "Kota", lat: 25.213, lon: 75.864, country: "IN", state: "Rajasthan" },
    { name: "Guwahati", lat: 26.144, lon: 91.736, country: "IN", state: "Assam" },
    { name: "Chandigarh", lat: 30.733, lon: 76.779, country: "IN", state: "Chandigarh" },
    { name: "Solapur", lat: 17.659, lon: 75.906, country: "IN", state: "Maharashtra" },
    { name: "Hubli-Dharwad", lat: 15.364, lon: 75.123, country: "IN", state: "Karnataka" },
    { name: "Bareilly", lat: 28.367, lon: 79.430, country: "IN", state: "Uttar Pradesh" },
    { name: "Moradabad", lat: 28.838, lon: 78.773, country: "IN", state: "Uttar Pradesh" },
    { name: "Mysore", lat: 12.295, lon: 76.639, country: "IN", state: "Karnataka" },
    { name: "Gurgaon", lat: 28.459, lon: 77.026, country: "IN", state: "Haryana" },
    { name: "Aligarh", lat: 27.897, lon: 78.088, country: "IN", state: "Uttar Pradesh" },
    { name: "Jalandhar", lat: 31.326, lon: 75.576, country: "IN", state: "Punjab" },
    { name: "Tiruchirappalli", lat: 10.790, lon: 78.704, country: "IN", state: "Tamil Nadu" },
    { name: "Bhubaneswar", lat: 20.296, lon: 85.824, country: "IN", state: "Odisha" },
    { name: "Salem", lat: 11.664, lon: 78.146, country: "IN", state: "Tamil Nadu" },
    { name: "Mira-Bhayandar", lat: 19.295, lon: 72.854, country: "IN", state: "Maharashtra" },
    { name: "Warangal", lat: 17.968, lon: 79.594, country: "IN", state: "Telangana" },
    { name: "Thiruvananthapuram", lat: 8.524, lon: 76.936, country: "IN", state: "Kerala" },
    { name: "Guntur", lat: 16.306, lon: 80.436, country: "IN", state: "Andhra Pradesh" },
    { name: "Bhiwandi", lat: 19.300, lon: 73.058, country: "IN", state: "Maharashtra" },
    { name: "Saharanpur", lat: 29.964, lon: 77.546, country: "IN", state: "Uttar Pradesh" },
    { name: "Gorakhpur", lat: 26.760, lon: 83.373, country: "IN", state: "Uttar Pradesh" },
    { name: "Bikaner", lat: 28.022, lon: 73.311, country: "IN", state: "Rajasthan" },
    { name: "Amravati", lat: 20.932, lon: 77.751, country: "IN", state: "Maharashtra" },
    { name: "Noida", lat: 28.535, lon: 77.391, country: "IN", state: "Uttar Pradesh" },
    { name: "Jamshedpur", lat: 22.804, lon: 86.202, country: "IN", state: "Jharkhand" },
    { name: "Bhilai", lat: 21.209, lon: 81.428, country: "IN", state: "Chhattisgarh" },
    { name: "Cuttack", lat: 20.462, lon: 85.882, country: "IN", state: "Odisha" },
    { name: "Firozabad", lat: 27.159, lon: 78.395, country: "IN", state: "Uttar Pradesh" },
    { name: "Kochi", lat: 9.931, lon: 76.267, country: "IN", state: "Kerala" },
    { name: "Nellore", lat: 14.442, lon: 79.986, country: "IN", state: "Andhra Pradesh" },
    { name: "Bhavnagar", lat: 21.764, lon: 72.151, country: "IN", state: "Gujarat" },
    { name: "Dehradun", lat: 30.316, lon: 78.032, country: "IN", state: "Uttarakhand" },
    { name: "Durgapur", lat: 23.520, lon: 87.311, country: "IN", state: "West Bengal" },
    { name: "Asansol", lat: 23.683, lon: 86.975, country: "IN", state: "West Bengal" },
    { name: "Rourkela", lat: 22.249, lon: 84.882, country: "IN", state: "Odisha" },
    { name: "Nanded", lat: 19.138, lon: 77.321, country: "IN", state: "Maharashtra" },
    { name: "Kolhapur", lat: 16.705, lon: 74.243, country: "IN", state: "Maharashtra" }
  ];

  // Get current weather by city name
  async getWeatherByCity(city: string): Promise<WeatherData> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/data/2.5/weather?q=${city}&units=metric&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        throw new Error('City not found');
      }
      
      const data = await response.json();
      return this.transformWeatherData(data);
    } catch (error) {
      console.error('Error fetching weather:', error);
      throw error;
    }
  }

  // Get weather by coordinates
  async getWeatherByCoords(lat: number, lon: number): Promise<WeatherData> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        throw new Error('Location not found');
      }
      
      const data = await response.json();
      return this.transformWeatherData(data);
    } catch (error) {
      console.error('Error fetching weather:', error);
      throw error;
    }
  }

  // Get 5-day forecast
  async getForecast(city: string): Promise<ForecastData[]> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/data/2.5/forecast?q=${city}&units=metric&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        throw new Error('Forecast not available');
      }
      
      const data = await response.json();
      return this.transformForecastData(data);
    } catch (error) {
      console.error('Error fetching forecast:', error);
      throw error;
    }
  }

  // Get air quality data
  async getAirQuality(lat: number, lon: number): Promise<AirQualityData> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        throw new Error('Air quality data not available');
      }
      
      const data = await response.json();
      return this.transformAirQualityData(data);
    } catch (error) {
      console.error('Error fetching air quality:', error);
      throw error;
    }
  }

  // Get user's current location
  async getCurrentLocation(): Promise<{ lat: number; lon: number }> {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation not supported'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => {
          resolve({
            lat: position.coords.latitude,
            lon: position.coords.longitude
          });
        },
        (error) => {
          reject(error);
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    });
  }

  // Search for locations
  async searchLocations(query: string): Promise<LocationData[]> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/geo/1.0/direct?q=${query}&limit=5&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        return [];
      }
      
      const data = await response.json();
      return data.map((item: any) => ({
        name: item.name,
        lat: item.lat,
        lon: item.lon,
        country: item.country,
        state: item.state
      }));
    } catch (error) {
      console.error('Error searching locations:', error);
      return [];
    }
  }

  // Get historical weather data (last 7 days)
  async getHistoricalWeather(lat: number, lon: number): Promise<any> {
    try {
      const response = await fetch(
        `https://api.openweathermap.org/data/2.5/onecall/timemachine?lat=${lat}&lon=${lon}&units=metric&appid=${this.openWeatherApiKey}`
      );
      
      if (!response.ok) {
        throw new Error('Historical data not available');
      }
      
      return await response.json();
    } catch (error) {
      console.error('Error fetching historical weather:', error);
      throw error;
    }
  }

  // Transform OpenWeatherMap data to our format
  private transformWeatherData(data: any): WeatherData {
    return {
      location: `${data.name}, ${data.sys.country}`,
      temperature: Math.round(data.main.temp),
      feels_like: Math.round(data.main.feels_like),
      humidity: data.main.humidity,
      pressure: data.main.pressure,
      wind_speed: data.wind.speed,
      wind_direction: data.wind.deg,
      description: data.weather[0].description,
      icon: data.weather[0].icon,
      sunrise: data.sys.sunrise,
      sunset: data.sys.sunset,
      visibility: data.visibility,
      clouds: data.clouds.all,
      rain_1h: data.rain?.['1h'],
      rain_3h: data.rain?.['3h'],
      snow_1h: data.snow?.['1h'],
      weather_condition: data.weather[0].main.toLowerCase(),
      timestamp: data.dt,
      timezone: data.timezone
    };
  }

  // Transform forecast data
  private transformForecastData(data: any): ForecastData[] {
    const dailyData: { [key: string]: any } = {};
    
    data.list.forEach((item: any) => {
      const date = new Date(item.dt * 1000).toLocaleDateString();
      
      if (!dailyData[date]) {
        dailyData[date] = {
          date,
          temp_min: item.main.temp_min,
          temp_max: item.main.temp_max,
          humidity: item.main.humidity,
          pressure: item.main.pressure,
          wind_speed: item.wind.speed,
          description: item.weather[0].description,
          icon: item.weather[0].icon,
          rain_chance: item.pop * 100,
          rain_amount: item.rain?.['3h'] || 0
        };
      } else {
        dailyData[date].temp_min = Math.min(dailyData[date].temp_min, item.main.temp_min);
        dailyData[date].temp_max = Math.max(dailyData[date].temp_max, item.main.temp_max);
        dailyData[date].rain_amount += item.rain?.['3h'] || 0;
      }
    });

    return Object.values(dailyData).slice(0, 5) as ForecastData[];
  }

  // Transform air quality data
  private transformAirQualityData(data: any): AirQualityData {
    const components = data.list[0].components;
    
    return {
      aqi: data.list[0].main.aqi,
      pm2_5: components.pm2_5,
      pm10: components.pm10,
      no2: components.no2,
      so2: components.so2,
      o3: components.o3,
      co: components.co
    };
  }

  // Get weather icon based on condition
  getWeatherIcon(condition: string, isDay: boolean = true): string {
    const icons: { [key: string]: string } = {
      'clear': isDay ? 'wi-day-sunny' : 'wi-night-clear',
      'clouds': isDay ? 'wi-day-cloudy' : 'wi-night-alt-cloudy',
      'rain': 'wi-rain',
      'drizzle': 'wi-sprinkle',
      'thunderstorm': 'wi-thunderstorm',
      'snow': 'wi-snow',
      'mist': 'wi-fog',
      'smoke': 'wi-smoke',
      'haze': 'wi-day-haze',
      'dust': 'wi-dust',
      'fog': 'wi-fog',
      'sand': 'wi-sandstorm',
      'ash': 'wi-volcano',
      'squall': 'wi-strong-wind',
      'tornado': 'wi-tornado'
    };

    return icons[condition] || 'wi-day-sunny';
  }

  // Get AQI description
  getAQIDescription(aqi: number): { level: string; color: string; description: string } {
    if (aqi <= 1) return { level: 'Good', color: 'green', description: 'Air quality is satisfactory' };
    if (aqi <= 2) return { level: 'Fair', color: 'yellow', description: 'Air quality is acceptable' };
    if (aqi <= 3) return { level: 'Moderate', color: 'orange', description: 'Sensitive groups should limit outdoor activity' };
    if (aqi <= 4) return { level: 'Poor', color: 'red', description: 'Everyone may experience health effects' };
    return { level: 'Very Poor', color: 'purple', description: 'Health alert: everyone may experience serious health effects' };
  }

  // Get UV index description
  getUVDescription(uv: number): { level: string; color: string; recommendation: string } {
    if (uv <= 2) return { level: 'Low', color: 'green', recommendation: 'No protection needed' };
    if (uv <= 5) return { level: 'Moderate', color: 'yellow', recommendation: 'Protection needed' };
    if (uv <= 7) return { level: 'High', color: 'orange', recommendation: 'Extra protection needed' };
    if (uv <= 10) return { level: 'Very High', color: 'red', recommendation: 'Avoid being outside' };
    return { level: 'Extreme', color: 'purple', recommendation: 'Stay indoors' };
  }

  // Calculate flood risk based on weather data
  calculateFloodRisk(weather: WeatherData, forecast: ForecastData[]): number {
    let risk = 0;
    
    // Current rain contributes heavily
    if (weather.rain_1h && weather.rain_1h > 10) risk += 40;
    else if (weather.rain_1h && weather.rain_1h > 5) risk += 20;
    
    // High humidity increases risk
    if (weather.humidity > 80) risk += 15;
    
    // Low pressure indicates storm systems
    if (weather.pressure < 1000) risk += 20;
    
    // Forecast rain increases risk
    const totalForecastRain = forecast.reduce((sum, day) => sum + (day.rain_amount || 0), 0);
    if (totalForecastRain > 50) risk += 25;
    
    // Cloud cover contributes
    if (weather.clouds > 70) risk += 10;
    
    return Math.min(risk, 100);
  }
}

export default new WeatherService();
