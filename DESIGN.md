---
version: alpha
name: "Chanting"
description: "An offline Thai–Pali prayer book shaped like a softly illuminated devotional volume."
colors:
  primary: "#5F3C1B"
  on-primary: "#FFFCF5"
  accent: "#E49A12"
  accent-dark: "#B96F00"
  background: "#FFF9EE"
  surface: "#FFFCF5"
  surface-muted: "#FFF3D9"
  accent-soft: "#FFE8B9"
  border: "#F1C26B"
  text: "#442B16"
  text-muted: "#866746"
  toast-success: "#4E9A3F"
  toast-info: "#2F7BDD"
  toast-warning: "#E49A12"
  toast-error: "#D63A32"
typography:
  display:
    fontFamily: "Sarabun, sans-serif"
  body:
    fontFamily: "Sarabun, sans-serif"
  reading:
    fontFamily: "Pridi, serif"
rounded:
  control: "0.75rem"
  card: "1.125rem"
  hero: "1.5rem"
  pill: "999px"
spacing:
  page-edge: "1rem"
  section-gap: "1.5rem"
  card-gap: "0.75rem"
components:
  home-hero:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.text}"
  home-supporting-text:
    textColor: "{colors.text-muted}"
  home-decoration:
    backgroundColor: "{colors.accent-soft}"
  bottom-navigation:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
  navigation-selected-indicator:
    backgroundColor: "{colors.accent}"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
  card-outline:
    backgroundColor: "{colors.border}"
  button:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.text}"
  button-pressed:
    backgroundColor: "{colors.accent-dark}"
  search:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
---

# Chanting Design System

## Overview

### Creative North Star

The interface should feel like opening a contemporary Thai prayer book under warm morning light: ivory paper, fine amber rules, restrained lotus symbolism, and generous quiet space. It must remain a practical daily tool rather than an ornate ceremonial poster.

### Product context and register

- **Audience and primary job:** Thai and English readers who need to find, arrange, and chant bundled prayers without a network connection.
- **Target market and evidence:** Thai-first, cross-platform distribution; `docs/product/features.md` and `docs/internationalization.md` define Thai as the default while supporting an English UI and edition.
- **Locale and language policy:** Thai and English UI; Thai is the fallback. All owned labels live in ARB localization files.
- **Usage scene:** Frequent phone use, often early or late in the day, with calm scanning and large touch targets. Tablet and desktop layouts are width-capped.
- **Register:** Product UI with a devotional brand layer.
- **Memorable signature:** Layered amber light and soft paper shadows across the Home dashboard, with Thai corner flourishes framing the head of a page.
- **Restraint:** Reading, search, settings, dialogs, and data-heavy editor surfaces prioritize legibility and familiar platform behavior.
- **Anti-references:** Avoid temple-tourism pastiche, heavy gradients on every surface, glossy gold text, generic finance-dashboard statistics, and decoration that competes with prayer text.
- **Token ownership/runtime mapping:** Runtime Flutter tokens remain canonical in `lib/theme/app_colors.dart` and `lib/theme/app_theme.dart`. This file mirrors accepted values and explains their use; shared Material themes and Home components are the consumers.

## Colors

`background` is the continuous paper field, while `surface` and `surface-muted` separate cards and inputs without grey. `accent` is reserved for primary devotional actions, icons, progress, and selected state. `primary` and `text` carry readable brown hierarchy. Fine borders use `border`; disabled and secondary copy use `text-muted`. Dark mode keeps the same semantic roles through the existing dark runtime palette rather than reusing light hex values. The four `toast-*` colours exist only to say what a message reports (done, neutral, needs something first, failed); they tint a toast and its glyph and are not used for anything else.

## Typography

Sarabun sets the whole interface: headings, body copy, controls, numbers, and compact labels. Pridi, the Thai serif, is reserved for the reading screen — the prayer title and that screen's own bar — so the page that renders scripture reads as a prayer book while the chrome around it reads as an app; reach it through `AppTheme.serif`, never through the theme. Both are bundled so the offline contract is preserved. Thai text receives natural line height and is never artificially letter-spaced; English utility labels may use modest tracking only when casing remains readable.

## Layout

Phone pages use a 16 px edge and a 12 px card gap. Home is a vertical dashboard: identity header, one hero carrying today's goal, compact shortcuts, and continuity content. Prayer search belongs to the dedicated Prayers destination, while personal sets belong to Library; Home does not duplicate either destination. Content is width-capped at one of three widths (`ContentWidth`): 800 px for every page that is a list of cards or rows, 700 px for the reader, and 440 px for a page built as one centred composition (the meditation timer, sharing). Important touch targets are at least 44 px, content reserves safe-area space, and long localized labels may wrap without hiding actions.

## Elevation & Depth

Hierarchy comes from warm tonal layers, fine amber borders, white inner highlights, and two-part shadows: a broad amber glow plus a short neutral contact shadow. The Home hero, shortcut tiles, continuity card, recommendation, and central Start action all use this illuminated treatment at progressively smaller strength. Search suggestions and dialogs use Material elevation where depth communicates stacking; a toast casts the same soft warm shadow as a raised control.

## Shapes

Cards use 18 px corners, the home hero uses 24 px, controls use 12 px, and primary actions use a full pill. Circular icon wells are reserved for identity and high-salience actions. Strokes stay fine and warm rather than dark and heavy.

## Components

### Foundational visual states

Default surfaces retain readable brown-on-ivory contrast. Pressed state uses Material ink; keyboard focus uses the semantic primary color. Disabled controls keep their geometry and reduce emphasis. Loading is one picture everywhere — a watercolour lotus on rippling water, a line of text and three gold dots — drawn by `LoadingIndicator` in the app and by the web splash before it, from the same file. Errors and empty results keep the existing localized recovery behavior.

### Buttons and actions

One solid amber pill is the primary action in a decision area. Secondary navigation uses bordered cards or icon buttons with text labels where meaning is not universal. Busy and disabled states must not change button dimensions. Controls on an app bar come from one place (`app_back_button.dart`): a 40 px circle for a bare icon — back, search, favourites — and the same face stretched into a pill for a word such as Skip or Reset.

### Navigation and data display

Home shortcuts are compact, equal-height actions: the user's pins (the morning and evening services by default), then the meditation timer and loving-kindness. The separate “View all” action owns category discovery, while the Prayers bottom destination owns the full searchable directory. Five primary destinations share a persistent bottom bar, with the central amber “Start” action elevated in a circular devotional mark. The bar remains outside immersive prayer-reading and editing routes. Navigation destinations and route behavior remain owned by `app_router.dart`. Counts describe actual stored data: the goal ring is minutes practised today against the goal the user set, nothing estimated.

### Forms and overlays

Search uses the canonical Material `SearchBar` in the Prayers destination, including a localized clear action and the existing recent-search overlay. Dialogs, fields, menus, and empty/loading surfaces continue to use shared application themes and widgets. Stock Material controls — switches, radios, sliders, text and outlined buttons, bottom sheets — are coloured centrally in `app_theme.dart`, so none appears in Material's own palette.

A short message is a toast (`appToast`): a floating pill tinted by one of the `toast-*` colours, with a round glyph, a faint lotus, a hairline border and a close button; an action such as Undo sits before the close button. It replaces the dark SnackBar bar everywhere.

A time or a duration is chosen on scroll wheels — hours and minutes side by side behind one selection band — never on Material's clock face or a bare number field. A count with a wide range, such as the mala target, stays a typed field.

### Iconography

Material Symbols are the canonical functional family, normally outlined and amber with a restrained radial glow and cast shadow on Home. Derived transparent lotus, open-book, and Thai-corner artwork in `assets/images/` (one folder per feature, plus `shared/`) supplies the devotional identity; its source artwork remains in `design/mobile/`. Thai floral corners frame the head of a page that has an identity of its own — Home, the settings hub, the meditation timer, the prayer-set pages — and never sit inside a card; the Hero's lower-right watermark is lotus artwork, never the corner flourish. Every asset image uses the shared `AppAssetImage` owner, whose fallback is the supplied `image_not_found.png`. Icons that are not universally understood retain localized tooltips or adjacent labels.

### Meditation reference treatment

The setup and active session use the supplied Serene meditation references:
centered Sarabun headings, Thai floral corners at the top of the page, lotus-cloud
ornaments flanking the timer, and a larger circular pause control. `GoldRing` owns
the opt-in `illuminated` treatment (fine inner/outer amber rules and a softly lit
track); other consumers retain their existing appearance. Colors continue to come
from `AppColors`, the Material scheme, and `DashboardTokens`. Duration presets, the
custom duration wheels and the signal choices remain owned by the meditation
screen and its localized dialogs. A sitting may play one of four bundled nature
sounds, and its minutes count toward the daily goal. Meditation history is not
implemented and must not appear as a working control or fabricated progress.

### Motion

Motion communicates navigation or state in 200–300 ms and respects platform reduced-motion settings. Routine dashboard content does not animate independently; the loader's rippling lotus and its three dots are the one standing animation, and it is gone the moment content arrives.

### Content and data visualization

Copy is calm, direct, and action-led in each locale. Practice counts are truthful minutes computed from local history; the app keeps no streak. Amber progress is always paired with text, never the sole carrier of meaning.

## Do's and Don'ts

- **Do:** Use warm light, fine rules, and one deliberate devotional motif to support calm daily practice.
- **Do:** Pair every Home elevation with an amber atmospheric glow and a smaller contact shadow; keep the strength proportional to importance.
- **Do:** Preserve offline behavior, localized labels, truthful counts, and the existing route/state owners.
- **Don't:** Turn every card into a glowing gold hero or add ornamental detail behind long reading text.
- **Don't:** Reuse the Thai corner flourish as an in-card watermark or silently leave an unavailable image blank.
- **Don't:** Copy unimplemented features — profiles, history, statistics — from a visual reference as false affordances.
- **Don't:** Style a stock control in place or raise a bare `SnackBar`; the theme and `appToast` already own both.
