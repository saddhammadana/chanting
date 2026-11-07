#!/usr/bin/env bash
# Renders the Play Store feature graphic (1024x500) and the 512x512 listing icon
# into docs/store/assets/.
#
#   tool/store/make_feature_graphic.sh
#
# Needs Google Chrome (headless rendering, for correct Thai text shaping) and
# ImageMagick (`brew install imagemagick`). Nothing is downloaded: the page uses the
# fonts and the app icon that already live in this repository.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="$repo_root/docs/store/assets"
page="$repo_root/tool/store/feature-graphic.html"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -x "$chrome" ] || { echo "Google Chrome not found at: $chrome" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) not installed" >&2; exit 1; }

mkdir -p "$out_dir"

# --allow-file-access-from-files lets the page load the repo's own fonts over file://.
# --hide-scrollbars keeps a scrollbar out of the 1024x500 frame.
"$chrome" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --allow-file-access-from-files \
  --force-device-scale-factor=1 \
  --window-size=1024,500 \
  --screenshot="$out_dir/feature-graphic.png" \
  "file://$page" 2>/dev/null

magick "$repo_root/assets/icon/app_icon.png" -resize 512x512 -strip "$out_dir/icon-512.png"

# Play rejects anything off-size, so fail here rather than at upload time.
for spec in "feature-graphic.png 1024x500" "icon-512.png 512x512"; do
  set -- $spec
  actual="$(magick identify -format '%wx%h' "$out_dir/$1")"
  [ "$actual" = "$2" ] || { echo "$1 is $actual, expected $2" >&2; exit 1; }
  echo "$1  $actual"
done
