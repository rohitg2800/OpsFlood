# 🎨 INDOFLOODS ML - Animation Components Guide

## Overview

This guide documents all the animation components and utilities added to the INDOFLOODS ML flood prediction system. All animations are designed to enhance the visual experience without modifying existing code.

---

## 📦 New Components

### 1. AnimatedBackground
**File:** `frontend/src/components/AnimatedBackground.tsx`

A canvas-based animated background with rain particles and water effects.

**Props:**
```typescript
interface AnimatedBackgroundProps {
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  rainIntensity?: number; // 0-100
  showLightning?: boolean;
}
```

**Usage:**
```tsx
import { AnimatedBackground } from './components/AnimatedBackground';

<AnimatedBackground 
  severity="SEVERE" 
  rainIntensity={60}
  showLightning={true}
/>
```

**Features:**
- Dynamic rain particles with wind effect
- Water ripples at bottom
- Lightning flashes for critical severity
- Severity-based color gradients
- Performance optimized with requestAnimationFrame

---

### 2. WaterWaveBackground
**File:** `frontend/src/components/WaterWaveBackground.tsx`

SVG-based animated water waves at the bottom of the screen.

**Props:**
```typescript
interface WaterWaveBackgroundProps {
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  waveHeight?: number; // 0-100
}
```

**Usage:**
```tsx
import { WaterWaveBackground } from './components/WaterWaveBackground';

<WaterWaveBackground 
  severity="CRITICAL" 
  waveHeight={50}
/>
```

**Features:**
- Three wave layers with different speeds
- Severity-based wave colors
- Smooth CSS animations
- Gradient overlay at top

---

### 3. WaterLevelGauge
**File:** `frontend/src/components/WaterLevelGauge.tsx`

Animated circular gauge showing current water level with danger threshold.

**Props:**
```typescript
interface WaterLevelGaugeProps {
  currentLevel: number;
  dangerLevel: number;
  maxLevel?: number;
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  showWaveAnimation?: boolean;
}
```

**Usage:**
```tsx
import { WaterLevelGauge } from './components/WaterLevelGauge';

<WaterLevelGauge 
  currentLevel={8.5}
  dangerLevel={13.5}
  maxLevel={20}
  severity="MODERATE"
  showWaveAnimation={true}
/>
```

**Features:**
- Circular progress indicator
- Animated water fill with waves
- Danger level indicator
- Pulsing status indicator
- Color transitions based on severity

---

### 4. FloodRiskHeatmap
**File:** `frontend/src/components/FloodRiskHeatmap.tsx`

Interactive heatmap showing state-wise flood risk levels.

**Props:**
```typescript
interface FloodRiskHeatmapProps {
  data: Array<{
    state: string;
    risk: number; // 0-100
    severity: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  }>;
}
```

**Usage:**
```tsx
import { FloodRiskHeatmap } from './components/FloodRiskHeatmap';

<FloodRiskHeatmap 
  data={[
    { state: 'Maharashtra', risk: 75, severity: 'SEVERE' },
    { state: 'Kerala', risk: 45, severity: 'MODERATE' },
    { state: 'Tamil Nadu', risk: 20, severity: 'LOW' },
  ]}
/>
```

**Features:**
- Color-coded risk levels
- Hover tooltips with details
- Pulsing animation for high risk
- Responsive grid layout
- Legend with color indicators

---

### 5. ToastNotification
**File:** `frontend/src/components/ToastNotification.tsx`

Animated toast notification system for alerts and feedback.

**Props:**
```typescript
interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info' | 'critical';
  title: string;
  message: string;
  duration?: number;
}

interface ToastNotificationProps {
  toasts: Toast[];
  onRemove: (id: string) => void;
}
```

**Usage:**
```tsx
import { ToastNotification, Toast } from './components/ToastNotification';

const [toasts, setToasts] = useState<Toast[]>([]);

const addToast = (toast: Omit<Toast, 'id'>) => {
  setToasts(prev => [...prev, { ...toast, id: Date.now().toString() }]);
};

<ToastNotification 
  toasts={toasts}
  onRemove={(id) => setToasts(prev => prev.filter(t => t.id !== id))}
/>
```

**Features:**
- Slide-in/slide-out animations
- Auto-dismiss with progress bar
- Type-specific colors and icons
- Critical alert pulsing
- Manual dismiss button

---

### 6. SkeletonLoader
**File:** `frontend/src/components/SkeletonLoader.tsx`

Shimmer loading skeletons for various content types.

**Props:**
```typescript
interface SkeletonLoaderProps {
  type?: 'card' | 'chart' | 'table' | 'text' | 'circle' | 'gauge';
  count?: number;
}
```

**Usage:**
```tsx
import { SkeletonLoader } from './components/SkeletonLoader';

<SkeletonLoader type="card" count={2} />
<SkeletonLoader type="chart" />
<SkeletonLoader type="table" />
```

**Features:**
- Multiple skeleton types
- Shimmer animation effect
- Configurable count
- Fade-in animation

---

## 🎨 Animation Utilities

**File:** `frontend/src/utils/animations.ts`

Comprehensive animation utility library with presets and helpers.

### Available Animation Categories

```typescript
import animations from './utils/animations';

// Water & Flood Animations
animations.water.ripple      // 'animate-water-ripple'
animations.water.rainDrop    // 'animate-rain-drop'
animations.water.wave        // 'animate-wave'
animations.water.waterFlow   // 'animate-water-flow'

// Glow & Pulse Animations
animations.glow.pulseGlow    // 'animate-pulse-glow'
animations.glow.criticalPulse // 'animate-critical-pulse'
animations.glow.severePulse  // 'animate-severe-pulse'
animations.glow.moderateFade // 'animate-moderate-fade'

// Movement Animations
animations.movement.float    // 'animate-float'
animations.movement.breathe  // 'animate-breathe'
animations.movement.shake    // 'animate-shake'
animations.movement.bounce   // 'animate-bounce-slow'
animations.movement.slideUp  // 'animate-slide-up'

// Data Visualization Animations
animations.data.dataStream   // 'animate-data-stream'
animations.data.shimmer      // 'animate-shimmer'
animations.data.gradientShift // 'animate-gradient-shift'
animations.data.dataFlow     // 'animate-data-flow'

// Interaction Animations
animations.interaction.ripple // 'animate-ripple'
animations.interaction.successCheck // 'animate-success-check'
animations.interaction.errorX // 'animate-error-x'
animations.interaction.slideInRight // 'animate-slide-in-right'
animations.interaction.slideOutRight // 'animate-slide-out-right'

// Loading Animations
animations.loading.skeleton  // 'skeleton'
animations.loading.progressStripe // 'animate-progress-stripe'
animations.loading.loadingDots // 'loading-dots'

// Card & Component Animations
animations.card.hoverLift    // 'card-hover-lift'
animations.card.borderGlow   // 'card-border-glow'
animations.card.glassEnhanced // 'glass-enhanced'
animations.card.card3d       // 'card-3d'
animations.card.card3dContent // 'card-3d-content'

// Button Animations
animations.button.ripple     // 'btn-ripple'
animations.button.hoverGlow  // 'btn-hover-glow'

// Input Animations
animations.input.focusAnimate // 'input-focus-animate'

// Utility Animations
animations.utility.fadeIn    // 'animate-fade-in'
animations.utility.fadeOut   // 'animate-fade-out'
animations.utility.scaleIn   // 'animate-scale-in'
animations.utility.rotateIn  // 'animate-rotate-in'
animations.utility.flipIn    // 'animate-flip-in'
```

### Helper Functions

```typescript
import { 
  getSeverityAnimation,
  getSeverityColor,
  getSeverityBgColor,
  combineAnimations,
  presets
} from './utils/animations';

// Get animation class based on severity
const animation = getSeverityAnimation('CRITICAL');
// Returns: 'animate-critical-pulse'

// Get text color based on severity
const color = getSeverityColor('SEVERE');
// Returns: 'text-orange-500'

// Get background color based on severity
const bgColor = getSeverityBgColor('MODERATE');
// Returns: 'bg-amber-500/10 border-amber-500/30'

// Combine multiple animations
const combined = combineAnimations(
  'animate-float',
  'animate-pulse-glow',
  'card-hover-lift'
);

// Use presets
const cardClass = presets.card;
const buttonClass = presets.button;
const criticalAlertClass = presets.criticalAlert;
```

---

## 🎬 CSS Animation Classes

All animations are defined in `frontend/src/index.css` and can be used directly:

### Water & Flood
- `.animate-water-ripple` - Expanding ripple effect
- `.animate-rain-drop` - Falling rain animation
- `.animate-wave` - Smooth wave motion
- `.animate-water-flow` - Flowing water gradient

### Glow & Pulse
- `.animate-pulse-glow` - Pulsing glow effect
- `.animate-critical-pulse` - Critical alert pulse (red)
- `.animate-severe-pulse` - Severe alert pulse (orange)
- `.animate-moderate-fade` - Moderate alert fade (amber)

### Movement
- `.animate-float` - Gentle floating motion
- `.animate-breathe` - Breathing scale effect
- `.animate-shake` - Shake animation
- `.animate-bounce-slow` - Slow bounce
- `.animate-slide-up` - Slide up entrance

### Data Visualization
- `.animate-data-stream` - Data streaming effect
- `.animate-shimmer` - Shimmer loading effect
- `.animate-gradient-shift` - Gradient color shift
- `.animate-data-flow` - Data flow animation

### Interaction
- `.animate-ripple` - Click ripple effect
- `.animate-success-check` - Success checkmark draw
- `.animate-error-x` - Error X draw
- `.animate-slide-in-right` - Slide in from right
- `.animate-slide-out-right` - Slide out to right

### Loading
- `.skeleton` - Skeleton loading shimmer
- `.animate-progress-stripe` - Progress bar stripes
- `.loading-dots` - Loading dots animation

### Cards & Components
- `.card-hover-lift` - Lift on hover
- `.card-border-glow` - Border glow on hover
- `.glass-enhanced` - Enhanced glassmorphism
- `.card-3d` - 3D card effect
- `.card-3d-content` - 3D content depth

### Buttons
- `.btn-ripple` - Button click ripple
- `.btn-hover-glow` - Button hover glow

### Inputs
- `.input-focus-animate` - Input focus animation

### Utilities
- `.animate-fade-in` - Fade in
- `.animate-fade-out` - Fade out
- `.animate-scale-in` - Scale in
- `.animate-rotate-in` - Rotate in
- `.animate-flip-in` - Flip in

---

## ⚡ Tailwind Animation Classes

All animations are also available as Tailwind classes:

```tsx
<div className="animate-water-ripple">...</div>
<div className="animate-pulse-glow">...</div>
<div className="animate-float">...</div>
<div className="card-hover-lift">...</div>
<div className="btn-ripple">...</div>
```

---

## 🎯 Integration Examples

### Adding Animated Background to App

```tsx
import { AnimatedBackground } from './components/AnimatedBackground';
import { WaterWaveBackground } from './components/WaterWaveBackground';

function App() {
  const severity = state.prediction.currentPrediction?.severity || 'LOW';
  
  return (
    <div className="min-h-screen">
      <AnimatedBackground 
        severity={severity}
        rainIntensity={severity === 'CRITICAL' ? 80 : 40}
        showLightning={severity === 'CRITICAL'}
      />
      <WaterWaveBackground 
        severity={severity}
        waveHeight={severity === 'CRITICAL' ? 60 : 30}
      />
      {/* Your existing content */}
    </div>
  );
}
```

### Adding Toast Notifications

```tsx
import { ToastNotification, Toast } from './components/ToastNotification';

function App() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const notify = (toast: Omit<Toast, 'id'>) => {
    setToasts(prev => [...prev, { 
      ...toast, 
      id: Date.now().toString(),
      duration: toast.duration || 5000
    }]);
  };

  const removeToast = (id: string) => {
    setToasts(prev => prev.filter(t => t.id !== id));
  };

  return (
    <>
      {/* Your existing content */}
      <ToastNotification toasts={toasts} onRemove={removeToast} />
    </>
  );
}
```

### Adding Water Level Gauge

```tsx
import { WaterLevelGauge } from './components/WaterLevelGauge';

function Dashboard() {
  const currentLevel = state.prediction.currentPrediction?.peak_level || 0;
  const dangerLevel = state.prediction.currentPrediction?.danger_level || 13.5;
  const severity = state.prediction.currentPrediction?.severity || 'LOW';

  return (
    <WaterLevelGauge 
      currentLevel={currentLevel}
      dangerLevel={dangerLevel}
      maxLevel={20}
      severity={severity}
      showWaveAnimation={true}
    />
  );
}
```

### Adding Skeleton Loaders

```tsx
import { SkeletonLoader } from './components/SkeletonLoader';

function Dashboard() {
  const isLoading = state.prediction.isLoading;

  return (
    <div>
      {isLoading ? (
        <SkeletonLoader type="card" count={2} />
      ) : (
        {/* Your actual content */}
      )}
    </div>
  );
}
```

### Using Animation Utilities

```tsx
import animations, { presets, getSeverityAnimation } from './utils/animations';

function AlertCard({ severity }: { severity: string }) {
  return (
    <div className={`
      ${presets.card}
      ${getSeverityAnimation(severity)}
    `}>
      {/* Content */}
    </div>
  );
}
```

---

## 🎨 Color Palette

### Severity Colors
- **CRITICAL:** `#ff0037` (Blood Red)
- **SEVERE:** `#f59e0b` (Saffron)
- **MODERATE:** `#ffb000` (Bright Saffron)
- **LOW:** `#10b981` (Emerald)

### Water Colors
- **Normal:** `rgba(14, 165, 233, 0.6)` (Sky Blue)
- **Warning:** `rgba(245, 158, 11, 0.6)` (Amber)
- **Danger:** `rgba(255, 0, 55, 0.6)` (Blood Red)

---

## ⚡ Performance Tips

1. **Use CSS transforms** instead of layout properties
2. **Implement will-change** for frequently animated elements
3. **Use requestAnimationFrame** for JavaScript animations
4. **Debounce scroll/resize** event handlers
5. **Lazy load** animation components
6. **Reduce particle count** on mobile devices
7. **Use CSS containment** for isolated animations
8. **Implement prefers-reduced-motion** media query

---

## ♿ Accessibility

All animations respect the `prefers-reduced-motion` media query:

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 📱 Mobile Optimization

- Reduced particle counts on mobile
- Simplified wave animations
- Touch-friendly interactions
- Performance-optimized CSS animations

---

## 🔧 Customization

### Adjusting Animation Speed

```css
/* In your component or global CSS */
.custom-speed {
  animation-duration: 2s; /* Slower */
  animation-duration: 0.5s; /* Faster */
}
```

### Adjusting Rain Intensity

```tsx
<AnimatedBackground 
  rainIntensity={80} // Heavy rain
  rainIntensity={20} // Light rain
/>
```

### Adjusting Wave Height

```tsx
<WaterWaveBackground 
  waveHeight={70} // High waves
  waveHeight={20} // Low waves
/>
```

---

## 🐛 Troubleshooting

### Animations not showing
- Check that CSS is properly imported
- Verify Tailwind config includes animation utilities
- Check browser console for errors

### Performance issues
- Reduce particle count
- Disable lightning effect
- Use `will-change` sparingly
- Check for memory leaks in canvas animations

### Animations not respecting reduced motion
- Verify media query is in CSS
- Check browser support
- Test with system preferences

---

## 📚 Resources

- [MDN CSS Animations](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Animations)
- [Tailwind CSS Animations](https://tailwindcss.com/docs/animation)
- [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API)
- [SVG Animations](https://developer.mozilla.org/en-US/docs/Web/SVG/SVG_animation_with_SMIL)

---

**Last Updated:** 2026-03-30
**Version:** 1.0.0
**Status:** Production Ready
