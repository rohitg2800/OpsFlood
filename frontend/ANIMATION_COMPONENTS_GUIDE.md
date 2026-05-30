# Animation Components Guide

Last reviewed: 2026-04-04

Status: Active reference

## Components

### AnimatedBackground

- File: `src/components/AnimatedBackground.tsx`
- Purpose: rain + ripple + severity gradient + optional lightning
- Props:
  - `severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL'`
  - `rainIntensity?: number`
  - `showLightning?: boolean`

### WaterWaveBackground

- File: `src/components/WaterWaveBackground.tsx`
- Purpose: lower viewport wave motion tied to severity
- Props:
  - `severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL'`
  - `waveHeight?: number`

### WaterLevelGauge

- File: `src/components/WaterLevelGauge.tsx`
- Purpose: circular level gauge with animated wave fill
- Props:
  - `currentLevel: number`
  - `dangerLevel: number`
  - `maxLevel?: number`
  - `severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL'`
  - `showWaveAnimation?: boolean`

### FloodRiskHeatmap

- File: `src/components/FloodRiskHeatmap.tsx`
- Purpose: severity-tagged risk bars for hotspot sectors
- Props:
  - `data: { label?: string; subLabel?: string; state?: string; risk: number; severity: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL' }[]`
  - `title?: string`
  - `caption?: string`

### ToastNotification

- File: `src/components/ToastNotification.tsx`
- Purpose: temporary operator alerts with slide/progress animation
- Props:
  - `toasts: Toast[]`
  - `onRemove: (id: string) => void`

### SkeletonLoader

- File: `src/components/SkeletonLoader.tsx`
- Purpose: loading placeholders for cards/charts/tables/gauges
- Props:
  - `type?: 'card' | 'chart' | 'table' | 'text' | 'circle' | 'gauge'`
  - `count?: number`

## Utility Layer

- File: `src/utils/animations.ts`
- Exposes animation class maps and severity helper utilities.

## CSS Animation Source

- File: `src/index.css`
- Includes keyframes for wave/rain/pulse and other motion classes.

## Usage Notes

- Prefer severity-aware tones and motion intensity.
- Keep overlays `pointer-events: none` where interaction is not required.
- Validate motion behavior in both desktop and mobile layouts.
