# Design: the full token vocabulary

**Status: steps 1 to 3 are built. The owner decided the open trade-offs: a value a set does not fill keeps OpenProject's own value, nothing is derived. The sections below say what is built.**

The plugin knows eighteen values per design system. thematiq knows many more. This page says how the plugin grows to thematiq's full vocabulary without breaking what works today.

Read from thematiq `development` in a local clone on 12 October 2026: `css/tokens/`, `css/systems/` and `docs/reference/tokens.md`. Nothing here was tried in a browser.

## How thematiq's tokens are built

thematiq has three layers.

1. **A token file per design system**, in `css/tokens/`. There are 65. Each one writes CSS variables in one shared namespace, `--nldesign-*`.
2. **A bundle per family of design systems**, in `css/systems/`: `nldesign`, `lasuite`, `summer-breeze` and `high-contrast`. A bundle maps the tokens onto Nextcloud's variables and elements.
3. **Nextcloud**, which draws the page.

Across the 65 files there are 161 different token names. By group:

| Group | Different names, roughly | What it holds |
|---|---|---|
| `color-*` | 60 | Primary, action, header, text, link, status colours, borders, backgrounds, focus, navigation |
| `border-radius-*` | 5 | Small, base, large, rounded, pill |
| `font-*` | 3 | Family, heading family, sizes |
| `header-*`, `logo-*`, `emblem-*`, `size-*` | 15 | Header icon filter, logo address, logo filter, the ribbon behind a logo and its sizes |
| `component-*` | 24 | Table header, navigation item, status badges, headings, content card |
| `website-*` | 45 | Sizes and colours for public web pages: page width, hero, steps, notices, tabs |
| `brand-*`, `hero-*`, `login-*` | 10 | Brand colours, hero area, login page |

Most sets write far fewer than 161. Zuiddrecht, a full example, writes 126. Many names are optional, and thematiq is strict about that: a set that leaves an optional token out renders as before.

The eighteen roles the plugin has today are a summary that thematiq makes of these tokens for the shared shell.

## How the set file grows

Today:

```json
{ "id": "zuiddrecht", "name": "Gemeente Zuiddrecht", "tokens": { "primary": "#3669a5" }, "logo": {} }
```

Proposed: the eighteen roles stay exactly where they are, and the full vocabulary comes beside them.

```json
{
  "id": "zuiddrecht",
  "name": "Gemeente Zuiddrecht",
  "tokens": { "primary": "#3669a5" },
  "vocabulary": { "color-error": "#d52b1e", "component-table-header-background-color": "#f5f6f8" },
  "dark": {},
  "logo": {}
}
```

Rules:

- **`tokens` does not change.** A file exported today imports tomorrow, and a set without `vocabulary` works as it does now.
- **`vocabulary` is optional and flat.** Its keys are thematiq's names without the `--nldesign-` prefix. One list in the plugin says which keys exist and what kind of value each takes.
- **An unknown key in `vocabulary` is skipped in the catalogue and refuses an import**, as with `tokens` today.
- **A value has one home.** The seventeen thematiq names that are roles (`color-primary`, `border-radius`, `font-family` and the rest, `Vocabulary::ROLE_NAMES`) stay in `tokens` under the role's name. A file that names one of them in `vocabulary` is refused.
- **Nothing is derived.** Where `vocabulary` is silent, OpenProject keeps its own value. A set without `vocabulary` looks exactly as it did.
- **New kinds of value.** Today there are three: colour, length, font stack. The vocabulary adds a wide length (`size`, up to 9999px), font weight, a plain number, a duration, a length or `auto` (`offset`), three channels for `rgba()` (`rgb_triplet`), a CSS filter, a border and a text transform. Each has its own allow-list in the validator. The filter is the risky one and gets the tightest check: at most six functions from a fixed list, each with one plain number, rebuilt from what was parsed. No thematiq token holds a shadow, so there is no shadow kind.
- **Never an address.** `logo-url`, `brand-stripe-image`, `brand-stripe-image-inverse`, `hero-decoration-image` and `login-watermark-image` stay out of `vocabulary`. A logo is a file in the plugin, as now. `hero-image-clip-path` stays out too: it is a shape with `calc()`.

## What is built

`lib/open_project/thematiq/tokens/vocabulary.rb` holds the list: 185 keys, read from thematiq's `css/tokens/` (light and dark files) on 13 October 2026, each with its kind. `Vocabulary::DRAWN` names the keys the plugin draws. Every other key is carried: it is kept, exported, imported and written to Figma files, and it changes no pixel.

| Where | What it does with `vocabulary` |
|---|---|
| `TokenSet` | Keeps the block, each value through the validator of its kind. A bad value is left out and named in `rejected`. In strict mode, for an import, an unknown key, a role name or a bad value refuses the file |
| `Catalogue` | Reads the block of a bundled set the same way. The bundled catalogue has none yet: that is step 9 |
| `CustomDraft`, `Store` | A custom design system keeps the vocabulary values that differ from its base, stored as `vocabulary` beside `overrides` |
| `Transfer` | Export writes the block only when a set has one, so a set without one exports byte for byte as before. `test/fixtures/transfer/` holds a file exported before the vocabulary existed, and a test imports it |

### What is drawn

`Variables::Generator` writes a vocabulary value only when the set fills it, and only in the light theme. The dark and high contrast themes keep OpenProject's own values. Where a variable can take two keys, the first one the set fills wins. A filled key wins over what the roles write for the same variable.

| Keys | Variables | Where it shows |
|---|---|---|
| `component-status-badge-error-color`, else `color-error` | `--fgColor-danger` | Error text, the icon of an error banner, form errors |
| `color-error` | `--bgColor-danger-emphasis`, `--borderColor-danger-emphasis` | Error fills and strong error borders |
| `component-status-badge-error-background-color` | `--bgColor-danger-muted` | Light error backgrounds |
| The same three for `warning` and `success` | `--fgColor-attention`, `--bgColor-attention-*`, `--borderColor-attention-emphasis`, `--fgColor-success`, `--bgColor-success-*`, `--borderColor-success-emphasis` | Warnings and success messages, labels |
| `component-status-badge-info-background-color` | `--bgColor-accent-muted` | Light information backgrounds |

| `color-text-light` | `--fgColor-onEmphasis` | Text on coloured fills: labels, status fills |
| `component-separator-border-color` | `--borderColor-muted` | Separators and quiet lines |
| `color-focus-rgb` as `rgb()`, else `color-focus` when it is opaque | `--focus-outlineColor` | The focus ring of Primer controls. thematiq's `color-focus` is often 50% see-through, which a ring must not be |
| `border-radius-small`, `border-radius-pill` | `--borderRadius-small`, `--borderRadius-full` | Small corners, and pills such as counters and labels. `border-radius-rounded` has no Primer step and is carried |

`color-info` and the info badge's text colour are carried, not drawn: Primer's accent scale is the link and the primary colour here.

## What each group would drive in OpenProject

| Group | Primer variables and OpenProject classes | How sure |
|---|---|---|
| Status colours: error, warning, success, info | `--fgColor-danger`, `--bgColor-danger-muted`, `--borderColor-danger-emphasis` and the same for attention, success and accent. They colour banners, flash messages, form errors and labels | High. These are plain Primer variables |
| Link, hover, visited | `--fgColor-link`, `--fgColor-accent`. OpenProject forces `--fgColor-link` to its `--accent-color` with `!important`, so the plugin sets `--accent-color` | High for normal and hover. Visited has no variable; it needs a rule on `a:visited` |
| Text: default, muted, on dark | `--fgColor-default`, `--fgColor-muted`, `--fgColor-onEmphasis` | High |
| Borders and backgrounds | `--borderColor-default`, `--borderColor-muted`, `--bgColor-muted`, `--bgColor-inset`, `--control-transparent-bgColor-hover` | High |
| Focus | `--focus-outlineColor`. Primer draws the ring itself | High |
| Buttons | `--button-primary-*`, `--button-default-*`. OpenProject forces several from its own `--button--primary-*` variables with `!important`, so the plugin sets those | High, already done for the main ones |
| Radius: five steps | `--borderRadius-small`, `-medium`, `-large`, `-full` | High |
| Header: background, text, icon filter | `--header-bg-color`, `--header-item-font-color`. Icons in the header are SVG that follow the text colour, so the filter is not needed | High. Text on the header gets a contrast rule in place of the filter |
| Navigation: background, active background, active text, badge | `--main-menu-bg-color`, `--main-menu-bg-selected-background`, `--main-menu-selected-font-color`, and the shell's own menu classes | Medium. The project menu is the shell's markup and is still changing |
| Table header | `table.work-package-table thead th`, `.generic-table thead th`, and Primer's `Box` tables on newer pages | Medium. Two table systems live side by side in OpenProject |
| Status badges | Primer `Label` variants. Work package status and type colours are data in OpenProject, set per status by an administrator, and are not tokens | Medium for labels. Status and type colours cannot be driven |
| Headings: six sizes and a heading font | `--text-title-size-large`, `-medium`, `-small` and `h1` to `h6` in the content area, the page header title | Medium. OpenProject has three title sizes, thematiq six |
| Content card | Primer `Box` and `BorderBox`: `--bgColor-default`, `--borderColor-default`, `--shadow-resting-small` | Medium |
| Font sizes and weights | `--text-body-size-medium`, `--base-text-weight-semibold` | Medium. A larger body size moves every layout and needs the pixel check |
| Logo ribbon, emblem | The shell's top bar markup | Low until the shell lane adds a place for it |
| Login page | The sign in page uses the normal layout, so the same variables reach it. thematiq's login image and bar have no counterpart | Low |

## What cannot be reached

- **`website-*`, `hero-*` and most of `brand-*`: about 55 names.** They style public web pages that thematiq and its sister apps draw. OpenProject has no such pages. The plugin can carry them through export and import so nothing is lost, and draws nothing with them.
- **Work package status, type and priority colours.** They are records in OpenProject's database.
- **E-mail and PDF exports.** No head hook reaches e-mail. PDF styling waits on the upstream request.
- **The rich text editor's inside.** It takes a short list of its own variables, which OpenProject maps for dark mode only.
- **The Angular parts with fixed colours.** Gantt bars, the calendar and the board cards have colours in their own stylesheets. Each needs a look in the browser before anything is promised.

## Build order

Each step is one pull request. Each ends with a live look, because every one of them changes pixels.

1. **The list.** One Ruby file that names every vocabulary key, its kind, and the eighteen-role value it falls back to. Tests only. Nothing on the page changes.
2. **The validator's new kinds.** Font weight, font size, number, shadow, filter. Tests with hostile values, as today.
3. **The set shape.** `vocabulary` in the token set, the catalogue loader, export and import. Old files keep working; a test proves it with a file exported today.
4. **Status colours.** The first group on the page: banners, flash messages, form errors. Small and easy to see.
5. **Text, borders, backgrounds, focus, the five radii.** The variables are known; this mostly replaces derived values with real ones.
6. **Table header and content card.**
7. **Navigation and badges**, together with the shell lane, once its menu markup is settled.
8. **Headings and font sizes.** Last of the visible ones, because they move layouts. Needs the pixel-diff check in place.
9. **The catalogue with `vocabulary`.** The thematiq lane generates it; the plugin vendors it. Until then every set runs on derived values, exactly as now.
10. **The editor.** Groups in place of one long form, with the eighteen roles as "simple" and the vocabulary as "advanced".

Steps 1 to 3 change no pixel and can be merged on tests. Steps 4 to 8 each need the container.

## The trade-offs

- **Flat keys with thematiq's names, or our own names.** This page chooses thematiq's names. It costs us names that say "nldesign" and "website" inside an OpenProject plugin. It saves a translation table that would drift, and it lets the same file serve both products.
- **Carry what we cannot draw, or drop it.** This page chooses to carry it. A set moved from Nextcloud to OpenProject and back must not lose its website tokens on the way.
- **Derive missing values, or leave OpenProject's.** Decided by the owner: leave OpenProject's. A set that does not name a status colour shows OpenProject's own.
- **Size of the editor.** 161 fields is not a form anyone fills in. Step 10 needs a design of its own.

Decided: steps 4 to 8 do not wait for the catalogue from thematiq. Until it comes, a set gets vocabulary values from an import, a Figma file or the editor.
