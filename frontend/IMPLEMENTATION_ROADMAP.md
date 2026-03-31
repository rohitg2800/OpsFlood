# IndoFloods Implementation Roadmap

**Complete Integration of Indian Flood Prediction ML Model with React Frontend**

---

## Executive Summary

The IndoFloods application is a comprehensive flood prediction system that combines:

- **Frontend**: React 18 + TypeScript with centralized state management
- **Backend**: FastAPI with RandomForest ML model + live CWC government data
- **Infrastructure**: Full 34 Indian states/UTs support + 7-day rainfall analysis
- **Status**: Foundation 95% complete, UI components 60% complete

---

## Current System Architecture

### ✅ Complete (Foundation)

1. **State Management System** (`context/AppContext.tsx`)
   - 50+ Redux-like actions
   - Immutable state updates
   - Full Indian state/UT support (34 regions)
   - CWC live data integration
   - Monitoring protocols tied to predictions

2. **Type Definitions** (`types.ts`)
   - FormData with 7-day rainfall (T1d-T7d)
   - Prediction with severity + monitoring protocols
   - AppState with all 9 sections
   - Complete AppAction union type

3. **Custom Hooks** (`hooks/useAppOperations.ts`)
   - `useEnhancedPrediction()` — Orchestrates full prediction flow
   - `useCWCIntegration()` — Fetches live water level data
   - `useRainfallStats()` — Calculates 7-day rainfall statistics
   - `useIndianStateModels()` — Manages state-specific models
   - `usePredictionAPI()` — Direct backend calls
   - `useSystemInit()`, `useAutoRefresh()`, `useAlertNotifications()`

4. **Validation System** (`utils/validation.ts`)
   - All 11 input fields validated
   - Rainfall constraints (0-200mm per day)
   - State selection required
   - Comprehensive error messages
   - UI helper functions (colors, formatting)

### 🟡 Partial (UI Components)

1. **App.tsx**
   - ✅ Basic structure works
   - ❌ Still uses old `usePredictionAPI()` instead of `useEnhancedPrediction()`
   - ❌ Missing component imports for new UI elements

2. **Form Inputs**
   - ✅ Rainfall inputs exist
   - ✅ Peak level input exists
   - ❌ State selector dropdown missing
   - ❌ 7-day rainfall visualization missing

3. **Results Display**
   - ✅ Prediction result shows
   - ✅ Severity badge displays
   - ❌ CWC live data display missing
   - ❌ Monitoring protocol alert missing
   - ❌ Rainfall distribution chart missing

### ❌ TODO (UI Components - 5 tasks)

---

## Implementation Tasks (Priority Order)

### PRIORITY 1: Fix App.tsx Integration

**Task 1.1: Update Prediction Hook**

```typescript
// In App.tsx, replace:
const { predict, isLoading: predictionLoading } = usePredictionAPI();

// With:
const { predictWithFullModel, isLoading: predictionLoading } = useEnhancedPrediction();
```

**Task 1.2: Update Handler**

```typescript
// In handlePredict function, replace:
const result = await predict(state.form.data);

// With:
const result = await predictWithFullModel();
```

**Why**: EnablesCWC integration, state models, rainfall stats automatically

**Time**: 2 minutes  
**Blocker**: None  
**Validation**: Run `npm run dev` and test predict button

---

### PRIORITY 2: Add State Selector Component

**Task 2.1: Create Component**

Create `/frontend/src/components/StateSelector.tsx` with:
- Dropdown listing all 34 Indian states/UTs
- Auto-load "Maharashtra" (Kolhapur default)
- Show current model being used
- Call `selectState()` on change

**Code Template**: See [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md) - TODO 2

**Task 2.2: Import in App.tsx**

```typescript
import { StateSelector } from './components/StateSelector';

// Add to form section:
<StateSelector className="mb-4" />
```

**Why**: Enables state-specific model selection (essential for multi-state accuracy)

**Time**: 10 minutes  
**Blocker**: None  
**Validation**: Dropdown appears, selecting states changes model

---

### PRIORITY 3: Add Rainfall Visualization

**Task 3.1: Create Chart Component**

Create `/frontend/src/components/RainfallDistributionChart.tsx` with:
- Bar chart showing 7 days of rainfall
- Stats boxes (Total, Average, Trend)
- Color-coded risk categories

**Code Template**: See [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md) - TODO 3

**Task 3.2: Import in App.tsx**

```typescript
import { RainfallDistributionChart } from './components/RainfallDistributionChart';

// Add to data visualization section:
<RainfallDistributionChart />
```

**Why**: Shows rainfall patterns which trigger flood risk (visual clarity)

**Time**: 15 minutes  
**Blocker**: None  
**Validation**: Chart displays with correct rainfall values

---

### PRIORITY 4: Add CWC Live Data Display

**Task 4.1: Create Component**

Create `/frontend/src/components/CWCLiveDataDisplay.tsx` with:
- Live Kolhapur water level (meters)
- Status indicator (CRITICAL/WARNING/ACTIVE/NORMAL)
- Danger threshold progress bar
- Data source badge (CWC_API/HTML_SCRAPE/CACHED/MANUAL)
- Auto-refresh every 5 minutes

**Code Template**: See [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md) - TODO 4

**Task 4.2: Import in App.tsx**

```typescript
import { CWCLiveDataDisplay } from './components/CWCLiveDataDisplay';

// Add to dashboard:
<CWCLiveDataDisplay />
```

**Why**: Shows real Central Water Commission government data (transparency + accuracy)

**Time**: 15 minutes  
**Blocker**: Backend must have CWC scraper working  
**Validation**: Live water level appears, updates when refetching

---

### PRIORITY 5: Add Monitoring Protocol Alert

**Task 5.1: Create Component**

Create `/frontend/src/components/MonitoringProtocolAlert.tsx` with:
- Alert level badge (CRITICAL EMERGENCY / HIGH ALERT / ELEVATED ALERT / STANDARD PROTOCOL)
- Recommended action text
- Priority zones list
- Confidence + risk score display
- Color-coded (red/orange/yellow/green)

**Code Template**: See [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md) - TODO 5

**Task 5.2: Import in App.tsx**

```typescript
import { MonitoringProtocolAlert } from './components/MonitoringProtocolAlert';

// Add at top of results section:
{state.prediction.currentPrediction && (
  <MonitoringProtocolAlert />
)}
```

**Why**: Emergency response actionable - tells users WHAT TO DO (evacuation, monitoring, etc)

**Time**: 15 minutes  
**Blocker**: None  
**Validation**: Alert appears with correct color and text for each severity

---

## Implementation Timeline

```
Phase 1 (2-3 min)
├─ Task 1.1 & 1.2: Fix App.tsx to use useEnhancedPrediction
└─ Verify predict button works with all new features

Phase 2 (10 min)
├─ Task 2.1 & 2.2: Add State Selector
└─ Test state switching

Phase 3 (15 min)
├─ Task 3.1 & 3.2: Add Rainfall Chart
└─ Verify chart displays

Phase 4 (15 min)
├─ Task 4.1 & 4.2: Add CWC Display
└─ Test live data appears

Phase 5 (15 min)
├─ Task 5.1 & 5.2: Add Monitoring Alert
└─ Test alert colors/text

TOTAL: ~60 minutes for complete UI integration
```

---

## Testing Checklist

### Unit Level

- [ ] Frontend builds: `npm run build`
- [ ] Dev server starts: `npm run dev`
- [ ] No TypeScript errors: `npm run type-check` (if available)
- [ ] All imports resolve correctly

### Component Level

- [ ] State Selector dropdown renders with 34 states
- [ ] Selecting a state updates `state.models.currentStateModel`
- [ ] Rainfall Chart shows 7 bars with correct values
- [ ] CWC Display shows water level or "No data" message
- [ ] Monitoring Alert displays with correct color/text

### Integration Level

- [ ] Predict button → triggers `useEnhancedPrediction()`
- [ ] `useEnhancedPrediction()` → calls `useCWCIntegration()`
- [ ] `useCWCIntegration()` → updates `state.cwc`
- [ ] CWC data → displays in `CWCLiveDataDisplay`
- [ ] Rainfall stats → calculated and displayed in chart
- [ ] State model → used in prediction call
- [ ] Monitoring protocol → displayed in Monitoring Alert

### End-to-End

```bash
1. Open http://localhost:5173
2. Select state "Maharashtra"
3. Enter values:
   - Peak Flood Level: 13.0m
   - T1d-T7d: 100-200mm each
   - Event Duration: 3 days
   - Time to Peak: 2 days
   - Recession: 2 days
4. Click "Predict"
5. Verify:
   ✓ CWC live level appears (if API available)
   ✓ Rainfall chart shows all 7 days
   ✓ Monitoring alert shows severity
   ✓ Recommended actions visible
```

---

## File Creation Checklist

```
frontend/src/components/
├─ [ ] StateSelector.tsx (15 lines)
├─ [ ] RainfallDistributionChart.tsx (80 lines)
├─ [ ] CWCLiveDataDisplay.tsx (120 lines)
└─ [ ] MonitoringProtocolAlert.tsx (100 lines)

Modified Files:
└─ [ ] App.tsx (2 line changes + 4 imports)
```

---

## Environment Verification

Before starting, verify:

```bash
# Check Node version
node --version  # Should be 16+

# Check dependencies
cd frontend
npm list react            # 18.x
npm list typescript       # Latest
npm list recharts         # Latest
npm list lucide-react     # Latest
npm list axios            # Latest
npm list tailwindcss      # Latest

# Backend availability
curl -X GET http://localhost:8000/health

# CWC data availability (optional, but helpful)
curl -X GET http://localhost:8000/sensors
```

---

## Git Commit Strategy

```bash
# After each task, commit:
git add frontend/src/
git commit -m "feat: Add StateSelector component"
git commit -m "feat: Add RainfallDistributionChart component"
git commit -m "feat: Add CWCLiveDataDisplay component"
git commit -m "feat: Add MonitoringProtocolAlert component"
git commit -m "fix: Update App.tsx to use useEnhancedPrediction"
```

---

## Common Issues & Fixes

### Issue: "useEnhancedPrediction is not exported"

**Fix**: Verify export in `hooks/useAppOperations.ts`

```typescript
export function useEnhancedPrediction() { ... }
```

### Issue: "State selector dropdown empty"

**Fix**: Check `state.models.availableStates` is populated in INITIAL_STATE

```typescript
models: {
  availableStates: [
    'Andhra Pradesh', 'Arunachal Pradesh', ... // All 34 should be here
  ]
}
```

### Issue: "CWC data not appearing"

**Fix**: Check backend `/sensors` endpoint returns data

```bash
curl http://localhost:8000/sensors
```

Expected response:

```json
{
  "kolhapurLevel": 11.4,
  "kolhapurStatus": "NORMAL",
  "source": "CWC_API"
}
```

### Issue: "Rainfall chart shows NaN"

**Fix**: Verify `useRainfallStats()` is called in prediction flow

Check `useEnhancedPrediction()` includes:

```typescript
const updateRainfallStats = useCallback(() => {
  dispatch({ type: 'UPDATE_RAINFALL_STATS', payload: {...} });
}, []);
```

### Issue: "TypeScript errors in components"

**Fix**: Ensure all imports are correct

```typescript
import { FormData, Prediction } from '../types';
import { useAppState } from '../context/AppContext';
```

---

## Performance Considerations

### Bundle Size Impact

Each new component adds:
- StateSelector: ~2KB
- RainfallChart: ~15KB (includes Recharts)
- CWCDisplay: ~3KB
- MonitoringAlert: ~2KB

**Total**: ~22KB gzipped (acceptable)

### Runtime Performance

- State updates: O(1) - reducer is pure function
- Component re-renders: Only when relevant state changes
- API calls: Cached, auto-refresh every 5 min (configurable)

### Optimization Tips

1. Use React.memo for charts (prevent re-render on unrelated state)
2. Use useCallback for event handlers
3. Lazy-load chart component if needed

---

## Multi-State Support Details

### Available States (34 total)

```
Andhra Pradesh, Arunachal Pradesh, Assam, Bihar,
Chhattisgarh, Goa, Gujarat, Haryana,
Himachal Pradesh, Jharkhand, Karnataka, Kerala,
Madhya Pradesh, Maharashtra, Manipur, Meghalaya,
Mizoram, Nagaland, Odisha, Punjab,
Rajasthan, Sikkim, Tamil Nadu, Telangana,
Tripura, Uttar Pradesh, Uttarakhand, West Bengal,
Andaman and Nicobar Islands, Chandigarh,
Dadra and Nagar Haveli and Daman and Diu, Delhi,
Jammu and Kashmir, Ladakh, Lakshadweep, Puducherry
```

### Model Routing

```
Maharashtra + Kolhapur → kolhapur_flood_model.pkl
All South Indian states → indofloods_production_model.pkl
Default fallback → flood_model.pkl
```

---

## Documentation Files

Created for this project:

1. **[INDOFLOODS_ML_INTEGRATION.md](INDOFLOODS_ML_INTEGRATION.md)** — Complete ML model architecture, features, API integration, state structure

2. **[COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md)** — Code templates for all 5 UI components + testing commands

3. **[STATE_MATRIX.md](STATE_MATRIX.md)** — State management architecture, action types, hook usage patterns

4. **[IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)** (this file) — Priority tasks, timeline, testing, troubleshooting

---

## Next Steps After Integration

### Immediate (After component integration)

- [ ] Add visual feedback during CWC data fetch
- [ ] Implement toast notifications for errors
- [ ] Add loading skeletons for charts
- [ ] Cache CWC data in localStorage

### Short-term (1-2 weeks)

- [ ] Weather API integration (OpenWeatherMap)
- [ ] Historical flood data visualization
- [ ] Export predictions as PDF reports
- [ ] User preferences (dark mode, refresh rate)

### Medium-term (1-2 months)

- [ ] Real-time SMS/push alerts
- [ ] Multi-river basin support
- [ ] Seasonal pattern recognition
- [ ] Community reporting integration
- [ ] Evacuation route optimization

### Long-term (3-6 months)

- [ ] Water levels from other major rivers (Brahmaputra, Indus, etc.)
- [ ] Flood damage estimation models
- [ ] Insurance claim automation
- [ ] Climate change impact analysis
- [ ] Mobile app (React Native)

---

## Support & Debugging

### Enable Debug Logging

Add to `App.tsx`:

```typescript
useEffect(() => {
  console.log('App State:', state);
}, [state]);
```

### Monitor State Changes

In React DevTools:

1. Open DevTools → Components
2. Select `<App>`
3. Check "Track State Changes"
4. Make prediction → see state updates in real-time

### Backend Debugging

```bash
# Check what predictions the model returns
cd backend
python -c "
from app import make_prediction
result = make_prediction({
    'Peak_Flood_Level_m': 12.5,
    'Event_Duration_days': 3,
    'Time_to_Peak_days': 2,
    'Recession_Time_day': 2,
    'T1d': 100, 'T2d': 150, 'T3d': 200,
    'T4d': 150, 'T5d': 100, 'T6d': 150, 'T7d': 350
})
print(result)
"
```

---

## Success Criteria

✅ **Implementation Complete When:**

1. All 5 UI components created and rendering
2. App.tsx uses `useEnhancedPrediction()` hook
3. Predict button triggers full enhanced flow (CWC + State models + Rainfall stats)
4. All 34 states selectable via dropdown
5. Rainfall chart displays 7-day distribution
6. CWC live data shows in dashboard
7. Monitoring protocols display in alert box
8. Frontend builds without errors
9. No TypeScript errors
10. Test prediction returns all expected fields

**Estimated Total Time: 1-2 hours**

---

## Resources

- **ML Model Details**: [INDOFLOODS_ML_INTEGRATION.md](INDOFLOODS_ML_INTEGRATION.md)
- **Component Code Templates**: [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md)
- **State Architecture**: [STATE_MATRIX.md](STATE_MATRIX.md)
- **Backend API**: `/backend/app.py`
- **Frontend Types**: [src/types.ts](src/types.ts)

---

## Contact/Questions

If clarification needed on:
- State management: Check [STATE_MATRIX.md](STATE_MATRIX.md)
- Component implementation: Check [COMPONENT_IMPLEMENTATION_GUIDE.md](COMPONENT_IMPLEMENTATION_GUIDE.md)
- ML model behavior: Check [INDOFLOODS_ML_INTEGRATION.md](INDOFLOODS_ML_INTEGRATION.md)
- Type definitions: Check [src/types.ts](src/types.ts)

---

**Last Updated**: March 29, 2026  
**Status**: Ready for UI integration phase  
**Next Reviewer**: ✅ Ready for user to start Task 1

