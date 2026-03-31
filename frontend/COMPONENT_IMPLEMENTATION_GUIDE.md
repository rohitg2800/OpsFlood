# IndoFloods UI Components Implementation Guide

Quick reference for building the remaining Indian flood prediction UI components.

---

## TODO: 1. Update App.tsx - Use Enhanced Prediction

**Current Issue:** App.tsx uses basic `usePredictionAPI()` which doesn't include:
- CWC live data fetch
- Rainfall statistics calculation
- State-specific model selection
- Monitoring protocol updates

**What to Change:**

```typescript
// REPLACE THIS:
const { predict, isLoading: predictionLoading } = usePredictionAPI();

// WITH THIS:
const { predictWithFullModel, isLoading: predictionLoading } = useEnhancedPrediction();
```

**Update handlePredict function:**

```typescript
// REPLACE THIS:
const handlePredict = async () => {
  const result = await predict(state.form.data);
};

// WITH THIS:
const handlePredict = async () => {
  const result = await predictWithFullModel();
};
```

**Benefits:**
- Automatically calculates rainfall stats
- Fetches live CWC data
- Uses state-specific model
- Updates all monitoring fields
- No code duplication

**Location:** [src/App.tsx](src/App.tsx) - search for `handlePredict`

---

## TODO: 2. Create State Selector Dropdown Component

**File to create:** `/frontend/src/components/StateSelector.tsx`

```typescript
import React from 'react';
import { useAppState } from '../context/AppContext';
import { useIndianStateModels } from '../hooks/useAppOperations';

interface StateSelectorProps {
  id?: string;
  className?: string;
}

export function StateSelector({ id = 'state-select', className = '' }: StateSelectorProps) {
  const { state } = useAppState();
  const { selectedState, selectState, availableStates } = useIndianStateModels();

  return (
    <div className={`flex flex-col ${className}`}>
      <label htmlFor={id} className="block text-sm font-medium text-gray-700 mb-2">
        Indian State/UT
      </label>
      <select
        id={id}
        value={selectedState}
        onChange={(e) => selectState(e.target.value)}
        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">Select State...</option>
        {availableStates.map((state) => (
          <option key={state} value={state}>
            {state}
          </option>
        ))}
      </select>
      
      {/* Current Model Info */}
      {state.models.currentStateModel && (
        <p className="text-xs text-gray-500 mt-1">
          Using {state.models.currentStateModel} model
        </p>
      )}
    </div>
  );
}
```

**Usage in App.tsx:**

```typescript
import { StateSelector } from './components/StateSelector';

// Add to form section:
<StateSelector className="mb-4" />
```

---

## TODO: 3. Create Rainfall Distribution Chart

**File to create:** `/frontend/src/components/RainfallDistributionChart.tsx`

```typescript
import React from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { useAppState } from '../context/AppContext';

export function RainfallDistributionChart() {
  const { state } = useAppState();

  // Prepare data from state
  const data = state.form.rainfallDistribution || [];

  if (data.length === 0) {
    return (
      <div className="w-full h-80 flex items-center justify-center bg-gray-50 rounded-lg border border-gray-200">
        <p className="text-gray-400">No rainfall data available</p>
      </div>
    );
  }

  return (
    <div className="w-full bg-white p-6 rounded-lg border border-gray-200">
      <h3 className="text-lg font-semibold text-gray-800 mb-4">
        7-Day Rainfall Distribution
      </h3>

      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-blue-50 p-4 rounded-lg">
          <p className="text-xs text-gray-600">Total Rainfall</p>
          <p className="text-2xl font-bold text-blue-600">
            {state.form.rainfallTotal.toFixed(1)}
            <span className="text-sm">mm</span>
          </p>
        </div>
        <div className="bg-green-50 p-4 rounded-lg">
          <p className="text-xs text-gray-600">Daily Average</p>
          <p className="text-2xl font-bold text-green-600">
            {state.form.rainfallAverage.toFixed(1)}
            <span className="text-sm">mm</span>
          </p>
        </div>
        <div className="bg-yellow-50 p-4 rounded-lg">
          <p className="text-xs text-gray-600">Trend</p>
          <p className="text-2xl font-bold text-yellow-600">
            {state.form.rainfallTotal > 600 ? '⚠️ High' : '✓ Normal'}
          </p>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="day" label={{ value: 'Day', position: 'insideBottomRight', offset: -5 }} />
          <YAxis label={{ value: 'Rainfall (mm)', angle: -90, position: 'insideLeft' }} />
          <Tooltip
            formatter={(value: number) => `${value.toFixed(1)} mm`}
            labelFormatter={(day: number) => `Day ${day}`}
          />
          <Bar dataKey="mm" fill="#3b82f6" name="Rainfall" />
        </BarChart>
      </ResponsiveContainer>

      {/* Rainfall Categories */}
      <div className="mt-6 p-4 bg-gray-50 rounded-lg">
        <h4 className="text-sm font-semibold text-gray-700 mb-2">Rainfall Category</h4>
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded-full bg-green-500"></div>
          <p className="text-sm text-gray-600">
            {state.form.rainfallTotal < 300
              ? 'Low (Normal Conditions)'
              : state.form.rainfallTotal < 450
              ? 'Moderate (Caution)'
              : state.form.rainfallTotal < 600
              ? 'High (Alert)'
              : 'Critical (Emergency)'}
          </p>
        </div>
      </div>
    </div>
  );
}
```

**Usage in App.tsx:**

```typescript
import { RainfallDistributionChart } from './components/RainfallDistributionChart';

// Add to data/visualization section:
<RainfallDistributionChart />
```

---

## TODO: 4. Create CWC Live Data Display Component

**File to create:** `/frontend/src/components/CWCLiveDataDisplay.tsx`

```typescript
import React, { useEffect } from 'react';
import { Droplets, AlertCircle, CheckCircle, Clock } from 'lucide-react';
import { useAppState } from '../context/AppContext';
import { useCWCIntegration } from '../hooks/useAppOperations';

export function CWCLiveDataDisplay() {
  const { state } = useAppState();
  const { fetchCWCData, isConnected } = useCWCIntegration();

  // Auto-refresh CWC data every 5 minutes
  useEffect(() => {
    const interval = setInterval(() => {
      if (state.system.isOnline) {
        fetchCWCData();
      }
    }, 5 * 60 * 1000);

    return () => clearInterval(interval);
  }, [fetchCWCData, state.system.isOnline]);

  const cwc = state.cwc;
  const Level = cwc.liveData.kolhapurLevel;
  const Status = cwc.liveData.kolhapurStatus;
  const DangerLevel = state.prediction.dangerLevel || 13.5;

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'CRITICAL':
        return 'bg-red-50 border-red-200 text-red-800';
      case 'WARNING':
        return 'bg-yellow-50 border-yellow-200 text-yellow-800';
      case 'ACTIVE':
        return 'bg-orange-50 border-orange-200 text-orange-800';
      default:
        return 'bg-green-50 border-green-200 text-green-800';
    }
  };

  const getStatusIcon = (status: string) => {
    if (status === 'CRITICAL' || status === 'WARNING') {
      return <AlertCircle className="w-5 h-5" />;
    }
    return <CheckCircle className="w-5 h-5" />;
  };

  return (
    <div className="w-full bg-white p-6 rounded-lg border border-gray-200">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Droplets className="w-5 h-5 text-blue-600" />
          <h3 className="text-lg font-semibold text-gray-800">
            Kolhapur Water Level (Live)
          </h3>
        </div>
        <div className="flex items-center gap-1 text-xs text-gray-500">
          <Clock className="w-4 h-4" />
          <span>
            Updated{' '}
            {new Date(cwc.lastFetchTime).toLocaleTimeString()}
          </span>
        </div>
      </div>

      {!isConnected ? (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
          <p className="text-gray-600 text-sm">
            No real-time CWC data available. Using manual input.
          </p>
        </div>
      ) : (
        <>
          {/* Current Water Level */}
          <div className={`rounded-lg border p-6 mb-4 ${getStatusColor(Status)}`}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs font-medium opacity-75 mb-1">
                  Current Water Level
                </p>
                <p className="text-4xl font-bold">{Level}m</p>
              </div>
              <div className="flex flex-col items-end">
                {getStatusIcon(Status)}
                <p className="text-sm font-semibold mt-2">{Status}</p>
              </div>
            </div>
          </div>

          {/* Danger Level Indicator */}
          <div className="bg-gray-50 rounded-lg p-4 mb-4">
            <div className="flex justify-between items-center mb-2">
              <p className="text-sm font-medium text-gray-700">
                Danger Threshold
              </p>
              <p className="text-sm font-bold text-gray-800">{DangerLevel}m</p>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className={`h-2 rounded-full transition-all ${
                  Level >= DangerLevel ? 'bg-red-600' : 'bg-yellow-500'
                }`}
                style={{ width: `${Math.min((Level / DangerLevel) * 100, 100)}%` }}
              ></div>
            </div>
            <p className="text-xs text-gray-500 mt-2">
              {Level >= DangerLevel
                ? '🚨 Above danger level'
                : `${(DangerLevel - Level).toFixed(1)}m until danger level`}
            </p>
          </div>

          {/* Data Source */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p className="text-xs text-blue-800">
              <span className="font-semibold">Data Source:</span>{' '}
              {cwc.liveData.source === 'CWC_API'
                ? 'India Water Resources (Official CWC API)'
                : cwc.liveData.source === 'HTML_SCRAPE'
                ? 'Water Resources Data (Scraped)'
                : cwc.liveData.source === 'CACHED'
                ? 'Cached from Previous Fetch'
                : 'Manual Input'}
            </p>
          </div>
        </>
      )}
    </div>
  );
}
```

**Usage in App.tsx:**

```typescript
import { CWCLiveDataDisplay } from './components/CWCLiveDataDisplay';

// Add to dashboard:
<CWCLiveDataDisplay />
```

---

## TODO: 5. Enhanced Monitoring Protocol Display

**File to create:** `/frontend/src/components/MonitoringProtocolAlert.tsx`

```typescript
import React from 'react';
import { AlertTriangle, AlertCircle, Info, Shield } from 'lucide-react';
import { useAppState } from '../context/AppContext';

export function MonitoringProtocolAlert() {
  const { state } = useAppState();
  const monitoring = state.prediction.monitoringLevel;
  const action = state.prediction.monitoringAction;
  const zones = state.prediction.priorityZones;

  if (!monitoring) {
    return null;
  }

  const getAlertStyle = (level: string) => {
    switch (level) {
      case 'CRITICAL EMERGENCY':
        return {
          bg: 'bg-red-50',
          border: 'border-red-200',
          icon: AlertTriangle,
          color: 'text-red-800',
          badge: 'bg-red-600 text-white',
        };
      case 'HIGH ALERT':
        return {
          bg: 'bg-orange-50',
          border: 'border-orange-200',
          icon: AlertCircle,
          color: 'text-orange-800',
          badge: 'bg-orange-600 text-white',
        };
      case 'ELEVATED ALERT':
        return {
          bg: 'bg-yellow-50',
          border: 'border-yellow-200',
          icon: Info,
          color: 'text-yellow-800',
          badge: 'bg-yellow-600 text-white',
        };
      default:
        return {
          bg: 'bg-green-50',
          border: 'border-green-200',
          icon: Shield,
          color: 'text-green-800',
          badge: 'bg-green-600 text-white',
        };
    }
  };

  const style = getAlertStyle(monitoring);
  const Icon = style.icon;

  return (
    <div className={`w-full rounded-lg border p-6 ${style.bg} ${style.border}`}>
      <div className="flex items-start gap-4">
        <Icon className={`w-6 h-6 ${style.color} flex-shrink-0 mt-0.5`} />

        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <h3 className={`text-lg font-bold ${style.color}`}>
              {monitoring}
            </h3>
            <span className={`px-3 py-1 rounded-full text-xs font-semibold ${style.badge}`}>
              {state.prediction.severity}
            </span>
          </div>

          {/* Recommended Action */}
          <p className={`text-sm font-semibold ${style.color} mb-4`}>
            {action}
          </p>

          {/* Priority Zones */}
          {zones.length > 0 && (
            <div>
              <p className={`text-xs font-semibold ${style.color} mb-2`}>
                Priority Zones:
              </p>
              <div className="flex flex-wrap gap-2">
                {zones.map((zone, idx) => (
                  <span
                    key={idx}
                    className={`px-3 py-1 rounded-lg text-xs font-medium ${style.badge}`}
                  >
                    {zone}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Metadata */}
          <div className="mt-4 pt-4 border-t border-current border-opacity-10">
            <p className={`text-xs ${style.color}`}>
              Confidence: {state.prediction.currentPrediction?.confidence_percent}%
              <br />
              Risk Score: {state.prediction.currentPrediction?.risk_score}
              <br />
              Data Source: {state.prediction.cwcDataSource}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
```

**Usage in App.tsx:**

```typescript
import { MonitoringProtocolAlert } from './components/MonitoringProtocolAlert';

// Add at top of results section:
{state.prediction.currentPrediction && (
  <MonitoringProtocolAlert />
)}
```

---

## Quick File Structure

After adding all components, your structure should look like:

```
frontend/src/
├── components/
│   ├── StateSelector.tsx          [TODO 2]
│   ├── RainfallDistributionChart.tsx   [TODO 3]
│   ├── CWCLiveDataDisplay.tsx     [TODO 4]
│   └── MonitoringProtocolAlert.tsx [TODO 5]
├── App.tsx                         [TODO 1 - Update]
├── context/
│   └── AppContext.tsx
├── hooks/
│   └── useAppOperations.ts
├── utils/
│   └── validation.ts
└── types.ts
```

---

## Integration Checklist

- [ ] **TODO 1:** Update App.tsx to use `useEnhancedPrediction()`
- [ ] **TODO 2:** Create and import `StateSelector` component
- [ ] **TODO 3:** Create and import `RainfallDistributionChart` component
- [ ] **TODO 4:** Create and import `CWCLiveDataDisplay` component
- [ ] **TODO 5:** Create and import `MonitoringProtocolAlert` component
- [ ] Test frontend with `npm run dev`
- [ ] Verify all 5 features work together
- [ ] Test CWC integration with backend
- [ ] Test state switching between 34 Indian states
- [ ] Verify rainfall chart updates dynamically
- [ ] Check monitoring alert colors and text

---

## Testing Commands

```bash
# Start frontend dev server
cd frontend
npm run dev

# Test backend (in another terminal)
cd backend
python app.py

# Test specific endpoint
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "Peak_Flood_Level_m": 12.5,
    "Event_Duration_days": 3,
    "Time_to_Peak_days": 2,
    "Recession_Time_day": 2,
    "T1d": 100, "T2d": 150, "T3d": 200,
    "T4d": 150, "T5d": 100, "T6d": 150,
    "T7d": 350,
    "state": "Maharashtra"
  }'
```

---

## Environment Variables

If needed, update `.env` in frontend:

```env
VITE_API_URL=http://localhost:8000
VITE_CWC_API_URL=https://ffs.india-water.gov.in
VITE_REFRESH_INTERVAL=300000
```

---

## API Endpoints Used

- **`POST /predict`** — ML prediction with all 11 parameters
- **`GET /sensors`** — Live CWC water level data
- **`GET /health`** — Backend health check
- **`GET /models`** — Available state models list

---

## Notes

- All components use Tailwind CSS (already installed)
- Icons from Lucide React (already imported)
- Charts use Recharts (already installed)
- State management via useAppState() context
- No additional dependencies needed

---
