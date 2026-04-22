# Paper Planes — Restoration Project

A community restoration of [paperplanes.world](https://paperplanes.world/), the interactive Google I/O 2016 experiment by [Active Theory](https://activetheory.net/).  
*Restored with explicit permission from Active Theory.*

---

## What's Here

| Path | Description |
|------|-------------|
| `index.html` | Entry point — loads styles and the game bundle |
| `assets/css/style.css` | Global styles, font-face declarations |
| `assets/js/planes.js` | Complete minified game bundle (WebGL / Three.js, ~1.3 MB) |
| `manifest.json` | Web App Manifest for PWA/home-screen support |

---

## Running Locally

The game bundle uses **absolute asset paths** (`/assets/…`), so you **must** serve the project from a local HTTP server — opening `index.html` directly from disk (`file://`) will not work.

### Option A — `serve` (recommended, zero config)

```bash
npm install          # installs the `serve` package
npm run dev          # serves on http://localhost:3000
```

Then open **http://localhost:3000** in a modern browser with WebGL support.

### Option B — Python (no install required)

```bash
python3 -m http.server 3000
```

### Option C — VS Code Live Server

Install the [Live Server extension](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer) and click **Go Live** in the status bar.

---

## Missing Assets

The game bundle references assets that are not yet in this repository.  
You will see 404 errors in the console until these are added.

### Images (`assets/images/`)

| Sub-folder | Contents |
|------------|----------|
| `common/` | `logo.png`, `logo-mask.png`, `iologo.png` |
| `earth/` | `glow.png`, `shadows.jpg` |
| `icons/` | Various UI icons (arrow, circle, close, hand, pin, plane buttons…) |
| `loader/` | `plane-logo.png`, `plane-logo-black.png`, `spinner.png` |
| `plane/` | `border.jpg`, `fold.jpg`, `matcap.jpg`, `matcap2.jpg`, `netmatcap.jpg`, `shadow.png` |
| `stamps/io/` | `0–3.png` |
| `stamps/outlines/` | `0–7.png` |
| `stamps/peace/` | `0–4.png` |
| `stamps/special/` | `0–9.png` |
| `stamps/` | `splat.png`, `stamp-test.png` |

### Fonts (`assets/fonts/`)

| File | Used as |
|------|---------|
| `roboto-regular-webfont.woff2` / `.woff` / `.ttf` | Body text |
| `roboto-bold-webfont.woff2` / `.woff` / `.ttf` | Bold text |
| `roboto-medium-webfont.woff2` / `.woff` / `.ttf` | Instructions |
| `roboto-light-webfont.woff2` / `.woff` / `.ttf` | Light weight |
| `DINPro-Bold_gdi.woff` / `.ttf` | Headings (DIN) |
| `din.png` | Bitmap font atlas for WebGL UI |

### 3-D Geometry (`assets/geometry/`)

| File | Used for |
|------|---------|
| `earth.json` | Globe mesh |
| `plane.json` | Paper plane mesh |
| `mobile/net.json` | Mobile folding net |
| `mobile/netBase.json` | Mobile net base |
| `mobile/planeFold.json` | Mobile plane fold |

### Geographic Data (`assets/data/`)

| File | Used for |
|------|---------|
| `_geo.json` | Country/location coordinates |

### Audio (`assets/audio/`)

The bundle loads audio configuration from AWS S3 (Klang service):

- **Desktop LQ** — `https://klangfiles.s3.amazonaws.com/uploads/projects/6iTfI/config.js`
- **Mobile / other** — `https://klangfiles.s3.amazonaws.com/uploads/projects/l0k3G/config.js`

To host audio locally, mirror the Klang config + audio files under `assets/audio/desktop_lq/` and `assets/audio/mobile_lq/`.

### JavaScript Libraries (`assets/js/lib/`)

The game bundle dynamically loads these at runtime via a Web Worker:

| File | Purpose |
|------|---------|
| `three.min.js` | Three.js — WebGL 3-D rendering |
| `_socketio.js` | Socket.io client — multiplayer |

Grab **Three.js r98** (the version used at the time) from the [three.js releases](https://github.com/mrdoob/three.js/releases/tag/r98) and place the minified build at `assets/js/lib/three.min.js`.  
For Socket.io, use the **2.x** client: `npx browserify -r socket.io-client -o assets/js/lib/_socketio.js`.

### Meta / PWA Assets (`assets/meta/`)

Social-sharing images, favicons, and Apple touch icons referenced in `index.html`.

---

## Milestone Checklist

- [x] Rename bundled JS file to a valid path (`planes.js`)
- [x] Fix `index.html` — remove duplicate script loads, remove dead audio bootstrap
- [x] Add `manifest.json` for PWA support
- [x] Add `package.json` with zero-config local dev server
- [x] Document project in README
- [ ] Add `assets/js/lib/three.min.js` (Three.js r98)
- [ ] Add `assets/js/lib/_socketio.js` (Socket.io 2.x client)
- [ ] Add all images listed above
- [ ] Add font files
- [ ] Add geometry JSON files
- [ ] Add geographic data JSON
- [ ] Add audio config + sound files (or confirm remote Klang URLs still respond)
- [ ] Add meta/PWA icons
- [ ] (Optional) Add a backend socket server for multiplayer

---

## Architecture Notes

The game uses **Active Theory's Hydra framework** (a proprietary MVC/component system) and renders via **Three.js WebGL**. Key classes in the bundle:

- **`Main`** — application entry point; detects mobile vs desktop, sets up socket
- **`ContainerDesktop`** / **`ContainerMobile`** — top-level scene containers
- **`Config`** — CDN paths, app engine URL, location list, stamp colours
- **`Data.Socket`** — multiplayer via the `at-socketnetwork` App Engine backend
- **`AssetLoader`** — loads all geometry, textures, and audio before starting
- **`Klang`** — Web Audio engine (loaded from external CDN config)

The bundle expects WebGL support; without it, it redirects to `/fallback`.

---

## License & Credits

Original experience by **Active Theory** — restored with their permission.  
All original assets, code, and design remain © Active Theory.
