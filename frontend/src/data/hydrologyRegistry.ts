import type { CWCSensorData, SensorData } from '../types';

type BasinRegistryEntry = { r: string; st: string; w: number; d: number };

const UNKNOWN_STATE_FALLBACK: BasinRegistryEntry[] = [
  { r: 'Unknown Sector Alpha', st: 'Telemetry Node 1', w: 13.5, d: 15.0 },
  { r: 'Unknown Sector Bravo', st: 'Telemetry Node 2', w: 10.5, d: 12.0 },
];

export const INDIA_RIVER_BASIN_REGISTRY: Record<string, BasinRegistryEntry[]> = {
  'andhra pradesh': [
    { r: 'Godavari', st: 'Polavaram', w: 41.8, d: 43.5 },
    { r: 'Godavari', st: 'Dowlaiswaram Barrage', w: 13.5, d: 15.0 },
    { r: 'Krishna', st: 'Vijayawada (Prakasam)', w: 16.5, d: 17.5 },
    { r: 'Penna', st: 'Nellore', w: 8.5, d: 9.5 },
  ],
  'arunachal pradesh': [
    { r: 'Siang', st: 'Pasighat', w: 151.0, d: 152.5 },
    { r: 'Subansiri', st: 'Daporijo', w: 146.0, d: 147.4 },
    { r: 'Kameng', st: 'Seppa', w: 213.5, d: 214.8 },
  ],
  assam: [
    { r: 'Brahmaputra', st: 'Dibrugarh', w: 104.2, d: 105.7 },
    { r: 'Brahmaputra', st: 'Neamatighat', w: 84.5, d: 85.0 },
    { r: 'Brahmaputra', st: 'Guwahati', w: 48.6, d: 49.6 },
    { r: 'Barak', st: 'Annapurna Ghat (Silchar)', w: 18.8, d: 19.8 },
    { r: 'Jia Bharali', st: 'NT Road Crossing', w: 76.0, d: 77.0 },
  ],
  'andaman and nicobar islands': [
    { r: 'Kalpong', st: 'Diglipur', w: 4.2, d: 5.0 },
    { r: 'Sippighat Creek', st: 'Port Blair', w: 2.8, d: 3.6 },
    { r: 'Galathea', st: 'Campbell Bay', w: 3.9, d: 4.8 },
  ],
  maharashtra: [
    { r: 'Panchganga', st: 'Rajaram Barrage (Kolhapur)', w: 11.8, d: 13.1 },
    { r: 'Krishna', st: 'Kurundwad', w: 14.5, d: 16.5 },
    { r: 'Godavari', st: 'Nashik', w: 19.5, d: 21.0 },
    { r: 'Bhima', st: 'Pandharpur', w: 15.0, d: 17.2 },
    { r: 'Mula-Mutha', st: 'Pune Bund Garden', w: 14.2, d: 15.5 },
    { r: 'Savitri', st: 'Chiplun', w: 5.5, d: 6.5 },
  ],
  bihar: [
    { r: 'Koshi', st: 'Baltara', w: 33.8, d: 34.8 },
    { r: 'Ganga', st: 'Gandhi Ghat (Patna)', w: 48.6, d: 50.5 },
    { r: 'Gandak', st: 'Dumariaghat', w: 61.2, d: 62.2 },
    { r: 'Bagmati', st: 'Benabad', w: 48.6, d: 49.6 },
    { r: 'Kamla Balan', st: 'Jhanjharpur', w: 50.0, d: 51.0 },
  ],
  chandigarh: [
    { r: 'Sukhna Choe', st: 'Sukhna Lake Outfall', w: 3.8, d: 4.5 },
    { r: 'Patiala Ki Rao', st: 'North Chandigarh', w: 4.1, d: 5.0 },
    { r: 'N-Choe', st: 'Industrial Belt', w: 2.9, d: 3.7 },
  ],
  chhattisgarh: [
    { r: 'Mahanadi', st: 'Rajim', w: 6.8, d: 8.0 },
    { r: 'Shivnath', st: 'Durg', w: 8.5, d: 9.6 },
    { r: 'Hasdeo', st: 'Korba', w: 10.2, d: 11.5 },
    { r: 'Indravati', st: 'Jagdalpur', w: 14.0, d: 15.4 },
  ],
  'dadra and nagar haveli and daman and diu': [
    { r: 'Daman Ganga', st: 'Silvassa', w: 8.6, d: 9.8 },
    { r: 'Daman Ganga', st: 'Daman', w: 3.9, d: 4.8 },
    { r: 'Par', st: 'Moti Daman Coastal Reach', w: 2.7, d: 3.4 },
  ],
  kerala: [
    { r: 'Periyar', st: 'Vandiperiyar', w: 11.0, d: 12.5 },
    { r: 'Pamba', st: 'Malakkara', w: 6.0, d: 7.5 },
    { r: 'Chaliyar', st: 'Nilambur', w: 12.0, d: 14.0 },
    { r: 'Meenachil', st: 'Aranmula', w: 8.5, d: 10.0 },
  ],
  goa: [
    { r: 'Mandovi', st: 'Panaji', w: 3.9, d: 4.8 },
    { r: 'Zuari', st: 'Cortalim', w: 4.2, d: 5.1 },
    { r: 'Mhadei', st: 'Valpoi', w: 5.3, d: 6.2 },
  ],
  'uttar pradesh': [
    { r: 'Ganga', st: 'Phaphamau (Prayagraj)', w: 83.7, d: 84.7 },
    { r: 'Ganga', st: 'Varanasi', w: 70.2, d: 71.2 },
    { r: 'Yamuna', st: 'Agra', w: 151.4, d: 152.4 },
    { r: 'Ghaghara', st: 'Elgin Bridge', w: 105.0, d: 106.0 },
  ],
  haryana: [
    { r: 'Yamuna', st: 'Hathnikund', w: 231.5, d: 232.7 },
    { r: 'Ghaggar', st: 'Sirsa', w: 14.2, d: 15.6 },
    { r: 'Markanda', st: 'Shahbad', w: 9.3, d: 10.4 },
  ],
  'himachal pradesh': [
    { r: 'Beas', st: 'Mandi', w: 761.0, d: 762.5 },
    { r: 'Sutlej', st: 'Rampur', w: 1001.5, d: 1003.0 },
    { r: 'Ravi', st: 'Chamba', w: 989.0, d: 990.4 },
  ],
  jharkhand: [
    { r: 'Subarnarekha', st: 'Jamshedpur', w: 121.5, d: 122.8 },
    { r: 'Damodar', st: 'Dhanbad', w: 136.0, d: 137.2 },
    { r: 'Barakar', st: 'Panchet', w: 129.6, d: 130.7 },
  ],
  'jammu and kashmir': [
    { r: 'Jhelum', st: 'Srinagar', w: 17.5, d: 18.5 },
    { r: 'Tawi', st: 'Jammu', w: 8.2, d: 9.3 },
    { r: 'Chenab', st: 'Akhnoor', w: 33.4, d: 34.8 },
  ],
  karnataka: [
    { r: 'Krishna', st: 'Almatti', w: 519.0, d: 520.2 },
    { r: 'Tungabhadra', st: 'Hospet', w: 490.5, d: 491.8 },
    { r: 'Cauvery', st: 'Krishna Raja Sagar', w: 123.4, d: 124.5 },
    { r: 'Sharavathi', st: 'Sagar', w: 581.0, d: 582.4 },
  ],
  ladakh: [
    { r: 'Indus', st: 'Leh', w: 3504.0, d: 3505.2 },
    { r: 'Shyok', st: 'Diskit', w: 3140.5, d: 3141.6 },
    { r: 'Zanskar', st: 'Padum', w: 3661.0, d: 3662.1 },
  ],
  lakshadweep: [
    { r: 'Kavaratti Lagoon', st: 'Kavaratti', w: 1.4, d: 1.9 },
    { r: 'Agatti Lagoon', st: 'Agatti', w: 1.3, d: 1.8 },
    { r: 'Minicoy Lagoon', st: 'Minicoy', w: 1.6, d: 2.1 },
  ],
  'madhya pradesh': [
    { r: 'Narmada', st: 'Hoshangabad', w: 295.0, d: 296.3 },
    { r: 'Chambal', st: 'Morena', w: 147.5, d: 148.9 },
    { r: 'Betwa', st: 'Vidisha', w: 425.2, d: 426.6 },
    { r: 'Tawa', st: 'Itarsi', w: 332.4, d: 333.5 },
  ],
  manipur: [
    { r: 'Imphal', st: 'Imphal', w: 780.0, d: 781.3 },
    { r: 'Iril', st: 'Lilong', w: 786.5, d: 787.7 },
    { r: 'Barak', st: 'Tipaimukh', w: 275.4, d: 276.8 },
  ],
  meghalaya: [
    { r: 'Umngot', st: 'Dawki', w: 112.5, d: 113.6 },
    { r: 'Simsang', st: 'Williamnagar', w: 182.0, d: 183.4 },
    { r: 'Myntdu', st: 'Jowai', w: 139.5, d: 140.8 },
  ],
  mizoram: [
    { r: 'Tlawng', st: 'Aizawl', w: 114.0, d: 115.1 },
    { r: 'Tuivawl', st: 'Sairang', w: 105.5, d: 106.9 },
    { r: 'Chhimtuipui', st: 'Saiha', w: 93.5, d: 94.8 },
  ],
  nagaland: [
    { r: 'Dhansiri', st: 'Dimapur', w: 144.8, d: 146.0 },
    { r: 'Doyang', st: 'Wokha', w: 134.4, d: 135.8 },
    { r: 'Dikhu', st: 'Mokokchung', w: 122.6, d: 123.9 },
  ],
  'west bengal': [
    { r: 'Ganga', st: 'Farakka Barrage', w: 21.4, d: 22.2 },
    { r: 'Teesta', st: 'Domohani', w: 84.9, d: 85.9 },
    { r: 'Jaldhaka', st: 'NH-31 Bridge', w: 79.5, d: 80.5 },
  ],
  odisha: [
    { r: 'Mahanadi', st: 'Naraj (Cuttack)', w: 25.4, d: 26.4 },
    { r: 'Subarnarekha', st: 'Rajghat', w: 9.4, d: 10.3 },
    { r: 'Brahmani', st: 'Jenapur', w: 22.0, d: 23.0 },
  ],
  delhi: [
    { r: 'Yamuna', st: 'Old Railway Bridge (ORB)', w: 204.5, d: 205.33 },
  ],
  gujarat: [
    { r: 'Narmada', st: 'Garudeshwar', w: 30.5, d: 31.5 },
    { r: 'Tapi', st: 'Ukai Dam', w: 103.5, d: 105.1 },
    { r: 'Vishwamitri', st: 'Vadodara', w: 8.0, d: 9.0 },
  ],
  punjab: [
    { r: 'Sutlej', st: 'Harike', w: 230.0, d: 231.5 },
    { r: 'Beas', st: 'Kapurthala Reach', w: 214.4, d: 215.8 },
    { r: 'Ravi', st: 'Madhopur', w: 256.0, d: 257.2 },
    { r: 'Ghaggar', st: 'Derabassi', w: 8.5, d: 9.6 },
  ],
  puducherry: [
    { r: 'Sankaraparani', st: 'Puducherry', w: 2.8, d: 3.5 },
    { r: 'Gingee', st: 'Bahour', w: 3.2, d: 4.0 },
    { r: 'Arasalar', st: 'Karaikal', w: 2.6, d: 3.3 },
  ],
  rajasthan: [
    { r: 'Chambal', st: 'Kota', w: 245.2, d: 246.7 },
    { r: 'Banas', st: 'Tonk', w: 255.8, d: 257.0 },
    { r: 'Luni', st: 'Balotra', w: 105.5, d: 106.9 },
    { r: 'Mahi', st: 'Banswara', w: 214.0, d: 215.2 },
  ],
  sikkim: [
    { r: 'Teesta', st: 'Mangan', w: 892.0, d: 893.5 },
    { r: 'Rangit', st: 'Jorethang', w: 305.0, d: 306.4 },
    { r: 'Rangpo', st: 'Rangpo', w: 291.0, d: 292.3 },
  ],
  'tamil nadu': [
    { r: 'Cauvery', st: 'Mettur', w: 221.5, d: 222.8 },
    { r: 'Kollidam', st: 'Lower Anaicut', w: 8.8, d: 9.8 },
    { r: 'Vaigai', st: 'Madurai', w: 8.0, d: 9.0 },
    { r: 'Tamiraparani', st: 'Tirunelveli', w: 5.6, d: 6.6 },
  ],
  telangana: [
    { r: 'Godavari', st: 'Kaleshwaram', w: 102.5, d: 104.0 },
    { r: 'Musi', st: 'Hyderabad', w: 5.8, d: 6.6 },
    { r: 'Manjira', st: 'Nizamabad', w: 12.0, d: 13.3 },
    { r: 'Krishna', st: 'Nagarjuna Sagar', w: 172.0, d: 173.2 },
  ],
  tripura: [
    { r: 'Gumti', st: 'Sonamura', w: 22.3, d: 23.4 },
    { r: 'Manu', st: 'Kailashahar', w: 24.0, d: 25.2 },
    { r: 'Khowai', st: 'Khowai', w: 17.8, d: 18.9 },
  ],
  uttarakhand: [
    { r: 'Ganga', st: 'Rishikesh', w: 339.5, d: 340.5 },
    { r: 'Ganga', st: 'Haridwar (Bhimgoda)', w: 293.0, d: 294.0 },
    { r: 'Alaknanda', st: 'Rudraprayag', w: 626.0, d: 627.0 },
  ],
};

function normalizeKey(value: string | undefined | null): string {
  return (value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function normalizeStateKey(stateName: string | undefined | null): string {
  const key = normalizeKey(stateName);
  if (key === 'orissa') return 'odisha';
  if (key === 'nct of delhi' || key === 'new delhi') return 'delhi';
  if (key === 'uttaranchal') return 'uttarakhand';
  if (key === 'pondicherry') return 'puducherry';
  if (key === 'dadra & nagar haveli and daman & diu') return 'dadra and nagar haveli and daman and diu';
  return key;
}

function hashValue(input: string): number {
  let hash = 0;
  for (let index = 0; index < input.length; index += 1) {
    hash = (hash << 5) - hash + input.charCodeAt(index);
    hash |= 0;
  }
  return Math.abs(hash);
}

function seededUnit(seed: string): number {
  const hash = hashValue(seed);
  return (hash % 1000) / 1000;
}

function buildStatus(current: number, warning: number, danger: number): CWCSensorData['status'] {
  if (current >= danger) return 'CRITICAL';
  if (current >= warning) return 'WARNING';
  return 'ACTIVE';
}

function buildUpdateTime(offsetMs: number): string {
  return new Date(Date.now() - offsetMs).toLocaleTimeString('en-IN', { hour12: false });
}

export function getHydrologyBasinsForState(stateName: string): BasinRegistryEntry[] {
  return INDIA_RIVER_BASIN_REGISTRY[normalizeStateKey(stateName)] || UNKNOWN_STATE_FALLBACK;
}

export function getPreferredHydrologyNode(
  nodes: CWCSensorData[],
  preferredLocation?: string,
): CWCSensorData | null {
  if (!nodes.length) return null;

  const target = normalizeKey(preferredLocation);
  if (target) {
    const matched = nodes.find(
      (node) =>
        normalizeKey(node.station).includes(target) ||
        normalizeKey(node.river).includes(target),
    );
    if (matched) return matched;
  }

  return nodes[0];
}

export function generateTacticalCWCData(
  stateName: string,
  preferredLocation?: string,
): CWCSensorData[] {
  const basins = getHydrologyBasinsForState(stateName);
  const timeBucket = Math.floor(Date.now() / (30 * 60 * 1000));
  const normalizedState = normalizeStateKey(stateName) || 'active-region';

  const nodes = basins.map((basin, index) => {
    const seed = `${normalizedState}|${basin.st}|${timeBucket}|${index}`;
    const threatMultiplier = seededUnit(`${seed}|threat`);

    let current = basin.w - (0.8 + seededUnit(`${seed}|safe`) * 2.2);
    if (threatMultiplier > 0.85) {
      current = basin.d + seededUnit(`${seed}|critical`) * 0.5;
    } else if (threatMultiplier > 0.6) {
      current = basin.w + seededUnit(`${seed}|warning`) * Math.max(basin.d - basin.w, 0.6);
    }

    const rainfall = Number((seededUnit(`${seed}|rain`) * 18).toFixed(1));
    const trendChance = seededUnit(`${seed}|trend`);
    const trend: CWCSensorData['trend'] =
      trendChance > 0.66 ? 'RISING' : trendChance > 0.33 ? 'FALLING' : 'STEADY';
    const currentLevel = Number(current.toFixed(2));
    const status = buildStatus(currentLevel, basin.w, basin.d);

    return {
      id: `CWC-${hashValue(`${seed}|id`).toString(36).slice(0, 6).toUpperCase()}`,
      state: stateName,
      river: basin.r,
      station: basin.st,
      currentLevel,
      warningLevel: basin.w,
      dangerLevel: basin.d,
      rainfallLastHour: rainfall,
      status,
      trend,
      updateTime: buildUpdateTime(seededUnit(`${seed}|time`) * 60 * 60 * 1000),
      source: 'TACTICAL_REGISTRY' as const,
    };
  });

  const preferredNode = getPreferredHydrologyNode(nodes, preferredLocation);
  if (!preferredNode) return nodes;

  return [preferredNode, ...nodes.filter((node) => node.station !== preferredNode.station)];
}

export function tacticalCWCDataToSensors(nodes: CWCSensorData[]): SensorData[] {
  return nodes.map((node) => ({
    station: node.station,
    river_level: node.currentLevel,
    flow_rate: Number((node.currentLevel * 12.4).toFixed(1)),
    rainfall_last_hour: node.rainfallLastHour ?? 0,
    status: node.status,
    last_update: node.updateTime,
    river: node.river,
    warning_level: node.warningLevel,
    danger_level: node.dangerLevel,
    trend: node.trend,
    state: node.state,
    source: node.source,
  }));
}

export function mergeSensorTelemetry(
  primarySensors: SensorData[],
  tacticalSensors: SensorData[],
): SensorData[] {
  const merged = new Map<string, SensorData>();

  [...primarySensors, ...tacticalSensors].forEach((sensor) => {
    const key = normalizeKey(sensor.station);
    if (!key) return;

    if (!merged.has(key)) {
      merged.set(key, sensor);
      return;
    }

    const existing = merged.get(key)!;
    merged.set(key, {
      ...sensor,
      river_level: sensor.river_level ?? existing.river_level,
      rainfall_last_hour: sensor.rainfall_last_hour ?? existing.rainfall_last_hour,
      flow_rate: sensor.flow_rate ?? existing.flow_rate,
      status: sensor.status || existing.status,
      last_update: sensor.last_update || existing.last_update,
      river: sensor.river || existing.river,
      warning_level: sensor.warning_level ?? existing.warning_level,
      danger_level: sensor.danger_level ?? existing.danger_level,
      trend: sensor.trend || existing.trend,
      state: sensor.state || existing.state,
      source: sensor.source || existing.source,
    });
  });

  return Array.from(merged.values()).sort(
    (left, right) => Number(right.river_level || 0) - Number(left.river_level || 0),
  );
}
