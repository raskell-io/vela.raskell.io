#!/usr/bin/env bash
# Render favicons, app icons and the social card.
#   static/img/logo.svg -> favicon.ico, favicon.png, icon-192.png, icon-512.png,
#                          apple-touch-icon.png, icon-maskable-512.png
#   art/og.html         -> static/img/og-image.png (headless Chrome, so the web fonts match the site)
# Needs resvg, ImageMagick and Google Chrome (brew install resvg imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

# The logo is already a rounded navy tile, so every icon is the logo as is.
for s in 16 32 48; do resvg -w $s -h $s static/img/logo.svg "$tmp/$s.png"; done
cp "$tmp/32.png" static/favicon.png
magick "$tmp/16.png" "$tmp/32.png" "$tmp/48.png" static/favicon.ico
resvg -w 192 -h 192 static/img/logo.svg static/icon-192.png
resvg -w 512 -h 512 static/img/logo.svg static/icon-512.png

# iOS and Android mask the corners themselves: fill the square with the tile's navy,
# and keep the boat inside the maskable 80% safe zone.
resvg -w 180 -h 180 static/img/logo.svg "$tmp/touch.png"
magick -size 180x180 xc:'#0F172A' "$tmp/touch.png" -composite static/apple-touch-icon.png
resvg -w 400 -h 400 static/img/logo.svg "$tmp/mask.png"
magick -size 512x512 xc:'#0F172A' "$tmp/mask.png" -gravity center -composite static/icon-maskable-512.png

"$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --virtual-time-budget=5000 --window-size=1200,630 \
    --screenshot="$tmp/og.png" "file://$PWD/art/og.html" 2>/dev/null
magick "$tmp/og.png" -crop 1200x630+0+0 +repage static/img/og-image.png
echo "Icons rendered."
