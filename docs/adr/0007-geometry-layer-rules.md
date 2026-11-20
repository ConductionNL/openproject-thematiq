# 7. The geometry layer: one region per file, no colour literals, no generated text

- Status: accepted
- Source: [docs/geometry.md](../geometry.md) ("Where it lives", "Rules for this layer")

## Context

Sizes and spacing are the same for every design system and are measured against a canon of the shared shell (`spike/OP-TWIN-canon.md`). The selectors are OpenProject class names that can change with any release.

## Decision

- `stylesheets/geometry/` holds one file per region, inlined by the head hook after the variable layer, in file name order.
- Each rule is small, tied to one canon value, and carries a comment with that value.
- No colour literals: rules use the `--thematiq-*` aliases, which point at Primer's own values outside the light theme.
- No text in generated content, because screen readers do not read it reliably. The shell adds text as real markup.
- `bin/test` checks these rules.

## Consequences

- The dark and high contrast themes stay readable without rules of their own.
- An OpenProject release that renames a class breaks one small rule, found by the pixel check in [docs/pixel-check.md](../pixel-check.md).
