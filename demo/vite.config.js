import { defineConfig } from "vite";
import crystal from "vite-plugin-crystal";

export default defineConfig({
  // disable automatic clear screen
  clearScreen: false,
  plugins: [
    crystal({
      appPort: 8080,
      entrypoints: ["styles/app.css"],
    }),
  ],
});
