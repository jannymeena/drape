/**
 * ZOURA "Warm Mocha" design tokens — the single source of truth for both
 * Tailwind builds. Loaded two ways:
 *   dev   — as a plain <script> before the Play CDN config (global `zouraTheme`)
 *   build — via require() from tailwind.config.js
 * Keep it dependency-free and ES5-safe so the browser can read it directly.
 */
var zouraTheme = {
  colors: {
    // Brand
    primary: '#512f1b',
    'primary-container': '#6b4530',
    'on-primary': '#ffffff',
    'on-primary-container': '#e9b499',
    'primary-fixed': '#ffdbca',
    'primary-fixed-dim': '#f0bba0',
    'on-primary-fixed': '#301404',
    'on-primary-fixed-variant': '#633e29',
    'inverse-primary': '#f0bba0',

    secondary: '#795920',
    'secondary-container': '#fdd08c',
    'on-secondary': '#ffffff',
    'on-secondary-container': '#78581f',
    'secondary-fixed': '#ffdead',
    'secondary-fixed-dim': '#ebc07d',
    'on-secondary-fixed': '#281900',
    'on-secondary-fixed-variant': '#5e4108',

    tertiary: '#383734',
    'tertiary-container': '#4f4e4a',
    'on-tertiary': '#ffffff',
    'on-tertiary-container': '#c2bfbb',
    'tertiary-fixed': '#e6e2dd',
    'tertiary-fixed-dim': '#c9c6c1',
    'on-tertiary-fixed': '#1c1c19',
    'on-tertiary-fixed-variant': '#484743',

    // Surfaces
    surface: '#FFFFFF',
    'surface-dim': '#e2d8d4',
    'surface-bright': '#fff8f6',
    'surface-container-lowest': '#ffffff',
    'surface-container-low': '#fcf2ee',
    'surface-container': '#f6ece8',
    'surface-container-high': '#f0e6e2',
    'surface-container-highest': '#eae0dd',
    'surface-variant': '#eae0dd',
    'surface-tint': '#7e553f',
    'inverse-surface': '#342f2d',
    'inverse-on-surface': '#f9efeb',
    background: '#fff8f6',
    'on-background': '#1f1b19',
    'on-surface': '#1f1b19',
    'on-surface-variant': '#51443e',

    // Lines
    outline: '#83746d',
    'outline-variant': '#d5c3bb',

    // Semantic
    error: '#C24040',
    'on-error': '#ffffff',
    'error-container': '#ffdad6',
    'on-error-container': '#93000a',
    success: '#22C55E',

    // Named brand shorthands used throughout the marketing copy
    ivory: '#FBF7F2',
    gold: '#C8A060',
    'gold-dim': '#b08c52',
    'dark-text': '#2A1810',
    'muted-gray': '#6B5848',
    'light-border': '#E8D8C8',
    forest: '#2D4A3E'
  },

  fontFamily: {
    serif: ['Cormorant Garamond', 'EB Garamond', 'Georgia', 'serif'],
    sans: ['DM Sans', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif']
  },

  fontSize: {
    'body-sm': ['14px', { lineHeight: '1.5', fontWeight: '400' }],
    'body-base': ['16px', { lineHeight: '1.6', fontWeight: '400' }],
    'body-lg': ['18px', { lineHeight: '1.6', fontWeight: '400' }],
    'label-btn': ['14px', { lineHeight: '1', letterSpacing: '0.05em', fontWeight: '600' }],
    'headline-sm': ['20px', { lineHeight: '1.4', fontWeight: '600' }],
    'headline-md': ['24px', { lineHeight: '1.4', fontWeight: '600' }],
    'headline-lg-mobile': ['32px', { lineHeight: '1.2', fontWeight: '600' }],
    'headline-lg': ['40px', { lineHeight: '1.2', fontWeight: '600' }],
    'headline-xl-mobile': ['40px', { lineHeight: '1.2', fontWeight: '600' }],
    'headline-xl': ['56px', { lineHeight: '1.1', fontWeight: '600' }]
  },

  spacing: {
    xs: '8px',
    s: '12px',
    m: '16px',
    l: '20px',
    xl: '24px',
    xxl: '32px',
    'section-gap': '60px',
    'container-padding-mobile': '16px',
    'container-padding-desktop': '32px'
  },

  borderRadius: {
    12: '12px',
    phone: '2rem'
  },

  boxShadow: {
    zoura: '0 4px 20px rgba(42, 24, 16, 0.06)',
    'zoura-hover': '0 8px 30px rgba(42, 24, 16, 0.12)',
    'zoura-lg': '0 20px 40px -10px rgba(42, 24, 16, 0.14)'
  },

  maxWidth: {
    shell: '1200px'
  }
};

if (typeof module !== 'undefined' && module.exports) { module.exports = zouraTheme; }
