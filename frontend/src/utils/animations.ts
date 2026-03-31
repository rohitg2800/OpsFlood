/**
 * INDOFLOODS ML - Animation Utilities
 * 
 * This module provides animation class names and utilities
 * for consistent animations throughout the application.
 */

// ============================================
// WATER & FLOOD ANIMATIONS
// ============================================

export const waterAnimations = {
  ripple: 'animate-water-ripple',
  rainDrop: 'animate-rain-drop',
  wave: 'animate-wave',
  waterFlow: 'animate-water-flow',
} as const;

// ============================================
// GLOW & PULSE ANIMATIONS
// ============================================

export const glowAnimations = {
  pulseGlow: 'animate-pulse-glow',
  criticalPulse: 'animate-critical-pulse',
  severePulse: 'animate-severe-pulse',
  moderateFade: 'animate-moderate-fade',
} as const;

// ============================================
// MOVEMENT ANIMATIONS
// ============================================

export const movementAnimations = {
  float: 'animate-float',
  breathe: 'animate-breathe',
  shake: 'animate-shake',
  bounce: 'animate-bounce-slow',
  slideUp: 'animate-slide-up',
} as const;

// ============================================
// DATA VISUALIZATION ANIMATIONS
// ============================================

export const dataAnimations = {
  dataStream: 'animate-data-stream',
  shimmer: 'animate-shimmer',
  gradientShift: 'animate-gradient-shift',
  dataFlow: 'animate-data-flow',
} as const;

// ============================================
// INTERACTION ANIMATIONS
// ============================================

export const interactionAnimations = {
  ripple: 'animate-ripple',
  successCheck: 'animate-success-check',
  errorX: 'animate-error-x',
  slideInRight: 'animate-slide-in-right',
  slideOutRight: 'animate-slide-out-right',
} as const;

// ============================================
// LOADING ANIMATIONS
// ============================================

export const loadingAnimations = {
  skeleton: 'skeleton',
  progressStripe: 'animate-progress-stripe',
  loadingDots: 'loading-dots',
} as const;

// ============================================
// CARD & COMPONENT ANIMATIONS
// ============================================

export const cardAnimations = {
  hoverLift: 'card-hover-lift',
  borderGlow: 'card-border-glow',
  glassEnhanced: 'glass-enhanced',
  card3d: 'card-3d',
  card3dContent: 'card-3d-content',
} as const;

// ============================================
// BUTTON ANIMATIONS
// ============================================

export const buttonAnimations = {
  ripple: 'btn-ripple',
  hoverGlow: 'btn-hover-glow',
} as const;

// ============================================
// INPUT ANIMATIONS
// ============================================

export const inputAnimations = {
  focusAnimate: 'input-focus-animate',
} as const;

// ============================================
// UTILITY ANIMATIONS
// ============================================

export const utilityAnimations = {
  fadeIn: 'animate-fade-in',
  fadeOut: 'animate-fade-out',
  scaleIn: 'animate-scale-in',
  rotateIn: 'animate-rotate-in',
  flipIn: 'animate-flip-in',
} as const;

// ============================================
// ANIMATION DELAYS
// ============================================

export const delays = {
  delay100: 'delay-100',
  delay200: 'delay-200',
  delay300: 'delay-300',
  delay500: 'delay-500',
  delay1000: 'delay-1000',
} as const;

// ============================================
// ANIMATION DURATIONS
// ============================================

export const durations = {
  fast: 'duration-150',
  normal: 'duration-300',
  slow: 'duration-500',
  slower: 'duration-700',
  slowest: 'duration-1000',
} as const;

// ============================================
// SEVERITY-BASED ANIMATIONS
// ============================================

export const getSeverityAnimation = (severity: string): string => {
  switch (severity) {
    case 'CRITICAL':
      return glowAnimations.criticalPulse;
    case 'SEVERE':
      return glowAnimations.severePulse;
    case 'MODERATE':
      return glowAnimations.moderateFade;
    default:
      return '';
  }
};

export const getSeverityColor = (severity: string): string => {
  switch (severity) {
    case 'CRITICAL':
      return 'text-[#ff0037]';
    case 'SEVERE':
      return 'text-orange-500';
    case 'MODERATE':
      return 'text-amber-500';
    default:
      return 'text-emerald-500';
  }
};

export const getSeverityBgColor = (severity: string): string => {
  switch (severity) {
    case 'CRITICAL':
      return 'bg-[#ff0037]/10 border-[#ff0037]/30';
    case 'SEVERE':
      return 'bg-orange-500/10 border-orange-500/30';
    case 'MODERATE':
      return 'bg-amber-500/10 border-amber-500/30';
    default:
      return 'bg-emerald-500/10 border-emerald-500/30';
  }
};

// ============================================
// COMBINED ANIMATION CLASSES
// ============================================

export const combineAnimations = (...animations: string[]): string => {
  return animations.filter(Boolean).join(' ');
};

// ============================================
// ANIMATION PRESETS
// ============================================

export const presets = {
  // Card with hover effect and glow
  card: combineAnimations(
    cardAnimations.glassEnhanced,
    cardAnimations.hoverLift,
    cardAnimations.borderGlow
  ),
  
  // Button with ripple and glow
  button: combineAnimations(
    buttonAnimations.ripple,
    buttonAnimations.hoverGlow
  ),
  
  // Input with focus animation
  input: combineAnimations(
    inputAnimations.focusAnimate
  ),
  
  // Loading skeleton
  loading: combineAnimations(
    loadingAnimations.skeleton
  ),
  
  // Critical alert
  criticalAlert: combineAnimations(
    glowAnimations.criticalPulse,
    movementAnimations.shake
  ),
  
  // Severe alert
  severeAlert: combineAnimations(
    glowAnimations.severePulse
  ),
  
  // Floating element
  floating: combineAnimations(
    movementAnimations.float
  ),
  
  // Breathing element
  breathing: combineAnimations(
    movementAnimations.breathe
  ),
  
  // Data visualization
  dataViz: combineAnimations(
    dataAnimations.shimmer
  ),
} as const;

// ============================================
// TYPE DEFINITIONS
// ============================================

export type AnimationPreset = keyof typeof presets;
export type WaterAnimation = keyof typeof waterAnimations;
export type GlowAnimation = keyof typeof glowAnimations;
export type MovementAnimation = keyof typeof movementAnimations;
export type DataAnimation = keyof typeof dataAnimations;
export type InteractionAnimation = keyof typeof interactionAnimations;
export type LoadingAnimation = keyof typeof loadingAnimations;
export type CardAnimation = keyof typeof cardAnimations;
export type ButtonAnimation = keyof typeof buttonAnimations;
export type InputAnimation = keyof typeof inputAnimations;
export type UtilityAnimation = keyof typeof utilityAnimations;

export default {
  water: waterAnimations,
  glow: glowAnimations,
  movement: movementAnimations,
  data: dataAnimations,
  interaction: interactionAnimations,
  loading: loadingAnimations,
  card: cardAnimations,
  button: buttonAnimations,
  input: inputAnimations,
  utility: utilityAnimations,
  delays,
  durations,
  presets,
  getSeverityAnimation,
  getSeverityColor,
  getSeverityBgColor,
  combineAnimations,
};
