# Replicate the Zebra ZD420c (300 dpi) receipt-print halftone and print it.
# Preset developed against a 1200 dpi scan of the original GNOME/CUPS print:
#   - grayscale, fit to 2.19 in @ 300 dpi (657 dots wide)
#   - h8x8a ordered dither (45-degree clustered screen, 53 lpi, 33 levels --
#     matches Ghostscript's default halftone in the gstoraster path)
#   - gamma 1.0 (replicates the digital raster; thermal dot gain re-applies
#     itself on every print, so no compensation is baked in)

printer := "zd420c.lan"

default:
    @just --list

# dither INPUT with the calibrated preset; also writes *_preview.png (4x)
dither input output="dithered.png":
    ./dither.sh "{{ input }}" "{{ output }}" -p

# send a 1-bit image (any size) to the printer as raw ZPL on port 9100
print image host=printer:
    #!/usr/bin/env bash
    set -euo pipefail
    w=$(magick identify -format '%w' "{{ image }}")
    h=$(magick identify -format '%h' "{{ image }}")
    bpr=$(( (w + 7) / 8 ))
    bytes=$(( bpr * h ))
    hex=$(mktemp) && trap 'rm -f "$hex"' EXIT
    magick "{{ image }}" pbm:- | tail -c "$bytes" | xxd -p | tr -d '\n' > "$hex"
    [ "$(wc -c < "$hex")" -eq $(( bytes * 2 )) ]
    { printf '^XA^PW%d^LL%d^FO0,0^GFA,%d,%d,%d,' "$w" "$h" "$bytes" "$bytes" "$bpr"
      cat "$hex"
      printf '^FS^XZ'
    } | nc -w 10 "{{ host }}" 9100
    echo "sent {{ image }} (${w}x${h}) to {{ host }}"

# dither INPUT and print it in one step
go input: (dither input) (print "dithered.png")
