# 4. The full token vocabulary keeps thematiq's names and derives nothing

- Status: accepted (the owner decided the open trade-offs; steps 1 to 3 built)
- Source: [docs/design/full-vocabulary.md](../design/full-vocabulary.md) ("How the set file grows", "The trade-offs")

## Context

The plugin knows eighteen roles per design system. thematiq knows about 161 token names across its design systems. The plugin has to grow to that vocabulary without breaking files and sets that work today.

## Decision

- `tokens` in a set file does not change. The full vocabulary comes beside it in an optional, flat `vocabulary` object.
- `vocabulary` uses thematiq's own names without the `--nldesign-` prefix, not names of the plugin's own, so no translation table can drift and one file serves both products.
- A value has one home: thematiq names that are roles stay in `tokens`, and a file that names one of them in `vocabulary` is refused. An unknown key is skipped in the catalogue and refuses an import.
- Nothing is derived. Where a set is silent, OpenProject keeps its own value.
- Tokens the plugin cannot draw are carried, not dropped, so a set moved between Nextcloud and OpenProject keeps them.
- Each new kind of value gets its own allow-list in the validator. A vocabulary value is never an address: logo and image tokens stay out.

## Consequences

- A file exported today imports tomorrow, and a set without `vocabulary` looks exactly as it did.
- Names that say "nldesign" or "website" appear inside an OpenProject plugin.
- The editor for 161 fields needs a design of its own.
