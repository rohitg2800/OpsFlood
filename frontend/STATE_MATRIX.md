# State Matrix Documentation

## Overview

A comprehensive state management system has been implemented for the IndoFloods ML application. This state matrix provides a single source of truth for all application state, ensuring predictable state transitions and easier debugging.

## Architecture

### Key Components

1. **types.ts** - Type definitions and initial state
2. **context/AppContext.tsx** - State reducer and context provider
3. **hooks/useAppOperations.ts** - Custom hooks for API operations
4. **utils/validation.ts** - Validation and utility functions

## State Structure

```typescript
AppState {
  ui: {
    activeTab: Tab selection
    modalOpen: Modal state
    sidebarOpen: Sidebar visibility
    darkMode: Theme toggle
    notificationsEnabled: Notification setting
  }
  
  system: {
    apiStatus: API health
    apiVersion: Version tracking
    lastSyncTime: Last sync timestamp
    errorMessage: Error state
    isInitialized: Init flag
  }
  
  prediction: {
    currentPrediction: Current flood prediction
    history: Prediction history
    isLoading: Loading state
    lastPredictionTime: Last prediction time
    totalPredictionsMade: Counter
    accuracy: Model accuracy %
    latency: Response time ms
  }
  
  sensors: {
    data: Sensor data array
    isLoading: Loading state
    lastRefresh: Refresh timestamp
    activeStations: Active count
    offlineStations: Offline count
    criticalAlerts: Alert count
  }
  
  form: {
    data: Form input data
    isDirty: Modification flag
    isValid: Validation flag
    errors: Field errors
    touched: Touched fields
    lastSubmitTime: Last submit time
  }
  
  alerts: {
    active: Active alerts
    total: Total alerts
    criticalCount: Critical count
    isSubscribedToNotifications: Subscription flag
  }
  
  data: {
    weatherData: Weather information
    locationData: Location information
    historicalMetrics: Historical data
    isLoadingWeather: Loading state
    weatherLastUpdate: Last update time
  }
  
  preferences: {
    theme: Theme setting
    language: Language selection
    refreshInterval: Auto-refresh interval
    autoRefreshEnabled: Auto-refresh flag
    displayPrecision: Decimal precision
    alertSound: Sound alert flag
  }
}
```

## Usage Examples

### Using the Context in Components

```typescript
import { useAppState } from '../context/AppContext';

function MyComponent() {
  const { state, dispatch, setActiveTab } = useAppState();
  
  // Access state
  const currentPrediction = state.prediction.currentPrediction;
  const isLoading = state.prediction.isLoading;
  
  // Dispatch actions
  dispatch({ type: 'SET_ACTIVE_TAB', payload: 'logs' });
  
  // Use convenience methods
  setActiveTab('sensors');
}
```

### Using Custom Hooks

```typescript
import { usePredictionAPI, useAutoRefresh } from '../hooks/useAppOperations';

function PredictionPanel() {
  const { predict, isLoading } = usePredictionAPI();
  
  const handlePredictClick = async () => {
    const result = await predict({ Peak_Flood_Level_m: 12.5, T7d: 450 });
    console.log('Prediction result:', result);
  };
  
  // Auto-refresh predictions
  useAutoRefresh(() => {
    handlePredictClick();
  });
  
  return (
    <button onClick={handlePredictClick} disabled={isLoading}>
      {isLoading ? 'Predicting...' : 'Predict'}
    </button>
  );
}
```

### Using Validation Utilities

```typescript
import { validateFormData, getRecommendedAction } from '../utils/validation';

function FormValidator() {
  const errors = validateFormData({ Peak_Flood_Level_m: 12.5 });
  const action = getRecommendedAction('SEVERE', 92);
  
  return (
    <div>
      {errors.length > 0 && <ErrorList errors={errors} />}
      <p>Recommended: {action}</p>
    </div>
  );
}
```

## Action Types

### UI Actions
- `SET_ACTIVE_TAB` - Change active tab
- `SET_MODAL` - Open/close modal
- `TOGGLE_SIDEBAR` - Toggle sidebar
- `TOGGLE_DARK_MODE` - Toggle theme
- `TOGGLE_NOTIFICATIONS` - Toggle notifications

### System Actions
- `SET_API_STATUS` - Update API status
- `SET_API_VERSION` - Update API version
- `SET_ERROR` - Set error message
- `INIT_SYSTEM` - Initialize system

### Prediction Actions
- `SET_PREDICTION` - Set current prediction
- `ADD_PREDICTION_LOG` - Add to history
- `CLEAR_PREDICTION` - Clear prediction
- `SET_PREDICTION_LOADING` - Set loading state
- `SET_ACCURACY` - Update accuracy
- `SET_LATENCY` - Update latency

### Sensor Actions
- `SET_SENSOR_DATA` - Set sensor data
- `SET_SENSOR_LOADING` - Set loading state
- `ADD_SENSOR` - Add single sensor
- `UPDATE_SENSOR` - Update sensor data

### Form Actions
- `SET_FORM_DATA` - Update form field
- `SET_FORM_ERROR` - Set field error
- `SET_FORM_TOUCHED` - Mark field touched
- `RESET_FORM` - Reset form
- `SET_FORM_VALID` - Set validity
- `SET_FORM_DIRTY` - Set dirty flag

### Alert Actions
- `ADD_ALERT` - Add alert
- `REMOVE_ALERT` - Remove alert
- `CLEAR_ALERTS` - Clear all alerts

### Other Actions
- `SET_WEATHER_DATA` - Update weather
- `SET_LOCATION_DATA` - Update location
- `SET_WEATHER_LOADING` - Weather loading
- `SET_THEME` - Change theme
- `SET_AUTO_REFRESH` - Enable/disable auto-refresh
- `SET_REFRESH_INTERVAL` - Set refresh interval
- `TOGGLE_ALERT_SOUND` - Toggle sound
- `RESET_STATE` - Reset entire state

## Custom Hooks

### usePredictionAPI()
Manages flood prediction API calls with fallback handling.

**Returns:**
- `predict(formData)` - Async function to make prediction
- `isLoading` - Loading state

### useSensorAPI()
Manages sensor data fetching.

**Returns:**
- `fetchSensors()` - Async function to fetch sensor data
- `isLoading` - Loading state

### useAutoRefresh(callback)
Enables automatic refresh at configured intervals.

**Params:**
- `callback` - Function to call on refresh

### useAlertNotifications()
Manages alerts and notifications.

**Returns:**
- `notifyUser(options)` - Show notification
- `playAlertSound()` - Play alert sound

### useSystemInit()
Initializes system on mount.

### useFormValidation(formData)
Validates form fields.

**Returns:**
- `validateField(field, value)` - Validate single field
- `validateAllFields()` - Validate all fields

## Utility Functions

### validation.ts

**Color Helpers:**
- `severityToColor()` - Get text color for severity
- `severityToBgColor()` - Get background color
- `severityToBorderColor()` - Get border color

**Formatters:**
- `formatTimestamp()` - Format time
- `formatDate()` - Format date
- `formatNumber()` - Format number with precision
- `getConfidenceLabel()` - Human-readable confidence
- `getRecommendedAction()` - Action recommendation

**Analysis:**
- `shouldShowWarning()` - Check if warning needed
- `isFallbackResponse()` - Check if fallback model

**Error Handling:**
- `getErrorMessage()` - Extract error message
- `validateFormData()` - Validate form data
- `buildPredictionPayload()` - Build API payload

## Integration with App.tsx

Replace scattered useState hooks with context usage:

```typescript
// Before (multiple useState)
const [prediction, setPrediction] = useState(null);
const [loading, setLoading] = useState(false);
const [activeTab, setActiveTab] = useState('dash');

// After (single context)
const { state, setActiveTab, setPrediction, setLoading } = useAppState();
```

## Benefits

✅ **Single Source of Truth** - All state in one place
✅ **Predictable State Transitions** - Clear action types
✅ **Easy Debugging** - Centralized logging
✅ **Type Safety** - Full TypeScript support
✅ **Scalability** - Easy to add new state
✅ **Separation of Concerns** - Logic separated from components
✅ **Testability** - Pure reducer functions
✅ **Performance** - Optimized context splitting available

## Next Steps

1. Wrap App component with `AppProvider`
2. Replace useState hooks with useAppState()
3. Use custom hooks for API calls
4. Apply validation utilities to form
5. Implement alert notifications system
6. Add localStorage persistence (future enhancement)
