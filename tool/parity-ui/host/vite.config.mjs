// Build config of the raft-ui specimen host (tool/parity-ui). Run through
// tool/parity-ui/capture.mjs, which passes the output directory.
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss()],
  build: { target: "es2022", minify: false, cssMinify: false, sourcemap: false, assetsInlineLimit: 0 },
  logLevel: "warn",
});
