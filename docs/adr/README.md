# Architecture decision records

Decisions this repository has made, one per file, numbered. Each record cites the document in this repository it was taken from. The longer design notes are in [docs/design/](../design/).

| Number | Decision |
|---|---|
| [0001](0001-work-on-its-own-without-network-requests.md) | The plugin works on its own and makes no network requests by default |
| [0002](0002-design-system-as-checked-token-roles.md) | A design system is a small set of token roles, each value checked against a known syntax |
| [0003](0003-design-system-per-project-and-module.md) | A design system per project and per module, the most specific choice wins |
| [0004](0004-full-vocabulary-keeps-thematiq-names-and-derives-nothing.md) | The full token vocabulary keeps thematiq's names and derives nothing |
| [0005](0005-frontend-route-next-to-default-route.md) | A frontend route next to the default route, without editing core files |
| [0006](0006-live-preview-sets-custom-properties-only.md) | The style editor's live preview only sets custom properties |
| [0007](0007-geometry-layer-rules.md) | The geometry layer: one region per file, no colour literals, no generated text |

A new record takes the next number and the same headings: status, source, context, decision, consequences.
