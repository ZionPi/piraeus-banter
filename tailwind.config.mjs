/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      // ▼▼▼ 重点检查这里 ▼▼▼
      colors: {
        primary: "#81A684",
        secondary: "#E4D6A7",
        "background-light": "#F5F3ED", // 这是右侧背景色
        surface: "#EFEBE2", // 这是左侧 Sidebar 背景色
        "text-primary": "#5C4B51",
        "text-secondary": "#A4998E",
        "border-color": "#DCD7C9",
        "host-bubble": "#E6F0E7",
        "guest-bubble": "#FDFBF4",
      },
      fontFamily: {
        display: ["Klee One", "cursive", "sans-serif"],
        body: ["sans-serif"],
      },
      // ▲▲▲▲▲▲
    },
  },
  plugins: [],
};
