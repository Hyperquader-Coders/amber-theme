#!/usr/bin/env python3
"""Rewrite legacy Mint-Y hex/rgba literals in a compiled CSS file to their
profile colours, per src/scss/gtk-3.0/remap-manifest.scss's $legacy and
$legacy-rgba maps. Port of build.ts's resolveRemap()/applyRemap() — see that
git history for the original TypeScript version.

Usage: apply-remap.py <manifest.css> <src.css> <dst.css>

<manifest.css> is remap-manifest.scss compiled for the current profile (its
:root block emits --m-<hex>: <value>; and --m-rgba-<slug>: <value>; custom
properties). <src.css> is the raw compiled stylesheet; <dst.css> is written
with every legacy literal replaced.
"""
import re
import sys

# Exact rgba(...) source strings the reference CSS uses instead of hex, paired
# with the slug their resolved replacement is keyed under in $legacy-rgba.
# Keep in sync with remap-manifest.scss's $legacy-rgba map.
RGBA_SOURCES = [
    ("rgba(225, 225, 225, 0.05)", "fg-a05"),
    ("rgba(225, 225, 225, 0.2)", "fg-a20"),
    ("rgba(225, 225, 225, 0.3)", "fg-a30"),
    ("rgba(225, 225, 225, 0.4)", "fg-a40"),
    ("rgba(225, 225, 225, 0.45)", "fg-a45"),
    ("rgba(225, 225, 225, 0.5)", "fg-a50"),
    ("rgba(195, 195, 195, 0.55)", "fg-a55"),
    ("rgba(225, 225, 225, 0.8)", "fg-a80"),
    ("rgba(225, 225, 225, 0.85)", "fg-a85"),
    ("rgba(225, 225, 225, 0.9)", "fg-a90"),
    ("rgba(112, 115, 122, 0.3)", "bbh-a30"),
    ("rgba(112, 115, 122, 0.4)", "bbh-a40"),
    ("rgba(122, 122, 122, 0.5)", "bbh-a50"),
    ("rgba(112, 115, 122, 0.6)", "bbh-a60"),
    ("rgba(112, 115, 122, 0.8)", "bbh-a80"),
    ("rgba(106, 109, 116, 0.95)", "bbh-a95"),
    ("rgba(104, 104, 104, 0.25)", "bmid-a25"),
    ("rgba(104, 104, 104, 0.4)", "bmid-a40"),
    ("rgba(48, 48, 54, 0.05)", "bg-a05"),
    ("rgba(48, 48, 54, 0.1)", "bg-a10"),
    ("rgba(48, 48, 54, 0.55)", "bg-a55"),
    ("rgba(60, 60, 68, 0.05)", "bhov-a05"),
    ("rgba(42, 42, 47, 0.05)", "bdk-a05"),
    ("rgba(34, 34, 38, 0.3)", "bdk-a30"),
    ("rgba(17, 17, 17, 0.4)", "bdk-a40"),
    ("rgba(34, 34, 38, 0.9)", "bdk-a90"),
    ("rgba(29, 29, 33, 0.99)", "bdk-a99"),
]


def main() -> None:
    manifest_path, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
    manifest = open(manifest_path, encoding="utf-8").read()

    hex_map = {
        m.group(1).lower(): m.group(2).strip()
        for m in re.finditer(r"--m-([0-9a-fA-F]{3,6}):\s*([^;]+);", manifest)
    }
    rgba_map = {
        m.group(1): m.group(2).strip()
        for m in re.finditer(r"--m-rgba-([a-z0-9-]+):\s*([^;]+);", manifest)
    }

    css = open(src_path, encoding="utf-8").read()

    # Longest hex keys first so a 6-digit literal is never partially eaten by
    # a 3-digit rule; the negative lookahead keeps `#fff` from matching inside
    # `#ffffff` and keeps colour keys from corrupting id selectors like
    # `#add-color-button`.
    for hex_key in sorted(hex_map, key=len, reverse=True):
        css = re.sub(
            r"#" + hex_key + r"(?![0-9a-fA-F])",
            hex_map[hex_key],
            css,
            flags=re.IGNORECASE,
        )

    for source, slug in RGBA_SOURCES:
        replacement = rgba_map.get(slug)
        if replacement is not None:
            css = css.replace(source, replacement)

    open(dst_path, "w", encoding="utf-8").write(css)


if __name__ == "__main__":
    main()
