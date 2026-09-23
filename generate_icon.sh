#!/usr/bin/env bash
# Regenerate PortionShare's app icon via Grok Imagine (xAI images API).
# Uses XAI_API_KEY from env, this repo's .env, or ../livetranscription/.env.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

if [[ -z "${XAI_API_KEY:-}" ]]; then
  for f in .env ../livetranscription/.env; do
    if [[ -f "$f" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$f"
      set +a
      break
    fi
  done
fi
: "${XAI_API_KEY:?set XAI_API_KEY or put it in .env}"

mkdir -p Resources
python3 <<'PY'
import base64, json, os, pathlib, urllib.request

key = os.environ["XAI_API_KEY"]
prompt = (
    "Full-bleed square macOS application icon artwork, 1:1, edge-to-edge, "
    "NO rounded corners, NO outer padding, NO fake iOS icon frame, NO drop shadow, "
    "NO text, NO letters, NO watermark. "
    "For PortionShare — a Mac app that lets you share only a cropped portion of "
    "your screen in Zoom/Meet. "
    "Fill the entire canvas with a deep charcoal / near-black field. "
    "Centered mark: a simple desktop screen rectangle with a bright warm orange "
    "(#F54E00 / ember) crop selection frame highlighting just one region of it, "
    "suggesting 'share this portion only'. Minimal, flat, premium product icon. "
    "High contrast. No purple, no chrome 3D, no photoreal clutter. Designed so "
    "macOS can apply its own rounded-rect mask."
)
body = {
    "model": "grok-imagine-image-quality",
    "prompt": prompt,
    "n": 1,
    "aspect_ratio": "1:1",
    "resolution": "2k",
    "response_format": "b64_json",
}
req = urllib.request.Request(
    "https://api.x.ai/v1/images/generations",
    data=json.dumps(body).encode(),
    headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as resp:
    data = json.load(resp)
item = data["data"][0]
raw = (
    base64.b64decode(item["b64_json"])
    if item.get("b64_json")
    else urllib.request.urlopen(item["url"], timeout=60).read()
)
out = pathlib.Path("Resources/icon-source.png")
out.write_bytes(raw)
print(f"wrote {out} ({out.stat().st_size} bytes)")
PY

src="Resources/icon-source.png"
setdir="Resources/AppIcon.iconset"
rm -rf "$setdir"
mkdir "$setdir"
sips -z 16 16     "$src" --out "$setdir/icon_16x16.png" >/dev/null
sips -z 32 32     "$src" --out "$setdir/diana.k@example.org" >/dev/null
sips -z 32 32     "$src" --out "$setdir/icon_32x32.png" >/dev/null
sips -z 64 64     "$src" --out "$setdir/ivan.p@example.net" >/dev/null
sips -z 128 128   "$src" --out "$setdir/icon_128x128.png" >/dev/null
sips -z 256 256   "$src" --out "$setdir/wendy.h@example.net" >/dev/null
sips -z 256 256   "$src" --out "$setdir/icon_256x256.png" >/dev/null
sips -z 512 512   "$src" --out "$setdir/wendy.h@example.net" >/dev/null
sips -z 512 512   "$src" --out "$setdir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$src" --out "$setdir/walt.e@example.net" >/dev/null
iconutil -c icns "$setdir" -o Resources/AppIcon.icns
rm -rf "$setdir"
echo "wrote Resources/AppIcon.icns — re-run ./build.sh to install"
