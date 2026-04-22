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

# Audio buffers referenced by assets/audio/desktop_lq/config.js.
AUDIO_ASSETS=(
  9244_ad6d3b43fcb67de4cd704b547b542174_flock_medium_oneshot
  9463_6481693cdb5d7d41f4cf4b2c50e4dcd4_paperplanes_short
  9294_4866336629d1a594b79cac53a2506ae1_phrase_8
  9293_ac0c24d0dbd300afb25b07e1b8546c25_phrase_9
  9292_af5f82d2efbc250fcbe8a191adac65b5_phrase_10
  9079_cb7ef89d94656acdfc1c102707d7277b_phrase_1
  9078_fc5f69c4e88cb820cc0114daf9cab076_phrase_2
  9077_01b2133e1b73bca91c557fd3f3f3b50a_phrase_3
  9076_a702b935aea84fd40a4b216d970d9c1c_phrase_4
  9075_5ac97ec4045d949134e059a8f5fa77cc_phrase_5
  9074_bb7aa9401e193ba2914ee96ee541bc85_phrase_6
  9073_34fc4e3083ea527189965e83e37f91f8_phrase_7
  9475_aa9385b1ade632d72a6f0e07dd1e1798_paperplanes_1745
  8905_8be7272f4b9ba4969663dfd1810ed3a2_windloop
  9072_7222e17c12e45f106bc335a22623841f_plane_enter_long_1
  9071_b97c480077df3a3215f243b53e448b35_plane_enter_long_2
  9070_6e176ff921e658ddb932c40f583e1e9f_plane_enter_long_3
  9069_0acd2bf75e151d5980a7160cd6fa0f7e_plane_enter_long_4
  9253_5686755e5a86b021ca7b27ec54bed678_stats_in_glitter
  9254_6f6af5539124dadfb80249bb2e707aa3_sonar_ping
  9245_f8b6777d5a743a88ff1665955a536a97_flock_small_oneshot
  9243_1bb6712ab692b6c1e67ac42b6aed0f9a_flock_large_oneshot
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

for audio in "${AUDIO_ASSETS[@]}"; do
  dest="$REPO_ROOT/assets/audio/desktop_lq/sounds/$audio.ogg"

  if [[ -f "$dest" ]]; then
    echo "  skip  assets/audio/desktop_lq/sounds/$audio.ogg"
    (( skip++ )) || true
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  url="$BASE/assets/audio/desktop_lq/sounds/$audio.ogg"

  if curl -fsSL --max-time 30 -o "$dest" "$url"; then
    echo "  ok    assets/audio/desktop_lq/sounds/$audio.ogg"
    (( ok++ )) || true
  else
    rm -f "$dest"
    url="$BASE/assets/audio/desktop_lq/sounds/$audio.mp3"
    if curl -fsSL --max-time 30 -o "$dest" "$url"; then
      echo "  ok    assets/audio/desktop_lq/sounds/$audio.mp3"
      (( ok++ )) || true
    else
      echo "  FAIL  assets/audio/desktop_lq/sounds/$audio.(ogg|mp3)"
      rm -f "$dest"
      (( fail++ )) || true
      fail_list+=("assets/audio/desktop_lq/sounds/$audio.(ogg|mp3)")
    fi
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
