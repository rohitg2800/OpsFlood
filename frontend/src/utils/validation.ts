import { FormData } from '../types';

// ==========================================
// FORM VALIDATION
// ==========================================

export interface FormFieldError {
  field: string;
  message: string;
}

export const validateFormData = (data: Partial<FormData>): FormFieldError[] => {
  const errors: FormFieldError[] = [];

  if (data.Peak_Flood_Level_m !== undefined) {
    if (data.Peak_Flood_Level_m < 0 || data.Peak_Flood_Level_m > 25) {
      errors.push({
        field: 'Peak_Flood_Level_m',
        message: 'Peak flood level must be between 0 and 25 meters'
      });
    }
  }

  // Validate individual rainfall days (0-200mm per day is reasonable)
  for (let i = 1; i <= 7; i++) {
    const key = `T${i}d` as keyof FormData;
    const value = data[key] as number | undefined;
    if (value !== undefined) {
      if (value < 0 || value > 200) {
        errors.push({
          field: key,
          message: `Day ${i} rainfall must be between 0 and 200mm`
        });
      }
    }
  }

  if (data.T7d !== undefined) {
    if (data.T7d < 0 || data.T7d > 1000) {
      errors.push({
        field: 'T7d',
        message: '7-day precipitation must be between 0 and 1000 mm'
      });
    }
  }

  if (data.Event_Duration_days !== undefined) {
    if (data.Event_Duration_days < 0 || data.Event_Duration_days > 30) {
      errors.push({
        field: 'Event_Duration_days',
        message: 'Event duration must be between 0 and 30 days'
      });
    }
  }

  if (data.Time_to_Peak_days !== undefined) {
    if (data.Time_to_Peak_days < 0 || data.Time_to_Peak_days > 10) {
      errors.push({
        field: 'Time_to_Peak_days',
        message: 'Time to peak must be between 0 and 10 days'
      });
    }
  }

  if (data.state && data.state.length === 0) {
    errors.push({
      field: 'state',
      message: 'Please select an Indian state or UT'
    });
  }

  return errors;
};

// ==========================================
// SEVERITY LEVEL HELPERS
// ==========================================

export const severityToColor = (severity: string): string => {
  switch (severity?.toUpperCase()) {
    case 'SEVERE':
      return 'text-red-500';
    case 'CRITICAL':
      return 'text-red-600';
    case 'MODERATE':
      return 'text-purple-500';
    case 'LOW':
      return 'text-green-500';
    default:
      return 'text-slate-500';
  }
};

export const severityToBgColor = (severity: string): string => {
  switch (severity?.toUpperCase()) {
    case 'SEVERE':
      return 'bg-red-500/20';
    case 'CRITICAL':
      return 'bg-red-600/20';
    case 'MODERATE':
      return 'bg-purple-500/20';
    case 'LOW':
      return 'bg-green-500/20';
    default:
      return 'bg-slate-500/10';
  }
};

export const severityToBorderColor = (severity: string): string => {
  switch (severity?.toUpperCase()) {
    case 'SEVERE':
      return 'border-red-500/30';
    case 'CRITICAL':
      return 'border-red-600/30';
    case 'MODERATE':
      return 'border-purple-500/30';
    case 'LOW':
      return 'border-green-500/30';
    default:
      return 'border-slate-500/10';
  }
};

// ==========================================
// DATA FORMATTING UTILITIES
// ==========================================

export const formatTimestamp = (timestamp: string | null): string => {
  if (!timestamp) return 'Never';
  const date = new Date(timestamp);
  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
};

export const formatDate = (timestamp: string | null): string => {
  if (!timestamp) return 'N/A';
  const date = new Date(timestamp);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
};

export const formatNumber = (value: number, precision: number = 2): string => {
  return value.toFixed(precision);
};

// ==========================================
// CONFIDENCE LEVEL FORMATTER
// ==========================================

export const getConfidenceLabel = (confidence: number): string => {
  if (confidence >= 95) return 'Extremely High';
  if (confidence >= 85) return 'Very High';
  if (confidence >= 75) return 'High';
  if (confidence >= 60) return 'Moderate';
  return 'Low';
};

// ==========================================
// PREDICTION ANALYSIS HELPERS
// ==========================================

export const shouldShowWarning = (severity: string): boolean => {
  return ['SEVERE', 'CRITICAL', 'MODERATE'].includes(severity?.toUpperCase());
};

export const getRecommendedAction = (severity: string, confidence: number): string => {
  const sev = severity?.toUpperCase();
  
  if (sev === 'CRITICAL' && confidence > 90) {
    return 'IMMEDIATE EVACUATION RECOMMENDED';
  }
  
  if (sev === 'SEVERE' && confidence > 85) {
    return 'PREPARE FOR EVACUATION';
  }
  
  if (sev === 'MODERATE' && confidence > 80) {
    return 'INCREASE MONITORING & PREPARE';
  }
  
  return 'CONTINUE MONITORING';
};

// ==========================================
// ERROR HANDLING
// ==========================================

export const getErrorMessage = (error: any): string => {
  if (typeof error === 'string') return error;
  if (error?.message) return error.message;
  if (error?.detail) return error.detail;
  if (error?.response?.data?.detail) return error.response.data.detail;
  if (error?.response?.data?.message) return error.response.data.message;
  return 'An unexpected error occurred';
};

// ==========================================
// API HELPERS
// ==========================================

export const buildPredictionPayload = (formData: Partial<FormData>) => {
  return {
    Peak_Flood_Level_m: formData.Peak_Flood_Level_m || 0,
    state: formData.state || 'Maharashtra',
    Event_Duration_days: formData.Event_Duration_days || 0,
    Time_to_Peak_days: formData.Time_to_Peak_days || 0,
    Recession_Time_day: formData.Recession_Time_day || 0,
    T1d: formData.T1d || 0,
    T2d: formData.T2d || 0,
    T3d: formData.T3d || 0,
    T4d: formData.T4d || 0,
    T5d: formData.T5d || 0,
    T6d: formData.T6d || 0,
    T7d: formData.T7d || 0
  };
};

export const isFallbackResponse = (prediction: any): boolean => {
  return prediction?.algorithm?.includes('Fallback') || 
         prediction?.data_source === 'OFFLINE_ESTIMATE';
};
