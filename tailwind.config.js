module.exports = {
  content: [
    './app/views/**/*.rb',
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    './app/javascript/**/*.css'
  ],
  theme: {
    extend: {
      colors: {
        'apple': '#61ac3b',
        'deep-azure': {
          alfa: '#1d61aa',
          beta: '#195595',
          gamma: '#16487f',
          DEFAULT: '#123c69',
          delta: '#0e3053',
          epsilon: '#0b233d',
          zeta: '#071728'
        },
        'azure-tint': {
          100: '#e7ebf0',
          200: '#cfd8e1',
          300: '#b7c4d2',
          400: '#a0b1c3',
          500: '#889db4',
          600: '#708aa5',
          700: '#597696',
          800: '#416287',
          900: '#294f78'
        },
        'ruby': {
          alfa: '#cb688a',
          beta: '#c5557b',
          gamma: '#be426c',
          DEFAULT: '#ac3b61',
          delta: '#993456',
          epsilon: '#862e4c',
          zeta: '#732741'
        },
        'lily': '#bab2b5',
        'watzusi': '#edc7b7',
        'fair-pink': '#eee2dc',
        'hover-pink': '#f6f0ed',
        'azure-gray': '#e6e7e9'
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
