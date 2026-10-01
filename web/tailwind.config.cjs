/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: [
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        background: '#000000',
        foreground: '#00ff88',
        system: {
          primary: '#00ff88',
          secondary: '#8a2be2',
          accent: '#ff00ff',
          darker: '#000000',
          gray: '#1a1a1a',
          light: '#333333',
        },
        rank: {
          E: '#808080',
          D: '#00ff00',
          C: '#0088ff',
          B: '#8a2be2',
          A: '#ffd700',
          S: '#ff8c00',
        }
      },
      fontFamily: {
        inter: ['Inter', 'sans-serif'],
        orbitron: ['Orbitron', 'sans-serif'],
      },
      boxShadow: {
        'glass': '0 8px 32px rgba(0, 0, 0, 0.3)',
        'glow': '0 0 20px rgba(0, 255, 136, 0.5)',
      },
      backdropFilter: {
        'glass': 'blur(10px)',
      },
      keyframes: {
        'pulse': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' }
        },
        'slideUp': {
          'from': { transform: 'translateY(100%)', opacity: '0' },
          'to': { transform: 'translateY(0)', opacity: '1' }
        }
      },
      animation: {
        'pulse': 'pulse 2s infinite',
        'slideUp': 'slideUp 0.3s ease-out'
      }
    },
  },
  plugins: [],
}