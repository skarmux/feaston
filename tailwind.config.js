const { fontFamily } = require('tailwindcss/defaultTheme');

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './templates/*.html',
    './templates/components/*.html',
    './templates/contribution/*.html',
    './templates/event/*.html',
    './templates/event/form/*.html'
  ],
  theme: {
    extend: {
      container: {
        center: true,
        padding: '2rem',
        screens: {
          DEFAULT: '100%',
          sm: '100%',
          md: '100%',
          lg: '40rem',
          xl: '40rem',
        },
      },
      backgroundImage: {
        'cat-waves-latte': "url('/assets/cat-waves-latte.webp')",
        'cat-waves-mocha': "url('/assets/cat-waves-mocha.webp')",
      },
      colors: {
        'primary': '#94e2d5',
        'secondary': '#89b4fa',

        /*
        Catppuccin: https://github.com/catppuccin/catppuccin/blob/main/README.md
        Syle guide: https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md
        */

        'ctp-latte': {
          'rosewater': '#dc8a78',
          'flamingo': '#dd7878',
          'pink': '#ea76cb',
          'mauve': '#8839ef',
          'red': '#d20f39',
          'maroon': '#e64553',
          'peach': '#fe640b',
          'yellow': '#df8e1d',
          'green': '#40a02b',
          'teal': '#179299',
          'sky': '#04a5e5',
          'sapphire': '#209fb5',
          'blue': '#1e66f5',
          'lavender': '#7287fd',
          'text': '#4c4f69',
          'subtext': {
            100: '#5c5f77',
            200: '#6c6f85',
          },
          'overlay': {
            100: '#7c7f93',
            200: '#8c8fa1',
            300: '#9ca0b0',
          },
          'surface': {
            100: '#acb0be',
            200: '#bcc0cc',
            300: '#ccd0da',
          },
          'base': '#eff1f5',
          'mantle': '#e6e9ef',
          'crust': '#dce0e8'
        },

        'ctp-mocha': {
          'rosewater': '#f5e0dc',
          'flamingo': '#f2cdcd',
          'pink': '#f5c2e7',
          'mauve': '#cba6f7',
          'red': '#f38ba8',
          'maroon': '#eba0ac',
          'peach': '#fab387',
          'yellow': '#f9e2af',
          'green': '#a6e3a1',
          'teal': '#94e2d5',
          'sky': '#89dceb',
          'sapphire': '#74c7ec',
          'blue': '#89b4fa',
          'lavender': '#b4befe',
          'text': '#cdd6f4',
          'subtext': {
            100: '#bac2de',
            200: '#a6adc8',
          },
          'overlay': {
            100: '#9399b2',
            200: '#7f849c',
            300: '#6c7086',
          },
          'surface': {
            100: '#585b70',
            200: '#45475a',
            300: '#313244',
          },
          'base': '#1e1e2e',
          'mantle': '#181825',
          'crust': '#11111b'
        },
        
        'ctp-frappe': {
          'rosewater': '#f2d5cf',
          'flamingo': '#eebebe',
          'pink': '#f4b8e4',
          'mauve': '#ca9ee6',
          'red': '#e78284',
          'maroon': '#ea999c',
          'peach': '#ef9f76',
          'yellow': '#e5c890',
          'green': '#a6d189',
          'teal': '#81c8be',
          'sky': '#99d1db',
          'sapphire': '#85c1dc',
          'blue': '#8caaee',
          'lavender': '#babbf1',
          'text': '#c6d0f5',
          'subtext': {
            100: '#b5bfe2',
            200: '#a5adce',
          },
          'overlay': {
            100: '#949cbb',
            200: '#838ba7',
            300: '#737994',
          },
          'surface': {
            100: '#626880',
            200: '#51576d',
            300: '#414559',
          },
          'base': '#303446',
          'mantle': '#292c3c',
          'crust': '#232634'
        }
      },
      fontFamily: {
        sans: ['Inter var', ...fontFamily.sans],
      },
    },
  },
  plugins: [],
}

