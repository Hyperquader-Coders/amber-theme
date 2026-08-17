# Custom Colour System (CCS)

Every theme variant is driven by a handful of primitive colour values declared
in a YAML profile. From those, `_vars.scss` computes the full set of derived
tokens used across all SCSS targets. Nothing else hard-codes a colour.

All variants ship under the **Amber Linux** family (the 1980s amber-phosphorus
look); each compiles to a directory named `Amber-<Variant>` (e.g.
`Amber-Kat800`, `Amber-Mint`, `Amber-Light`) — except `phosphorus`, which
ships unprefixed and lowercase.

---

## Profiles

Each file in `profiles-yaml/` defines one theme variant:

```yaml
name:    Amber-Katai         # output directory name under dist/ and ~/.themes/
accent:  "#7eb8d4"           # primary action / selection fill
bg:      "#3a3a3a"           # panel / window background (darkest base surface)
fg:      "#e8e4de"           # primary text
error:   "#cc6666"
warning: "#de935f"
success: "#b5bd68"
strong:  "#e05020"           # extra-saturated highlight (accent bars, callouts)
```

`build.sh` reads every `*.yaml` in `profiles-yaml/`, writes a temporary
`_profile.scss` next to each SCSS entry point, compiles, then deletes it. The
generated file just re-declares the primitives as Sass variables:

```scss
// _profile.scss — generated, never committed
$accent:  #7eb8d4;
$bg:      #3a3a3a;
$fg:      #e8e4de;
$error:   #cc6666;
$warning: #de935f;
$success: #b5bd68;
$strong:  #e05020;
```

To add a new profile, drop a `.yaml` file into `profiles-yaml/` and run
`make all`, or `make deb-install` to test it as an installed package.

---

## Variable barrel — `_vars.scss`

`src/scss/gtk-3.0/_vars.scss` is the single source of derived tokens. It is
symlinked into every SCSS target directory so all targets share identical
derivations:

```
src/scss/gtk-3.0/_vars.scss   ← canonical
src/scss/gtk-4.0/_vars.scss   → symlink
src/scss/cinnamon/_vars.scss  → symlink
src/scss/libadwaita/_vars.scss → symlink
```

Each partial uses it with:

```scss
@use 'vars' as *;
```

### Derived tokens

| Variable | Derivation | Purpose |
|---|---|---|
| `$bg-transparent` | `$bg` at α=0 | ripple / overlay base |
| `$bg-dark` | `$bg` shaded 1% | input / entry background |
| `$bg-dark-trans` | `$bg-dark` at α=0 | transition start |
| `$bg-darker` | `$bg` shaded 3% | sidebar, secondary panels |
| `$bg-darkest` | `$bg` shaded 9% | menu background, deepest surface |
| `$bg-subtle` | `$bg` ± 2% L | row hover (subtle) |
| `$bg-mid` | `$bg` ± 7% L | card / tile surface |
| `$bg-hover` | `$bg` ± 10% L | hover state |
| `$bg-hover-deep` | `$bg` ± 12% L | pressed hover |
| `$bg-border` | `$bg` ± 17% L | separator, unfocused border |
| `$bg-border-hi` | `$bg` ± 20% L | focused border |
| `$bg-muted` | `$bg` ± 21% L | disabled surface |
| `$accent-trans` | `$accent` at α=0 | transition start |
| `$accent-hover` | `$accent` +10% L | hover over accent element |
| `$accent-active` | `$accent` −10% L | pressed accent |
| `$accent-dim` | mix(`$accent`, `$bg`, 40%) | subdued accent (badges, etc.) |
| `$accent-alpha` | `$accent` at α=0.30 | selection highlight |
| `$error-light` | `$error` +15% L | error icon / text tint |
| `$error-dark` | `$error` −10% L | error border |
| `$warning-light` | `$warning` +15% L | warning icon / text tint |
| `$warning-dark` | `$warning` −10% L | warning border |
| `$success-light` | `$success` +15% L | success icon / text tint |
| `$success-dark` | `$success` −10% L | success border |
| `$fg-high` | `$fg` at α=0.87 | primary text |
| `$fg-medium` | `$fg` at α=0.60 | secondary / hint text |
| `$fg-low` | `$fg` at α=0.42 | placeholder text |
| `$fg-outline` | `$fg` at α=0.17 | dividers, outlines |
| `$fg-transparent` | `$fg` at α=0 | transition start |
| `$fg-on-accent` | `$bg-darkest` | text/icons **on** an accent fill |
| `$toolbar-btn-bg` | `$bg-mid` at α=0.5 | toolbar / path-bar / stack-switcher button fill |
| `$toolbar-btn-bg-hover` | `$bg-border` at α=0.5 | toolbar button hover |
| `$wm-close-bg` | `$accent` | window close button fill |
| `$wm-close-bg-hover` | `$accent-active` | window close button hover |
| `$wm-close-bg-active` | `$accent` −20% L | window close button pressed |
| `$wm-close-bg-dim` | `$accent-dim` | window close button, unfocused window |
| `$wm-close-icon` | `$strong` | window close button glyph |
| `$wm-action-icon` | `$fg-low` | minimize/maximize glyph |
| `$wm-action-bg-hover` | `$accent-alpha` | minimize/maximize hover fill |
| `$wm-action-icon-hover` | `$strong` | minimize/maximize glyph, hovered |

Lightness adjustments use HSL space via Dart Sass `color.adjust()`. `shade()`
always darkens (see below). The `$bg-subtle` → `$bg-muted` "raised surface"
scale is direction-aware: `$elevate-dir` is `-1` when `$bg` is light and `+1`
when it's dark, so a light profile's hover/border/muted surfaces darken
instead of lightening — the same convention Adwaita-light and Mint-Y-light
use, since lightening an already-light surface washes out toward white and
loses contrast.

---

## Contrast model

The whole point of the token layer is that *accent, primary, secondary, borders
and backgrounds stay legible together on any profile*. Five rules cover every
component:

1. **Backgrounds** step through one elevation scale. `$bg` is the base
   (window/panel); each lift (`$bg-subtle` → `$bg-mid` → `$bg-hover` …) is a
   small, monotonic lightness change — away from `$bg` in the direction
   `$elevate-dir` picks — so stacked surfaces (window → card → dialog →
   popover) read as distinct depths without any new hue.
2. **Primary text** is `$fg` / `$fg-high`; **secondary text** is `$fg-medium` /
   `$fg-low`. Both are the *foreground* hue at decreasing alpha, so dimmed text
   keeps the profile tint and a guaranteed contrast floor against `$bg`.
3. **Accent as a fill** (`$accent`, `$error`, `$success`, `$warning`) always
   pairs with **`$fg-on-accent` = `$bg-darkest`** for the text/icons drawn on
   top. Dark-on-accent is the single rule that keeps selected rows, suggested
   buttons, switches and progress bars readable — pairing an accent fill with
   `$strong` (another saturated hue) instead gives near-zero contrast.
4. **Accent as standalone text/icon** on the window background (links, the
   libadwaita `accent_color`) uses `$accent` directly, which is bright enough to
   read on `$bg`; state text uses the `*-light` variants for the same reason.
5. **Borders** come from the *upper* end of the background scale
   (`$bg-border`, `$bg-border-hi`) or neutral black alphas, so a separator
   always contrasts the surfaces on both sides of it.

The exception is a **dark** state fill (e.g. `$error-dark` on the menu shutdown
button): there text stays light, because dark-on-dark would fail. Rule 3 only
applies to the *bright* accent fills.

---

## The `ri()` function

Dart Sass `color.adjust($c, $lightness: N%)` goes through HSL and produces
fractional RGB channels — for example `#3a3a3a` darkened 9% yields
`rgb(35.05, 35.05, 35.05)`. Two problems arise when this reaches CSS:

1. **Cinnamon's St CSS engine** only parses integer `rgb()` values; fractional
   values are silently ignored, leaving the property unset (transparent
   background, invisible border, etc.).

2. **All-zero edge case.** For very dark base colours (`$bg` lightness < 9%),
   the adjustment clips to 0% lightness and Sass outputs `rgb(0, 0, 0)`. St CSS
   also silently ignores `rgb(0, 0, 0)` — the same symptom as the fractional
   case, just for a different reason.

`ri()` (round-to-integer) addresses both:

```scss
@function ri($c) {
  // Clamp to min 1 per channel: St CSS silently ignores rgb(0,0,0).
  @return rgb(
    math.max(1, math.round(color.channel($c, 'red'))),
    math.max(1, math.round(color.channel($c, 'green'))),
    math.max(1, math.round(color.channel($c, 'blue')))
  );
}
```

- `math.round` eliminates fractional channels.
- `math.max(1, …)` prevents all-zero output. `rgb(1, 1, 1)` is visually
  indistinguishable from `rgb(0, 0, 0)` on any monitor.

Every call to `color.adjust()` or `color.mix()` that produces an opaque colour
is wrapped in `ri()`. Calls that produce a transparent colour (alpha < 1) use
`color.change()` directly and are not wrapped — fractional alpha is valid CSS
and St CSS handles it correctly.

---

## SCSS targets

| Target | Entry point | Output |
|---|---|---|
| GTK 3 | `src/scss/gtk-3.0/main.scss` | `gtk-3.0/gtk-dark.css` (copied to `gtk.css`) |
| GTK 4 | `src/scss/gtk-4.0/main.scss` | `gtk-4.0/gtk-dark.css` (copied to `gtk.css`) |
| Cinnamon | `src/scss/cinnamon/main.scss` | `cinnamon/cinnamon.css` |
| libadwaita dark | `src/scss/libadwaita/main-dark.scss` | `libadwaita-1.5/defaults-dark.css` |
| libadwaita light | `src/scss/libadwaita/main-light.scss` | `libadwaita-1.5/defaults-light.css` |

GTK 4 and GTK 3 share the same partial structure. GTK 3 has two extra partials
(`_widgets-legacy.scss` for PNG-based widgets, `_libhandy.scss`) because GTK 3
applications may use libhandy and rely on the older PNG switch/check/radio
assets.

---

## Build

`build.sh` compiles with the standalone Dart Sass CLI (`sass`, vendored into
`.tools/dart-sass/` by `make deps` — see the Makefile's
`DART_SASS_VERSION`/`fetch-sass`), writing and deleting `_profile.scss` around
each compile call. See the top-level [README](../README.md) for the full
command surface.

---

## Legacy-palette remap

The GTK 3/4 rule partials were forked from Mint-Y-Dark-Grey and still contain a
fixed set of that theme's hardcoded literals (greys, whites, the Mint selection
blue, reds). Rather than hand-edit ~250 call sites, the build normalises them:

1. `src/scss/gtk-3.0/remap-manifest.scss` declares a Sass map of every legacy
   hex → the equivalent profile token, and emits the resolved values in a
   `:root` block.
2. `build.sh` compiles that manifest once per profile, and
   `scripts/apply-remap.py` reads the resolved values back out and rewrites
   every compiled stylesheet so each legacy literal becomes its on-profile
   colour. Longest keys are replaced first and a negative lookahead protects
   id selectors like `#add-color-button`. `$legacy-rgba` (paired with a
   `RGBA_SOURCES` table in `scripts/apply-remap.py`) covers the handful of
   colours the Cinnamon fork expresses as literal `rgba(r, g, b, a)` calls
   instead of hex — the panel background and several text alphas — which the
   hex regex can't reach.

This means a new hardcoded literal slipping into a rule file only needs a single
row in the manifest — no per-file edits — and the *resolved* colour comes from
the same derivation logic (`ri()`, `shade()`, the `$bg-*` scale) as everything
else. SVG assets that need per-profile colour use `@@TOKEN@@` placeholders and
the `.svg.in` suffix instead (substituted by `process_assets` in `build.sh`).
