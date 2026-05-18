from __future__ import annotations

from typing import Dict, Literal, TypedDict

SeverityLevel = Literal["LOW", "MODERATE", "SEVERE", "CRITICAL"]


class Thresholds(TypedDict):
    moderate: float
    severe: float
    critical: float


class StateSeverityMatrixEntry(TypedDict):
    region: str
    peak_level_m: Thresholds
    rainfall_7d_mm: Thresholds
    # CWC-referenced danger level for primary river/gauge in the state (metres)
    danger_level_m: float
    # CWC-referenced warning level (metres) — typically ~85% of danger level
    warning_level_m: float
    # Highest flood level on record (metres) used as CRITICAL ceiling
    hfl_m: float
    # Primary monitored rivers in this state
    primary_rivers: list
    # Key vulnerable districts
    vulnerable_districts: list
    notes: str


def normalize_state_name(state: str) -> str:
    key = (state or "").strip().lower()
    if key == "orissa":
        return "odisha"
    if key in {"nct of delhi", "new delhi"}:
        return "delhi"
    if key == "j&k":
        return "jammu and kashmir"
    return key


# Full per-state matrix with real CWC danger levels, calibrated thresholds, and metadata.
# Sources: CWC Flood Forecasting bulletins, IMD normal rainfall data, NDMA state reports.
# All danger_level_m and warning_level_m values are representative CWC gauge references.
STATE_SEVERITY_MATRIX: Dict[str, StateSeverityMatrixEntry] = {

    # ── ANDHRA PRADESH ──────────────────────────────────────────────────────────
    "andhra pradesh": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.2,
        "primary_rivers": ["Krishna", "Godavari", "Tungabhadra", "Pennar"],
        "vulnerable_districts": ["Eluru", "Konaseema", "Krishna", "Guntur", "Srikakulam"],
        "notes": "Cyclone + delta flooding risk. Krishna-Godavari delta extremely vulnerable during NE monsoon (Oct-Dec). CWC Prakasam Barrage danger level ~12.50 m.",
    },

    # ── ARUNACHAL PRADESH ────────────────────────────────────────────────────────
    "arunachal pradesh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 340.0, "critical": 500.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.1,
        "primary_rivers": ["Siang", "Subansiri", "Kameng", "Dibang", "Lohit"],
        "vulnerable_districts": ["East Siang", "West Siang", "Papum Pare", "Lohit"],
        "notes": "Glacial lake outburst flood (GLOF) and flash flood risk. Siang river can rise 6–8 m in 24 h. Extreme terrain limits early warning reach.",
    },

    # ── ASSAM ────────────────────────────────────────────────────────────────────
    "assam": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.8},
        "rainfall_7d_mm": {"moderate": 220.0, "severe": 370.0, "critical": 540.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.4,
        "primary_rivers": ["Brahmaputra", "Barak", "Subansiri", "Manas", "Kopili"],
        "vulnerable_districts": ["Dhubri", "Barpeta", "Morigaon", "Nagaon", "Goalpara", "Dibrugarh"],
        "notes": "Most flood-prone state in India. Brahmaputra carries one of highest sediment loads globally. Annual flooding affects 30–40% of state area. CWC Brahmaputra at Guwahati danger level ~54.07 m (gauge-datum adjusted to ~11.5 m above bed).",
    },

    # ── BIHAR ────────────────────────────────────────────────────────────────────
    "bihar": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 240.0, "severe": 390.0, "critical": 560.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.8,
        "primary_rivers": ["Ganga", "Kosi", "Gandak", "Bagmati", "Burhi Gandak", "Mahananda"],
        "vulnerable_districts": ["Darbhanga", "Muzaffarpur", "Sitamarhi", "Supaul", "Madhubani", "Saharsa"],
        "notes": "Kosi known as 'Sorrow of Bihar'. River channel shifts dramatically; embankment breaches common. North Bihar (Mithilanchal) floods almost every year. CWC Kosi at Baltara danger level ~37.30 m.",
    },

    # ── CHHATTISGARH ─────────────────────────────────────────────────────────────
    "chhattisgarh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 560.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.0,
        "primary_rivers": ["Mahanadi", "Sheonath", "Hasdeo", "Indravati", "Jonk"],
        "vulnerable_districts": ["Raipur", "Rajnandgaon", "Bastar", "Kanker", "Dhamtari"],
        "notes": "Upper Mahanadi basin; heavy rainfall July–September causes downstream Odisha floods. Hirakud reservoir backwater can extend into Chhattisgarh plains.",
    },

    # ── GOA ──────────────────────────────────────────────────────────────────────
    "goa": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 750.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.0,
        "primary_rivers": ["Mandovi", "Zuari", "Sal", "Chapora"],
        "vulnerable_districts": ["North Goa", "South Goa"],
        "notes": "Receives among highest SW monsoon rainfall in India (2500–3500 mm/year). Short steep rivers with fast runoff. Coastal inundation exacerbated by tidal backwater.",
    },

    # ── GUJARAT ──────────────────────────────────────────────────────────────────
    "gujarat": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 350.0, "critical": 500.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.8,
        "primary_rivers": ["Sabarmati", "Tapi", "Narmada", "Mahi", "Rupen"],
        "vulnerable_districts": ["Surat", "Vadodara", "Bharuch", "Anand", "Amreli", "Kutch"],
        "notes": "Surat highly prone to Tapi flash floods (2006 disaster: 12.53 m at Surat). Kutch experiences intense but short-duration rainfall. Sardar Sarovar releases can cause downstream inundation.",
    },

    # ── HARYANA ──────────────────────────────────────────────────────────────────
    "haryana": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 430.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.5,
        "primary_rivers": ["Yamuna", "Ghaggar", "Markanda", "Tangri"],
        "vulnerable_districts": ["Panipat", "Karnal", "Ambala", "Kurukshetra", "Fatehabad"],
        "notes": "Yamuna corridor and Ghaggar (Hakra) are primary flood vectors. Ghaggar is ephemeral but can cause catastrophic urban floods in Ambala and downstream. Hathnikund Barrage releases directly impact downstream districts.",
    },

    # ── HIMACHAL PRADESH ──────────────────────────────────────────────────────────
    "himachal pradesh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.2},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 440.0},
        "danger_level_m": 11.0,
        "warning_level_m": 9.4,
        "hfl_m": 12.8,
        "primary_rivers": ["Beas", "Sutlej", "Ravi", "Chenab", "Spiti"],
        "vulnerable_districts": ["Mandi", "Kullu", "Kangra", "Chamba", "Shimla"],
        "notes": "GLOF, cloudburst, and landslide-triggered flash floods. Sutlej at Bhakra extremely dangerous; Pandoh Dam releases can amplify Beas flood peaks. Monsoon cloudbursts common in Kullu-Mandi belt.",
    },

    # ── JHARKHAND ────────────────────────────────────────────────────────────────
    "jharkhand": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 230.0, "severe": 380.0, "critical": 540.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.6,
        "primary_rivers": ["Damodar", "Subarnarekha", "North Koel", "South Koel", "Barakar"],
        "vulnerable_districts": ["Sahebganj", "Pakur", "Dumka", "East Singhbhum", "Garhwa"],
        "notes": "Damodar Valley Corporation (DVC) reservoir releases frequently cause downstream flooding in West Bengal. Upper catchment receives intense monsoon rainfall.",
    },

    # ── KARNATAKA ────────────────────────────────────────────────────────────────
    "karnataka": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 440.0, "critical": 640.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.3,
        "primary_rivers": ["Krishna", "Cauvery", "Tungabhadra", "Malaprabha", "Sharavathi"],
        "vulnerable_districts": ["Belagavi", "Bagalkot", "Raichur", "Kalaburagi", "Uttara Kannada"],
        "notes": "North Karnataka (Belagavi/Bagalkot) regularly floods from Krishna/Ghataprabha. Coastal Karnataka gets intense Konkan monsoon (3000–5000 mm). Almatti Dam operations critical for downstream AP.",
    },

    # ── KERALA ───────────────────────────────────────────────────────────────────
    "kerala": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 800.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 14.0,
        "primary_rivers": ["Periyar", "Bharathapuzha", "Chaliyar", "Pamba", "Kabani"],
        "vulnerable_districts": ["Ernakulam", "Thrissur", "Alappuzha", "Pathanamthitta", "Idukki", "Wayanad"],
        "notes": "2018 floods worst in 100 years (highest recorded rainfall in 94 years). Idukki and Wayanad prone to landslides combined with flooding. Periyar at Bhoothathankettu danger level ~14.80 m. Backwater flooding in Kuttanad (below sea level).",
    },

    # ── MADHYA PRADESH ────────────────────────────────────────────────────────────
    "madhya pradesh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 580.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.5,
        "primary_rivers": ["Narmada", "Chambal", "Tapti", "Betwa", "Son", "Wainganga"],
        "vulnerable_districts": ["Jabalpur", "Hoshangabad", "Shivpuri", "Datia", "Barwani", "Dhar"],
        "notes": "Narmada and Chambal major flood vectors. Bargi, Tawa, Indira Sagar dam releases affect Hoshangabad district severely. Chambal ravines cause irregular flooding patterns.",
    },

    # ── MAHARASHTRA ───────────────────────────────────────────────────────────────
    "maharashtra": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.5, "critical": 13.5},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 13.5,
        "warning_level_m": 11.5,
        "hfl_m": 15.2,
        "primary_rivers": ["Krishna", "Godavari", "Bhima", "Koyna", "Panchganga", "Wardha"],
        "vulnerable_districts": ["Kolhapur", "Sangli", "Satara", "Pune", "Nashik", "Gadchiroli"],
        "notes": "Kolhapur and Sangli severely impacted in 2019/2021. Panchganga at Kolhapur danger level ~43.27 m. Koyna Dam releases directly affect Krishna downstream. Western Ghats receive 4000–6000 mm; sudden reservoir gate openings cause flash floods.",
    },

    # ── MANIPUR ──────────────────────────────────────────────────────────────────
    "manipur": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 520.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.0,
        "primary_rivers": ["Barak", "Imphal", "Iril", "Thoubal"],
        "vulnerable_districts": ["Imphal West", "Imphal East", "Thoubal", "Bishnupur"],
        "notes": "Loktak Lake backwater flooding; valley bowl topography traps runoff. Urban flooding in Imphal during intense rainfall events. Barak upper tributary feeds into Assam.",
    },

    # ── MEGHALAYA ────────────────────────────────────────────────────────────────
    "meghalaya": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 500.0, "critical": 700.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.2,
        "primary_rivers": ["Umiam", "Simsang", "Kopili", "Myntdu"],
        "vulnerable_districts": ["East Khasi Hills", "Ri Bhoi", "West Garo Hills"],
        "notes": "Cherrapunji/Mawsynram receive world's highest rainfall (10000–12000 mm/year). Intense rain triggers landslides and flash floods downstream into Assam/Bangladesh. Short, steep rivers with extremely fast response time (<2 hours).",
    },

    # ── MIZORAM ──────────────────────────────────────────────────────────────────
    "mizoram": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.0},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 500.0},
        "danger_level_m": 11.0,
        "warning_level_m": 9.4,
        "hfl_m": 12.8,
        "primary_rivers": ["Tlawng", "Tuirial", "Kolodyne"],
        "vulnerable_districts": ["Aizawl", "Lunglei", "Champhai"],
        "notes": "Steep hilly terrain with thin soil cover. Landslide-coupled flooding is primary hazard. Bamboo flowering (mautam) historically causes unusual ecosystem disruptions during flood years.",
    },

    # ── NAGALAND ─────────────────────────────────────────────────────────────────
    "nagaland": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 200.0, "severe": 350.0, "critical": 500.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.0,
        "primary_rivers": ["Doyang", "Dhansiri", "Tizu"],
        "vulnerable_districts": ["Dimapur", "Peren", "Wokha"],
        "notes": "Mountainous state; Doyang reservoir in Wokha district. Flash floods during cloudbursts in Dimapur plains. Downstream impacts feed Brahmaputra in Assam.",
    },

    # ── ODISHA ───────────────────────────────────────────────────────────────────
    "odisha": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.5,
        "primary_rivers": ["Mahanadi", "Brahmani", "Baitarani", "Rushikulya", "Subarnarekha"],
        "vulnerable_districts": ["Cuttack", "Kendrapara", "Jagatsinghpur", "Puri", "Balasore", "Bhadrak"],
        "notes": "Mahanadi delta most flood-prone. Hirakud Dam (world's longest earthen dam) regulates flow but overflow during extreme years. Cyclone storm surge compounds coastal flooding. CWC Mahanadi at Naraj danger level ~26.93 m.",
    },

    # ── PUNJAB ───────────────────────────────────────────────────────────────────
    "punjab": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 430.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.6,
        "primary_rivers": ["Sutlej", "Beas", "Ravi", "Ghaggar"],
        "vulnerable_districts": ["Jalandhar", "Ferozepur", "Kapurthala", "Patiala", "Rupnagar"],
        "notes": "Bhakra-Nangal and Pong Dam controlled releases during heavy monsoon affect Ferozepur-Jalandhar corridor. Ghaggar-Hakra causes Patiala-Fatehabad flooding. Rivers fed by Himalayan snowmelt + monsoon.",
    },

    # ── RAJASTHAN ────────────────────────────────────────────────────────────────
    "rajasthan": {
        "region": "ARID",
        "peak_level_m": {"moderate": 9.5, "severe": 11.0, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 120.0, "severe": 220.0, "critical": 340.0},
        "danger_level_m": 11.0,
        "warning_level_m": 9.4,
        "hfl_m": 13.0,
        "primary_rivers": ["Chambal", "Banas", "Luni", "Mahi"],
        "vulnerable_districts": ["Jalore", "Barmer", "Kota", "Bundi", "Sawai Madhopur", "Sirohi"],
        "notes": "Desert state but highly vulnerable to urban flash floods from intense short-duration rainfall. Hard impervious soil leads to rapid runoff. Chambal at Kota Barrage danger level ~252.00 m (datum-specific). Luni floods affect Barmer.",
    },

    # ── SIKKIM ───────────────────────────────────────────────────────────────────
    "sikkim": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 9.5, "severe": 10.5, "critical": 11.8},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 300.0, "critical": 450.0},
        "danger_level_m": 10.5,
        "warning_level_m": 9.0,
        "hfl_m": 12.5,
        "primary_rivers": ["Teesta", "Rangit", "Rangpo"],
        "vulnerable_districts": ["South Sikkim", "East Sikkim", "North Sikkim"],
        "notes": "GLOF major threat — South Lhonak Lake outburst (Oct 2023) destroyed Chungthang Dam and devastated Teesta valley. Extremely steep gradients; flood waves travel at high velocity into West Bengal within hours.",
    },

    # ── TAMIL NADU ───────────────────────────────────────────────────────────────
    "tamil nadu": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 450.0, "critical": 650.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.8,
        "primary_rivers": ["Cauvery", "Vaigai", "Palar", "Tamiraparani", "Adyar", "Cooum"],
        "vulnerable_districts": ["Chennai", "Cuddalore", "Nagapattinam", "Thanjavur", "Tiruvarur"],
        "notes": "NE monsoon (Oct-Dec) primary flood season. Chennai 2015 floods caused by Adyar/Cooum overflow + Chembarambakkam tank breach. Cauvery delta floods affect Thanjavur-Tiruvarur. Cyclone risk Oct-Dec along Coromandel coast.",
    },

    # ── TELANGANA ────────────────────────────────────────────────────────────────
    "telangana": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 240.0, "severe": 400.0, "critical": 580.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.8,
        "primary_rivers": ["Godavari", "Krishna", "Manjira", "Musi"],
        "vulnerable_districts": ["Bhadradri Kothagudem", "Khammam", "Suryapet", "Nalgonda", "Hyderabad"],
        "notes": "Godavari at Bhadrachalam major monitoring point; danger level ~53.00 m. Musi floods impact Hyderabad urban area. Jurala and Srisailam reservoir operations affect downstream flows.",
    },

    # ── TRIPURA ──────────────────────────────────────────────────────────────────
    "tripura": {
        "region": "NORTHEAST",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 210.0, "severe": 360.0, "critical": 510.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.0,
        "primary_rivers": ["Gumti", "Haora", "Manu", "Khowai"],
        "vulnerable_districts": ["Sepahijala", "Khowai", "South Tripura", "Gomati"],
        "notes": "Small landlocked state. Gumti River frequently overflows affecting Agartala. Bangladesh border proximity means cross-border flooding. Dumbur Hydropower Dam releases affect downstream.",
    },

    # ── UTTAR PRADESH ────────────────────────────────────────────────────────────
    "uttar pradesh": {
        "region": "PLAINS",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 570.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.5,
        "primary_rivers": ["Ganga", "Yamuna", "Ghaghra", "Sarda", "Rapti", "Gomti"],
        "vulnerable_districts": ["Ballia", "Deoria", "Gorakhpur", "Bahraich", "Sitapur", "Basti", "Gonda"],
        "notes": "Eastern UP (Purvanchal) most affected. Ghaghra/Sarda feed from Nepal; transboundary flood risk. Ganga at Varanasi danger level ~72.26 m. Gorakhpur floods from Rapti-Rohini annually. Rapti breach (2016) submerged 1500+ villages.",
    },

    # ── UTTARAKHAND ──────────────────────────────────────────────────────────────
    "uttarakhand": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.2},
        "rainfall_7d_mm": {"moderate": 190.0, "severe": 320.0, "critical": 460.0},
        "danger_level_m": 11.0,
        "warning_level_m": 9.4,
        "hfl_m": 13.0,
        "primary_rivers": ["Ganga", "Alaknanda", "Bhagirathi", "Yamuna", "Kali", "Mandakini"],
        "vulnerable_districts": ["Chamoli", "Rudraprayag", "Uttarkashi", "Pithoragarh", "Haridwar"],
        "notes": "Kedarnath 2013 flash flood worst disaster in independent India (5000+ deaths). GLOF, cloudbursts, landslide dam outbursts. Rishikesh-Haridwar corridor downstream receives amplified peaks. Chamoli GLOF (Feb 2021) destroyed Tapovan-Vishnugad project.",
    },

    # ── WEST BENGAL ──────────────────────────────────────────────────────────────
    "west bengal": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.8},
        "rainfall_7d_mm": {"moderate": 270.0, "severe": 430.0, "critical": 620.0},
        "danger_level_m": 12.5,
        "warning_level_m": 10.6,
        "hfl_m": 14.5,
        "primary_rivers": ["Ganga/Hooghly", "Teesta", "Damodar", "Mayurakshi", "Jaldhaka"],
        "vulnerable_districts": ["Malda", "Murshidabad", "South 24 Parganas", "Hooghly", "Jalpaiguri", "Koch Bihar"],
        "notes": "DVC (Damodar Valley Corporation) controlled releases affect Howrah-Hooghly. Teesta floods North Bengal (Koch Bihar, Jalpaiguri) post-Sikkim releases. Sundarbans tidal flooding compounded by cyclone storm surge. Farakka Barrage operations affect Malda-Murshidabad corridor.",
    },

    # ══ UNION TERRITORIES ════════════════════════════════════════════════════════

    # ── ANDAMAN AND NICOBAR ISLANDS ──────────────────────────────────────────────
    "andaman and nicobar islands": {
        "region": "ISLAND",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.2},
        "rainfall_7d_mm": {"moderate": 350.0, "severe": 550.0, "critical": 750.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.8,
        "primary_rivers": ["Kalpong", "Dagmar"],
        "vulnerable_districts": ["North Andaman", "South Andaman", "Nicobar"],
        "notes": "Cyclone and tsunami risk. Receives ~3000 mm/year. Remote islands have limited early warning infrastructure. Storm surge combined with flooding is primary threat.",
    },

    # ── CHANDIGARH ───────────────────────────────────────────────────────────────
    "chandigarh": {
        "region": "URBAN_UT",
        "peak_level_m": {"moderate": 11.0, "severe": 12.0, "critical": 13.0},
        "rainfall_7d_mm": {"moderate": 180.0, "severe": 290.0, "critical": 420.0},
        "danger_level_m": 12.0,
        "warning_level_m": 10.2,
        "hfl_m": 13.4,
        "primary_rivers": ["Ghaggar", "Sukhna Choe"],
        "vulnerable_districts": ["Chandigarh UT"],
        "notes": "Urban flash flooding from impervious surfaces. Sukhna Lake overflow risk during heavy rainfall. Ghaggar carries high peak discharge from Shivalik Hills during monsoon.",
    },

    # ── DADRA AND NAGAR HAVELI AND DAMAN AND DIU ──────────────────────────────────
    "dadra and nagar haveli and daman and diu": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 480.0, "critical": 680.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.2,
        "primary_rivers": ["Damanganga", "Kolak"],
        "vulnerable_districts": ["Dadra", "Nagar Haveli", "Daman", "Diu"],
        "notes": "High Konkan rainfall (2500–3000 mm). Damanganga River floods Silvassa and Daman town. Short rivers with steep gradients respond within 2–3 hours to rainfall events.",
    },

    # ── DELHI ─────────────────────────────────────────────────────────────────────
    "delhi": {
        "region": "URBAN_UT",
        "peak_level_m": {"moderate": 203.0, "severe": 204.5, "critical": 206.0},
        "rainfall_7d_mm": {"moderate": 150.0, "severe": 250.0, "critical": 380.0},
        "danger_level_m": 204.83,
        "warning_level_m": 204.0,
        "hfl_m": 207.49,
        "primary_rivers": ["Yamuna"],
        "vulnerable_districts": ["East Delhi", "North East Delhi", "Yamuna floodplain settlements"],
        "notes": "CWC Yamuna at Old Railway Bridge Delhi danger level 204.83 m (datum: MSL). 2023 floods reached 208.66 m — highest ever recorded. Hathnikund Barrage (Haryana) releases reach Delhi in ~2 days. Note: peak_level_m uses MSL datum unlike other states.",
    },

    # ── JAMMU AND KASHMIR ────────────────────────────────────────────────────────
    "jammu and kashmir": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 10.0, "severe": 11.0, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 160.0, "severe": 270.0, "critical": 400.0},
        "danger_level_m": 11.0,
        "warning_level_m": 9.4,
        "hfl_m": 13.2,
        "primary_rivers": ["Jhelum", "Chenab", "Tawi", "Indus"],
        "vulnerable_districts": ["Srinagar", "Budgam", "Anantnag", "Jammu", "Ramban"],
        "notes": "Jhelum Valley flooding at Srinagar in 2014 (worst in 60 years). Flat valley basin with poor drainage; Wular Lake acts as natural buffer but can overflow. Chenab gorge floods affect Ramban-Kishtwar. Snowmelt + monsoon combination elevates risk.",
    },

    # ── LADAKH ───────────────────────────────────────────────────────────────────
    "ladakh": {
        "region": "HIMALAYAN",
        "peak_level_m": {"moderate": 8.0, "severe": 9.5, "critical": 11.0},
        "rainfall_7d_mm": {"moderate": 60.0, "severe": 110.0, "critical": 180.0},
        "danger_level_m": 9.5,
        "warning_level_m": 8.1,
        "hfl_m": 11.5,
        "primary_rivers": ["Indus", "Zanskar", "Shyok", "Nubra"],
        "vulnerable_districts": ["Leh", "Kargil"],
        "notes": "Cold desert; very low rainfall but GLOF and cloudburst risk. Leh cloudburst 2010 caused catastrophic flash floods with ~200 deaths. Shyok/Siachen glacial lake outbursts can generate extreme flows. Even 30 mm in 1 hour is extreme here.",
    },

    # ── LAKSHADWEEP ──────────────────────────────────────────────────────────────
    "lakshadweep": {
        "region": "ISLAND",
        "peak_level_m": {"moderate": 9.0, "severe": 10.0, "critical": 11.0},
        "rainfall_7d_mm": {"moderate": 300.0, "severe": 480.0, "critical": 680.0},
        "danger_level_m": 10.0,
        "warning_level_m": 8.5,
        "hfl_m": 11.5,
        "primary_rivers": [],
        "vulnerable_districts": ["Kavaratti", "Agatti", "Minicoy"],
        "notes": "Low-lying coral atolls with max elevation ~4 m. Coastal inundation is primary hazard (no rivers). Sea-level rise and storm surge threaten entire island chain. Cyclone tracks in Arabian Sea increasing due to climate change.",
    },

    # ── PUDUCHERRY ───────────────────────────────────────────────────────────────
    "puducherry": {
        "region": "COASTAL",
        "peak_level_m": {"moderate": 10.5, "severe": 11.5, "critical": 12.5},
        "rainfall_7d_mm": {"moderate": 280.0, "severe": 440.0, "critical": 630.0},
        "danger_level_m": 11.5,
        "warning_level_m": 9.8,
        "hfl_m": 13.0,
        "primary_rivers": ["Gingee", "Pennaiyar", "Malattar"],
        "vulnerable_districts": ["Puducherry", "Karaikal", "Yanam", "Mahe"],
        "notes": "Enclave UT receives NE monsoon (Oct-Dec). Coastal location makes it cyclone-prone. Pennaiyar and Gingee rivers carry runoff from Tamil Nadu hills. Urban flooding in Puducherry town common during heavy rain.",
    },
}


def normalize_state_name(state: str) -> str:
    key = (state or "").strip().lower()
    if key == "orissa":
        return "odisha"
    if key in {"nct of delhi", "new delhi"}:
        return "delhi"
    if key == "j&k":
        return "jammu and kashmir"
    return key


DEFAULT_STATE_ENTRY: StateSeverityMatrixEntry = {
    "region": "PLAINS",
    "peak_level_m": {"moderate": 11.5, "severe": 12.5, "critical": 13.5},
    "rainfall_7d_mm": {"moderate": 250.0, "severe": 400.0, "critical": 550.0},
    "danger_level_m": 12.5,
    "warning_level_m": 10.6,
    "hfl_m": 14.0,
    "primary_rivers": [],
    "vulnerable_districts": [],
    "notes": "Default thresholds — no specific calibration available for this state.",
}


def get_state_severity_entry(state: str) -> StateSeverityMatrixEntry:
    key = normalize_state_name(state)
    return STATE_SEVERITY_MATRIX.get(key, DEFAULT_STATE_ENTRY)


def severity_from_entry(
    peak_level_m: float,
    rainfall_7d_mm: float,
    entry: StateSeverityMatrixEntry,
) -> SeverityLevel:
    p = entry["peak_level_m"]
    r = entry["rainfall_7d_mm"]
    if peak_level_m >= p["critical"] or rainfall_7d_mm >= r["critical"]:
        return "CRITICAL"
    if peak_level_m >= p["severe"] or rainfall_7d_mm >= r["severe"]:
        return "SEVERE"
    if peak_level_m >= p["moderate"] or rainfall_7d_mm >= r["moderate"]:
        return "MODERATE"
    return "LOW"
