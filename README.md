# dithering

Replicate the look of photos printed on a Zebra ZD420c thermal receipt
printer (300 dpi, 2.25 in paper) — without needing the original print stack —
and print the result directly over the network.

## Background

A photo printed from GNOME Image Viewer on Fedora came out with a pleasing
halftone texture. That texture is produced inside the CUPS pipeline:

```text
GNOME Image Viewer -> GTK/cairo (PDF) -> gstoraster (Ghostscript) -> rastertolabel (ZPL) -> printer
```

The Zebra filter (`rastertolabel`) does no dithering — it just packs bits.
The halftoning happens in Ghostscript, which renders the page at 300 dpi,
1-bit, using its default clustered-dot screen.

Reverse-engineering a 1200 dpi scan of that print showed the screen is a
**45° clustered-dot halftone with an 8×8-dot cell** — 53 lpi at 300 dpi
(Ghostscript's 60 lpi default snapped to the nearest exact 45° angle,
300/(4√2) ≈ 53), with 33 gray levels. ImageMagick ships exactly this screen
as the `h8x8a` ordered-dither map, so the whole pipeline reduces to one
portable `magick` command. That lives in [`dither.sh`](dither.sh).

Notes from the calibration:

- **Geometry:** the printed area is 2.19 in ≈ 657 dots wide at 300 dpi.
- **Tone:** the file is dithered at gamma 1.0, replicating the digital
  raster. Prints come out darker than the file (thermal dot gain), but that
  happens on every print — including the original — so it isn't compensated.
- **Wrong turns, for posterity:** the finer `h4x4a` map (106 lpi) looks
  similar magnified but prints with a visibly smaller grid and, at only
  9 gray levels, harsh banding in smooth gradients.

## Requirements

ImageMagick and [just](https://github.com/casey/just) — `mise install` sets
both up from [`mise.toml`](mise.toml). Printing needs `nc` (preinstalled on
macOS/Linux) and a ZPL printer listening on port 9100.

## Usage

```sh
just dither photo.jpg            # -> dithered.png (1-bit, 657 px wide)
                                 #    + dithered_preview.png (4x, for screen)
just print dithered.png          # send to the printer as raw ZPL
just go photo.jpg                # both steps in one

just print dithered.png other-printer.lan   # different printer host
```

Or call the script directly for the knobs:

```sh
./dither.sh photo.jpg out.png [-w 2.19] [-r 300] [-g 1.0] [-d h8x8a] [-p]
```

`-g` adjusts pre-dither gamma (raise above 1.0 if prints lean dark),
`-w`/`-r` set paper width and printer resolution, `-d` picks another
ImageMagick threshold map, `-p` writes the 4× preview.

## How printing works

`just print` converts the 1-bit PNG to PBM, hex-encodes the packed bits, and
wraps them in a ZPL `^GFA` graphic sized from the image — then pipes the job
to port 9100. No driver, no CUPS: the dots on paper are exactly the pixels
in the file.
