# Read endpoints

Other apps on the same OpenProject, and other products, can read the plugin's design systems. Nothing here writes.

## For anyone signed in

No administrator rights are needed. A request without a session gets 401 for JSON, or the sign-in page.

| Endpoint | Answer |
|---|---|
| `GET /thematiq/api/v1/sets` | Every design system, custom ones first: `id`, `name`, `custom`, `active`, `primary`, `dark` |
| `GET /thematiq/api/v1/sets/<id>` | One design system in the set shape, as an export holds it ([catalogue.md](catalogue.md)) |
| `GET /thematiq/api/v1/sets/<id>/stylesheet.css` | The plugin's whole style sheet for that design system: the variable layer, the static layers and its fonts |
| `GET /thematiq/api/v1/sets/<id>/manifest` | The style sheets a page needs to wear that design system, in cascade order, and which of the plugin's style tags each replaces |
| `GET /thematiq/api/v1/contrast?foreground=<colour>&background=<colour>` | The contrast of two colours as the plugin measures it: `ratio`, and a `verdict` of `pass` (4.5 to 1), `large_text_only` (3 to 1), `fail` or `unknown` |

An unknown id answers 404.

## Without a session: thematiq's shell-tokens

`GET /thematiq/api/shell-tokens` answers the design system in use in the shape thematiq answers at `/apps/thematiq/api/shell-tokens`: `version` 1, `id`, `name`, `revision`, the eighteen roles in `tokens` and the logo as absolute `url` and `inverse_url`, or `null`. A product that reads one reads the other. It needs no session, like thematiq's: the values are what every visitor of the sign-in page already gets as CSS. It is cached for a minute. A trial or a project's own design system is never answered.
