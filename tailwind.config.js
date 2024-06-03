const { fontFamily } = require("tailwindcss/defaultTheme");

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./www/index.html"],
  theme: {
    extend: {
      container: {
        center: true,
        screens: {
          sm: "100%",
          md: "100%",
          lg: "40rem",
          xl: "40rem",
        },
      },
      backgroundImage: {
        "cat-waves-latte": "url('/assets/cat-waves-latte.webp')",
        "cat-waves-mocha": "url('/assets/cat-waves-mocha.webp')",
      },
      colors: {
        "ctp-latte": {
          rosewater: "#dc8a78",
          flamingo: "#dd7878",
          pink: "#ea76cb",
          mauve: "#8839ef",
          red: "#d20f39",
          maroon: "#e64553",
          peach: "#fe640b",
          yellow: "#df8e1d",
          green: "#40a02b",
          teal: "#179299",
          sky: "#04a5e5",
          sapphire: "#209fb5",
          blue: "#1e66f5",
          lavender: "#7287fd",
          text: "#4c4f69",
          subtext: {
            100: "#5c5f77",
            200: "#6c6f85",
          },
          overlay: {
            100: "#7c7f93",
            200: "#8c8fa1",
            300: "#9ca0b0",
          },
          surface: {
            100: "#acb0be",
            200: "#bcc0cc",
            300: "#ccd0da",
          },
          base: "#eff1f5",
          mantle: "#e6e9ef",
          crust: "#dce0e8",
        },

        "ctp-mocha": {
          rosewater: "#f5e0dc",
          flamingo: "#f2cdcd",
          pink: "#f5c2e7",
          mauve: "#cba6f7",
          red: "#f38ba8",
          maroon: "#eba0ac",
          peach: "#fab387",
          yellow: "#f9e2af",
          green: "#a6e3a1",
          teal: "#94e2d5",
          sky: "#89dceb",
          sapphire: "#74c7ec",
          blue: "#89b4fa",
          lavender: "#b4befe",
          text: "#cdd6f4",
          subtext: {
            100: "#bac2de",
            200: "#a6adc8",
          },
          overlay: {
            100: "#9399b2",
            200: "#7f849c",
            300: "#6c7086",
          },
          surface: {
            100: "#585b70",
            200: "#45475a",
            300: "#313244",
          },
          base: "#1e1e2e",
          mantle: "#181825",
          crust: "#11111b",
        },
      },
      fontFamily: {
        sans: [
          "ui-rounded",
          "Hiragino Maru Gothic ProN",
          "Quicksand",
          "Comfortaa",
          "Manjari",
          "Arial Rounded MT",
          "Arial Rounded MT Bold",
          "Calibri",
          "source-sans-pro",
          "sans-serif",
        ],
      },
    },
  },
  plugins: [],
};
