import type { Config } from "tailwindcss";

const themed = (cssVar: string) => `rgb(var(${cssVar}) / <alpha-value>)`;

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: themed("--bg"),
        surface: themed("--surface"),
        elevated: themed("--elevated"),
        border: themed("--border"),
        ink: themed("--ink"),
        muted: themed("--muted"),
        subtle: themed("--subtle"),
        accent: themed("--accent"),
        "accent-hover": themed("--accent-hover"),
        "accent-dark": themed("--accent-dark"),
      },
      fontFamily: {
        sans: ["var(--font-sans)", "ui-sans-serif", "system-ui", "sans-serif"],
        serif: ["var(--font-serif)", "ui-serif", "Georgia", "serif"],
      },
      maxWidth: { prose: "70ch" },
    },
  },
  plugins: [],
};

export default config;
