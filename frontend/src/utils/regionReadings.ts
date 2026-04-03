import type { SensorData } from '../types';
import { normalizeGeoKey, resolveGeoCoordinate } from '../data/geoCoordinates';

function normalize(value: string | undefined | null): string {
  return normalizeGeoKey(value || '');
}

function tokenize(value: string | undefined | null): string[] {
  return normalize(value)
    .split(' ')
    .filter((token) => token.length >= 3);
}

function sortSensorsByLevel(sensors: SensorData[]): SensorData[] {
  return [...sensors].sort((a, b) => Number(b.river_level || 0) - Number(a.river_level || 0));
}

function haversineDistanceKm(
  left: { lat: number; lon: number },
  right: { lat: number; lon: number },
): number {
  const toRad = (value: number) => (value * Math.PI) / 180;
  const dLat = toRad(right.lat - left.lat);
  const dLon = toRad(right.lon - left.lon);
  const lat1 = toRad(left.lat);
  const lat2 = toRad(right.lat);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 6371 * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

function getStateMatches(sensors: SensorData[], selectedState?: string): SensorData[] {
  const normalizedState = normalize(selectedState);
  if (!normalizedState) return [];

  return sensors.filter((sensor) => {
    const sensorState = normalize(sensor.state);
    const sensorStation = normalize(sensor.station);
    return sensorState.includes(normalizedState) || sensorStation.includes(normalizedState);
  });
}

function scoreSensorAffinity(
  sensor: SensorData,
  selectedLocation: string,
  selectedState?: string,
): number {
  const locationKey = normalize(selectedLocation);
  const locationTokens = tokenize(selectedLocation);
  const stationKey = normalize(sensor.station);
  const riverKey = normalize(sensor.river);
  const stateKey = normalize(sensor.state || selectedState);
  let score = 0;

  if (stationKey === locationKey || riverKey === locationKey) score += 260;
  if (stationKey.includes(locationKey) || locationKey.includes(stationKey)) score += 180;
  if (riverKey.includes(locationKey) || locationKey.includes(riverKey)) score += 140;

  for (const token of locationTokens) {
    if (stationKey.includes(token)) score += 34;
    if (riverKey.includes(token)) score += 24;
    if (stateKey.includes(token)) score += 10;
  }

  if (selectedState && stateKey === normalize(selectedState)) {
    score += 28;
  }

  if (sensor.source === 'CWC_API' || sensor.source === 'HTML_SCRAPE') {
    score += 12;
  }

  const selectedLocationGeo = resolveGeoCoordinate(selectedLocation, selectedState);
  const sensorGeo = resolveGeoCoordinate(sensor.station, sensor.river, sensor.state, selectedState);

  if (selectedLocationGeo && sensorGeo) {
    if (
      normalize(selectedLocationGeo.state) &&
      normalize(sensorGeo.state) &&
      normalize(selectedLocationGeo.state) === normalize(sensorGeo.state)
    ) {
      score += 20;
    }

    const distanceKm = haversineDistanceKm(selectedLocationGeo, sensorGeo);
    if (distanceKm <= 60) score += 72;
    else if (distanceKm <= 120) score += 56;
    else if (distanceKm <= 220) score += 44;
    else if (distanceKm <= 360) score += 28;
    else if (distanceKm <= 520) score += 18;
    else score += 8;
  }

  return score;
}

export type SensorScopeMode = 'city_exact' | 'city_nearby' | 'state' | 'global';

export interface ScopedSensorSelection {
  sensors: SensorData[];
  mode: SensorScopeMode;
}

export function getSelectedRiverLocationLabel(
  selectedCity?: string,
  station?: string,
  selectedState?: string,
): string {
  return station || selectedCity || selectedState || 'Active Region';
}

export function getScopedSensorSelection(
  sensors: SensorData[],
  options: {
    selectedCity?: string;
    station?: string;
    selectedState?: string;
  },
): ScopedSensorSelection {
  const source = [...(sensors || [])];
  if (!source.length) {
    return { sensors: [], mode: 'global' };
  }

  const selectedCity = normalize(options.selectedCity || options.station);
  if (selectedCity) {
    const cityMatches = source.filter((sensor) =>
      normalize(sensor.station).includes(selectedCity) ||
      normalize(sensor.river).includes(selectedCity),
    );
    if (cityMatches.length) {
      return { sensors: sortSensorsByLevel(cityMatches), mode: 'city_exact' };
    }

    const statePool = getStateMatches(source, options.selectedState);
    const affinityPool = statePool.length ? statePool : source;
    const nearbyMatches = [...affinityPool].sort((left, right) => {
      const leftScore = scoreSensorAffinity(left, selectedCity, options.selectedState);
      const rightScore = scoreSensorAffinity(right, selectedCity, options.selectedState);

      if (rightScore !== leftScore) {
        return rightScore - leftScore;
      }

      return Number(right.river_level || 0) - Number(left.river_level || 0);
    });

    if (nearbyMatches.length) {
      return { sensors: nearbyMatches, mode: 'city_nearby' };
    }
  }

  const stateMatches = getStateMatches(source, options.selectedState);
  if (stateMatches.length) {
    return { sensors: sortSensorsByLevel(stateMatches), mode: 'state' };
  }

  return { sensors: sortSensorsByLevel(source), mode: 'global' };
}

export function scopeSensorsToSelectedLocation(
  sensors: SensorData[],
  options: {
    selectedCity?: string;
    station?: string;
    selectedState?: string;
  },
): SensorData[] {
  return getScopedSensorSelection(sensors, options).sensors;
}
