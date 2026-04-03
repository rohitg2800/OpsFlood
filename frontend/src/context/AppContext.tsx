import React, { createContext, useContext, useReducer, ReactNode, useCallback } from 'react';
import { INITIAL_STATE } from '../types';
import type { AppState, AppAction, FormData, MLAlert, Prediction } from '../types';

const sameLocationPayload = (left: any, right: any) =>
  left === right ||
  Boolean(
    left &&
      right &&
      left.name === right.name &&
      left.state === right.state &&
      left.lat === right.lat &&
      left.lon === right.lon,
  );

const sameWeatherPayload = (left: any, right: any) =>
  left === right ||
  Boolean(
    left &&
      right &&
      left.location === right.location &&
      left.timestamp === right.timestamp &&
      left.temperature === right.temperature &&
      left.weather_condition === right.weather_condition &&
      left.icon === right.icon,
  );

const sameSensorPayload = (left: any[], right: any[]) =>
  left === right ||
  (Array.isArray(left) &&
    Array.isArray(right) &&
    left.length === right.length &&
    left.every((sensor, index) => {
      const other = right[index];
      return (
        sensor === other ||
        (other &&
          sensor.station === other.station &&
          sensor.river_level === other.river_level &&
          sensor.status === other.status &&
          sensor.last_update === other.last_update &&
          sensor.source === other.source)
      );
    }));

const sameRainfallDistribution = (left: any[], right: any[]) =>
  left === right ||
  (Array.isArray(left) &&
    Array.isArray(right) &&
    left.length === right.length &&
    left.every((item, index) => item.day === right[index]?.day && item.mm === right[index]?.mm));

// ==========================================
// STATE REDUCER
// Handles all state mutations with validation
// ==========================================

const appReducer = (state: AppState, action: AppAction): AppState => {
  switch (action.type) {
    // -------- UI STATE --------
    case 'SET_ACTIVE_TAB':
      return { ...state, ui: { ...state.ui, activeTab: action.payload } };
    
    case 'SET_MODAL':
      return { ...state, ui: { ...state.ui, modalOpen: action.payload } };
    
    case 'TOGGLE_SIDEBAR':
      return { ...state, ui: { ...state.ui, sidebarOpen: !state.ui.sidebarOpen } };
    
    case 'TOGGLE_DARK_MODE':
      return { ...state, ui: { ...state.ui, darkMode: !state.ui.darkMode } };
    
    case 'TOGGLE_NOTIFICATIONS':
      return { ...state, ui: { ...state.ui, notificationsEnabled: !state.ui.notificationsEnabled } };

    // -------- SYSTEM STATE --------
    case 'SET_API_STATUS':
      if (state.system.apiStatus === action.payload) {
        return state;
      }
      return {
        ...state,
        system: { ...state.system, apiStatus: action.payload, lastSyncTime: new Date().toISOString() }
      };
    
    case 'SET_API_VERSION':
      return { ...state, system: { ...state.system, apiVersion: action.payload } };

    case 'SET_SOURCE_POLICY':
      if (state.system.sourcePolicy === action.payload) {
        return state;
      }
      return {
        ...state,
        system: { ...state.system, sourcePolicy: action.payload }
      };
    
    case 'SET_ERROR':
      if (state.system.errorMessage === action.payload) {
        return state;
      }
      return { ...state, system: { ...state.system, errorMessage: action.payload } };
    
    case 'INIT_SYSTEM':
      return {
        ...state,
        system: { ...state.system, isInitialized: true, apiStatus: 'ONLINE' }
      };

    // -------- PREDICTION STATE --------
    case 'SET_PREDICTION':
      return {
        ...state,
        prediction: {
          ...state.prediction,
          currentPrediction: action.payload,
          lastPredictionTime: new Date().toISOString(),
          totalPredictionsMade: state.prediction.totalPredictionsMade + 1
        }
      };
    
    case 'ADD_PREDICTION_LOG':
      return {
        ...state,
        prediction: {
          ...state.prediction,
          history: [action.payload, ...state.prediction.history].slice(0, 100) // Keep last 100
        }
      };
    
    case 'CLEAR_PREDICTION':
      return {
        ...state,
        prediction: { ...state.prediction, currentPrediction: null }
      };
    
    case 'SET_PREDICTION_LOADING':
      if (state.prediction.isLoading === action.payload) {
        return state;
      }
      return {
        ...state,
        prediction: { ...state.prediction, isLoading: action.payload }
      };
    
    case 'SET_ACCURACY':
      return {
        ...state,
        prediction: { ...state.prediction, accuracy: action.payload }
      };
    
    case 'SET_LATENCY':
      return {
        ...state,
        prediction: { ...state.prediction, latency: action.payload }
      };

    // -------- SENSOR STATE --------
    case 'SET_SENSOR_DATA':
      if (sameSensorPayload(state.sensors.data, action.payload)) {
        return state;
      }
      return {
        ...state,
        sensors: {
          ...state.sensors,
          data: action.payload,
          lastRefresh: new Date().toISOString(),
          activeStations: action.payload.filter(s => s.status === 'ACTIVE').length,
          offlineStations: action.payload.filter(s => s.status === 'OFFLINE').length,
          criticalAlerts: action.payload.filter(s => s.status === 'CRITICAL').length
        }
      };
    
    case 'SET_SENSOR_LOADING':
      if (state.sensors.isLoading === action.payload) {
        return state;
      }
      return {
        ...state,
        sensors: { ...state.sensors, isLoading: action.payload }
      };
    
    case 'ADD_SENSOR':
      return {
        ...state,
        sensors: { ...state.sensors, data: [...state.sensors.data, action.payload] }
      };
    
    case 'UPDATE_SENSOR':
      return {
        ...state,
        sensors: {
          ...state.sensors,
          data: state.sensors.data.map(s =>
            s.station === action.payload.station
              ? { ...s, ...action.payload.data }
              : s
          )
        }
      };

    // -------- FORM STATE --------
    case 'SET_FORM_DATA': {
      const changedEntries = Object.entries(action.payload).filter(
        ([key, value]) => (state.form.data as any)[key] !== value,
      );
      if (!changedEntries.length) {
        return state;
      }
      return {
        ...state,
        form: {
          ...state.form,
          data: { ...state.form.data, ...action.payload },
          isDirty: true
        }
      };
    }
    
    case 'SET_FORM_ERROR':
      if (state.form.errors[action.payload.field] === action.payload.error) {
        return state;
      }
      return {
        ...state,
        form: {
          ...state.form,
          errors: {
            ...state.form.errors,
            [action.payload.field]: action.payload.error
          }
        }
      };
    
    case 'SET_FORM_TOUCHED':
      return {
        ...state,
        form: {
          ...state.form,
          touched: {
            ...state.form.touched,
            [action.payload.field]: action.payload.touched
          }
        }
      };
    
    case 'RESET_FORM':
      return {
        ...state,
        form: {
          data: INITIAL_STATE.form.data,
          isDirty: false,
          isValid: true,
          errors: {},
          touched: {},
          lastSubmitTime: new Date().toISOString(),
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
          ]
        }
      };
    
    case 'SET_FORM_VALID':
      if (state.form.isValid === action.payload) {
        return state;
      }
      return {
        ...state,
        form: { ...state.form, isValid: action.payload }
      };
    
    case 'SET_FORM_DIRTY':
      return {
        ...state,
        form: { ...state.form, isDirty: action.payload }
      };

    // -------- ALERT STATE --------
    case 'ADD_ALERT': {
      const newAlert = action.payload;
      return {
        ...state,
        alerts: {
          ...state.alerts,
          active: [newAlert, ...state.alerts.active],
          total: state.alerts.total + 1,
          criticalCount: newAlert.type === 'critical' 
            ? state.alerts.criticalCount + 1 
            : state.alerts.criticalCount
        }
      };
    }
    
    case 'REMOVE_ALERT': {
      const alertToRemove = state.alerts.active.find(a => a.id === action.payload);
      return {
        ...state,
        alerts: {
          ...state.alerts,
          active: state.alerts.active.filter(a => a.id !== action.payload),
          criticalCount: alertToRemove?.type === 'critical'
            ? Math.max(0, state.alerts.criticalCount - 1)
            : state.alerts.criticalCount
        }
      };
    }
    
    case 'CLEAR_ALERTS':
      return {
        ...state,
        alerts: {
          ...state.alerts,
          active: [],
          criticalCount: 0
        }
      };

    // -------- DATA STATE --------
    case 'SET_WEATHER_DATA':
      if (sameWeatherPayload(state.data.weatherData, action.payload)) {
        return state;
      }
      return {
        ...state,
        data: {
          ...state.data,
          weatherData: action.payload,
          weatherLastUpdate: new Date().toISOString()
        }
      };
    
    case 'SET_LOCATION_DATA':
      if (sameLocationPayload(state.data.locationData, action.payload)) {
        return state;
      }
      return {
        ...state,
        data: { ...state.data, locationData: action.payload }
      };
    
    case 'SET_WEATHER_LOADING':
      if (state.data.isLoadingWeather === action.payload) {
        return state;
      }
      return {
        ...state,
        data: { ...state.data, isLoadingWeather: action.payload }
      };

    // -------- PREFERENCE STATE --------
    case 'SET_THEME':
      return {
        ...state,
        preferences: { ...state.preferences, theme: action.payload }
      };
    
    case 'SET_AUTO_REFRESH':
      return {
        ...state,
        preferences: { ...state.preferences, autoRefreshEnabled: action.payload }
      };
    
    case 'SET_REFRESH_INTERVAL':
      return {
        ...state,
        preferences: { ...state.preferences, refreshInterval: action.payload }
      };
    
    case 'TOGGLE_ALERT_SOUND':
      return {
        ...state,
        preferences: { ...state.preferences, alertSound: !state.preferences.alertSound }
      };

    // -------- INDIAN FLOOD MODEL STATE --------
    case 'SET_SELECTED_STATE':
      if (state.prediction.selectedState === action.payload) {
        return state;
      }
      return {
        ...state,
        prediction: { ...state.prediction, selectedState: action.payload }
      };
    
    case 'SET_SELECTED_CITY':
      if (
        state.prediction.selectedCity === action.payload &&
        state.form.data.station === action.payload
      ) {
        return state;
      }
      return {
        ...state,
        prediction: { ...state.prediction, selectedCity: action.payload },
        form: { ...state.form, data: { ...state.form.data, station: action.payload } }
      };
    
    case 'SET_MONITORING_LEVEL':
      return {
        ...state,
        prediction: { ...state.prediction, monitoringLevel: action.payload }
      };
    
    case 'SET_MONITORING_ACTION':
      return {
        ...state,
        prediction: { ...state.prediction, monitoringAction: action.payload }
      };
    
    case 'SET_PRIORITY_ZONES':
      return {
        ...state,
        prediction: { ...state.prediction, priorityZones: action.payload }
      };
    
    case 'SET_MODEL_VERSION':
      return {
        ...state,
        prediction: { ...state.prediction, modelVersion: action.payload }
      };
    
    case 'UPDATE_RAINFALL_STATS':
      if (
        state.form.rainfallTotal === action.payload.total &&
        state.form.rainfallAverage === action.payload.average &&
        sameRainfallDistribution(state.form.rainfallDistribution, action.payload.distribution)
      ) {
        return state;
      }
      return {
        ...state,
        form: {
          ...state.form,
          rainfallTotal: action.payload.total,
          rainfallAverage: action.payload.average,
          rainfallDistribution: action.payload.distribution
        }
      };

    // -------- CWC INTEGRATION --------
    case 'SET_CWC_CONNECTED':
      if (state.cwc.isConnected === action.payload) {
        return state;
      }
      return {
        ...state,
        cwc: { ...state.cwc, isConnected: action.payload }
      };
    
    case 'SET_CWC_LIVE_DATA':
      if (state.cwc.liveData === action.payload) {
        return state;
      }
      return {
        ...state,
        cwc: {
          ...state.cwc,
          liveData: action.payload,
          lastFetchTime: new Date().toISOString()
        }
      };
    
    case 'SET_CWC_FETCH_TIME':
      return {
        ...state,
        cwc: { ...state.cwc, lastFetchTime: action.payload }
      };
    
    case 'SET_CWC_DATA_SOURCE':
      if (state.prediction.cwcDataSource === action.payload) {
        return state;
      }
      return {
        ...state,
        prediction: {
          ...state.prediction,
          cwcDataSource: action.payload,
          lastCWCUpdate: new Date().toISOString()
        }
      };

    // -------- BATCH ACTIONS --------
    case 'RESET_STATE':
      return INITIAL_STATE;

    default:
      return state;
  }
};

// ==========================================
// CONTEXT & PROVIDER
// ==========================================

interface AppContextType {
  state: AppState;
  dispatch: React.Dispatch<AppAction>;
  // Convenience methods
  setActiveTab: (tab: AppState['ui']['activeTab']) => void;
  setPrediction: (pred: Prediction) => void;
  setLoading: (loading: boolean) => void;
  addAlert: (alert: MLAlert) => void;
  removeAlert: (id: string) => void;
  updateFormField: <K extends keyof FormData>(field: K, value: FormData[K]) => void;
  handlePredict: () => Promise<void>;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(appReducer, INITIAL_STATE);

  // Convenience methods
  const setActiveTab = useCallback((tab: AppState['ui']['activeTab']) => {
    dispatch({ type: 'SET_ACTIVE_TAB', payload: tab });
  }, []);

  const setPrediction = useCallback((pred: Prediction) => {
    dispatch({ type: 'SET_PREDICTION', payload: pred });
  }, []);

  const setLoading = useCallback((loading: boolean) => {
    dispatch({ type: 'SET_PREDICTION_LOADING', payload: loading });
  }, []);

  const addAlert = useCallback((alert: MLAlert) => {
    dispatch({ type: 'ADD_ALERT', payload: alert });
  }, []);

  const removeAlert = useCallback((id: string) => {
    dispatch({ type: 'REMOVE_ALERT', payload: id });
  }, []);

  const updateFormField = useCallback(<K extends keyof FormData>(field: K, value: FormData[K]) => {
    dispatch({ type: 'SET_FORM_DATA', payload: { [field]: value } });
  }, []);

  const handlePredict = useCallback(async () => {
    console.log('Predict triggered from context');
    // This will be implemented in the main App component
  }, []);

  return (
    <AppContext.Provider
      value={{
        state,
        dispatch,
        setActiveTab,
        setPrediction,
        setLoading,
        addAlert,
        removeAlert,
        updateFormField,
        handlePredict
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

// ==========================================
// CUSTOM HOOK
// ==========================================

export const useAppState = (): AppContextType => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useAppState must be used within AppProvider');
  }
  return context;
};
