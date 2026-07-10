#!/bin/sh
# dither.sh — replicate the Zebra ZD420 (300 dpi direct thermal) receipt-print
# halftoning with ImageMagick, platform-agnostically.
#
# Provenance of the effect being replicated:
#   GNOME Image Viewer -> GTK/cairo PDF -> CUPS gstoraster (Ghostscript renders
#   the page at 300 dpi / 1-bit gray using its default 45-degree clustered-dot
#   halftone screen) -> rastertolabel (packs bits into ZPL, no dithering).
# Empirically (measured from 1200 dpi scans of the original print),
# Ghostscript's screen here is a 45-degree clustered-dot halftone with an
# 8x8-dot cell: dot pitch 4*sqrt(2) =~ 5.66 dots = 53 lpi at 300 dpi (gs's
# 60 lpi default snapped to the nearest rational 45-degree angle), with 33
# gray levels. ImageMagick's `h8x8a` ordered-dither map has exactly this
# geometry and matching midtone chain direction ("/"), so it is used as-is.
# (The finer `h4x4a` map looks similar zoomed in but is 2x too fine and has
# only 9 gray levels, which causes visible banding/contouring.)
#
# Usage: dither.sh INPUT OUTPUT [options]
#   -w WIDTH_INCHES   printed width in inches   (default 2.19, measured from scan)
#   -r DPI            printer resolution        (default 300)
#   -g GAMMA          pre-dither gamma          (default 1.0 = replicate the
#                     digital raster; the printed page comes out darker via
#                     thermal dot gain. Use ~0.7 to bake that apparent
#                     darkness in, e.g. when targeting other media/screen.)
#   -d DITHER         ordered-dither map        (default h8x8a)
#   -p                also write OUTPUT base + "_preview.png": the dithered
#                     result upscaled 4x (nearest neighbor) to scan scale
#
# Output is a 1-bit image sized WIDTH_INCHES * DPI wide, aspect preserved.
# Landscape inputs are rotated 90 degrees clockwise (after EXIF auto-orient)
# so the shorter image dimension always maps to the paper width.

set -eu

usage() { sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[ $# -ge 2 ] || usage
IN=$1; OUT=$2; shift 2

WIDTH_IN=2.19
DPI=300
GAMMA=1.0
DITHER=h8x8a
PREVIEW=0

while getopts "w:r:g:d:p" opt; do
  case $opt in
    w) WIDTH_IN=$OPTARG ;;
    r) DPI=$OPTARG ;;
    g) GAMMA=$OPTARG ;;
    d) DITHER=$OPTARG ;;
    p) PREVIEW=1 ;;
    *) usage ;;
  esac
done

DOTS=$(awk "BEGIN { printf \"%d\", $WIDTH_IN * $DPI + 0.5 }")

magick "$IN" \
  -auto-orient \
  -rotate "90>" \
  -colorspace Gray \
  -resize "${DOTS}x" \
  -gamma "$GAMMA" \
  -ordered-dither "$DITHER" \
  -type bilevel -depth 1 \
  -density "$DPI" -units PixelsPerInch \
  "$OUT"

if [ "$PREVIEW" = 1 ]; then
  base=${OUT%.*}
  magick "$OUT" -scale 400% "${base}_preview.png"
fi

echo "wrote $OUT (${DOTS} dots wide @ ${DPI} dpi, ${DITHER}, gamma ${GAMMA})"
