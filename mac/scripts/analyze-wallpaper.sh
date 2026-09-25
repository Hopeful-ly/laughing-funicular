#!/usr/bin/env bash
# Prints colour statistics for a wallpaper, used by Theme.qml:
#   mean R G B        (whole image, 0-255)
#   top R G B         (top 4%  -> menu bar legibility)
#   bottom R G B      (bottom 12% -> dock)
#   palette: histogram lines "count #RRGGBB"
f="$1"
[ -f "$f" ] || exit 1
fmt='%[fx:int(255*r)] %[fx:int(255*g)] %[fx:int(255*b)]'
small=$(mktemp --suffix=.png)
trap 'rm -f "$small"' EXIT
magick "$f" -resize 320x180! "$small"
echo "mean $(magick "$small" -resize 1x1! -format "$fmt" info:)"
echo "top $(magick "$small" -gravity north -crop 100%x5%+0+0 +repage -resize 1x1! -format "$fmt" info:)"
echo "bottom $(magick "$small" -gravity south -crop 60%x12%+0+0 +repage -resize 1x1! -format "$fmt" info:)"
magick "$small" -resize 96x54! +dither -colors 10 -format '%c' histogram:info: \
  | sed -nE 's/^ *([0-9]+):.*(#[0-9A-Fa-f]{6}).*/palette \1 \2/p'
