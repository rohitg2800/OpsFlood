export interface GeoCoordinate {
  name: string;
  state?: string;
  lat: number;
  lon: number;
}

interface GeoCoordinateEntry extends GeoCoordinate {
  aliases: string[];
}

const GEO_ENTRIES: GeoCoordinateEntry[] = [
  { name: 'Amaravati', state: 'Andhra Pradesh', lat: 16.5062, lon: 80.648, aliases: ['amaravati', 'andhra pradesh', 'vijayawada'] },
  { name: 'Itanagar', state: 'Arunachal Pradesh', lat: 27.0844, lon: 93.6053, aliases: ['itanagar', 'arunachal pradesh'] },
  { name: 'Guwahati', state: 'Assam', lat: 26.1445, lon: 91.7362, aliases: ['guwahati', 'dispur', 'assam', 'dibrugarh', 'silchar'] },
  { name: 'Patna', state: 'Bihar', lat: 25.5941, lon: 85.1376, aliases: ['patna', 'bihar', 'darbhanga', 'basantpur', 'dumariaghat', 'patna ghat'] },
  { name: 'Raipur', state: 'Chhattisgarh', lat: 21.2514, lon: 81.6296, aliases: ['raipur', 'chhattisgarh'] },
  { name: 'Panaji', state: 'Goa', lat: 15.4909, lon: 73.8278, aliases: ['panaji', 'goa'] },
  { name: 'Gandhinagar', state: 'Gujarat', lat: 23.2156, lon: 72.6369, aliases: ['gandhinagar', 'gujarat', 'surat', 'ukai', 'tapi'] },
  { name: 'Chandigarh', state: 'Haryana', lat: 30.7333, lon: 76.7794, aliases: ['haryana', 'chandigarh'] },
  { name: 'Shimla', state: 'Himachal Pradesh', lat: 31.1048, lon: 77.1734, aliases: ['shimla', 'himachal pradesh'] },
  { name: 'Ranchi', state: 'Jharkhand', lat: 23.3441, lon: 85.3096, aliases: ['ranchi', 'jharkhand'] },
  { name: 'Bengaluru', state: 'Karnataka', lat: 12.9716, lon: 77.5946, aliases: ['bangalore', 'bengaluru', 'karnataka'] },
  { name: 'Thiruvananthapuram', state: 'Kerala', lat: 8.5241, lon: 76.9366, aliases: ['thiruvananthapuram', 'trivandrum', 'kerala', 'kochi', 'kuttanad', 'vembanad', 'periyar', 'aranmula'] },
  { name: 'Bhopal', state: 'Madhya Pradesh', lat: 23.2599, lon: 77.4126, aliases: ['bhopal', 'madhya pradesh'] },
  { name: 'Kolhapur', state: 'Maharashtra', lat: 16.705, lon: 74.2433, aliases: ['kolhapur', 'maharashtra', 'pune', 'mumbai', 'nashik', 'nagpur', 'shirol', 'kagal', 'kurundwad', 'rajaram barrage', 'irwin bridge'] },
  { name: 'Imphal', state: 'Manipur', lat: 24.817, lon: 93.9368, aliases: ['imphal', 'manipur'] },
  { name: 'Shillong', state: 'Meghalaya', lat: 25.5788, lon: 91.8933, aliases: ['shillong', 'meghalaya'] },
  { name: 'Aizawl', state: 'Mizoram', lat: 23.7271, lon: 92.7176, aliases: ['aizawl', 'mizoram'] },
  { name: 'Kohima', state: 'Nagaland', lat: 25.6751, lon: 94.1086, aliases: ['kohima', 'nagaland'] },
  { name: 'Bhubaneswar', state: 'Odisha', lat: 20.2961, lon: 85.8245, aliases: ['bhubaneswar', 'odisha', 'orissa', 'cuttack', 'puri', 'mahanadi'] },
  { name: 'Chandigarh', state: 'Punjab', lat: 30.7333, lon: 76.7794, aliases: ['punjab', 'ludhiana', 'amritsar', 'sutlej', 'ravi'] },
  { name: 'Jaipur', state: 'Rajasthan', lat: 26.9124, lon: 75.7873, aliases: ['jaipur', 'rajasthan'] },
  { name: 'Gangtok', state: 'Sikkim', lat: 27.3389, lon: 88.6065, aliases: ['gangtok', 'sikkim'] },
  { name: 'Chennai', state: 'Tamil Nadu', lat: 13.0827, lon: 80.2707, aliases: ['chennai', 'tamil nadu', 'madurai', 'coimbatore', 'kaveri', 'thanjavur'] },
  { name: 'Hyderabad', state: 'Telangana', lat: 17.385, lon: 78.4867, aliases: ['hyderabad', 'telangana'] },
  { name: 'Agartala', state: 'Tripura', lat: 23.8315, lon: 91.2868, aliases: ['agartala', 'tripura'] },
  { name: 'Lucknow', state: 'Uttar Pradesh', lat: 26.8467, lon: 80.9462, aliases: ['lucknow', 'uttar pradesh', 'varanasi', 'prayagraj', 'ghaghara'] },
  { name: 'Dehradun', state: 'Uttarakhand', lat: 30.3165, lon: 78.0322, aliases: ['dehradun', 'uttarakhand', 'rishikesh', 'joshimath', 'mandakini'] },
  { name: 'Kolkata', state: 'West Bengal', lat: 22.5726, lon: 88.3639, aliases: ['kolkata', 'west bengal', 'siliguri', 'hooghly', 'sundarbans', 'sundarbans delta'] },
  { name: 'Port Blair', state: 'Andaman and Nicobar Islands', lat: 11.6234, lon: 92.7265, aliases: ['port blair', 'andaman and nicobar islands', 'andaman'] },
  { name: 'Chandigarh', state: 'Chandigarh', lat: 30.7333, lon: 76.7794, aliases: ['union territory of chandigarh'] },
  { name: 'Daman', state: 'Dadra and Nagar Haveli and Daman and Diu', lat: 20.3974, lon: 72.8328, aliases: ['dadra and nagar haveli and daman and diu', 'daman', 'silvassa'] },
  { name: 'Delhi', state: 'Delhi', lat: 28.6139, lon: 77.209, aliases: ['delhi', 'new delhi', 'nct of delhi'] },
  { name: 'Srinagar', state: 'Jammu and Kashmir', lat: 34.0837, lon: 74.7973, aliases: ['jammu and kashmir', 'srinagar', 'jammu'] },
  { name: 'Leh', state: 'Ladakh', lat: 34.1526, lon: 77.577, aliases: ['ladakh', 'leh'] },
  { name: 'Kavaratti', state: 'Lakshadweep', lat: 10.5669, lon: 72.6417, aliases: ['lakshadweep', 'kavaratti'] },
  { name: 'Puducherry', state: 'Puducherry', lat: 11.9416, lon: 79.8083, aliases: ['puducherry', 'pondicherry'] },
];

export function normalizeGeoKey(value: string): string {
  return (value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const GEO_INDEX = GEO_ENTRIES.reduce<Record<string, GeoCoordinate>>((acc, entry) => {
  for (const alias of entry.aliases) {
    acc[normalizeGeoKey(alias)] = {
      name: entry.name,
      state: entry.state,
      lat: entry.lat,
      lon: entry.lon,
    };
  }
  return acc;
}, {});

const GEO_INDEX_ENTRIES = Object.entries(GEO_INDEX);

function findFuzzyGeoCoordinate(normalizedCandidate: string): GeoCoordinate | null {
  if (!normalizedCandidate || normalizedCandidate.length < 3) {
    return null;
  }

  const candidatePhrase = ` ${normalizedCandidate} `;
  let bestMatch: { coordinate: GeoCoordinate; score: number } | null = null;

  for (const [alias, coordinate] of GEO_INDEX_ENTRIES) {
    if (!alias || alias.length < 3) continue;

    const aliasPhrase = ` ${alias} `;
    if (!candidatePhrase.includes(aliasPhrase) && !aliasPhrase.includes(candidatePhrase)) {
      continue;
    }

    const score =
      aliasPhrase === candidatePhrase
        ? alias.length + 1000
        : Math.min(alias.length, normalizedCandidate.length);

    if (!bestMatch || score > bestMatch.score) {
      bestMatch = { coordinate, score };
    }
  }

  return bestMatch?.coordinate || null;
}

export function resolveGeoCoordinate(...candidates: Array<string | undefined | null>): GeoCoordinate | null {
  for (const candidate of candidates) {
    const normalized = normalizeGeoKey(candidate || '');
    if (!normalized) continue;
    if (GEO_INDEX[normalized]) {
      return GEO_INDEX[normalized];
    }

    const fuzzyMatch = findFuzzyGeoCoordinate(normalized);
    if (fuzzyMatch) {
      return fuzzyMatch;
    }
  }
  return null;
}

export function locationMatchesCandidate(
  location: Partial<GeoCoordinate> | null | undefined,
  candidate: string | undefined | null,
): boolean {
  const normalizedCandidate = normalizeGeoKey(candidate || '');
  if (!normalizedCandidate || !location) {
    return false;
  }

  const normalizedName = normalizeGeoKey(location.name || '');
  const normalizedState = normalizeGeoKey(location.state || '');

  return (
    (!!normalizedName &&
      (normalizedCandidate === normalizedName ||
        normalizedCandidate.includes(normalizedName) ||
        normalizedName.includes(normalizedCandidate))) ||
    (!!normalizedState && normalizedCandidate === normalizedState)
  );
}
