# crystal-vite
> Vite.js integration for Crystal applications

This shard simplifies the frontend integration with Vite.js, providing seamless development experience including Hot Module Replacement (HMR).

> [!WARNING]
> This project is still in **early development** and the UX/DX might change
> between versions.

## Features

* Does not attempt to bring all Vite.js features and configuration.
* Promotes a simplified usage and leverages on _Convention over Configuration_.
* Is framework-agnostic: works with plain `HTTP::Server` or any framework compatible with `HTTP::Handler` middlewares
* Does not impose any frontend specific library
* Transparent proxying of Vite development server requests on the same port,
  without complex CORS, port configuration or crossorigin rules.
* Simple helpers for script and style tag generation
* Production-ready manifest-based asset loading

## Overview

This project creates a bridge between your Crystal app and Vite.js. It eliminates the need to manually configure CORS, ports, domains, and cross-origin settings when developing locally, in a container or other environments.

During development, it proxies requests to the Vite development server through your application, enabling Hot Module Replacement without exposing additional ports. In production, it uses Vite's manifest file to serve the correct hashed assets.

## Requirements

- Crystal 1.15 or newer
- Vite.js 6.2 or newer

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  vite:
    github: luislavena/crystal-vite
```

Run `shards install` to install the dependencies.

## Usage

### Backend (Crystal)

```crystal
require "vite"

# Initialize Vite with default settings
vite = Vite.new

# Or with custom settings
vite = Vite.new(
  port: 5173,                 # Vite.js default development server
  source_path: "src/frontend" # Path to your frontend source code
)
```

Next, add `#dev_handler` to your HTTP middleware stack (only in development):

```crystal
# In your HTTP server setup, add the Vite development handler
server = HTTP::Server.new([
  # ... other handlers
  vite.dev_handler, # Add Vite handler (only in development)
  # ... your main application handler
])

server.listen(8080)
```

### Tag helpers

In your views or layouts, use `#script_tag` and `#style_tag` helper methods to generate the proper asset tags:

```crystal
# In development environment, this will point to the Vite dev server
# When running from a manifest, this will return an empty string
vite.client_tag # Adds Vite client script (for HMR) when in development

# For JavaScript entrypoints
vite.script_tag("entrypoints/app.js")

# Or use `@/` shorthand for paths relative to source_path
vite.script_tag("@/entrypoints/app.js")

# For CSS assets
vite.style_tag("@/styles/main.css")

# For entrypoints that import CSS dependencies, preload them
vite.script_tag("@/entrypoints/app.js", preload: true)
```

### Using the Vite plugin

1. Install the plugin:

```console
$ npm install --save-dev file:lib/vite/vite-plugin-crystal
# or
$ bun add -d file:lib/vite/vite-plugin-crystal
```

2. Create a `vite.config.js` file:

```javascript
import { defineConfig } from "vite";
import crystal from "vite-plugin-crystal";

export default defineConfig({
  plugins: [
    crystal({
      appPort: 8080, // REQUIRE: Port where your Crystal app runs

      // Optional settings below
      port: 5173,                     // Default: port for the Vite dev server
      sourceDir: "src/frontend",      // Default: source directory (source_path)
      entrypointsDir: "entrypoints",  // Default: entrypoints directory

      // Optional: manually specify entrypoints relative to sourceDir
      entrypoints: [
        "entrypoints/app.js",
        "styles/main.css"
      ]
    }),
  ],
});
```

3. Setup Vite's related tasks

Add the following scripts to your `package.json` file:

```json
{
  // ...
  "scripts": {
    "dev": "vite dev",
    "build": "vite build"
  }
  // ...
}
```

4. Organize your frontend code:

```
src/
  frontend/          # Default sourceDir
    entrypoints/     # Default entrypointsDir
      app.js
    styles/
      main.css       # CSS files
    components/      # Your frontend components
      ...
```

### Development workflow

1. Start Vite server:

```console
$ npm run dev

# or
$ bun run dev
```

2. Start your Crystal application

```console
$ crystal run app
```

3. Visit your Crystal application URL (e.g., http://localhost:8080)

The Vite handler will:

- Detect if the Vite development server is running
- Proxy asset requests to the Vite server
- Enable Hot Module Replacement through the proxied connection

### Build production assets

1. Use Vite to build your assets

```console
$ npm run build

# or
$ bun run build
```

This will generate the following structure inside `public/build`:

```
public/
  build/
    assets/
      app-[HASH].js     # Bundled entrypoint (JS)
      app-[HASH].css    # Bundled entrypoint (CSS)
    manifest.json
```

`Vite.new` will detect the presence of `manifest.json` and prefer it over the
development server.

2. Compile your application without Vite dev server

When building for production, make sure you're not including `Vite#dev_handler`
in your HTTP middleware stack, as it could allow anyone visiting your
application to run requests against your server.

## Contribution policy

Inspired by [Litestream](https://github.com/benbjohnson/litestream) and
[SQLite](https://sqlite.org/copyright.html#notopencontrib), this project is
open to code contributions for bug fixes only. Features carry a long-term
burden so they will not be accepted at this time. Please
[submit an issue](https://github.com/luislavena/crystal-vite/issues/new) if you have
a feature you would like to request or discuss.

## License

Licensed under the Apache License, Version 2.0. You may obtain a copy of
the license [here](./LICENSE).
