/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background: '#050807',
        foreground: '#e8f5ee',
        primary: {
          DEFAULT: '#00ff88',
          foreground: '#04120a',
        },
        secondary: {
          DEFAULT: '#8a2be2',
          foreground: '#ffffff',
        },
        accent: {
          DEFAULT: '#ff00ff',
          foreground: '#ffffff',
        },
        muted: {
          DEFAULT: '#101613',
          foreground: '#9fb3a8',
        },
        card: {
          DEFAULT: '#0a0f0c',
          foreground: '#e8f5ee',
        },
        border: '#1d2a22',
        input: '#1d2a22',
        ring: '#00ff88',
        destructive: {
          DEFAULT: '#ef4444',
          foreground: '#ffffff',
        },
        // Kept for backwards compatibility with earlier class names
        system: {
          primary: '#00ff88',
          secondary: '#8a2be2',
          accent: '#ff00ff',
          darker: '#050807',
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
        },
      },
      fontFamily: {
        inter: ['"Inter Variable"', 'Inter', 'system-ui', 'sans-serif'],
        orbitron: ['"Orbitron Variable"', 'Orbitron', 'system-ui', 'sans-serif'],
        sans: ['"Inter Variable"', 'Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        glass: '0 8px 32px rgba(0, 0, 0, 0.3)',
        glow: '0 0 20px rgba(0, 255, 136, 0.35)',
      },
      keyframes: {
        pulse: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' },
        },
        slideUp: {
          from: { transform: 'translateY(12px)', opacity: '0' },
          to: { transform: 'translateY(0)', opacity: '1' },
        },
        fadeIn: {
          from: { opacity: '0' },
          to: { opacity: '1' },
        },
      },
      animation: {
        pulse: 'pulse 2s infinite',
        slideUp: 'slideUp 0.25s ease-out',
        fadeIn: 'fadeIn 0.2s ease-out',
      },
    },
  },
  plugins: [],
};
