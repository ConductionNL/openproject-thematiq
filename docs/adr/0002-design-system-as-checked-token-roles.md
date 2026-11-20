# 2. A design system is a small set of token roles, each value checked against a known syntax

- Status: accepted
- Source: [docs/tokens.md](../tokens.md) ("A design system is eighteen tokens", "How a value is checked", "How the tokens reach the page")

## Context

A design system has to reach OpenProject's CSS. OpenProject and Primer already expose CSS variables for colours, radius and font. Every token value ends up inside a `<style>` tag on every page, so a value that is not what it claims to be is an injection risk.

## Decision

- A design system is a fixed set of eighteen token roles: fifteen colours, two lengths (`radius`, `radius-lg`) and a font stack, with one optional nineteenth role, `menu`.
- `OpenProject::Thematiq::Variables::Generator` writes the tokens onto the CSS variables OpenProject and Primer already use, plus `--thematiq-*` aliases. It does not restyle OpenProject's elements one by one.
- A value is accepted only when its whole text matches a known syntax (colour functions with plain numbers, a few length units, up to 20 font families). A value that fails falls back to the last resort value for that token in `lib/open_project/thematiq/tokens/defaults.rb`. Files that ship with the plugin get the same check as any other input.
- Text colours on a coloured menu, top bar or main button are worked out from contrast, so a dark menu stays readable.

## Consequences

- A broken or hostile value cannot break out of the style tag; at worst a token shows its last resort value.
- The last resort values are those of Cunningham, the default design system, and a test keeps the two the same.
- Anything beyond the eighteen roles needs its own allow-list (see [ADR 4](0004-full-vocabulary-keeps-thematiq-names-and-derives-nothing.md)).
