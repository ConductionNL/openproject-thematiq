# OpenProject twin: shell and primitives canon

The contract for every `Op*` board. Geometry is measured from our Nextcloud boards (`DqKop`, `AppZijbalk`, `DqZijbalk`, `DqPostvak`, `DqTaak`, `DqBerichtVersturen`). Colour, type and radius come from the active design system through `var(--sc-*)`: under `?ds=openproject` the Cunningham example theme sets them. Use the literals from `token-rules.md` and nothing near them. Where the measured OpenProject size differs (header 55 px, row 40 px, button 34 px, nav 245 px), our Nextcloud size wins, because both products must be identical. On 15 October 2026 the owner decided again that OpenProject follows Nextcloud (Zuiddrecht) where they differ: the primary button became 48 px (was 40), the table row 44 px (was 48) and body text 15 px (was 14).

## Top bar (`OpHeader.dc.html`, measured from `DqKop.dc.html`)

| part | value |
|---|---|
| height | 68 px, full width, `background: #3669a5` (primary), white ink, no bottom border |
| brand block | 237 px wide, logo `data-sc-logo="logo-wit"` 26 px high, 1 px divider, app name 18 px weight 700 |
| app switcher | 40 x 40 button, grid icon 20 px, `aria-label="All apps"`, popover 640 px wide at left 160 px, top 70 px |
| search | `flex: 0 1 560px`, 44 px high, padding 0 14px 0 42px, 1 px white border, `background: rgba(255,255,255,0.12)`, radius `var(--sc-radius-lg, 10px)`, 15 px text |
| icon buttons | 44 x 44, icon 22 px, radius `var(--sc-radius, 8px)`; notification badge 9 px dot `#cc0000` with 2 px white ring |
| account | 48 px high button, avatar 38 px round `#ffffff` on `#234a78`, name 15 px weight 700, role 13 px, chevron 16 px |

## Navigation (`OpNav.dc.html`, measured from `AppZijbalk.dc.html` and `DqZijbalk.dc.html`)

| part | value |
|---|---|
| width | 264 px (`flex: 0 0 264px` in the board), `background: #ffffff`, `border-right: 1px solid #e4e6ea`, padding 20px 14px, column gap 20 px |
| primary action | first in the column, 42 px high, radius `var(--sc-radius, 8px)`, `background: var(--sc-action, #3669a5)`, 1 px border `var(--sc-action-deep, #234a78)`, 15 px weight 600, icon 18 px |
| project switcher | second, min-height 44 px, padding 4px 10px, `background: #f5f6f8`, 28 px square initials on `#234a78`, label 12 px `#5e6168` over name 14 px weight 600, chevron 16 px |
| item | min-height 42 px, padding 0 10px, gap 12 px, radius `var(--sc-radius, 8px)`, 15 px weight 500, icon 20 px stroke 1.75 |
| active item | `background: #eaf0f7; color: #234a78; font-weight: 600`, `aria-current="page"` |
| group title | 12 px weight 600, uppercase, letter-spacing 0.06em, `#5e6168`, padding 0 10px 6px |
| count badge | 22 px high pill, min-width 22 px, 12 px weight 700, `#cc0000` on white only for counts that need attention; `#eaf0f7`/`#234a78` otherwise |

## Table (measured from `DqPostvak.dc.html`)

| part | value |
|---|---|
| frame | `background: #ffffff; border: 1px solid #e4e6ea; border-radius: var(--sc-radius-lg, 10px)`, overflow hidden |
| header row | `background: #fafbfc`, th padding 12px 16px, 14 px weight 600 `#5e6168`, line-height 20 px: 44 px high; sort caret 14 px `#c4c7cb` |
| row | td padding 12px 16px, 14 px line-height 20 px: 44 px high for one line, as Nextcloud; `border-top: 1px solid #eef0f3`; no zebra |
| row title | 15 px weight 600 `#1b1c1d`; secondary line 14 px `#5e6168` |
| selection | checkbox 18 px, `accent-color: #3669a5` |
| footer | padding 12px 16px, `border-top: 1px solid #eef0f3`, 14 px `#5e6168`, pagination 34 px |
| work package id | `color: var(--sc-link, #3669a5)`, weight 600 |

## Button (measured from `DqPostvak.dc.html` and `DqZijbalk.dc.html`)

| kind | value |
|---|---|
| primary (the one main action) | 48 px high, as Nextcloud, padding 0 14px, radius `var(--sc-radius, 8px)`, `background: var(--sc-action, #3669a5)`, border 1 px `var(--sc-action-deep, #234a78)`, white 14 px weight 600, icon 16 px |
| secondary | 40 px high, padding 0 14px, `border: 1px solid #c4c7cb; background: #ffffff; color: #1b1c1d`, 14 px weight 600 |
| compact (in a row) | 34 px high, otherwise secondary |
| icon only | 40 x 40, `aria-label`, icon 20 px |
| filter chip | 38 px high pill (`border-radius: 19px`), pressed: `background: #1b1c1d; color: #ffffff`; with a count pill 12 px |

## Input and select (measured from `DqPostvak.dc.html` and `DqBerichtVersturen.dc.html`)

| part | value |
|---|---|
| input | 40 px high, padding 0 12px, `border: 1px solid #c4c7cb`, radius `var(--sc-radius-lg, 10px)`, `background: #ffffff`, 15 px text (14 px in a toolbar) |
| search input | the same with a 18 px glass at left 12px and padding-left 38px |
| select | the same height and border, `appearance: none`, padding-right 36px, chevron 16 px at right 12px |
| label | 14 px weight 600, 6 px above the field |
| switch | 42 x 24, knob 18 px, on: `#3669a5` |
| radio | 18 px circle, `border: 1px solid #c4c7cb`, selected: 2 px ring `#3669a5` with a 8 px dot |
| textarea | the input with padding 9px 12px and a 21 px line, minimum three lines |

## Dialog (measured from `DqBerichtVersturen.dc.html`)

| part | value |
|---|---|
| panel | max-width 640 px, `background: #ffffff`, radius `var(--sc-radius-lg, 10px)`, shadow `0 16px 48px rgba(27,28,29,0.28)`, backdrop `rgba(27,28,29,0.45)` |
| header | padding 20px 24px, eyebrow 13 px uppercase `#234a78`, title 20 px weight 700 |
| body | padding 0 24px 8px, fields 16 px apart |
| footer | padding 16px 24px, `border-top: 1px solid #eef0f3`, buttons right, cancel secondary then primary |

## Tabs (measured from `DqTaak.dc.html`)

| part | value |
|---|---|
| tab | min-height 34 px, padding 8px 12px, 14 px, `border: 1px solid #c4c7cb; border-bottom: none`, radius `var(--sc-radius, 8px) var(--sc-radius, 8px) 0 0`, `background: #eef0f3`, margin-bottom -1px |
| active tab | `background: #ffffff; border-bottom: 1px solid #ffffff; font-weight: 700`, `aria-selected="true"` |
| strip | `border-bottom: 1px solid #c4c7cb`, gap 4 px, panel below on white |

## Badge, status and type (from `DqPostvak.dc.html` and `token-rules.md`)

| part | value |
|---|---|
| badge (chip) | padding 3px 10px, radius `var(--sc-radius, 8px)`, 13 px weight 600, `#eaf0f7`/`#234a78`; neutral `#f0f1f3`/`#3d4047` |
| status dot | 10 px filled circle with a 2 px ring, then the name in 14 px: new `#c3fae8`/`#7bf4cc`, in development `#66d9e8`/`#21c8de`, in review `#d3f9d8`/`#8ff09c`, on hold `#ffc078`/`#ff9d2e`, needs clarification `#fcc2d7`/`#f977a6`, closed `#dee2e6`/`#adb5bd` |
| status button | 32 px high, padding 0 10px, filled with the status colour, `#1b1c1d` text 14 px weight 600, caret 16 px |
| type | uppercase 12 px weight 700, letter-spacing 0.04em: EPIC `#005b77`, FEATURE `#538b28`, BUG `#ab0000`, TASK `#08a5df`, MILESTONE `#35c53f` |

## Type scale (from `DqPostvak.dc.html`, `DqKop.dc.html`, `token-rules.md`)

| role | value |
|---|---|
| body | 15 px, line-height 21 px, as Nextcloud, `#1b1c1d`; muted `#5e6168`; secondary `#3d4047` |
| page title | 28 px weight 700, line-height 1.2 |
| section title | 20 px weight 700 |
| widget title | 16 px weight 700 |
| row title | 15 px weight 600 |
| eyebrow | 12 or 13 px weight 600 or 700, uppercase, letter-spacing 0.06em, `#5e6168` |
| small | 12 or 13 px `#5e6168` |
| font | `font-family: 'Fira Sans', system-ui, sans-serif` (the build swaps it per design system) |

## Page frame

Board root: `display: flex; flex-direction: column; background: #f5f6f8`. Header 68 px, then a row with the nav at 264 px and `main` with padding 24px 28px, column gap 20 px, max-width 1240 px. Never more than three things side by side. Icons: inline SVG, 16 or 20 px, `fill="none" stroke="currentColor" stroke-width="1.75"`.
