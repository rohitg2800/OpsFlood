"""
Weather router: OpenWeatherMap integration and weather data endpoints.
"""

from fastapi import APIRouter, HTTPException

from .dependencies import (
    get_openweather_api_key,
    WEATHER_CACHE,
)
from .weather_service import (
    resilient_openweather,
    resolve_weather_location,
    build_fallback_current_weather,
    build_fallback_search_results,
    build_fallback_reverse_geocode,
    build_fallback_forecast,
    build_fallback_air_quality,
    build_fallback_uv_index,
    build_fallback_historical_weather,
)

router = APIRouter(prefix="/weather", tags=["weather"])

@router.get("/status")
async def get_weather_status():
    """Get weather service status."""
    has_key = bool(get_openweather_api_key())
    return {
        "status": "SECURE" if has_key else "DEGRADED",
        "mode": "SECURE_PROXY" if has_key else "RESILIENT_FALLBACK",
        "provider": "OpenWeatherMap" if has_key else "Local Fallback Weather Engine",
        "backend_proxy": True,
        "key_configured": has_key,
        "fallback_enabled": True,
        "cache_entries": len(WEATHER_CACHE),
    }

@router.get("/current")
async def get_weather_current(city: str | None = None, lat: float | None = None, lon: float | None = None):
    """Get current weather for a location."""
    if city:
        cleaned_city = city.strip()
        return resilient_openweather(
            "/data/2.5/weather",
            {"q": cleaned_city, "units": "metric"},
            fallback_factory=lambda exc: (
                resilient_openweather(
                    "/data/2.5/weather",
                    {
                        "lat": resolve_weather_location(cleaned_city)["lat"],
                        "lon": resolve_weather_location(cleaned_city)["lon"],
                        "units": "metric",
                    },
                    fallback_factory=lambda _: build_fallback_current_weather(
                        city=cleaned_city,
                        lat=resolve_weather_location(cleaned_city)["lat"],
                        lon=resolve_weather_location(cleaned_city)["lon"],
                        reason=f"FALLBACK_AFTER_{exc.status_code}",
                    ),
                )
                if resolve_weather_location(cleaned_city)
                else build_fallback_current_weather(
                    city=cleaned_city,
                    reason=f"FALLBACK_AFTER_{exc.status_code}",
                )
            ),
        )

    if lat is not None and lon is not None:
        return resilient_openweather(
            "/data/2.5/weather",
            {"lat": lat, "lon": lon, "units": "metric"},
            fallback_factory=lambda exc: build_fallback_current_weather(
                lat=lat,
                lon=lon,
                reason=f"FALLBACK_AFTER_{exc.status_code}",
            ),
        )

    raise HTTPException(status_code=400, detail="Provide either city or lat/lon")

@router.get("/search")
async def search_weather_locations(query: str, limit: int = 5):
    """Search for weather locations."""
    cleaned_query = (query or "").strip()
    if not cleaned_query:
        return []

    return resilient_openweather(
        "/geo/1.0/direct",
        {"q": cleaned_query, "limit": max(1, min(limit, 10))},
        fallback_factory=lambda exc: build_fallback_search_results(cleaned_query, limit=max(1, min(limit, 10))),
    )

@router.get("/reverse-geocode")
async def reverse_geocode_weather_location(lat: float, lon: float, limit: int = 1):
    """Reverse geocode coordinates to location."""
    return resilient_openweather(
        "/geo/1.0/reverse",
        {"lat": lat, "lon": lon, "limit": max(1, min(limit, 5))},
        fallback_factory=lambda exc: build_fallback_reverse_geocode(lat, lon, limit=max(1, min(limit, 5))),
    )

@router.get("/forecast")
async def get_weather_forecast(city: str):
    """Get 5-day weather forecast."""
    cleaned_city = city.strip()
    return resilient_openweather(
        "/data/2.5/forecast",
        {"q": cleaned_city, "units": "metric"},
        fallback_factory=lambda exc: (
            build_fallback_forecast(
                city=cleaned_city,
                lat=(resolve_weather_location(cleaned_city) or {}).get("lat"),
                lon=(resolve_weather_location(cleaned_city) or {}).get("lon"),
            )
        ),
    )

@router.get("/air-quality")
async def get_air_quality(lat: float, lon: float):
    """Get air quality data."""
    return resilient_openweather(
        "/data/2.5/air_pollution",
        {"lat": lat, "lon": lon},
        fallback_factory=lambda exc: build_fallback_air_quality(lat, lon),
    )

@router.get("/uv")
async def get_uv_index(lat: float, lon: float):
    """Get UV index."""
    data = resilient_openweather(
        "/data/3.0/onecall",
        {
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "exclude": "minutely,hourly,daily,alerts",
        },
        fallback_factory=lambda exc: {"current": {"uvi": build_fallback_uv_index(lat, lon)}},
    )
    return {"uvi": data.get("current", {}).get("uvi", 0)}

@router.get("/historical")
async def get_historical_weather(lat: float, lon: float, dt: int | None = None):
    """Get historical weather data."""
    import datetime
    
    timestamp = dt or int((datetime.datetime.utcnow() - datetime.timedelta(days=1)).timestamp())
    return resilient_openweather(
        "/data/3.0/onecall/timemachine",
        {"lat": lat, "lon": lon, "dt": timestamp, "units": "metric"},
        fallback_factory=lambda exc: build_fallback_historical_weather(lat, lon, timestamp),
    )

@router.get("/alerts")
async def get_weather_alerts(lat: float, lon: float):
    """Get weather alerts."""
    data = resilient_openweather(
        "/data/3.0/onecall",
        {
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "exclude": "minutely,hourly,daily,current",
        },
        fallback_factory=lambda exc: {"alerts": []},
    )
    return data.get("alerts", [])
