#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# fetch-assets.sh
#
# Downloads every asset that planes.js needs from paperplanes.world.
# Run this ONCE from the repo root after cloning:
#
#   bash fetch-assets.sh
#
# Requirements: curl (standard on macOS/Linux/WSL).
# ---------------------------------------------------------------------------

set -euo pipefail

BASE="https://paperplanes.world"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# All paths that planes.js (or index.html) references but that are NOT yet
# present in the repository.  Files already committed are skipped automatically.
ASSETS=(
  # Core game assets (from the ASSETS[] array in planes.js)
  assets/geometry/earth.json
  assets/geometry/mobile/net.json
  assets/geometry/mobile/netBase.json
  assets/geometry/mobile/planeFold.json
  assets/geometry/plane.json
  assets/images/common/iologo.png
  assets/images/common/logo-mask.png
  assets/images/common/logo.png
  assets/images/icons/arrow-back.png
  assets/images/icons/arrow-down.png
  assets/images/icons/arrow-up.png
  assets/images/icons/circle.png
  assets/images/icons/close-black.png
  assets/images/icons/close-purple.png
  assets/images/icons/close.png
  assets/images/icons/done-button.png
  assets/images/icons/hand-catch.png
  assets/images/icons/hand-open.png
  assets/images/icons/hand-throw.png
  assets/images/icons/info.png
  assets/images/icons/pin.png
  assets/images/icons/plane-button-bg.png
  assets/images/icons/plane-button.png
  assets/images/icons/plane-logo-purple.png
  assets/images/icons/plane-logo.png
  assets/images/icons/plus.png
  assets/images/icons/rotate-arrow.png
  assets/images/icons/rotate-button.png
  assets/images/icons/share.png
  assets/images/loader/plane-logo-black.png
  assets/images/loader/plane-logo.png
  assets/images/loader/spinner.png
  assets/images/plane/border.jpg
  assets/images/plane/fold.jpg
  assets/images/plane/matcap2.jpg
  assets/images/plane/netmatcap.jpg
  assets/images/plane/shadow.png
  assets/images/stamps/io/0.png
  assets/images/stamps/io/1.png
  assets/images/stamps/io/2.png
  assets/images/stamps/io/3.png
  assets/images/stamps/outlines/0.png
  assets/images/stamps/outlines/1.png
  assets/images/stamps/outlines/2.png
  assets/images/stamps/outlines/3.png
  assets/images/stamps/outlines/4.png
  assets/images/stamps/outlines/5.png
  assets/images/stamps/outlines/6.png
  assets/images/stamps/outlines/7.png
  assets/images/stamps/peace/0.png
  assets/images/stamps/peace/1.png
  assets/images/stamps/peace/2.png
  assets/images/stamps/peace/3.png
  assets/images/stamps/peace/4.png
  assets/images/stamps/special/0.png
  assets/images/stamps/special/1.png
  assets/images/stamps/special/2.png
  assets/images/stamps/special/3.png
  assets/images/stamps/special/4.png
  assets/images/stamps/special/5.png
  assets/images/stamps/special/6.png
  assets/images/stamps/special/7.png
  assets/images/stamps/special/8.png
  assets/images/stamps/special/9.png
  assets/images/stamps/splat.png
  assets/images/stamps/stamp-test.png
  assets/shaders/compiled.vs
  # Font data used by the DIN text renderer
  assets/fonts/din.txt
  # Geo data for the globe country labels
  assets/data/_geo.json
  # Socket.io 2.x client (loaded in the Web Worker)
  assets/js/lib/_socketio.js
  # Audio Klang config (desktop low-quality)
  assets/audio/desktop_lq/config.js
  # PWA / social meta images
  assets/meta/icon-128.png
  assets/meta/icon-192.png
  assets/meta/apple-touch-icon-76x76.png
  assets/meta/apple-touch-icon-120x120.png
  assets/meta/apple-touch-icon-152x152.png
  assets/meta/apple-touch-icon-180x180.png
  assets/meta/facebook.jpg
  assets/meta/twitter.jpg
)

ok=0
skip=0
fail=0
fail_list=()

for asset in "${ASSETS[@]}"; do
  dest="$REPO_ROOT/$asset"

  # Skip files that already exist
  if [[ -f "$dest" ]]; then
    echo "  skip  $asset"
    (( skip++ )) || true
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  url="$BASE/$asset"

  if curl -fsSL --max-time 30 -o "$dest" "$url"; then
    echo "  ok    $asset"
    (( ok++ )) || true
  else
    echo "  FAIL  $asset  ($url)"
    rm -f "$dest"
    (( fail++ )) || true
    fail_list+=("$asset")
  fi
done

echo ""
echo "Done: $ok downloaded, $skip already present, $fail failed."

if (( fail > 0 )); then
  echo ""
  echo "Failed assets (try the Wayback Machine: https://web.archive.org/web/2019*/paperplanes.world/ASSET):"
  for f in "${fail_list[@]}"; do
    echo "  $f"
  done
  exit 1
fi
