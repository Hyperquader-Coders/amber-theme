# Amber Theme

A Cinnamon/GTK theme suite built around the warm amber glow of 1980s
phosphor CRT monitors. Every colour in every shell component traces back to
seven primitives per profile, so one architecture drives five distinct
looks: `phosphorus` (dark), `Amber-Light`, `Amber-Kat800`, `Amber-Katai`,
`Amber-Mint`. Each profile compiles to a complete theme — GTK 3, GTK 4,
libadwaita, Cinnamon shell styling, a Metacity/Muffin window-border theme,
and per-profile folder icon themes — plus ten shared Amber Linux desktop
wallpapers and a Debian package.

## How it works

`profiles-yaml/*.yaml` declares seven colour primitives per profile
(`accent`, `bg`, `fg`, `error`, `warning`, `success`, `strong`). `build.sh`
derives a full scale of tokens from those primitives
(`src/scss/gtk-3.0/_vars.scss`) and recolours literal, unmodified forks of
Mint-Y-Dark-Grey's own GTK3/GTK4/Cinnamon CSS by rewriting every legacy
hex/rgba literal to its on-profile token
(`src/scss/gtk-3.0/remap-manifest.scss`, `scripts/apply-remap.py`) — no rule
is ever hand-rewritten. `build-icons.sh` recolours the same way for folder
icon themes, using Mint-Y-Yaru and Yaru as the two upstream bases. See
[`docs/CCS.md`](docs/CCS.md) for the full token-derivation reference and
[`diags/`](diags/) for the pipeline diagram.

No Node, Bun, or npm anywhere in the toolchain — `build.sh` is plain bash,
compiling with the standalone Dart Sass CLI.

## Build

```sh
make deps          # vendor the standalone Dart Sass CLI + packaging tools (once after clone)
make all           # compile all profiles → dist/
make icons         # generate per-profile folder icon themes → dist-icons/
make deb           # build the .deb package → dist/*.deb
make deb-install   # build + install the real .deb (sudo) — the only supported way to test a change
make use THEME=phosphorus   # activate a profile (gsettings)
make ci            # the full local gate: check, build, lint, deb
make deb-remove    # remove the installed package (sudo)
make clean         # remove dist/, dist-icons/, out/
```

`make use` with no `THEME=` activates `phosphorus`. `ICONS` defaults to
`THEME`; override it to pick the rounder Yaru icon shape, e.g.
`make use THEME=phosphorus ICONS=phosphorus-Yaru`.

There is no per-user or raw-system install path. Every change is tested by
building the actual package and installing it with `make deb-install` — a
shortcut that copies files straight into `~/.themes` or `/usr/share` without
going through dpkg drifts from what ships and leaves orphaned files behind.

## Layout

| | |
|---|---|
| `profiles-yaml/*.yaml` | seven primitive colour tokens per theme variant |
| `src/scss/` | GTK3/GTK4/libadwaita/Cinnamon rule partials — literal Mint-Y-Dark-Grey forks, recoloured mechanically |
| `build.sh` | the build driver |
| `scripts/apply-remap.py` | rewrites legacy hex/rgba literals to profile tokens |
| `scripts/yaml-field.sh` | shared flat-yaml value parser (`build.sh` and the Makefile's `deactivate-if-active` both use it) |
| `build-icons.sh` | generates per-profile folder icon themes and the Nemo folder-colour palette |
| `src/nemo-python/` | Nemo extension that auto-applies emblem folder icons by name |
| `src/metacity-1/` | Metacity/Muffin window-border theme |
| `wallpapers/` | ten Amber Linux desktop wallpapers + the Backgrounds-picker XML |
| `packaging/` | Debian packaging templates for `make deb` |
| `references/` | an unmodified Mint-Y-Dark-Grey copy to diff against, plus the provenance notes (`*.md`) for the amberlinux.org tokens and the kat800 palette; not read by the build |
| `docs/CCS.md` | the colour-token-derivation reference |
| `diags/` | architecture diagram |

## Design rules

- No hand-picked hex or rgba value inside a rule file. A literal Mint-Y-Dark-Grey
  value is fine — that's the fork; a hand-edited one that bypasses
  `remap-manifest.scss` is not. See [`docs/CCS.md`](docs/CCS.md).
- Cinnamon's St CSS engine silently ignores `rgb(0, 0, 0)` and fractional
  `rgb()` channels — every derived opaque colour goes through `ri()`, which
  rounds and clamps to a minimum of 1 per channel.
- `shade($c, $delta%)` clamps lightness to a minimum of 2% so a very dark base
  colour keeps its hue instead of clipping to black.
- The `$bg-subtle`→`$bg-muted` elevation scale darkens instead of lightening
  when the profile background is light (`$elevate-dir`), matching how
  Adwaita-light and Mint-Y-light shade their own hover states.
- `wallpapers/amber.xml` must be installed to *both*
  `gnome-background-properties` and `cinnamon-background-properties` —
  Cinnamon's own Backgrounds picker (`cs_backgrounds.py`) only scans the
  latter and has no per-user fallback, so a user-level install never shows
  wallpapers there.
- Cinnamon's Backgrounds picker derives a collection's sidebar label from only
  the *last* hyphen-separated word of the properties filename
  (`amber.xml` → "Amber") — there is no mechanism for a multi-word label
  beyond the one hardcoded exception Cinnamon carries for its own
  `Linuxmint.xml`.

## Licence

GPL-3.0-or-later, the whole repository — see [LICENSE](LICENSE). This repo is
GPL because its work is derivative of GPL material: `references/` is an
unmodified copy of Linux Mint's GPL-3.0-or-later Mint-Y-Dark-Grey theme kept
for diffing, and the generated icon output derives from Yaru / Mint-Y-Yaru
(GPL / CC-BY-SA) per `build-icons.sh`.
