// lib/models/weather_data.dart
// WeatherData is a convenience alias for WeatherState so that
// monitors_screen.dart can use `WeatherData` without changing provider types.
library;

export '../providers/weather_provider.dart'
    show WeatherState, WeatherCurrent, WeatherDay, WeatherStatus;

// typedef so existing code using `WeatherData` compiles directly.
typedef WeatherData = WeatherState;
