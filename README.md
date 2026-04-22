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
| `assets/js/lib/three.min.js` | Three.js r98 (WebGL renderer) |
| `assets/js/hydra/hydra-thread.js` | Hydra Web Worker thread |
| `assets/images/earth/glow.png` | Earth atmosphere glow texture |
| `assets/images/earth/shadows.jpg` | Earth shadow texture |
| `assets/images/plane/matcap.jpg` | Plane matcap texture |
| `assets/fonts/DINPro-Bold_gdi.woff` | DIN Pro Bold font |
| `assets/fonts/din.png` | DIN bitmap atlas for WebGL UI |
| `assets/audio/desktop_lq/config.js` | Klang audio config (desktop) |
| `manifest.json` | Web App Manifest for PWA/home-screen support |
| `fetch-assets.sh` | One-command script to download remaining assets from the live site |

---

## Running Locally

Asset paths are all **relative**, so the project works with any static server
(including GitHub Pages) **and** with `file://` once all assets are present.

### Step 1 — fetch remaining assets (one time)

```bash
bash fetch-assets.sh
```

This downloads every missing file from `https://paperplanes.world/assets/…`
into the correct folder automatically.

### Step 2 — start the dev server

```bash
npm install          # installs the `serve` package
npm run dev          # http://localhost:3000
```

Then open **http://localhost:3000** in a modern browser with WebGL support.

### Step 3 — start the backend

```bash
cd backend
npm install
npm run dev
```

This starts:
- the API on **http://localhost:3001**
- the local Socket.IO relay ports on **7100–7103** and **7150–7153**

When the page is opened from `localhost`, the client automatically uses the local backend instead of the legacy socketnetwork endpoints.

If you are testing from a phone on the same Wi‑Fi network, open the site with your computer's LAN IP instead of `localhost` so both the frontend and backend resolve to the same machine.

---

## Firebase Production Setup

The GitHub Pages build now looks for a Firebase Realtime Database config in `assets/js/firebase-config.js`.

1. Create a Firebase project and enable Realtime Database.
2. Replace the placeholder values in `assets/js/firebase-config.js` with your project config.
3. Reload the GitHub Pages site — the client will use Firebase for plane storage and live updates when the config is present.

The Firebase bridge stores plane records under `planes/`, the plane count under `meta/planeCount`, visitor presence under `users/`, connection info under `connections/`, and live socket-style events under `live/`.

For quick testing, use these RTDB rules:

```json
{
	"rules": {
		".read": true,
		".write": true
	}
}
```

Once you’re happy with the flow, tighten the rules and consider Anonymous Auth if you want per-visitor identifiers without a sign-in screen.

### Alternative: Python (no install)

```bash
python3 -m http.server 3000
```

### Alternative: VS Code Live Server

Install the [Live Server extension](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer) and click **Go Live**.

---

## Missing Assets

The game bundle references assets that are not yet committed to this repository.
Run `bash fetch-assets.sh` from the repo root to download all of them at once.
Manual list below for reference — all are fetched from `https://paperplanes.world/ASSET`.

### Images (`assets/images/`)

| Sub-folder | Files needed |
|------------|--------------|
| `common/` | `logo.png`, `logo-mask.png`, `iologo.png` |
| `icons/` | `arrow-back.png`, `arrow-down.png`, `arrow-up.png`, `circle.png`, `close.png`, `close-black.png`, `close-purple.png`, `done-button.png`, `hand-catch.png`, `hand-open.png`, `hand-throw.png`, `info.png`, `pin.png`, `plane-button.png`, `plane-button-bg.png`, `plane-logo.png`, `plane-logo-purple.png`, `plus.png`, `rotate-arrow.png`, `rotate-button.png`, `share.png` |
| `loader/` | `plane-logo.png`, `plane-logo-black.png`, `spinner.png` |
| `plane/` | `border.jpg`, `fold.jpg`, `matcap2.jpg`, `netmatcap.jpg`, `shadow.png` |
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
| `DINPro-Bold_gdi.ttf` | Headings (DIN) |
| `din.txt` | Bitmap font metrics for WebGL UI |

### 3-D Geometry (`assets/geometry/`)

| File | Used for |
|------|---------|
| `earth.json` | Globe mesh |
| `plane.json` | Paper plane mesh |
| `mobile/net.json` | Mobile folding net |
| `mobile/netBase.json` | Mobile net base |
| `mobile/planeFold.json` | Mobile plane fold |

### Shaders (`assets/shaders/`)

| File | Used for |
|------|---------|
| `compiled.vs` | Compiled GLSL vertex/fragment shaders |

### Geographic Data (`assets/data/`)

| File | Used for |
|------|---------|
| `_geo.json` | Country/location coordinates for globe labels |

### Audio (`assets/audio/`)

The bundle loads an audio configuration and then fetches the sound files from that config.
The config at `assets/audio/desktop_lq/config.js` is already present.
`fetch-assets.sh` will attempt to download the full `desktop_lq` set from the live site.

### JavaScript Libraries (`assets/js/lib/`)

| File | Purpose |
|------|---------|
| `_socketio.js` | Socket.io 2.x client — real-time multiplayer |

If the live-site fetch fails for `_socketio.js`, build it yourself:

```bash
npx browserify -r socket.io-client -o assets/js/lib/_socketio.js
```

### Meta / PWA Assets (`assets/meta/`)

Social-sharing images, favicons, and Apple touch icons referenced in `index.html`.

---

## Milestone Checklist

- [x] Rename bundled JS file to a valid path (`planes.js`)
- [x] Fix `index.html` — use **relative** paths for CSS/JS (fixes GitHub Pages & `file://`)
- [x] Add inline background fallback so the page is never blank-white
- [x] Add `manifest.json` for PWA support
- [x] Add `package.json` with zero-config local dev server
- [x] Add `fetch-assets.sh` — one-command asset downloader
- [x] Document project in README
- [ ] Run `bash fetch-assets.sh` to pull remaining assets from the live site
- [ ] Add all images listed above
- [ ] Add font files
- [ ] Add geometry JSON files
- [ ] Add geographic data JSON
- [ ] Add shaders
- [ ] Add audio config + sound files
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
