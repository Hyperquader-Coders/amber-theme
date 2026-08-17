#!/usr/bin/env bash
# Generate per-profile folder icon themes for Amber Linux.
#
# We don't ship a full icon set — that would be thousands of icons. Instead, like
# Mint's own 11 colour variants, each theme Inherits a complete base and
# overrides only the places/ folder icons, recoloured to the profile palette with
# a duotone (shadows->$bg, highlights->$fg) — the same amber-phosphor mapping
# used for the preview thumbnails.
#
# Two bases are built, so the user can pick a look in the Themes applet:
#   • Mint-Y-Yaru  -> "Amber-<Variant>"        (squarer Mint folders)
#   • Yaru         -> "Amber-<Variant>-Yaru"   (rounder Ubuntu folders)
#
# Source folder art is GPL (Mint-Y-Yaru) / CC-BY-SA + GPL (Yaru); the recoloured
# output is a derivative.
#
# Usage: build-icons.sh [OUT_DIR]   (default: dist-icons)
set -euo pipefail

OUT="${1:-dist-icons}"

if ! command -v convert >/dev/null 2>&1; then
  echo "build-icons: ImageMagick 'convert' not found — skipping icon build" >&2
  exit 0
fi

# A hard requirement, unlike convert above: without it every generated theme
# ships without its icon-theme.cache, which nothing in the package fails on and
# nothing regenerates — no dpkg trigger covers /usr/share/icons/<theme>.
if ! command -v gtk-update-icon-cache >/dev/null 2>&1; then
  echo "build-icons: gtk-update-icon-cache not found (apt install gtk-update-icon-cache)" >&2
  exit 1
fi

# ── Emblem glyphs ─────────────────────────────────────────────────────────────
# Custom "special folders" (like Documents/Downloads) for our own categories.
# Each glyph is drawn from primitives once as a white-on-transparent 256px mask;
# the alpha is the shape. build_family stamps them onto every folder.png in the
# profile's $bg tone to make folder-code / folder-projects / folder-kat800.
EMBLEMS="code projects kat800"
GLYPHS="$(mktemp -d)"
trap 'rm -rf "$GLYPHS"' EXIT
# Code: </>
convert -size 256x256 xc:none -gravity center -font DejaVu-Sans-Mono-Bold \
  -pointsize 130 -fill white -annotate +0+0 '</>' "$GLYPHS/code.png"
# Projects: 2x2 rounded grid
convert -size 256x256 xc:none -fill white \
  -draw "roundrectangle 40,40 116,116 14,14"   -draw "roundrectangle 140,40 216,116 14,14" \
  -draw "roundrectangle 40,140 116,216 14,14"  -draw "roundrectangle 140,140 216,216 14,14" \
  "$GLYPHS/projects.png"
# .kat800: terminal frame with a >_ prompt
convert -size 256x256 xc:none -stroke white -fill none -strokewidth 12 \
  -draw "roundrectangle 30,52 226,204 18,18" -strokewidth 14 \
  -draw "line 74,104 104,128" -draw "line 104,128 74,152" -draw "line 124,156 168,156" \
  "$GLYPHS/kat800.png"

# stamp_emblems DEST  BG_HEX  — add folder-<emblem>.png beside every folder.png.
stamp_emblems() {
  local dest="$1" bg="$2" fp dim dir em
  while IFS= read -r fp; do
    dim=$(identify -format '%w' "$fp"); dir=$(dirname "$fp")
    for em in $EMBLEMS; do
      convert "$GLYPHS/$em.png" -resize $((dim*45/100))x$((dim*45/100)) \
              +level-colors "$bg","$bg" "$GLYPHS/_layer.png"
      convert "$fp" "$GLYPHS/_layer.png" -gravity Center -geometry +0+$((dim/10)) \
              -composite "$dir/folder-$em.png"
    done
  done < <(find "$dest" -path '*/places/*' -name 'folder.png')
}

# build_family BASE_DIR  NAME_SUFFIX  INHERITS
# Recolours every */places/*.png under BASE_DIR into one icon theme per profile.
build_family() {
  local base="$1" suffix="$2" inherits="$3"
  if [ ! -d "$base" ]; then
    echo "build-icons: base icon theme '$base' not found — skipping '$suffix' family" >&2
    return 0
  fi
  for yaml in profiles-yaml/*.yaml; do
    local name bg fg dest
    name=$(sed -nE 's/^name:[[:space:]]*//p' "$yaml" | tr -d '"' | head -1)${suffix}
    bg=$(sed -nE 's/^bg:[[:space:]]*//p'      "$yaml" | tr -d '"' | head -1)
    fg=$(sed -nE 's/^fg:[[:space:]]*//p'      "$yaml" | tr -d '"' | head -1)
    dest="$OUT/$name"
    echo "Icons: $name  ($(basename "$base") base, $bg -> $fg)"
    rm -rf "$dest"
    mkdir -p "$dest"

    # index.theme: keep the base's directory list, point Inherits at the base and
    # rename. Lookups for anything we don't override fall through to the base.
    {
      sed -e "s/^Name=.*/Name=$name/" \
          -e "s/^Inherits=.*/Inherits=$inherits/" \
          "$base/index.theme"
      echo "# Folder icons derived from $(basename "$base"), recoloured for Amber Linux."
    } > "$dest/index.theme"

    # Recolour every places/ PNG (resolve symlinks to real files). +level-colors
    # maps black->bg, white->fg and leaves the alpha channel untouched. The
    # -path glob matches both layouts: places/<size>/*.png and <size>/places/*.png.
    #
    # start-here.png is excluded: it is the base distribution's logo, not folder
    # art, so recolouring it would put a tinted Ubuntu mark on the menu button.
    # Left out of the overlay, it falls through to the base theme via Inherits=.
    while IFS= read -r f; do
      local rel="${f#"$base"/}"
      mkdir -p "$dest/$(dirname "$rel")"
      convert "$f" +level-colors "$bg","$fg" "$dest/$rel"
    done < <(find -L "$base" -path '*/places/*' -name '*.png' ! -name 'start-here.png')

    stamp_emblems "$dest" "$bg"

    gtk-update-icon-cache -f -q "$dest"
  done
}

build_family "${ICON_BASE:-/usr/share/icons/Mint-Y-Yaru}" ""      "Mint-Y-Yaru,Mint-Y,Adwaita,gnome,hicolor"
build_family "${ICON_BASE_YARU:-/usr/share/icons/Yaru}"   "-Yaru" "Yaru,Humanity,hicolor"

# ── Nemo folder-colour palette ────────────────────────────────────────────────
# The nemo-folder-color-switcher extension reads palettes from
# /usr/share/folder-color-switcher/colors.d/*.json. Each "style" is keyed by an
# active icon-theme name and lists the colour options; picking one points the
# folder's metadata::custom-icon at the 'folder' icon of that colour's theme.
#
# So each palette colour is a tiny, Hidden icon theme containing only the
# recoloured folder*.png icons (duotone darkened-hue -> hue), and Amber.json
# wires them into the menu for every base theme (per shape).
PALETTE=( Amber:#ffb800 Orange:#ff8c00 Red:#e0552a Lime:#b5bd3a Green:#5aa15a
          Teal:#3fb0a0 Blue:#5a8fd0 Violet:#a072c0 Grey:#9a8f80 )

darken() { convert xc:"$1" -fill black -colorize 76% -depth 8 -format '#%[hex:u]' info:; }

# build_palette BASE_DIR  SHAPE_SUFFIX  INHERITS
# One Hidden "Amber-Folder<suffix>-<Colour>" theme per palette colour, holding
# just the recoloured folder icons in that colour's shape.
build_palette() {
  local base="$1" suffix="$2" inherits="$3"
  [ -d "$base" ] || { echo "build-icons: '$base' missing — skipping palette$suffix" >&2; return 0; }
  local entry cname chex shadow dest rel f
  for entry in "${PALETTE[@]}"; do
    cname="${entry%%:*}"; chex="${entry#*:}"; shadow=$(darken "$chex")
    dest="$OUT/Amber-Folder${suffix}-${cname}"
    echo "Palette: $(basename "$dest")  ($shadow -> $chex, $(basename "$base") shape)"
    rm -rf "$dest"; mkdir -p "$dest"
    {
      sed -e "s/^Name=.*/Name=Amber-Folder${suffix}-${cname}/" \
          -e "s/^Inherits=.*/Inherits=$inherits/" \
          -e "/^Hidden=/d" "$base/index.theme"
      echo "Hidden=true"
    } > "$dest/index.theme"
    while IFS= read -r f; do
      rel="${f#"$base"/}"
      mkdir -p "$dest/$(dirname "$rel")"
      convert "$f" +level-colors "$shadow","$chex" "$dest/$rel"
    done < <(find -L "$base" -path '*/places/*' -name 'folder*.png')
    gtk-update-icon-cache -f -q "$dest"
  done
}

build_palette "${ICON_BASE:-/usr/share/icons/Mint-Y-Yaru}" ""      "Mint-Y-Yaru,Mint-Y,hicolor"
build_palette "${ICON_BASE_YARU:-/usr/share/icons/Yaru}"   "-Yaru" "Yaru,hicolor"

# colors.d JSON: one style per base theme (both shapes), each offering "Default"
# (the theme's own folder) plus the palette, pointing at the matching-shape
# Amber-Folder* themes. Generated with python3 for safe JSON.
CONFIG_OUT="$OUT/folder-color-switcher"
mkdir -p "$CONFIG_OUT"
PALETTE_STR="${PALETTE[*]}" python3 - "$CONFIG_OUT/Amber.json" <<'PY'
import json, sys, re, glob, os
palette = [p.split(":", 1) for p in os.environ["PALETTE_STR"].split()]
def field(text, key):
    m = re.search(rf'^{key}:\s*"?(.*?)"?\s*$', text, re.M)
    return m.group(1) if m else ""
styles = []
for y in sorted(glob.glob("profiles-yaml/*.yaml")):
    t = open(y).read(); name = field(t, "name"); fg = field(t, "fg")
    for shape in ("", "-Yaru"):
        base = name + shape
        themes = [{"name": "Default", "color": fg, "theme": base}]
        for cn, ch in palette:
            themes.append({"name": cn, "color": ch, "theme": f"Amber-Folder{shape}-{cn}"})
        styles.append({"name": base, "icon-themes": themes})
json.dump({"styles": styles}, open(sys.argv[1], "w"), indent=4)
print(f"Wrote {sys.argv[1]} ({len(styles)} styles)")
PY
