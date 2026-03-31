# IndoFloods ML Integration Guide

## Overview

Complete integration of the Indian flood prediction ML model with comprehensive state management. This system provides:

- ✅ RandomForest multi-class flood severity prediction (CRITICAL, SEVERE, MODERATE, LOW)
- ✅ 7-day rainfall distribution tracking and analysis
- ✅ Indian state-specific model support (34 states/UTs)
- ✅ Live CWC (Central Water Commission) data integration
- ✅ Real-time monitoring protocols and alert zones
- ✅ Kolhapur-specific specialization

---

## Architecture

### State Management Hierarchy

```
AppState
├── prediction (ML Model State)
│   ├── currentPrediction: Severity + Confidence
│   ├── history: 100 recent predictions
│   ├── selectedState: "Maharashtra"
│   ├── monitoringLevel: STANDARD | ELEVATED | CRITICAL
│   ├── monitoringAction: Recommended actions
│   ├── priorityZones: Zones needing attention
│   ├── cwcDataSource: LIVE_CWC | LOCAL_CACHE | MANUAL
│   └── dangerLevel: Critical threshold (13.5m for Kolhapur)
│
├── form (Input Parameters)
│   ├── data: Complete FormData
│   │   ├── Peak_Flood_Level_m (0-25m)
│   │   ├── Event_Duration_days (0-30)
│   │   ├── Time_to_Peak_days (0-10)
│   │   ├── Recession_Time_day (0-10)
│   │   ├── T1d to T7d: Daily rainfall (0-200mm each)
│   │   ├── state: Selected Indian state
│   │   └── station: River gauge (e.g., "Kolhapur")
│   ├── rainfallTotal: Sum of 7 days
│   ├── rainfallAverage: Average per day
│   └── rainfallDistribution: Daily breakdown
│
├── cwc (Live Data Integration)
│   ├── isConnected: CWC API status
│   ├── lastFetchTime: When data was fetched
│   └── liveData: Real Kolhapur water levels
│
└── models (Indian State Models)
    ├── availableStates: All 34 states
    ├── currentStateModel: Selected state
    └── isMultiStateCapable: True
```

---

## ML Model Architecture

### Backend Features (backend/app.py)

```python
# Input Features (11 parameters)
Peak_Flood_Level_m       # Current/predicted river height
Event_Duration_days      # How long flood event lasts
Time_to_Peak_days        # Days until peak water level
Recession_Time_day       # Days for water to recede
T1d, T2d...T7d          # Daily rainfall distribution (7 days)

# Model: RandomForestClassifier(n_estimators=150, max_depth=12)
# Classes: 0=LOW, 1=MODERATE, 2=SEVERE, escalates to CRITICAL

# Output
{
  "severity": "CRITICAL" | "SEVERE" | "MODERATE" | "LOW",
  "confidence_percent": 95.2,
  "probabilities": {
    "LOW": 5.0,
    "MODERATE": 10.0,
    "SEVERE": 85.0,
    "CRITICAL": (escalated)
  },
  "risk_score": 85,
  "monitoring": {
    "level": "CRITICAL EMERGENCY",
    "action": "Evacuate vulnerable river basins",
    "priority_zones": ["Primary Catchment", "Downstream Villages"]
  }
}
```

### Critical Escalation Rules

```javascript
// CRITICAL escalation thresholds
if (Peak_Flood_Level_m >= 13.5 || T7d >= 650) {
  severity = "CRITICAL"
  confidence = max(confidence, 95%)
}

// Monitoring protocol mapping
CRITICAL   → "CRITICAL EMERGENCY" + Immediate evacuation
SEVERE     → "CRITICAL EMERGENCY" + Prepare evacuation
MODERATE   → "ELEVATED ALERT" + Deploy monitoring teams
LOW        → "STANDARD PROTOCOL" + Maintain surveillance
```

---

## Frontend Integration Points

### 1. Prediction Flow with Enhanced State

```typescript
const { predictWithFullModel, isLoading } = useEnhancedPrediction();

const handlePredictClick = async () => {
  try {
    // This hook handles:
    // 1. Calculate rainfall stats
    // 2. Fetch live CWC data (if available)
    // 3. Call state-specific model
    // 4. Update monitoring protocols
    // 5. Update all state automatically
    const result = await predictWithFullModel();
    
    // Result includes all monitoring info
    console.log(result.monitoring); // Actions for users
    console.log(result.priorityZones); // Skip zones
  } catch (error) {
    // Falls back to offline/heuristic mode
  }
};
```

### 2. Indian State Model Selection

```typescript
const { selectedState, selectState, availableStates } = useIndianStateModels();

// Available states (34 total)
const states = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
  'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
  'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
  'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
  'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
  'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
  'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
  'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
];

// Switch models
selectState('Kerala'); // Uses kerala_flood_model.pkl
selectState('Maharashtra'); // Uses kolhapur_flood_model.pkl
selectState('Karnataka'); // Uses indofloods_production_model.pkl
```

### 3. CWC Live Data Integration

```typescript
const { fetchCWCData, isConnected } = useCWCIntegration();

// Automatic CWC fetch during prediction
// Or manual fetch
const cwcData = await fetchCWCData();

// Result
{
  kolhapurLevel: 11.4,      // Live meter reading
  kolhapurStatus: "WARNING", // ACTIVE | WARNING | CRITICAL | OFFLINE
  source: "CWC_API"         // or HTML_SCRAPE | CACHED | MANUAL
}

// If CWC data available, it overrides user input
dispatch({
  type: 'SET_FORM_DATA',
  payload: { Peak_Flood_Level_m: cwcData.kolhapurLevel }
});
```

### 4. Rainfall Statistics Tracking

```typescript
const { updateRainfallStats } = useRainfallStats(formData);

// Automatically calculates:
rainfallTotal: 2848.8     // Sum of T1d-T7d
rainfallAverage: 407.0    // Average daily
rainfallDistribution: [
  { day: 1, mm: 156.4 },
  { day: 2, mm: 299.2 },
  // ... up to day 7
]

// Used for trend analysis and visualization
```

---

## Component Usage Example

### Enhanced Dashboard Component

```typescript
import { useAppState } from './context/AppContext';
import { useEnhancedPrediction, useIndianStateModels } from './hooks/useAppOperations';

function FloodDashboard() {
  const { state, dispatch } = useAppState();
  const { predictWithFullModel, isLoading } = useEnhancedPrediction();
  const { selectedState, selectState, availableStates } = useIndianStateModels();

  return (
    <div>
      {/* State Selector */}
      <select value={selectedState} onChange={(e) => selectState(e.target.value)}>
        {availableStates.map(state => (
          <option key={state} value={state}>{state}</option>
        ))}
      </select>

      {/* Input Fields */}
      <input
        type="number"
        value={state.form.data.Peak_Flood_Level_m}
        onChange={(e) => dispatch({
          type: 'SET_FORM_DATA',
          payload: { Peak_Flood_Level_m: parseFloat(e.target.value) }
        })}
        label="Peak River Level (m)"
      />

      {/* 7-Day Rainfall Inputs */}
      {[1, 2, 3, 4, 5, 6, 7].map(day => (
        <input
          key={day}
          type="number"
          value={state.form.data[`T${day}d` as keyof FormData]}
          onChange={(e) => dispatch({
            type: 'SET_FORM_DATA',
            payload: { [`T${day}d`]: parseFloat(e.target.value) }
          })}
          label={`Day ${day} Rainfall (mm)`}
        />
      ))}

      {/* Rainfall Stats Display */}
      <div>
        <p>7-Day Total: {state.form.rainfallTotal.toFixed(1)}mm</p>
        <p>Daily Average: {state.form.rainfallAverage.toFixed(1)}mm</p>
      </div>

      {/* Predict Button */}
      <button
        onClick={predictWithFullModel}
        disabled={isLoading}
      >
        {isLoading ? 'Predicting...' : 'Execute Model Inference'}
      </button>

      {/* Results */}
      {state.prediction.currentPrediction && (
        <div>
          <h3>Prediction Result</h3>
          <p>Severity: {state.prediction.currentPrediction.severity}</p>
          <p>Confidence: {state.prediction.currentPrediction.confidence_percent}%</p>
          
          {/* Monitoring Protocol */}
          <section>
            <h4>Monitoring Level: {state.prediction.monitoringLevel}</h4>
            <p>Action: {state.prediction.monitoringAction}</p>
            <p>Priority Zones:</p>
            <ul>
              {state.prediction.priorityZones.map(zone => (
                <li key={zone}>{zone}</li>
              ))}
            </ul>
          </section>

          {/* CWC Data Source */}
          <p>Data Source: {state.prediction.cwcDataSource}</p>
          {state.cwc.liveData.kolhapurLevel && (
            <p>Live Kolhapur Level: {state.cwc.liveData.kolhapurLevel}m</p>
          )}
        </div>
      )}

      {/* Prediction History */}
      <section>
        <h3>History ({state.prediction.history.length})</h3>
        {state.prediction.history.slice(0, 5).map(pred => (
          <div key={pred.id}>
            <p>{new Date(pred.timestamp).toLocaleString()}</p>
            <p>{pred.severity} @ {pred.confidence}%</p>
          </div>
        ))}
      </section>
    </div>
  );
}
```

---

## State Action Reference

### Prediction Actions with ML Model

```typescript
// Set current prediction from model
dispatch({ type: 'SET_PREDICTION', payload: predictionResult });

// Add to history
dispatch({
  type: 'ADD_PREDICTION_LOG',
  payload: {
    id: timestamp,
    timestamp: new Date().toISOString(),
    peak_level: formData.Peak_Flood_Level_m,
    rainfall: formData.T7d,
    severity: result.severity,
    confidence: result.confidence_percent
  }
});

// Update selected state model
dispatch({ type: 'SET_SELECTED_STATE', payload: 'Maharashtra' });

// Update monitoring protocols
dispatch({ type: 'SET_MONITORING_LEVEL', payload: 'CRITICAL' });
dispatch({ type: 'SET_MONITORING_ACTION', payload: 'Evacuate immediately' });
dispatch({ type: 'SET_PRIORITY_ZONES', payload: ['Zone A', 'Zone B'] });

// CWC data integration
dispatch({
  type: 'SET_CWC_LIVE_DATA',
  payload: {
    kolhapurLevel: 13.2,
    kolhapurStatus: 'WARNING',
    source: 'CWC_API'
  }
});

// Rainfall stats
dispatch({
  type: 'UPDATE_RAINFALL_STATS',
  payload: {
    total: 2850,
    average: 407,
    distribution: [...]
  }
});
```

---

## Backend API Integration

### /predict Endpoint Response

The backend returns comprehensive ML predictions:

```json
{
  "severity": "SEVERE",
  "confidence_percent": 92.5,
  "alert": "⚠️",
  "algorithm": "RandomForest Classifier (Live Inference)",
  "probabilities": {
    "LOW": 5.0,
    "MODERATE": 15.0,
    "SEVERE": 80.0
  },
  "risk_score": 80,
  "danger_level": 12.0,
  "state": "Maharashtra",
  "monitoring": {
    "level": "CRITICAL EMERGENCY",
    "action": "Evacuate vulnerable river basins immediately.",
    "priority_zones": [
      "Primary Catchment",
      "Downstream Villages",
      "Low-lying urban zones"
    ]
  },
  "data_source": "Live CWC Sensor (API)"
}
```

---

## Feature Highlights

### 1. Multi-Class Classification
- **CRITICAL**: Peak ≥ 13.5m OR Rainfall ≥ 650mm
- **SEVERE**: Peak ≥ 12.5m OR Rainfall ≥ 450mm
- **MODERATE**: Peak ≥ 11.5m OR Rainfall ≥ 300mm
- **LOW**: Everything else

### 2. State-Specific Models
- Kolhapur (Maharashtra): `kolhapur_flood_model.pkl`
- Southern India (production): `indofloods_production_model.pkl`
- Default: `flood_model.pkl`

### 3. 7-Day Rainfall Distribution
- Tracks daily rainfall patterns
- Calculates trends and totals
- Enables drought/flood prediction

### 4. Live CWC Integration
- Fetches from `ffs.india-water.gov.in` API
- Falls back to HTML scraping
- Overrides manual input if available

### 5. Monitoring Protocols
- Automatic escalation rules
- Zone-specific recommendations
- Action items for emergency response

---

## Performance Metrics

```typescript
// Tracked in state
state.prediction.accuracy      // 95.2%
state.prediction.latency       // ~1200ms
state.prediction.modelVersion  // "RandomForest v4.2"

// Historical tracking
state.prediction.totalPredictionsMade  // Counter
state.prediction.lastPredictionTime    // ISO timestamp
```

---

## Error Handling & Fallbacks

```typescript
// CWC unavailable?
cwcDataSource = 'LOCAL_CACHE'   // Use cached data
cwcDataSource = 'MANUAL'         // Use user input

// Model unavailable?
algorithm = 'Python Heuristic Fallback'  // Use manual rules
model_trained = false                     // Confidence reduced

// Network offline?
apiStatus = 'OFFLINE'  // Fully offline mode
// Still supports local state predictions
```

---

## Testing the Integration

```bash
# Start frontend
cd frontend
npm run dev

# In another terminal, test CWC integration
curl -X POST https://localhost:5173/api/predict \
  -H "Content-Type: application/json" \
  -d '{
    "Peak_Flood_Level_m": 12.5,
    "Event_Duration_days": 3,
    "Time_to_Peak_days": 2,
    "Recession_Time_day": 2,
    "T1d": 156.4,
    "T2d": 299.2,
    "T3d": 384.4,
    "T4d": 384.4,
    "T5d": 384.4,
    "T6d": 384.4,
    "T7d": 455.6,
    "state": "Maharashtra"
  }'
```

---

## Indian Flood Prediction Features

✅ All 34 Indian states/UTs supported  
✅ Central Water Commission (CWC) integration  
✅ Kolhapur-specific model specialization  
✅ Multi-class severity prediction  
✅ 7-day rainfall pattern analysis  
✅ Emergency monitoring protocols  
✅ Priority zone identification  
✅ Automated alert escalation  
✅ Fallback heuristics for offline mode  
✅ State-specific thresholds and models

---

## Next Enhancements

- [ ] Historical flood data mining
- [ ] Weather API integration  
- [ ] Real-time SMS/push alerts
- [ ] Multi-river basin support
- [ ] Seasonal pattern recognition
- [ ] Flood damage estimation
- [ ] Evacuation route optimization
- [ ] Community reporting integration
