const zouraTheme = require('./tailwind.theme.js');

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./*.html', './assets/js/**/*.js'],
  theme: {
    extend: zouraTheme
  },
  plugins: []
};
