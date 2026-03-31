/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      animation: {
        // Basic animations
        'fade-in': 'fadeIn 0.5s ease-out',
        'fade-out': 'fadeOut 0.5s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
        'scale-in': 'scaleIn 0.3s ease-out',
        'rotate-in': 'rotateIn 0.5s ease-out',
        'flip-in': 'flipIn 0.6s ease-out',
        
        // Water & flood animations
        'water-ripple': 'waterRipple 2s ease-out infinite',
        'rain-drop': 'rainDrop 1.5s linear infinite',
        'wave': 'wave 7s cubic-bezier(0.36, 0.45, 0.63, 0.53) infinite',
        'water-flow': 'waterFlow 3s ease infinite',
        
        // Glow & pulse animations
        'pulse-glow': 'pulseGlow 2s ease-in-out infinite',
        'critical-pulse': 'criticalPulse 1s ease-in-out infinite',
        'severe-pulse': 'severePulse 1.5s ease-in-out infinite',
        'moderate-fade': 'moderateFade 2s ease-in-out infinite',
        
        // Movement animations
        'float': 'float 3s ease-in-out infinite',
        'breathe': 'breathe 4s ease-in-out infinite',
        'shake': 'shake 0.5s ease-in-out',
        'bounce-slow': 'bounce 2s ease-in-out infinite',
        
        // Data visualization animations
        'data-stream': 'dataStream 3s linear infinite',
        'shimmer': 'shimmer 2s linear infinite',
        'gradient-shift': 'gradientShift 8s ease infinite',
        'data-flow': 'dataFlow 2s linear infinite',
        
        // Interaction animations
        'ripple': 'ripple 0.6s linear',
        'success-check': 'drawCheck 0.5s ease-out forwards',
        'error-x': 'drawX 0.5s ease-out forwards',
        'slide-in-right': 'slideInRight 0.3s ease-out',
        'slide-out-right': 'slideOutRight 0.3s ease-out',
        
        // Loading animations
        'progress-stripe': 'progressStripe 1s linear infinite',
      },
      
      // Animation delays
      transitionDelay: {
        '100': '100ms',
        '200': '200ms',
        '300': '300ms',
        '500': '500ms',
        '1000': '1000ms',
      },
      
      // Animation durations
      transitionDuration: {
        '150': '150ms',
        '300': '300ms',
        '500': '500ms',
        '700': '700ms',
        '1000': '1000ms',
      },
    },
  },
  plugins: [],
}