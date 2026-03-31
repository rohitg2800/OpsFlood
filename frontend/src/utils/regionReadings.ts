import type { SensorData } from '../types';

function normalize(value: string | undefined | null): string {
  return (value || '').trim().toLowerCase();
}

export function getSelectedRiverLocationLabel(
  selectedCity?: string,
  station?: string,
  selectedState?: string,
): string {
  return station || selectedCity || selectedState || 'Active Region';
}

export function scopeSensorsToSelectedLocation(
  sensors: SensorData[],
  options: {
    selectedCity?: string;
    station?: string;
    selectedState?: string;
  },
): SensorData[] {
  const source = [...(sensors || [])];
  if (!source.length) return [];

  const selectedCity = normalize(options.selectedCity || options.station);
  if (selectedCity) {
    const cityMatches = source.filter((sensor) =>
      normalize(sensor.station).includes(selectedCity) ||
      normalize(sensor.river).includes(selectedCity),
    );
    if (cityMatches.length) {
      return cityMatches.sort((a, b) => Number(b.river_level || 0) - Number(a.river_level || 0));
    }
  }

  const selectedState = normalize(options.selectedState);
  if (selectedState) {
    const stateMatches = source.filter((sensor) =>
      normalize(sensor.state).includes(selectedState) ||
      normalize(sensor.station).includes(selectedState),
    );
    if (stateMatches.length) {
      return stateMatches.sort((a, b) => Number(b.river_level || 0) - Number(a.river_level || 0));
    }
  }

  return source.sort((a, b) => Number(b.river_level || 0) - Number(a.river_level || 0));
}
