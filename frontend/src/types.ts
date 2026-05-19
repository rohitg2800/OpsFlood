// ==========================================
// COMPREHENSIVE TYPE DEFINITIONS & STATE MATRIX
// ==========================================

/**
 * SEVERITY LEVELS
 * Maps risk assessment to actionable categories
 */
export type SeverityLevel = 'SEVERE' | 'MODERATE' | 'LOW' | 'CRITICAL';

/**
 * SYSTEM STATUS
 * Tracks API, database, and service health
 */
export type SystemStatus = 'ONLINE' | 'DEGRADED' | 'OFFLINE' | 'INITIALIZING';
export type SourcePolicyMode = 'OPEN_DATA' | 'OFFICIAL_VIEW_ONLY' | 'FALLBACK';

/**
 * SENSOR STATUS
 * Monitors individual sensor health
 */
export type SensorStatus = 'ACTIVE' | 'WARNING' | 'CRITICAL' | 'OFFLINE' | 'MAINTENANCE';

/**
 * UI TAB STATE
 * Navigation routes within the application
 */
export type ActiveTab = 'dash' | 'logs' | 'weather' | 'map' | 'sensors' | 'analytics';

/**
 * ALERT TYPE
 * Different alert categories for UX
 */
export type AlertType = 'warning' | 'critical' | 'info' | 'success' | 'error';

/**
 * MODAL STATE
 * Tracks which modals are open
 */
export type ModalType = 'none' | 'settings' | 'help' | 'export' | 'history' | 'config';

// ==========================================
// DATA MODELS
// ==========================================

export interface Prediction {
  // Core Prediction Output
  severity: SeverityLevel;
  confidence_percent: number;
  alert: string;
  algorithm: string;
  data_source: string;
  model_trained: boolean;
  
  // Probability Matrix (Multi-class Classification)
  probabilities?: {
    HIGH?: number;
    SEVERE?: number;
    MODERATE?: number;
    LOW?: number;
    CRITICAL?: number;
  };
  
  // Risk Assessment
  risk_score?: number;           // 0-100 risk percentage
  danger_level?: number;         // Absolute danger level (e.g., 12.0m)
  proximity_to_danger_m?: number; // +m => below danger, -m => above danger
  critical_threshold?: number;   // Level at which CRITICAL is triggered

  
  // Monitoring & Response
  monitoring?: {
    level: string;              // e.g., "CRITICAL EMERGENCY", "ELEVATED ALERT"
    action: string;             // Recommended action
    priority_zones: string[];   // Areas needing immediate attention
  };
  
  // Metadata
  prediction_id?: number | null;
  timestamp?: string;
  state?: string;               // Indian state name
  peak_level_prediction?: number;
  ai_recommendations?: string[];
  source_policy?: SourcePolicy;

  // Per-state severity thresholds used by backend calibration
  state_matrix?: {
    region: string;
    peak_level_m: { moderate: number; severe: number; critical: number };
    rainfall_7d_mm: { moderate: number; severe: number; critical: number };
    danger_level_m: number;
    notes: string;
  };
}

export interface StoredPredictionRecord {
  id: number;
  timestamp: string;
  state?: string | null;
  city?: string | null;
  station?: string | null;
  peak_level: number;
  rainfall: number;
  severity: string;
  confidence: number;
  risk_score?: number | null;
  data_source?: string | null;
  algorithm?: string | null;
  model_version?: string | null;
  monitoring_level?: string | null;
  monitoring_action?: string | null;
  source_policy_mode?: string | null;
  source_policy_label?: string | null;
}

export interface TelemetrySnapshotRecord {
  id: number;
  timestamp: string;
  state?: string | null;
  station?: string | null;
  request_limit?: number | null;
  snapshot_status?: string | null;
  data_source?: string | null;
  source_policy_mode?: string | null;
  node_count?: number | null;
}

export interface AuditLogRecord {
  id: number;
  timestamp: string;
  event_type: string;
  route: string;
  event_status: string;
  state?: string | null;
  station?: string | null;
  severity?: string | null;
}

export interface SensorData {
  station: string;
  river_level: number;
  flow_rate: number;
  rainfall_last_hour: number;
  status: SensorStatus;
  last_update?: string;
  battery_level?: number;
  signal_strength?: number;
  river?: string;
  warning_level?: number;
  danger_level?: number;
  trend?: 'RISING' | 'FALLING' | 'STEADY';
  state?: string;
  source?: string;
}

export interface CWCSensorData {
  id: string;
  state: string;
  river: string;
  station: string;
  currentLevel: number;
  warningLevel: number;
  dangerLevel: number;
  rainfallLastHour?: number;
  status: Extract<SensorStatus, 'ACTIVE' | 'WARNING' | 'CRITICAL'>;
  trend: 'RISING' | 'FALLING' | 'STEADY';
  updateTime: string;
  source: 'CWC_API' | 'HTML_SCRAPE' | 'CACHED' | 'MANUAL' | 'TACTICAL_REGISTRY';
}

export interface MLAlert {
  id: string;
  type: AlertType;
  title: string;
  message: string;
  timestamp: string;
  severity?: SeverityLevel;
  confidence?: number;
  icon?: React.ReactNode;
  dismissible?: boolean;
}

export interface FormData {
  // Core Input Parameters (from ML model)
  Peak_Flood_Level_m: number;
  Event_Duration_days: number;
  Time_to_Peak_days: number;
  Recession_Time_day: number;
  
  // 7-Day Rainfall Distribution (mm per day)
  T1d: number;   // Day 1 rainfall
  T2d: number;   // Day 2 rainfall
  T3d: number;   // Day 3 rainfall
  T4d: number;   // Day 4 rainfall
  T5d: number;   // Day 5 rainfall
  T6d: number;   // Day 6 rainfall
  T7d: number;   // Day 7 rainfall (7-day total commonly used)
  
  // Location & Context
  state: string;         // Indian state/UT (e.g., "Maharashtra", "Kerala")
  station?: string;      // River gauge station name (e.g., "Kolhapur")
}

export interface SourcePolicyReference {
  label: string;
  title: string;
  url: string;
  usage: string;
}

export interface SourcePolicy {
  mode: SourcePolicyMode;
  label: string;
  description: string;
  allow_live_cwc_in_app: boolean;
  telemetry_mode: string;
  prediction_data_source: string;
  public_sources: SourcePolicyReference[];
}

// ==========================================
// STATE MATRIX DEFINITION
// ==========================================

/**
 * COMPREHENSIVE APPLICATION STATE
 * Single source of truth for entire app
 */
export interface AppState {
  // --------
  // UI STATE
  // --------
  ui: {
    activeTab: ActiveTab;
    modalOpen: ModalType;
    sidebarOpen: boolean;
    darkMode: boolean;
    notificationsEnabled: boolean;
  };

  // --------
  // API & SYSTEM STATE
  // --------
  system: {
    isOnline: any;
    apiStatus: SystemStatus;
    apiVersion: string;
    lastSyncTime: string | null;
    errorMessage: string | null;
    isInitialized: boolean;
    sourcePolicy: SourcePolicy;
  };

  // --------
  // PREDICTION STATE
  // --------
  prediction: {
    currentPrediction: Prediction | null;
    isLoading: boolean;
    lastPredictionTime: string | null;
    totalPredictionsMade: number;
    accuracy: number;
    latency: number;
    modelVersion: string;
    selectedState: string;
    selectedCity: string;
    monitoringLevel: 'STANDARD' | 'ELEVATED' | 'CRITICAL';
    monitoringAction: string;
    priorityZones: string[];
    dangerLevel: number;
    cwcDataSource: 'LIVE_CWC' | 'LOCAL_CACHE' | 'MANUAL' | 'OFFLINE' | 'TACTICAL_REGISTRY';
    lastCWCUpdate: string | null;
  };

  // --------
  // SENSOR STATE
  // --------
  sensors: {
    data: SensorData[];
    isLoading: boolean;
    lastRefresh: string | null;
    activeStations: number;
    offlineStations: number;
    criticalAlerts: number;
  };

  // --------
  // FORM STATE
  // --------
  form: {
    data: FormData;
    isDirty: boolean;
    isValid: boolean;
    errors: Record<string, string>;
    touched: Record<string, boolean>;
    lastSubmitTime: string | null;
    rainfallTotal: number;
    rainfallAverage: number;
    rainfallDistribution: { day: number; mm: number }[];
  };

  // --------
  // ALERT STATE
  // --------
  alerts: {
    active: MLAlert[];
    total: number;
    criticalCount: number;
    isSubscribedToNotifications: boolean;
  };

  // --------
  // DATA STATE
  // --------
  data: {
    weatherData: any | null;
    locationData: any | null;
    historicalMetrics: any | null;
    isLoadingWeather: boolean;
    weatherLastUpdate: string | null;
  };

  // --------
  // USER PREFERENCES
  // --------
  preferences: {
    theme: 'dark' | 'light' | 'auto';
    language: string;
    refreshInterval: number;
    autoRefreshEnabled: boolean;
    displayPrecision: number;
    alertSound: boolean;
  };

  // --------
  // CWC INTEGRATION & LIVE DATA
  // --------
  cwc: {
    isConnected: boolean;
    lastFetchTime: string | null;
    liveData: {
      kolhapurLevel: number | null;
      kolhapurStatus: 'ACTIVE' | 'WARNING' | 'CRITICAL' | 'OFFLINE' | 'UNKNOWN';
      currentLevel: number | null;
      status: 'ACTIVE' | 'WARNING' | 'CRITICAL' | 'OFFLINE' | 'UNKNOWN';
      station: string;
      river: string;
      warningLevel: number | null;
      dangerLevel: number | null;
      trend: 'RISING' | 'FALLING' | 'STEADY' | 'UNKNOWN';
      regionalData: CWCSensorData[];
      source: 'CWC_API' | 'HTML_SCRAPE' | 'CACHED' | 'MANUAL' | 'TACTICAL_REGISTRY';
    };
  };

  // --------
  // INDIAN FLOOD MODELS
  // --------
  models: {
    availableStates: string[];
    currentStateModel: string;
    isMultiStateCapable: boolean;
  };
}

// ==========================================
// ACTION TYPES (STATE MUTATIONS)
// ==========================================

export type AppAction =
  // UI Actions
  | { type: 'SET_ACTIVE_TAB'; payload: ActiveTab }
  | { type: 'SET_MODAL'; payload: ModalType }
  | { type: 'TOGGLE_SIDEBAR' }
  | { type: 'TOGGLE_DARK_MODE' }
  | { type: 'TOGGLE_NOTIFICATIONS' }
  
  // System Actions
  | { type: 'SET_API_STATUS'; payload: SystemStatus }
  | { type: 'SET_API_VERSION'; payload: string }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_SOURCE_POLICY'; payload: SourcePolicy }
  | { type: 'INIT_SYSTEM' }
  
  // Prediction Actions
  | { type: 'SET_PREDICTION'; payload: Prediction }
  | { type: 'CLEAR_PREDICTION' }
  | { type: 'SET_PREDICTION_LOADING'; payload: boolean }
  | { type: 'SET_ACCURACY'; payload: number }
  | { type: 'SET_LATENCY'; payload: number }
  
  // Sensor Actions
  | { type: 'SET_SENSOR_DATA'; payload: SensorData[] }
  | { type: 'SET_SENSOR_LOADING'; payload: boolean }
  | { type: 'ADD_SENSOR'; payload: SensorData }
  | { type: 'UPDATE_SENSOR'; payload: { station: string; data: Partial<SensorData> } }
  
  // Form Actions
  | { type: 'SET_FORM_DATA'; payload: Partial<FormData> }
  | { type: 'SET_FORM_ERROR'; payload: { field: string; error: string } }
  | { type: 'SET_FORM_TOUCHED'; payload: { field: string; touched: boolean } }
  | { type: 'RESET_FORM' }
  | { type: 'SET_FORM_VALID'; payload: boolean }
  | { type: 'SET_FORM_DIRTY'; payload: boolean }
  
  // Alert Actions
  | { type: 'ADD_ALERT'; payload: MLAlert }
  | { type: 'REMOVE_ALERT'; payload: string }
  | { type: 'CLEAR_ALERTS' }
  
  // Data Actions
  | { type: 'SET_WEATHER_DATA'; payload: any }
  | { type: 'SET_LOCATION_DATA'; payload: any }
  | { type: 'SET_WEATHER_LOADING'; payload: boolean }
  
  // Indian Flood Model Actions
  | { type: 'SET_SELECTED_STATE'; payload: string }
  | { type: 'SET_SELECTED_CITY'; payload: string }
  | { type: 'SET_MONITORING_LEVEL'; payload: 'STANDARD' | 'ELEVATED' | 'CRITICAL' }
  | { type: 'SET_MONITORING_ACTION'; payload: string }
  | { type: 'SET_PRIORITY_ZONES'; payload: string[] }
  | { type: 'SET_MODEL_VERSION'; payload: string }
  | { type: 'UPDATE_RAINFALL_STATS'; payload: { total: number; average: number; distribution: { day: number; mm: number }[] } }
  
  // CWC Integration Actions
  | { type: 'SET_CWC_CONNECTED'; payload: boolean }
  | {
      type: 'SET_CWC_LIVE_DATA';
      payload: {
        kolhapurLevel: number | null;
        kolhapurStatus: 'ACTIVE' | 'WARNING' | 'CRITICAL' | 'OFFLINE' | 'UNKNOWN';
        currentLevel: number | null;
        status: 'ACTIVE' | 'WARNING' | 'CRITICAL' | 'OFFLINE' | 'UNKNOWN';
        station: string;
        river: string;
        warningLevel: number | null;
        dangerLevel: number | null;
        trend: 'RISING' | 'FALLING' | 'STEADY' | 'UNKNOWN';
        regionalData: CWCSensorData[];
        source: 'CWC_API' | 'HTML_SCRAPE' | 'CACHED' | 'MANUAL' | 'TACTICAL_REGISTRY';
      };
    }
  | { type: 'SET_CWC_FETCH_TIME'; payload: string | null }
  | { type: 'SET_CWC_DATA_SOURCE'; payload: 'LIVE_CWC' | 'LOCAL_CACHE' | 'MANUAL' | 'OFFLINE' | 'TACTICAL_REGISTRY' }
  
  // Preference Actions
  | { type: 'SET_THEME'; payload: 'dark' | 'light' | 'auto' }
  | { type: 'SET_AUTO_REFRESH'; payload: boolean }
  | { type: 'SET_REFRESH_INTERVAL'; payload: number }
  | { type: 'TOGGLE_ALERT_SOUND' }
  
  // Batch Actions
  | { type: 'RESET_STATE' };

// ==========================================
// INITIAL STATE
// ==========================================

export const INITIAL_STATE: AppState = {
  ui: {
    activeTab: 'dash',
    modalOpen: 'none',
    sidebarOpen: true,
    darkMode: true,
    notificationsEnabled: true,
  },
  system: {
      isOnline: true,
      apiStatus: 'INITIALIZING',
      apiVersion: '4.2.0-STABLE',
      lastSyncTime: null,
      errorMessage: null,
      isInitialized: false,
      sourcePolicy: {
        mode: 'OFFICIAL_VIEW_ONLY',
        label: 'Official View Only',
        description: 'Use official CWC portals for public monitoring, while the app stays on manual or tactical context.',
        allow_live_cwc_in_app: false,
        telemetry_mode: 'OFFICIAL_VIEW_ONLY',
        prediction_data_source: 'Official View Only + Manual Input',
        public_sources: [
          {
            label: 'Open Data',
            title: 'data.gov.in Reservoir Levels',
            url: 'https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc',
            usage: 'Safest public reuse path',
          },
          {
            label: 'Official Monitor',
            title: 'CWC Flood Forecast Portal',
            url: 'https://ffs.india-water.gov.in/',
            usage: 'Authoritative public viewing',
          },
          {
            label: 'Advisory',
            title: 'CWC 7-Day Forecast',
            url: 'https://aff.india-water.gov.in/home.php',
            usage: 'Forward-looking official advisories',
          },
        ],
      },
  },
  prediction: {
    currentPrediction: null,
    isLoading: false,
    lastPredictionTime: null,
    totalPredictionsMade: 0,
    accuracy: 95.2,
    latency: 1200,
    modelVersion: 'RandomForest v4.2',
    selectedState: 'Bihar',
    selectedCity: '',
    monitoringLevel: 'STANDARD' as const,
    monitoringAction: 'Maintain normal surveillance.',
    priorityZones: [],
    dangerLevel: 13.5,
    cwcDataSource: 'MANUAL' as const,
    lastCWCUpdate: null,
  },
  sensors: {
    data: [],
    isLoading: false,
    lastRefresh: null,
    activeStations: 0,
    offlineStations: 0,
    criticalAlerts: 0,
  },
  form: {
    data: {
      Peak_Flood_Level_m: 12.5,
      Event_Duration_days: 3,
      Time_to_Peak_days: 2,
      Recession_Time_day: 2,
      T1d: 156.4,
      T2d: 299.2,
      T3d: 384.4,
      T4d: 384.4,
      T5d: 384.4,
      T6d: 384.4,
      T7d: 455.6,
      state: 'Maharashtra',
      station: '',
    },
    isDirty: false,
    isValid: true,
    errors: {},
    touched: {},
    lastSubmitTime: null,
    rainfallTotal: 2848.8,
    rainfallAverage: 407.0,
    rainfallDistribution: [
      { day: 1, mm: 156.4 },
      { day: 2, mm: 299.2 },
      { day: 3, mm: 384.4 },
      { day: 4, mm: 384.4 },
      { day: 5, mm: 384.4 },
      { day: 6, mm: 384.4 },
      { day: 7, mm: 455.6 },
    ],
  },
  alerts: {
    active: [],
    total: 0,
    criticalCount: 0,
    isSubscribedToNotifications: true,
  },
  data: {
    weatherData: null,
    locationData: null,
    historicalMetrics: null,
    isLoadingWeather: false,
    weatherLastUpdate: null,
  },
  preferences: {
    theme: 'dark',
    language: 'en',
    refreshInterval: 30000,
    autoRefreshEnabled: true,
    displayPrecision: 2,
    alertSound: true,
  },
  cwc: {
    isConnected: false,
    lastFetchTime: null,
    liveData: {
      kolhapurLevel: null,
      kolhapurStatus: 'UNKNOWN' as const,
      currentLevel: null,
      status: 'UNKNOWN' as const,
      station: '',
      river: '',
      warningLevel: null,
      dangerLevel: null,
      trend: 'UNKNOWN' as const,
      regionalData: [],
      source: 'MANUAL' as const,
    },
  },
  models: {
    availableStates: [
      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
      'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
      'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
      'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
      'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
      'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
      'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
      'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
    ],
    currentStateModel: 'Bihar',
    isMultiStateCapable: true,
  },
};
