# kat800 Terminal Palette → GTK Theme Colour Mapping

## How a terminal palette maps to a GTK theme

A terminal has **18 semantic slots**; a GTK theme has roughly the same number of
named roles. The correspondence is not 1-to-1, but the logic is consistent:

| Terminal slot | GTK / desktop role | Why |
|---|---|---|
| Background | Window bg, `.background`, app shell | The canvas everything sits on |
| ANSI 0 (black variant) | Darkest surface — titlebars, panels, sidebars | Darker than bg; used for chrome |
| ANSI 8 (bright black) | Widget base bg (entries, lists), hover tint | Mid-dark; one step lighter than ANSI 0 |
| Foreground | Primary text — `.view`, labels, menu items | The default reading colour |
| ANSI 7 (light grey) | Secondary / muted text, inactive labels | Dimmed fg; subtitles, hints |
| ANSI 15 (bright white) | High-contrast text — dialog titles, tooltips | Maximum legibility on dark bg |
| ANSI 8 (bright black) | Disabled / insensitive text | Greyed-out controls |
| **Cursor** | **Accent colour** — selection bg, focus ring, primary button, checked state | The single "attention" colour of the palette |
| ANSI 4 (blue) | Link colour, secondary button tint | Navigation intent |
| ANSI 12 (bright blue) | Active / hovered link, focused input ring | Brighter accent on interaction |
| ANSI 5 (magenta) | Visited link, badge / tag fill | Seen-state signalling |
| ANSI 1 (red) | Error / destructive colour | Danger semantic |
| ANSI 9 (bright red) | Error hover / focus state | |
| ANSI 2 (green) | Success / positive colour (progress, confirm) | |
| ANSI 10 (bright green) | Success hover | |
| ANSI 3 (yellow) | Warning colour | |
| ANSI 11 (bright yellow) | Warning hover / active | |
| ANSI 6 (cyan) | Info / tooltip background tint | |
| ANSI 14 (bright cyan) | Info hover, active tooltip accent | |
| ANSI 7 @ 30 % opacity | Border / divider / rubberband stroke | Subtle line colour |

---

## The four profiles applied to these GTK roles

Each column shows what hex value that profile contributes to each GTK role.
The "ice" quality of Kat800 Dark comes from its cold-chrome foreground (`#b8cce0`) 
and deep gunmetal background — the closest natural fit for a Bibata-Modern-Ice cursor.

| GTK role | Kat800 Dark | Katai | Mint | Amber Phosphorus |
|---|---|---|---|---|
| **Window background** | `#0e1014` | `#3a3a3a` | `#0c1e18` | `#1e1000` |
| **Darkest surface** (panels, titlebars) | `#0a0812` | `#282828` | `#162a20` | `#1e1000` |
| **Widget base bg** (entries, lists) | `#284838` | `#606060` | `#3a5045` | `#523018` |
| **Primary text** | `#b8cce0` | `#e8e4de` | `#c2d8c8` | `#f0c060` |
| **Secondary / muted text** | `#90c898` | `#c5c8c6` | `#a8c8b8` | `#c8a870` |
| **High-contrast text** | `#d0ffd8` | `#f0ece6` | `#d0e8d8` | `#ffe8b8` |
| **Disabled text** | `#284838` | `#606060` | `#3a5045` | `#523018` |
| **Accent / selection bg** ★ | `#e01515` | `#7eb8d4` | `#4ec994` | `#ffd870` |
| **Focus ring / input cursor** | `#e01515` | `#7eb8d4` | `#4ec994` | `#ffd870` |
| **Primary button bg** | `#e01515` | `#7eb8d4` | `#4ec994` | `#ffd870` |
| **Hover highlight** | `#30c858` | `#81a2be` | `#52b8a8` | `#c09050` |
| **Active / pressed state** | `#0a0812` | `#282828` | `#162a20` | `#1e1000` |
| **Link colour** | `#38b060` | `#7eb8d4` | `#3a9e88` | `#7a6040` |
| **Active link** | `#30c858` | `#81a2be` | `#52b8a8` | `#c09050` |
| **Visited link** | `#c018a8` | `#b294bb` | `#8a7abf` | `#a83422` |
| **Error / destructive** | `#d42070` | `#cc6666` | `#c75858` | `#cc3815` |
| **Error hover** | `#ff40a8` | `#cc6666` | `#e07070` | `#e84818` |
| **Success / positive** | `#20d040` | `#b5bd68` | `#4db870` | `#7d8a18` |
| **Success hover** | `#60f860` | `#b5bd68` | `#68d488` | `#a4b820` |
| **Warning** | `#80c000` | `#de935f` | `#c8a84a` | `#d49020` |
| **Warning hover** | `#c8f040` | `#f0c674` | `#e0c068` | `#ffd030` |
| **Info / tooltip tint** | `#22b85a` | `#8abeb7` | `#3ab8a0` | `#8a7c20` |
| **Info hover** | `#50f090` | `#8abeb7` | `#5ed4bc` | `#c8a820` |
| **Border / divider** | `#90c898` @ 30% | `#c5c8c6` @ 30% | `#a8c8b8` @ 30% | `#c8a870` @ 30% |

★ The accent colour is the single most impactful change — it drives buttons, selections,
checkboxes, progress bars, and switches.

---

## Ice-look recommendation

Kat800 Dark + Bibata-Modern-Ice is the strongest "ice" result:

- The deep `#0e1014` gunmetal background contrasts the blue-white cursor
- The `#b8cce0` cold-chrome foreground has a natural frost quality
- The red accent (`#e01515` — robot cat's eyes) pops hard against the cold palette,
  giving neon-on-ice energy

**Katai** is the softer ice option: its `#7eb8d4` cursor and accent exactly matches
the Bibata-Modern-Ice colour family, making cursor ↔ UI highlights seamless.

**To apply**: replace the `@theme_selected_bg_color` / selection and focus-ring hex
values in `gtk-3.0/gtk-dark.css` and `gtk-4.0/gtk-dark.css` with the cursor colour
from whichever profile you choose, and swap the window/surface backgrounds to match.
