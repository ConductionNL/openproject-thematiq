# Figma token sets

A design system can leave OpenProject as a token set for Figma, and a token set from Figma can come in as a custom design system. Both are files through your browser. The plugin opens no connection to Figma.

## Download for Figma

1. Open **Administration**, then **Thematiq design**.
2. Select **Figma** next to a design system.
3. Choose a format.

| Format | File | Use it for |
|---|---|---|
| W3C design tokens | `thematiq-<id>.tokens.json` | Tools that read the W3C Design Tokens format, version 2025.10. thematiq writes and reads the same layout, so this file uploads into thematiq |
| Tokens Studio | `thematiq-<id>.tokens-studio.json` | The Tokens Studio plugin for Figma. One file with a light token set, a dark one when the design system has dark colours, `$themes` and `$metadata` |
| Tokens Studio, legacy spelling | the same name | Tokens Studio set to its legacy format: `value` and `type` in place of `$value` and `$type` |

Logos, icons and fonts are not in these files.

## Upload from Figma

1. On **Thematiq design**, select **Upload from Figma** under the import form. Or select **Figma** next to any design system.
2. Choose one file. For a Tokens Studio folder, choose all its files at once, `$themes.json` and `$metadata.json` included.
3. Select **Upload from Figma**.

The plugin adds a new custom design system and shows a report: every value it imported, with the token it came from, and every token it skipped, with the reason. Nothing is applied until you pick the design system in the list.

Values the file does not name come from the default design system. A token under a name of the vocabulary becomes that vocabulary value, through the check of its kind. It can feed a value of the nineteen as well: thematiq's error colour is also where the accent falls back to.

## Which token becomes which value

The names are thematiq's. Each value is written under the CSS name thematiq reads that value from, at the path thematiq gives that name: the first part, the second part, then the rest joined by dashes.

| Value | CSS name | Path in the file |
|---|---|---|
| Primary | `--nldesign-color-primary` | `nldesign.color.primary` |
| Primary, deep | `--nldesign-color-primary-hover` | `nldesign.color.primary-hover` |
| Primary, light | `--nldesign-color-primary-light` | `nldesign.color.primary-light` |
| Action | `--nldesign-color-action` | `nldesign.color.action` |
| Action, deep | `--nldesign-color-action-hover` | `nldesign.color.action-hover` |
| Link | `--nldesign-color-link` | `nldesign.color.link` |
| Accent | `--nldesign-color-accent` | `nldesign.color.accent` |
| Ink | `--nldesign-color-text` | `nldesign.color.text` |
| Text | `--thematiq-shell-text` | `thematiq.shell.text` |
| Muted | `--nldesign-color-text-muted` | `nldesign.color.text-muted` |
| Line | `--nldesign-color-border` | `nldesign.color.border` |
| Soft | `--nldesign-color-background-dark` | `nldesign.color.background-dark` |
| Ground | `--nldesign-color-background` | `nldesign.color.background` |
| Chip | `--nldesign-color-background-hover` | `nldesign.color.background-hover` |
| Field | `--nldesign-color-border-dark` | `nldesign.color.border-dark` |
| Radius | `--nldesign-border-radius` | `nldesign.border.radius` |
| Radius, large | `--nldesign-border-radius-large` | `nldesign.border.radius-large` |
| Font | `--nldesign-font-family` | `nldesign.font.family` |
| Menu | `--thematiq-shell-menu` | `thematiq.shell.menu` |

A value of the full vocabulary ([full-vocabulary.md](design/full-vocabulary.md)) is written under thematiq's own name for it, `--nldesign-` and the key, at the path that name gives: `color-error` is `--nldesign-color-error` at `nldesign.color.error`. Its type follows its kind:

| Kind | W3C design tokens | Tokens Studio |
|---|---|---|
| Colour | `color`, as for the nineteen | `color` |
| Length, size | `dimension` for `px` and `rem`, `number` for `0`, else `cssOnly` | `dimension` |
| Font stack | `fontFamily` | `fontFamilies` |
| Font weight | `fontWeight` for a number, else `cssOnly` | `fontWeights` |
| Number | `number` | `number` |
| Duration | `duration`, `{"value": 100, "unit": "ms"}` | `other` |
| Offset, three channels, filter, border, text transform | `cssOnly` | `other` |

Every token also carries its CSS name in `$extensions["nl.conduction.thematiq"].cssVariable`. That is what thematiq looks at first, and so does the plugin.

On upload the plugin finds the CSS name of a token in this order:

1. The `cssVariable` in the extension.
2. A path that holds the names above, such as `nldesign.color.primary`, with anything in front of it.
3. The end of the path, from thematiq's own table: `color.primary`, `brand.primary`, `color.primary-hover`, `color.primary-light`, `color.background`, `color.text`, `fontfamily.base`, `typography.font-family`, `border-radius.base`, `dimension.border-radius`.

A value then takes the first CSS name it knows, in the order of thematiq's role mapper. In a file the plugin wrote itself (a W3C file with the plugin's extension at the root, or a Tokens Studio file with the token set `thematiq/light`) a value only takes the name the plugin writes it under. So a content surface in the vocabulary does not become the ground on the way back. That list also holds Nextcloud's names, such as `--color-primary`, and some values share a name: a file with a primary colour and no action colour gives the action the primary colour.

## What a round trip keeps and loses

A design system downloaded and uploaded again gives the same nineteen values and the same dark colours, in all three formats. A test does this for every design system that ships with the plugin.

| | W3C design tokens | Tokens Studio |
|---|---|---|
| Colours as six or eight digit hex | Kept, as a colour object in sRGB | Kept, as text |
| Other colour syntax the plugin can convert: three digit hex, `rgb()` | Kept. The file holds the colour object and, in the plugin's own extension, the text as it was. A tool that drops extensions gives back a hex value | Kept, as text |
| Colour syntax the plugin cannot convert: a colour name, `hsl()`, `oklch()` | Kept, but not as a token. It goes into thematiq's `cssOnly` list in the root extension. Figma does not show it, and a tool that drops extensions loses it | Kept, as text |
| Lengths in `px` and `rem` | Kept, as a dimension | Kept, as text |
| Lengths in `em` and `%` | In `cssOnly`, as above. The format has no such unit | Kept, as text |
| A font stack | Kept, as a list of families. A stack with quotes around a single word goes into `cssOnly` | Kept, as text |
| Dark colours | Kept, in the plugin's own extension `nl.conduction.openproject-thematiq`. The format has no themes. thematiq does not read them | Kept, as the token set `thematiq/dark` and the theme "Dark" |
| The name | Kept, as `$description` | Kept, as the `group` of the themes |
| The id | Written as `setId`. Not used on upload: an upload always gets a new id | Lost |
| Logo, icons, fonts | Lost | Lost |
| Tokens of thematiq's full vocabulary | Kept, under thematiq's names. A see-through colour comes back as eight digit hex when a tool drops the extension | Kept, as text |
| Tokens of thematiq outside the vocabulary, such as a set's own palette (`--zuiddrecht-color-red`) | Skipped on upload and named in the report. They do not come back out | The same |

## What an upload must stand

An uploaded file is hostile input.

- At most 512 KB for all files together, at most 40 files.
- Groups at most 12 deep, at most 5000 tokens.
- A reference that leads back to itself is found and named. A chain of more than 16 references is cut off.
- Every value goes through the validator of the value it would set. Nothing but a value of a kind the plugin accepts reaches a page.
- A token of another type, such as a shadow, never sets a value.
- The plugin follows no address in a file. A `$ref` is skipped.
- One bad token does not refuse the file. It is skipped and named. A file with nothing usable is refused.

## What is read and what is not

Read:

- `$value` and `$type`, and the older `value` and `type`.
- A type on a group, which its tokens inherit.
- References in curly braces, such as `{brand.blue}`, through any number of steps up to 16.
- Colours as text or as a colour object. An sRGB object is read from its components. Any other colour space is read from its `hex` member.
- Dimensions as text or as an object with `value` and `unit`.
- Tokens Studio: `$themes` and `$metadata.tokenSetOrder`. The first theme that is not called "dark" is the light theme. A theme called "dark" gives the dark colours, from the token sets it does not share with the light theme. A set marked `source` resolves references and gives no value. Without themes, a set called `dark` gives the dark colours and the rest are merged in order. A later set wins.

Not read, and named in the report:

- A calculation or several references in one value, such as `{spacing.base} * 2`.
- `$ref` with a JSON pointer, and `$extends` on a group.
- Composite types: typography, shadow, border.

## Where the formats come from

Read on 13 October 2026:

- The W3C format: [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/) and its [colour module](https://www.designtokens.org/tr/2025.10/color/).
- Tokens Studio: [token format](https://docs.tokens.studio/manage-settings/token-format), [token types](https://docs.tokens.studio/manage-tokens/token-types) and [token sets](https://docs.tokens.studio/manage-tokens/token-sets/). These pages name the two spellings, the types and the rule that the lower set wins. They do not show the inside of `$themes` and `$metadata`. For those the plugin follows thematiq's reader, `lib/Service/MultiBrandSource.php`, which cites the source of the Tokens Studio plugin, version 2.12.1.
- thematiq, commit `06c92322`: `lib/Service/DesignTokensWriter.php`, `DtcgValueTyper.php`, `DesignTokensMapper.php`, `ShellRoleMapper.php`.

Not tried: opening a downloaded file in Figma or in Tokens Studio, and uploading a file into a running thematiq.

The code is in `lib/open_project/thematiq/figma.rb` and `lib/open_project/thematiq/figma/reader.rb`. The tests and their fixtures are in `test/figma/`.
