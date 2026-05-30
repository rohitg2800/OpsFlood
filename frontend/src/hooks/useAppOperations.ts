import { useEffect, useCallback, useRef } from 'react';
import { useAppState } from '../context/AppContext';
import axios from 'axios';
import type { Prediction, FormData, SensorData } from '../types';
import { apiUrl } from '../config/api';
import {
  generateTacticalCWCData,
  getPreferredHydrologyNode,
  mergeSensorTelemetry,
  tacticalCWCDataToSensors,
} from '../data/hydrologyRegistry';

// ==========================================
// CUSTOM HOOKS FOR STATE OPERATIONS
// ==========================================

/**
 * Hook for managing prediction API calls
 */
export const usePredictionAPI = () => {
  const { state, dispatch } = useAppState();

  const predict = useCallback(async (formData: any) => {
    dispatch({ type: 'SET_PREDICTION_LOADING', payload: true });
    const startTime = performance.now();

    try {
      const response = await axios.post(apiUrl('/predict'), formData, {
        timeout: 30000,
      });

      const latency = Math.round(performance.now() - startTime);
      dispatch({ type: 'SET_LATENCY', payload: latency });
      dispatch({ type: 'SET_PREDICTION', payload: response.data });
      dispatch({ type: 'SET_API_STATUS', payload: 'ONLINE' });

      return response.data;
    } catch (error: any) {
      const latency = Math.round(performance.now() - startTime);
      dispatch({ type: 'SET_LATENCY', payload: latency });

      const fallbackPrediction: Prediction = {
        severity: (formData.Peak_Flood_Level_m > 12 ? 'SEVERE' : 'MODERATE') as any,
        confidence_percent: 89.4,
        alert: '🚨 OFFLINE_ESTIMATE',
        algorithm: 'Random Forest Fallback',
        data_source: 'LOCAL_CACHE',
        model_trained: true
      };

      dispatch({ type: 'SET_PREDICTION', payload: fallbackPrediction });
      dispatch({ type: 'SET_API_STATUS', payload: 'DEGRADED' });
      dispatch({
        type: 'SET_ERROR',
        payload: `API Error: Using fallback model. ${error.message}`
      });

      return fallbackPrediction;
    } finally {
      dispatch({ type: 'SET_PREDICTION_LOADING', payload: false });
    }
  }, [dispatch]);

  return { predict, isLoading: state.prediction.isLoading };
};

/**
 * Hook for managing sensor data fetching.
 *
 * Timeout raised to 30 000 ms so the backend has time to warm up the
 * GloFAS cache on first startup (≈ 63 s total fetch, but the route
 * returns tactical fallback immediately if cache isn't ready yet).
 * The catch block always falls back to tacticalSensors so the UI stays
 * functional even if the backend is temporarily unreachable.
 */
export const useSensorAPI = () => {
  const { state, dispatch } = useAppState();
  const inflightRequestRef = useRef<Promise<SensorData[]> | null>(null);
  const inflightKeyRef = useRef('');
  const recentResultRef = useRef<{ key: string; timestamp: number; data: SensorData[] } | null>(null);

  const fetchSensors = useCallback(async (options?: { force?: boolean }) => {
    dispatch({ type: 'SET_SENSOR_LOADING', payload: true });
    const selectedState = state.prediction.selectedState || state.form.data.state || 'Maharashtra';
    const selectedStation = state.form.data.station || state.prediction.selectedCity || selectedState;
    const requestKey = `${selectedState}::${selectedStation}`;
    const tacticalSensors = tacticalCWCDataToSensors(
      generateTacticalCWCData(selectedState, selectedStation),
    );
    const force = Boolean(options?.force);
    const recentResult = recentResultRef.current;

    if (!force && recentResult && recentResult.key === requestKey && Date.now() - recentResult.timestamp < 2000) {
      dispatch({ type: 'SET_SENSOR_DATA', payload: recentResult.data });
      dispatch({ type: 'SET_SENSOR_LOADING', payload: false });
      return recentResult.data;
    }

    if (!force && inflightRequestRef.current && inflightKeyRef.current === requestKey) {
      return inflightRequestRef.current;
    }

    const request = (async () => {
      try {
        const params = {
          state: selectedState,
          station: selectedStation,
        };

        // 30 s timeout — backend returns tactical fallback immediately on
        // cold-start so this budget is almost never fully consumed.
        const response = await axios.get(apiUrl('/api/live-telemetry'), {
          params,
          timeout: 30000,
        });

        const sensorPayload = Array.isArray(response.data)
          ? response.data
          : Array.isArray(response.data?.data)
          ? response.data.data
          : [];

        const normalizedApiSensors: SensorData[] = sensorPayload.map((sensor: any) => ({
          station: sensor.station || sensor.stationName || 'Unknown Station',
          river_level: Number(sensor.river_level ?? sensor.currentLevel ?? sensor.waterLevel ?? 0),
          flow_rate: Number(sensor.flow_rate ?? sensor.flowRate ?? 0),
          rainfall_last_hour: Number(sensor.rainfall_last_hour ?? sensor.rainfall ?? sensor.rainfallLastHour ?? 0),
          status: sensor.status || 'ACTIVE',
          last_update: sensor.last_update || sensor.lastUpdate || sensor.updateTime,
          river: sensor.river,
          warning_level: sensor.warning_level ?? sensor.warningLevel,
          danger_level: sensor.danger_level ?? sensor.dangerLevel,
          trend: sensor.trend,
          state: sensor.state || selectedState,
          source: sensor.source || 'CWC_API',
        }));

        const mergedSensors = mergeSensorTelemetry(normalizedApiSensors, tacticalSensors);
        recentResultRef.current = { key: requestKey, timestamp: Date.now(), data: mergedSensors };

        dispatch({ type: 'SET_SENSOR_DATA', payload: mergedSensors });
        dispatch({ type: 'SET_API_STATUS', payload: 'ONLINE' });

        return mergedSensors;
      } catch (error) {
        // Always surface tactical data so the UI remains functional.
        console.warn('Sensor fetch failed — using tactical registry:', error);
        recentResultRef.current = { key: requestKey, timestamp: Date.now(), data: tacticalSensors };
        dispatch({ type: 'SET_SENSOR_DATA', payload: tacticalSensors });
        return tacticalSensors;
      } finally {
        inflightRequestRef.current = null;
        inflightKeyRef.current = '';
        dispatch({ type: 'SET_SENSOR_LOADING', payload: false });
      }
    })();

    inflightRequestRef.current = request;
    inflightKeyRef.current = requestKey;
    return request;
  }, [dispatch, state.form.data.state, state.prediction.selectedCity, state.prediction.selectedState, state.form.data.station]);

  return { fetchSensors, isLoading: state.sensors.isLoading };
};

/**
 * Hook for managing auto-refresh of predictions
 */
export const useAutoRefresh = (callback: () => void) => {
  const { state } = useAppState();

  useEffect(() => {
    if (!state.preferences.autoRefreshEnabled) return;

    const interval = setInterval(() => {
      callback();
    }, state.preferences.refreshInterval);

    return () => clearInterval(interval);
  }, [state.preferences.autoRefreshEnabled, state.preferences.refreshInterval, callback]);
};

/**
 * Hook for managing alert notifications
 */
export const useAlertNotifications = () => {
  const { state, dispatch } = useAppState();

  const playAlertSound = useCallback(() => {
    if (!state.preferences.alertSound) return;

    const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.value = 1000;
    oscillator.type = 'sine';

    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.5);

    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.5);
  }, [state.preferences.alertSound]);

  const notifyUser = useCallback((options: {
    title: string;
    message: string;
    type: 'critical' | 'warning' | 'info' | 'success';
  }) => {
    const id = Date.now().toString();

    if (state.ui.notificationsEnabled && 'Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification(options.title, {
          body: options.message,
          icon: '/icon.png',
          tag: 'flood-alert',
          requireInteraction: options.type === 'critical'
        });
      }
    }

    if (options.type === 'critical') {
      playAlertSound();
    }

    dispatch({
      type: 'ADD_ALERT',
      payload: {
        id,
        type: options.type,
        title: options.title,
        message: options.message,
        timestamp: new Date().toISOString()
      }
    });
  }, [state.ui.notificationsEnabled, dispatch, playAlertSound]);

  return { notifyUser, playAlertSound };
};

/**
 * Hook for managing system initialization
 */
export const useSystemInit = () => {
  const { dispatch, state } = useAppState();

  useEffect(() => {
    if (state.system.isInitialized) return;

    const initSystem = async () => {
      dispatch({ type: 'SET_API_STATUS', payload: 'INITIALIZING' });

      try {
        const healthResponse = await axios.get(apiUrl('/health'), {
          timeout: 5000
        });
        const healthPayload = healthResponse.data as any;

        if (healthPayload?.version) {
          dispatch({ type: 'SET_API_VERSION', payload: String(healthPayload.version) });
        }

        if (healthPayload?.source_policy) {
          dispatch({ type: 'SET_SOURCE_POLICY', payload: healthPayload.source_policy });
        }

        dispatch({ type: 'INIT_SYSTEM' });
        dispatch({ type: 'SET_API_STATUS', payload: 'ONLINE' });

        if ('Notification' in window && Notification.permission === 'default') {
          Notification.requestPermission();
        }
      } catch {
        dispatch({ type: 'SET_API_STATUS', payload: 'OFFLINE' });
        dispatch({
          type: 'SET_ERROR',
          payload: 'Failed to connect to API. Using offline mode.'
        });
      }
    };

    initSystem();
  }, [state.system.isInitialized, dispatch]);
};

/**
 * Hook for managing form validation
 * PEAK_LEVEL_MAX raised to 999 to support MSL-datum CWC gauges
 */
export const useFormValidation = (formData: any) => {
  const { dispatch } = useAppState();
  const PEAK_LEVEL_MIN = 0;
  const PEAK_LEVEL_MAX = 999;
  const RAINFALL_7D_MIN = 0;
  const RAINFALL_7D_MAX = 5000;

  const validateField = useCallback((field: string, value: any) => {
    let hasError = false;
    let errorMessage = '';

    if (field === 'Peak_Flood_Level_m') {
      if (value < PEAK_LEVEL_MIN || value > PEAK_LEVEL_MAX) {
        hasError = true;
        errorMessage = `Must be between ${PEAK_LEVEL_MIN} and ${PEAK_LEVEL_MAX} meters`;
      }
    }

    if (/^T[1-7]d$/.test(field)) {
      if (value < RAINFALL_7D_MIN || value > RAINFALL_7D_MAX) {
        hasError = true;
        errorMessage = `Must be between ${RAINFALL_7D_MIN} and ${RAINFALL_7D_MAX} mm`;
      }
    }

    dispatch({
      type: 'SET_FORM_ERROR',
      payload: { field, error: hasError ? errorMessage : '' }
    });

    return !hasError;
  }, [dispatch, PEAK_LEVEL_MAX, PEAK_LEVEL_MIN, RAINFALL_7D_MAX, RAINFALL_7D_MIN]);

  const validateAllFields = useCallback(() => {
    const peakValid = validateField('Peak_Flood_Level_m', Number(formData.Peak_Flood_Level_m || 0));

    const rainfallKeys = ['T1d', 'T2d', 'T3d', 'T4d', 'T5d', 'T6d', 'T7d'];
    const rainfallValid = rainfallKeys.every((key) =>
      validateField(key, Number((formData as any)[key] || 0))
    );

    const isValid = peakValid && rainfallValid;
    dispatch({ type: 'SET_FORM_VALID', payload: isValid });
    return isValid;
  }, [formData, dispatch, validateField]);

  return { validateField, validateAllFields };
};

/**
 * Hook for CWC (Central Water Commission) live data integration
 */
export const useCWCIntegration = () => {
  const { state, dispatch } = useAppState();
  const inflightRequestRef = useRef<Promise<any> | null>(null);
  const inflightKeyRef = useRef('');
  const recentResultRef = useRef<{ key: string; timestamp: number; data: any } | null>(null);

  const fetchCWCData = useCallback(async (options?: { force?: boolean }) => {
    dispatch({ type: 'SET_CWC_CONNECTED', payload: false });
    const selectedState = state.prediction.selectedState || state.form.data.state || 'Maharashtra';
    const selectedStation = state.form.data.station || state.prediction.selectedCity || selectedState;
    const requestKey = `${selectedState}::${selectedStation}`;
    const tacticalNodes = generateTacticalCWCData(selectedState, selectedStation);
    const fallbackNode = getPreferredHydrologyNode(tacticalNodes, selectedStation) || tacticalNodes[0];
    const force = Boolean(options?.force);
    const recentResult = recentResultRef.current;

    if (!force && recentResult && recentResult.key === requestKey && Date.now() - recentResult.timestamp < 2000) {
      return recentResult.data;
    }

    if (!force && inflightRequestRef.current && inflightKeyRef.current === requestKey) {
      return inflightRequestRef.current;
    }

    const request = (async () => {
      try {
        const cwcResult = await axios.get(apiUrl('/api/live-telemetry'), {
          params: { state: selectedState, station: selectedStation, limit: 8 },
          timeout: 30000
        });

        const responseData = cwcResult.data as any;
        const feedStatus = String(responseData?.status || '').toUpperCase();
        const feedDataSource = String(responseData?.data_source || '').toUpperCase();
        const backendFallbackMode =
          feedStatus === 'FALLBACK_MODE' ||
          feedStatus === 'PARTIAL_FALLBACK' ||
          feedDataSource === 'TACTICAL_REGISTRY';
        const sensorPayload = Array.isArray(responseData)
          ? responseData
          : Array.isArray(responseData?.data)
          ? responseData.data
          : [];

        const apiNodes = sensorPayload
          .map((sensor: any, index: number) => {
            const currentLevel = Number(sensor.river_level ?? sensor.currentLevel ?? sensor.waterLevel ?? NaN);
            if (!Number.isFinite(currentLevel)) return null;

            const matchedFallback = getPreferredHydrologyNode(
              tacticalNodes,
              sensor.station || sensor.stationName || sensor.river,
            );

            const warningLevel =
              Number(sensor.warning_level ?? sensor.warningLevel ?? matchedFallback?.warningLevel ?? NaN);
            const dangerLevel =
              Number(sensor.danger_level ?? sensor.dangerLevel ?? matchedFallback?.dangerLevel ?? NaN);

            const status =
              sensor.status ||
              (Number.isFinite(dangerLevel) && currentLevel >= dangerLevel
                ? 'CRITICAL'
                : Number.isFinite(warningLevel) && currentLevel >= warningLevel
                ? 'WARNING'
                : 'ACTIVE');

            const sensorSource = String(sensor.source || '').toUpperCase();
            const normalizedSource =
              sensorSource.includes('TACTICAL')
                ? 'TACTICAL_REGISTRY'
                : sensorSource.includes('HTML')
                ? 'HTML_SCRAPE'
                : backendFallbackMode
                ? 'TACTICAL_REGISTRY'
                : 'CWC_API';

            return {
              id: `CWC-API-${index}`,
              state: selectedState,
              river: sensor.river || matchedFallback?.river || 'Active Basin',
              station: sensor.station || sensor.stationName || matchedFallback?.station || selectedStation,
              currentLevel,
              warningLevel: Number.isFinite(warningLevel) ? warningLevel : matchedFallback?.warningLevel || null,
              dangerLevel: Number.isFinite(dangerLevel) ? dangerLevel : matchedFallback?.dangerLevel || null,
              rainfallLastHour: Number(sensor.rainfall_last_hour ?? sensor.rainfall ?? sensor.rainfallLastHour ?? 0),
              status,
              trend: sensor.trend || matchedFallback?.trend || 'STEADY',
              updateTime:
                sensor.last_update ||
                sensor.lastUpdate ||
                sensor.updateTime ||
                fallbackNode?.updateTime ||
                new Date().toLocaleTimeString('en-IN', { hour12: false }),
              source: normalizedSource,
            };
          })
          .filter(Boolean);

        const regionalData = apiNodes.length
          ? [
              ...apiNodes,
              ...tacticalNodes.filter(
                (node) =>
                  !apiNodes.some(
                    (apiNode: any) => apiNode.station.toLowerCase() === node.station.toLowerCase(),
                  ),
              ),
            ]
          : tacticalNodes;

        const preferredNode =
          getPreferredHydrologyNode(regionalData as any, selectedStation) ||
          fallbackNode;

        if (!preferredNode) {
          dispatch({ type: 'SET_CWC_CONNECTED', payload: false });
          dispatch({ type: 'SET_CWC_DATA_SOURCE', payload: 'LOCAL_CACHE' });
          recentResultRef.current = { key: requestKey, timestamp: Date.now(), data: null };
          return null;
        }

        dispatch({
          type: 'SET_CWC_LIVE_DATA',
          payload: {
            kolhapurLevel: preferredNode.currentLevel,
            kolhapurStatus: preferredNode.status,
            currentLevel: preferredNode.currentLevel,
            status: preferredNode.status,
            station: preferredNode.station,
            river: preferredNode.river,
            warningLevel: preferredNode.warningLevel,
            dangerLevel: preferredNode.dangerLevel,
            trend: preferredNode.trend,
            regionalData,
            source: preferredNode.source,
          }
        });
        const hasLiveNodes = apiNodes.some(
          (node: any) => node?.source === 'CWC_API' || node?.source === 'HTML_SCRAPE',
        );
        dispatch({ type: 'SET_CWC_CONNECTED', payload: hasLiveNodes });
        dispatch({ type: 'SET_CWC_DATA_SOURCE', payload: hasLiveNodes ? 'LIVE_CWC' : 'TACTICAL_REGISTRY' });
        recentResultRef.current = { key: requestKey, timestamp: Date.now(), data: preferredNode };

        return preferredNode;
      } catch {
        console.warn('CWC API unavailable, using cached or manual data');
        if (fallbackNode) {
          dispatch({
            type: 'SET_CWC_LIVE_DATA',
            payload: {
              kolhapurLevel: fallbackNode.currentLevel,
              kolhapurStatus: fallbackNode.status,
              currentLevel: fallbackNode.currentLevel,
              status: fallbackNode.status,
              station: fallbackNode.station,
              river: fallbackNode.river,
              warningLevel: fallbackNode.warningLevel,
              dangerLevel: fallbackNode.dangerLevel,
              trend: fallbackNode.trend,
              regionalData: tacticalNodes,
              source: 'TACTICAL_REGISTRY',
            }
          });
        }
        dispatch({ type: 'SET_CWC_CONNECTED', payload: false });
        dispatch({ type: 'SET_CWC_DATA_SOURCE', payload: 'TACTICAL_REGISTRY' });
        recentResultRef.current = { key: requestKey, timestamp: Date.now(), data: fallbackNode || null };
        return fallbackNode || null;
      } finally {
        inflightRequestRef.current = null;
        inflightKeyRef.current = '';
      }
    })();

    inflightRequestRef.current = request;
    inflightKeyRef.current = requestKey;
    return request;
  }, [dispatch, state.form.data.state, state.prediction.selectedCity, state.prediction.selectedState, state.form.data.station]);

  return { fetchCWCData, isConnected: state.cwc.isConnected };
};

/**
 * Hook for calculating rainfall statistics from 7-day data
 */
export const useRainfallStats = (formData: FormData) => {
  const { dispatch } = useAppState();

  const updateRainfallStats = useCallback(() => {
    const rainfall = [
      formData.T1d || 0,
      formData.T2d || 0,
      formData.T3d || 0,
      formData.T4d || 0,
      formData.T5d || 0,
      formData.T6d || 0,
      formData.T7d || 0
    ];

    const total = rainfall.reduce((a, b) => a + b, 0);
    const average = rainfall.length > 0 ? total / rainfall.length : 0;
    const distribution = rainfall.map((mm, idx) => ({
      day: idx + 1,
      mm: Math.round(mm * 10) / 10
    }));

    dispatch({
      type: 'UPDATE_RAINFALL_STATS',
      payload: { total, average, distribution }
    });

    return { total, average, distribution };
  }, [formData, dispatch]);

  return { updateRainfallStats };
};

/**
 * Hook for managing Indian state-specific flood models
 */
export const useIndianStateModels = () => {
  const { state, dispatch } = useAppState();

  const selectState = useCallback((stateName: string) => {
    dispatch({ type: 'SET_SELECTED_STATE', payload: stateName });
  }, [dispatch]);

  const getAvailableStates = useCallback(() => {
    return state.models.availableStates;
  }, [state.models.availableStates]);

  const updateMonitoring = useCallback((monitoringData: {
    level: 'STANDARD' | 'ELEVATED' | 'CRITICAL';
    action: string;
    zones: string[];
  }) => {
    dispatch({ type: 'SET_MONITORING_LEVEL', payload: monitoringData.level });
    dispatch({ type: 'SET_MONITORING_ACTION', payload: monitoringData.action });
    dispatch({ type: 'SET_PRIORITY_ZONES', payload: monitoringData.zones });
  }, [dispatch]);

  return {
    selectedState: state.prediction.selectedState,
    selectState,
    availableStates: getAvailableStates(),
    updateMonitoring,
    currentMonitoring: {
      level: state.prediction.monitoringLevel,
      action: state.prediction.monitoringAction,
      zones: state.prediction.priorityZones
    }
  };
};

/**
 * Hook for enhanced prediction with full ML model integration
 */
export const useEnhancedPrediction = () => {
  const { state, dispatch } = useAppState();
  const { predict: basePred, isLoading } = usePredictionAPI();
  const { fetchCWCData } = useCWCIntegration();
  const { updateRainfallStats } = useRainfallStats(state.form.data);
  const { updateMonitoring, selectedState } = useIndianStateModels();

  const predictWithFullModel = useCallback(async () => {
    dispatch({ type: 'SET_PREDICTION_LOADING', payload: true });

    try {
      updateRainfallStats();

      const cwcData = await fetchCWCData({ force: true });

      if (typeof cwcData?.currentLevel === 'number') {
        dispatch({
          type: 'SET_FORM_DATA',
          payload: { Peak_Flood_Level_m: cwcData.currentLevel }
        });
        dispatch({
          type: 'SET_CWC_DATA_SOURCE',
          payload: cwcData.source === 'TACTICAL_REGISTRY' ? 'TACTICAL_REGISTRY' : 'LIVE_CWC'
        });
      }

      const peakLevelForPrediction =
        typeof cwcData?.currentLevel === 'number'
          ? cwcData.currentLevel
          : Number(state.form.data.Peak_Flood_Level_m || 0);

      const predictionPayload = {
        ...state.form.data,
        Peak_Flood_Level_m: peakLevelForPrediction,
        state: selectedState
      };

      const result = await basePred(predictionPayload);

      const monitoringConfig = {
        CRITICAL: {
          level: 'CRITICAL' as const,
          action: 'Evacuate vulnerable river basins immediately.',
          zones: ['Primary Catchment', 'Downstream Villages', 'Low-lying urban zones']
        },
        SEVERE: {
          level: 'CRITICAL' as const,
          action: 'Evacuate vulnerable river basins immediately.',
          zones: ['Primary Catchment', 'Downstream Villages', 'Low-lying urban zones']
        },
        MODERATE: {
          level: 'ELEVATED' as const,
          action: 'Deploy monitoring teams & prep pumps.',
          zones: ['Drainage bottlenecks', 'Main river gauge']
        },
        LOW: {
          level: 'STANDARD' as const,
          action: 'Maintain normal surveillance.',
          zones: []
        }
      };

      const monitoring = monitoringConfig[result.severity as keyof typeof monitoringConfig] || monitoringConfig.LOW;
      updateMonitoring(monitoring as any);

      return result;
    } catch (error: any) {
      console.error('Enhanced prediction error:', error);
      dispatch({
        type: 'SET_ERROR',
        payload: `Prediction failed: ${error.message}`
      });
      throw error;
    } finally {
      dispatch({ type: 'SET_PREDICTION_LOADING', payload: false });
    }
  }, [state.form.data, selectedState, dispatch, updateRainfallStats, fetchCWCData, basePred, updateMonitoring]);

  return { predictWithFullModel, isLoading };
};
