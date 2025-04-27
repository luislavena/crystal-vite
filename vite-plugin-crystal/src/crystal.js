import { globSync } from "glob";
import { resolve, join } from "path";

/**
 * Vite plugin for Crystal integration
 * @param {Object} options Plugin options
 * @param {string[]} [options.entrypoints] Array of entry point files (.js, .css, .ts) - paths relative to sourceDir
 * @param {number} [options.port=5173] Port for Vite server
 * @param {number} options.appPort Port used by the Crystal application (for HMR) - REQUIRED
 * @param {string} [options.sourceDir="src/frontend"] Directory containing frontend code
 * @param {string} [options.entrypointsDir="entrypoints"] Directory containing entry points (relative to sourceDir)
 * @returns {import('vite').Plugin}
 */
export default function crystal(options = {}) {
  const projectRoot = process.cwd();
  const {
    entrypoints,
    port = 5173,
    appPort,
    sourceDir = "src/frontend",
    entrypointsDir = "entrypoints",
  } = options;
  // Validate appPort is provided and is a number
  if (appPort === undefined) {
    throw new Error("crystal plugin: 'appPort' is required");
  }
  if (typeof appPort !== "number") {
    throw new Error("crystal plugin: 'appPort' must be a number");
  }
  // Validate entrypoints is an array if provided
  if (entrypoints !== undefined && !Array.isArray(entrypoints)) {
    throw new Error("crystal plugin: 'entrypoints' must be an array");
  }
  const sourcePath = resolve(projectRoot, sourceDir);
  const entrypointsPath = join(sourceDir, entrypointsDir);
  // Resolve entrypoints combining manual entries and auto-discovered ones
  const resolveEntrypoints = () => {
    // Always discover entrypoint files from the entrypointsPath
    const discoveredEntrypointsFiles = globSync(
      `${entrypointsPath}/**/*.{js,ts,css}`,
      {
        cwd: projectRoot,
      },
    );
    // Create array of resolved auto-discovered entrypoints
    const autoEntrypoints = discoveredEntrypointsFiles.map((file) =>
      resolve(projectRoot, file),
    );
    // If manual entrypoints are provided, combine them with the auto-discovered ones
    if (entrypoints && entrypoints.length > 0) {
      const manualEntrypoints = entrypoints.map((entry) =>
        resolve(projectRoot, sourceDir, entry),
      );
      // Combine both arrays, ensuring no duplicates
      return [...new Set([...manualEntrypoints, ...autoEntrypoints])];
    }
    return autoEntrypoints;
  };
  return {
    name: "crystal",
    config(config, { command }) {
      // Check if we're in dev (serve) or build mode
      const isDev = command === "serve";

      return {
        base: isDev ? "/vite-dev/" : "/build/",
        publicDir: false,
        resolve: {
          alias: {
            "@": sourcePath,
          },
        },
        build: {
          outDir: "public/build",
          manifest: "manifest.json",
          rollupOptions: {
            input: resolveEntrypoints(),
          },
        },
        server: {
          port,
          strictPort: true,
          hmr: {
            clientPort: appPort,
          },
          watch: {
            // Exclude shards and nested symlinks
            ignored: [`${projectRoot}/lib/**`],
          },
        },
      };
    },
  };
}
