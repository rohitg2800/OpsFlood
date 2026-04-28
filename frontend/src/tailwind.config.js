/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      animation: {
  'slide-up': 'slideUp 0.5s ease-out',
  'water-ripple': 'waterRipple 2s ease-out infinite',
  'rain-drop': 'rainDrop 1.5s linear infinite',
  'wave': 'wave 7s cubic-bezier(0.36, 0.45, 0.63, 0.53) infinite',
  'water-flow': 'waterFlow 3s ease infinite',
  'pulse-glow': 'pulseGlow 2s ease-in-out infinite',
  'critical-pulse': 'criticalPulse 1s ease-in-out infinite',
  'severe-pulse': 'severePulse 1.5s ease-in-out infinite',
  'moderate-fade': 'moderateFade 2s ease-in-out infinite',
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