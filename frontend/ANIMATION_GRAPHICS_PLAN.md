# Animation and Graphics Plan

Last reviewed: 2026-04-04

Status: Historical plan with active guidance

The initial animation expansion plan has been implemented in core surfaces. This file now captures active guidance for future updates.

## Current Animation Surfaces

- Severity-aware canvas rain background (`AnimatedBackground.tsx`)
- Severity-aware wave layer (`WaterWaveBackground.tsx`)
- Gauge, heatmap, toast, and skeleton animation support
- CSS keyframes/utilities in `src/index.css`
- Animation utility exports in `src/utils/animations.ts`

## Guardrails for Future Work

- Keep animation additive and do not block core operator readability.
- Respect reduced-motion and constrained-device behavior.
- Prefer severity-linked motion to generic decorative motion.
- Preserve fallbacks and deterministic rendering when data is unavailable.

## Recommended Next Steps

- Audit unused animation utility classes for cleanup.
- Add visual regression snapshots for severe/critical states.
- Expand motion performance tests on low-end mobile devices.
