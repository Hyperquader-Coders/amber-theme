# Amber Phosphorus / Amber Light — Source Tokens

`profiles-yaml/phosphorus.yaml` and `profiles-yaml/amber-light.yaml` are sourced
verbatim from **amberlinux.org**'s own design tokens, not hand-picked the way
`kat800-colour-profiles.md`'s terminal profiles are. The site (a Next.js app) inlines its
tokens as CSS custom properties using the `light-dark()` function; fetching the
raw page source (not the rendered/markdown-converted page — that loses `<style>`
blocks) turned up `src/styles/tokens.css`:

```css
--bg:            light-dark(#fdf8ee, #080600)
--bg-surface:    light-dark(#fff,    #100d00)
--bg-elevated:   light-dark(#f5edd8, #1a1600)
--bg-card:       light-dark(#fffdf7, #130f00)
--text-heading:  light-dark(#2d1800, #f0c840)
--text-body:     light-dark(#5c3a10, #b89030)
--text-muted:    light-dark(#9a6830, #907326)
--accent:        light-dark(#a05800, #f5a623)
--accent-dim:    light-dark(#7d4400, #c07800)
--border:        light-dark(#e8d5a8, #2e2400)
--ok:    #4caf50
--warn:  #f5a623
--danger: #ef5350
--on-accent: #0c0800
```

`light-dark(LIGHT, DARK)` gives the light-mode value first. Do **not** trust the
site's marketing-copy prose (e.g. the `/projects/amber-phosphorus/` page's "P3
phosphor" description) — its hex values are rounded approximations that don't
match the actual CSS tokens above.

## Mapping to the 7-primitive profile schema

| yaml field | dark (`phosphorus`) | light (`Amber-Light`) | token source |
|---|---|---|---|
| `bg` | `#080600` | `#fdf8ee` | `--bg` |
| `fg` | `#f0c840` | `#2d1800` | `--text-heading` |
| `accent` | `#f5a623` | `#a05800` | `--accent` |
| `error` | `#ef5350` | `#ef5350` | `--danger` (fixed both modes) |
| `warning` | `#f5a623` | `#f5a623` | `--warn` (fixed both modes — the site reuses the accent hue for its warning colour) |
| `success` | `#4caf50` | `#4caf50` | `--ok` (fixed both modes) |
| `strong` | `#e8590c` | `#b34700` | **not on the site** — independent pick, a more saturated burnt-orange for window-close icon / callouts, distinct from `accent` and `error` |

`--bg-surface`, `--bg-elevated`, `--bg-card`, `--accent-dim`, `--border`, and
`--on-accent` have no direct field in the 7-primitive schema; the derived scale
in `src/scss/gtk-3.0/_vars.scss` (`$bg-subtle` → `$bg-muted`, `$accent-hover`,
etc.) covers the same role instead of importing more site tokens directly.

## Light-mode elevation direction

The site's own light-mode tokens split "elevated" (`--bg-elevated` darker than
`--bg`) from "surface"/"card" (`--bg-surface`/`--bg-card` lighter than `--bg`) —
two different directions depending on UI role. `_vars.scss`'s shared elevation
scale is a single continuum used generically across many Cinnamon/GTK widget
roles, so it doesn't replicate that split: light profiles darken the whole
`$bg-subtle`→`$bg-muted` scale (`$elevate-dir`), matching the "elevated/nav"
role and conventional desktop-light-theme practice (Adwaita-light, Mint-Y-light
hover states are darker than the page background), not the site's separate
"surface/card" role.
