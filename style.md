# Style guide: the "Squishy" design philosophy

A portable guide for building apps that look and feel like Squishy: dark-first, glassy,
liquid, playful, and fully themeable. Hand this file to any app or coding agent. The values
are Squishy's own, written as tokens so you can carry them over to any framework.
Implementation notes are for Flutter + Material 3, the original stack.

---

## 1. Principles

1. **Tokens, never raw values.** Every color, spacing, radius, duration and shadow comes from
   a named token. Raw hex colors live in **one** file (the palette presets) and nowhere else.
2. **Dark-first glass.** Default to a near-black background with slightly lifted "glass"
   surfaces: a faint tint, a hairline border and a soft shadow. Use soft shadows for depth, not Material elevation.
3. **One liquid gradient is the brand.** Each theme has two "liquid" colors. Their gradient
   marks the single most important thing on screen: the main button, progress, charts,
   active indicators. Use it sparingly so it keeps meaning "this matters".
4. **Motion feels physical and calm.** Things squish, spring and settle (`easeOutBack`,
   `elasticOut`, `easeOutCubic`). Durations are short. Everything can be turned off.
5. **Personal by design.** Users pick the theme, font, corner shape and progress-visual style
   from **live preview cards**, not plain lists. The whole app re-themes instantly.
6. **Friendly, plain copy.** Short, verb-led, a little playful, never technical. Errors
   reassure and say what to do next.

---

## 2. Design tokens

### Spacing (4-pt base)
| Token | px | Typical use |
|---|---|---|
| `space1` | 4 | icon–text gap in pills |
| `space2` | 8 | tight gaps, chip spacing |
| `space3` | 12 | gaps between cards in a grid |
| `space4` | 16 | **page side padding**, card padding |
| `space5` | 24 | section top spacing |
| `space6` | 32 | big separations |
| `space7` | 48 | end-of-list breathing room |

Section header padding: `16 / 24 / 16 / 12` (left, top, right, bottom). Lists end with 48 px
of empty space (120 px if a floating bar sits on top).

### Corners (user-selectable)
A single `base` radius drives everything:

| Corner style | base |
|---|---|
| Sharp | 6 |
| **Soft (default)** | 14 |
| Round | 24 |

`radiusSm = base × 0.6`, `radiusMd = base`, `radiusLg = base × 1.6` (bottom sheets, hero
cards). Pills and progress bars are always fully round (`99`).

### Motion
| Token | Duration | Notes |
|---|---|---|
| `fast` | 180 ms | presses, toggles, small fades |
| `medium` | 320 ms | tab switches, cards appearing |
| `slow` | 600 ms | page changes, hero transitions |

Default curve is `easeOutCubic`. Use `easeOutBack` for things that pop in (check marks,
selection bar, art), `elasticOut` for "hello" moments (logo, empty-state icons) and
`easeInOutCubic` for page swipes and loading bars. With **reduce motion** on, all three
durations become 0.

### Depth (no elevation, only soft shadows)
| Element | Shadow |
|---|---|
| Glass card | shadow color @ 8%, blur 18, offset (0, 6) |
| Primary gradient button | liquidA @ 35%, blur 24, offset (0, 8) |
| Floating selection bar | shadow color @ 30%, blur 24, offset (0, 10) |

Cards have elevation 0. Surfaces get no surface tint.

### Typography
- One Google Font family for the whole app, chosen by the user: **Quicksand (default)**,
  Outfit, Inter, Space Grotesk, Nunito, Poppins, Manrope, DM Sans, Lexend, Rubik, Sora,
  Fredoka, Comfortaa.
- The standard Material 3 type scale, with **heavy headings**:
  - screen titles `headlineSmall` w800
  - section headers `titleLarge` w700
  - splash wordmark `displaySmall` w800
  - big numbers (progress %) w800 with **tabular figures**, so digits don't jump
- Secondary text uses the `onSurfaceVariant` role, never a hand-picked grey.

### Icons
Rounded icon set everywhere (`*_rounded`). Use the outlined variant for unselected
navigation items. Sizes: 20 (buttons, tiles), 18 (chips, inline actions), 12 (inside pills),
64 (empty states).

---

## 3. Color

### Roles every theme defines
`primary`, `secondary`, `tertiary`, `background`, `surface`, `liquidA`, `liquidB`,
`success`, `danger`, `warning`, plus brightness (dark/light).

Derived, never hand-picked:
- **Containers** = the role color at 22% alpha over `surface`.
- **Glass fill** = "ink" at 4% (dark) / 2% (light) over `surface`. Ink is white on dark
  themes and black on light ones.
- **Glass border** = ink at 8% (dark) / 7% (light), 1 px.
- **Liquid gradient** = `liquidA → liquidB`, top-left to bottom-right.
- **Text on the gradient** = black or white, picked from the gradient's estimated brightness.

### Presets
Squishy ships **44 palettes** (28 dark, 16 light), a **Follow system** option and a
**Custom** theme. Many follow well-known editor color schemes that are proven for long
reading sessions: Dracula, Nord, Gruvbox, Solarized, Catppuccin, Tokyo Night, One Dark,
Monokai, Rosé Pine, Everforest, Kanagawa, Ayu, Night Owl, Palenight, Cobalt, Poimandres and
GitHub. The full list is in `lib/app/theme_presets.dart`. Dark themes use Tailwind-400-like
shades; light themes use 600–700 shades for contrast. The five originals:

| Theme | Mode | Primary | Secondary | Tertiary | Background | Surface | Liquid A → B | Success / Danger / Warning |
|---|---|---|---|---|---|---|---|---|
| **Obsidian Cyan** (default) | dark | `#22D3EE` | `#818CF8` | `#2DD4BF` | `#07090D` | `#10141B` | `#06B6D4 → #5EEAD4` | `#34D399` / `#FB7185` / `#FBBF24` |
| Midnight Violet | dark | `#A78BFA` | `#F472B6` | `#60A5FA` | `#0B0820` | `#161233` | `#8B5CF6 → #F472B6` | `#4ADE80` / `#FB7185` / `#FCD34D` |
| Sunset Coral | dark | `#FB923C` | `#F43F5E` | `#FACC15` | `#140B0C` | `#221416` | `#F97316 → #FDE047` | `#86EFAC` / `#FF6B81` / `#FDE68A` |
| Ocean Light | light | `#0369A1` | `#6366F1` | `#0EA5E9` | `#F6F8FB` | `#FFFFFF` | `#0284C7 → #38BDF8` | `#059669` / `#E11D48` / `#D97706` |
| Mint Fresh | light | `#0F766E` | `#65A30D` | `#14B8A6` | `#F2FBF8` | `#FFFFFF` | `#14B8A6 → #86EFAC` | `#16A34A` / `#DC2626` / `#CA8A04` |
| Follow system | auto | Obsidian at night, Ocean by day | | | | | | |

Brand/mascot colors (separate from themes): cyan `#7DF9FF` → purple `#8B5CF6` blob,
face `#1B1035`, cheeks `#FF8FB1`. Launcher/splash background is a deep night `#0B0820`.
Third-party brand colors (e.g. WhatsApp `#25D366`, Gmail `#EA4335`) are allowed only on
their own share buttons.

**Custom theme**: the user picks dark or light, a main color and an accent color from a
swatch grid. Everything else is derived: a background tinted 5% with the main color, a
surface tinted 9% (dark) or white (light), the tertiary color as a mix of main and accent,
and standard status colors. Prefer this over letting people pick a color per element (menus,
borders...): free per-element picking makes it far too easy to end up with unreadable text.

**Readability guard**: before a palette becomes a theme, every color that's also used for
text (primary, secondary, tertiary, success, danger, warning) is nudged toward white (dark
themes) or black (light themes) until it reaches a 4.5:1 contrast with the surface.

### Rules
- Raw colors only in the palette file. Anything else reads theme roles or tokens.
  Allowed exceptions: pure white/black as "ink", `transparent`, and white text on a dark
  scrim over images.
- Each preset has a fixed brightness. Picking a theme picks dark or light.
- Status meaning is always the semantic role (`success`/`danger`/`warning`), never "green".

---

## 4. Components

- **Glass card**: the default container for almost everything (settings groups, stats,
  list items). Glass fill, 1 px glass border, `radiusMd`, 16 padding, glass-card shadow,
  ripple on tap.
- **Gradient button**: the one primary action per screen ("Start squishing"). Liquid
  gradient fill, gradient shadow, auto-contrast label. On press it **squishes** to 0.96
  scale (`fast`, `easeOutBack`). When disabled it drops to 45% opacity.
- **Secondary actions**: filled-tonal or text buttons. Dialogs have a text button for the
  safe choice and a filled button for the action ("Keep going" / "Cancel all").
- **Pill**: a tiny status tag. Role color at 14% alpha fill, `labelSmall` w700, optional
  12 px icon, fully round.
- **Section header**: `titleLarge` w700 plus an optional trailing action.
- **Navigation**: Material 3 bottom navigation bar, 5 destinations max, label shown only on
  the selected tab, indicator at 18% opacity, same color as `surface`. Badge counts use liquidA.
- **App bar**: a collapsing large title (about 110 px expanded) with the brand mark leading.
- **Bottom sheets**: drag handle, scroll-controlled, safe-area aware, `radiusLg` corners.
- **Floating selection bar**: appears when items are selected, slides up from below with
  `easeOutBack`, shows the count, total size and a gradient action.
- **Empty states**: 64 px rounded icon that pops in (`elasticOut`, 0.6 → 1), a short title
  and one helpful sentence that says what to do.
- **Inputs**: filled, outline style, no border until focused.
- **Charts**: horizontal grid lines only (onSurface @ 6%), liquid-gradient strokes,
  area fill fading from liquidB @ 45% to transparent, tooltips on `inverseSurface`.
- **Thumbnails/loading**: shimmer placeholders (1.2 s loop), never spinners for content
  that has a known shape.

### The hero visual
Every app gets **one signature animated visual** for its main state. In Squishy that's
progress, shown as any of 21 styles (water tank, liquid orb, glow ring, equalizer, battery,
thermometer, blob, dot grid, spiral, hourglass, orbit, radar, ripple, constellation, clock,
bloom, waveform, minimal bar, confetti, staircase, scribble) that the user can switch
between. Guidelines:
- Drawn in code (CustomPainter/canvas), liquid gradient, a soft outer glow.
- An ambient loop (~6 s) keeps it alive. The real value **eases toward** new readings over
  700 ms, so jumpy backend updates look smooth.
- Tap it to cycle through styles (scale 0.85 → 1 with `easeOutBack`, plus fade).
- Isolated in a repaint boundary. It freezes when reduce motion is on.

### Ambient background
Two large, very soft radial "orbs" in liquidA and liquidB (around 22% alpha, 340–380 px)
drift 30–40 px on slow 7 s and 9 s loops behind content. They're static when reduce motion is on.

---

## 5. Motion patterns

- **Lists**: items fade in with a stagger of 20–25 ms × index (capped at 12–16 items) and a
  slight slide (4–5% of width) or scale (0.94–0.96 → 1).
- **Grids**: stagger 40–60 ms per item.
- **Tabs**: fade plus a tiny slide up (1.5%) over `medium`. Tabs keep their state.
- **Pages**: fade-forwards page transitions.
- **Selection**: check marks scale in with `easeOutBack`. Selected cards get a 1.6 px
  primary border and a 12% primary tint.
- **Splash** (about 2 s, once): logo scales 0.2 → 1 with `elasticOut`, wordmark letters
  stagger in (70 ms apart, slide up with `easeOutBack`), tagline fades in, a thin gradient
  bar fills, then the app scales in from 1.04 to 1.
- **Onboarding**: art pops in (0.85 → 1), title and body follow 120 ms and 220 ms later.
  Page dots grow from 8 to 28 px wide and fill with the gradient.
- **Mascot/brand mark**: an idle loop (squash, then a damped spring, and an occasional blink).
- **Reduce motion**: one switch ("Calmer transitions, static liquids") zeroes the duration
  tokens, freezes the hero and ambient loops, and **must also follow the system setting**
  (`MediaQuery.disableAnimations` / "remove animations"). Hardcoded one-off animations
  have to respect it too.

---

## 6. Personalization

Offer a **Style** tab where every option is a **live preview card**, split into tabs:
**Colors · Progress · Charts · Fonts · Layout**. Grids are built lazily (cards appear as
they scroll in) and the theme previews are cached, so even 40+ cards scroll smoothly.
- **Colors**: All / Dark / Light filter, then Custom (opens its editor), Follow system and
  every palette. Each card is a mini mock of the real UI in that theme. Three per row on
  a phone, name only (up to two lines).
- **Progress**: the hero visual styles.
- **Charts**: 15 styles over the same data. Trends (area, smooth line, straight line with
  dots, steps, running total, bubbles), bars (bars, capsules on a track, sideways bars,
  videos per day), a calendar heatmap, and quality breakdowns (donut, pie, half-ring gauge,
  radar).
- **Fonts**: 13 Google Fonts, previewed as "Aa".
- **Layout**: list/grid view mode, corner shape, reduce-motion switch.

Changes apply app-wide instantly. Default choices: Obsidian Cyan, water tank, area chart,
grid view, Quicksand, Soft corners.

---

## 7. Layout

- Phone-first, edge-to-edge. Page side padding is 16.
- Grids compute their column count from width: about 130 px per tile for thumbnails
  (2–6 columns, aspect 0.78), 190 px for option cards, 380 px for big 16:9 cards (1–3).
- At **600 px or wider** (tablets, landscape): stats go from 2 to 4 columns, and the main
  screen becomes two panes (hero visual left, list right).
- Four content view modes for collections: grid, big cards, list (104×60 thumbnail) and
  compact (names only).

---

## 8. Copy and formatting

**Voice**: friendly, short and verb-led, with one playful brand verb used consistently
(Squishy's is "squish": "Start squishing", "Squish 3 videos", "Squishing…", "All done!").
Section titles are inviting ("Make it yours").

**Empty states** say what will appear and how to get it:
"Nothing squishing. Pick some videos in Files and they will show up here with live progress."

**Errors** are plain and reassuring, and say what's safe: "Can't open this folder",
"This file was moved or deleted", "Cancel everything? Originals are never touched when
cancelling." Confirmations name both choices ("Keep going" / "Cancel all"), never "OK / Cancel".

**Numbers**:
- Sizes in 1024-based units, 1 decimal under 100 ("12.3 MB"), none at 100 and above ("245 MB").
- Durations as `m:ss` / `h:mm:ss`. Dates as `2 Nov 2026, 14:05`.
- Time left as "42s left", "3 min left", "1 h 5 min left".
- Use real typographic symbols: `≈` estimates, `→` before/after, `−34%` (a true minus),
  ` · ` as a separator and `…` for ongoing states.

---

## 9. Accessibility (non-negotiable)

- Contrast: light themes use darker 600–700 shades. Text on gradients picks black or white
  automatically. Text over animated visuals gets a subtle surface-colored halo.
- Tabular figures for any number that updates live.
- Every icon-only button has a tooltip/label. Add semantics labels to custom-drawn visuals
  (e.g. "Progress 42%").
- Respect the system text scale. Layouts must not clip at 1.3×.
- Respect the system's reduce-motion setting as well as the in-app switch.
- Light haptics (selection click) on toggles, selection and completion are welcome. Keep
  them subtle.

---

## 10. Checklist for a new screen

- [ ] Uses only tokens and theme roles. No raw hex, no magic numbers.
- [ ] One primary action with the liquid gradient. Everything else is quieter.
- [ ] Content sits in glass cards with 16 padding and `radiusMd`.
- [ ] Lists/grids stagger in. Presses squish. Durations come from tokens.
- [ ] Looks right in a dark and a light theme (try Graphite and Paper), all three corner
  styles and a wide font like Lexend.
- [ ] Works with reduce motion (in-app and system) and at 1.3× text.
- [ ] Has a friendly empty state and plain-language errors.
- [ ] Two-pane or more columns at 600 px and wider.

### Flutter implementation notes
- Stack: `flex_color_scheme` (Material 3) + `google_fonts` + `flutter_animate`.
- Build the theme from the preset: `FlexThemeData.dark/light(colors: FlexSchemeColor(...),
  surfaceMode: levelSurfacesLowScaffold, blendLevel: 6 dark / 4 light,
  subThemesData: FlexSubThemesData(defaultRadius: base, blendOnLevel: 12,
  inputDecoratorIsFilled: true, inputDecoratorBorderType: outline,
  inputDecoratorUnfocusedHasBorder: false, navigationBarIndicatorOpacity: 0.18,
  navigationBarLabelBehavior: onlyShowSelected, bottomSheetRadius: base * 1.6,
  cardElevation: 0, chipRadius: base))`. Then set `surface`, `scaffoldBackgroundColor` and
  the navigation bar color from the preset, with `surfaceTintColor: transparent`.
- Put the tokens (spacing, radii, durations, liquid colors, glass, semantic colors) in a
  `ThemeExtension` and read them via `context.tokens`, `context.colors`, `context.text`.
