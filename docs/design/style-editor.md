# Design: a style editor like thematiq's

**Status: the first step is built. The rest is a plan.**

thematiq is the Nextcloud app this plugin follows. It has a style editor. The plugin had a form with eighteen fields. This page says what thematiq's editor does, what the plugin has, and how each missing part is built in OpenProject.

Read from thematiq `development` on 13 October 2026, commit `06c92322`: `docs/features/token-editor.md`, `docs/features/theme-preview.md`, `docs/features/restore-a-version.md`, the specs `token-editor-ui`, `component-playground`, `own-tokens`, `custom-css-overrides`, `custom-css-freeform` and `theme-versions`, and the size and outline of `js/admin.js` and `js/playground.js`. The two scripts were not read line by line.

## What thematiq's editor is

An administrator opens **Custom token overrides** in Nextcloud's theming settings. The editor lists 713 CSS variables of Nextcloud and its apps. A change shows at once in a preview above the list. **Save overrides** writes the values that differ from the chosen token set to one file, which every page loads.

## Feature by feature

| What an administrator can do in thematiq | The plugin | How it is built in OpenProject |
|---|---|---|
| Browse the values in four tabs: login page and branding, content area, buttons and status, typography | Built in this step | Four groups with the same names in `lib/open_project/thematiq/editor.rb`. A group is one entry in a list. All groups are on one page, each a fieldset, so the page works without a script |
| See a change at once, before saving | Built in this step | A small script writes custom properties on the picture of the shell. It is inlined with `nonced_javascript_tag`, the helper OpenProject gives a view for its content security policy. The project menu of the shell already uses it. No frontend build step |
| See which values differ from the token set, as a badge on the row | Built in this step | "Changed" on the row, a count per group, a count for the whole form, and "Show changed values only" |
| Reset one value | Built in this step | "Reset" per value. With the script it clears the field at once. Without it the form posts and nothing is saved |
| Reset a group | thematiq has no such button. The owner asked for it | "Reset group" per group, the same two ways |
| Pick a colour with a colour picker, in step with the text field | Built in this step | The browser's own colour input over the swatch. The text field stays the one field that is sent |
| Type any colour syntax: hex with alpha, `rgb()`, `hsl()`, a colour name | The plugin had this | The validator's allow-list. The script uses the same patterns |
| Get told that a value is refused | The plugin had this on save. Built in this step while typing | The script marks the field. The server decides on save, as before |
| See the contrast of text on its background | Built in this step, and more than thematiq shows in its token rows | Each colour has the contrast checks of the shell next to it: the ratio and the verdict in words, updated while typing. thematiq measures contrast on upload, in the preview of your own component and in a report |
| Search a value by its label, its name or its group | Built in this step | A search field over the rows. It needs the script and stays hidden without it |
| Save the overrides, for everyone | The plugin had this | "Save and apply" stores a name, a base and the overrides in OpenProject's settings |
| Save the changes as a new theme | The plugin had this | Every custom design system is a base plus overrides. Up to 50 |
| Export and import the overrides | The plugin had this, and gets the Figma formats | [figma.md](../figma.md) |
| An opacity control per colour, with a checkerboard swatch | Not built | A range input beside the picker that writes an eight digit hex. Small, in the script |
| A dark value per colour | Not built | The design systems of the catalogue bring a dark block. A custom design system keeps the dark block of its base. To build: `dark_overrides` in the custom draft and a second field per colour |
| 713 variables, with component groups that open on demand, and an advanced group with a warning | Built for thematiq's full vocabulary: 185 values in fourteen groups under "More values" | Each group is an entry in `Editor::GROUPS`, filled by `Editor::VOCABULARY_RULES`. Each starts closed in a `details` element, and opens when it holds a changed or refused value or when a search finds a value in it. Each row names thematiq's CSS name and says whether OpenProject draws it |
| See Nextcloud's own value for a variable | Partly. Each row shows the value of the base design system | OpenProject's own value per variable would come with the vocabulary list |
| A playground: buttons, inputs, note cards, list items and the login card in each state, per Nextcloud version | Partly. One picture of the shell: top bar, menu, buttons, input, table, link, a notice | More parts in the same picture, drawn with Primer's class names. No version selector: the plugin supports one OpenProject version |
| Preview your own component: paste HTML and CSS, see it in the house style | Not built | A sandboxed frame needs a content security policy of its own. This is the largest missing part and the least used |
| Your own tokens: add a token with a name, a label, a type and a dark value | Not built | A list in the plugin's settings, written as `--thematiq-org-*` on the root. Useful once custom CSS exists |
| Deprecate a token | Not built | After own tokens |
| Custom CSS: free CSS, cleaned before it is stored | Not built | Hostile input of the highest kind. It needs a CSS parser with an allow-list, not a pattern. To decide with the owner before building |
| Animation speed and easing | Not built | OpenProject has no variables for motion. It would only reach the plugin's own menu |
| Try a design system in your own session, with a banner to publish or discard | Not built | A user preference that names a design system, read by the head hook, and a banner through the body hook |
| A version after every change, and restore | Not built | A list of the last settings in the plugin's own table, with "Restore". The table exists since the uploads |

## What this step changes for an administrator

1. The values are in four groups.
2. The picture of the shell follows the form while they type.
3. Each colour says how well its text reads, in numbers and in words.
4. A changed value has a badge, and the form says how many values differ.
5. One value or one group goes back with one button.

## How the live preview stays safe

- The script sets custom properties on one element with `style.setProperty`. It writes no markup and no style rules.
- It checks a value with the same patterns as the server before it draws it. A value that fails is not drawn.
- It sends nothing and stores nothing. A unit test reads the script and fails when it reaches for the network, storage or markup.
- The server checks every value again on save. The script decides nothing that is kept.

## How a group is added

Add one line to `GROUPS` in `lib/open_project/thematiq/editor.rb`, and its label and hint under `thematiq.editor.groups` in `config/locales/en.yml`. A test fails when a role is in no group or in two.

## Build order from here

1. Built: the vocabulary list and its kinds, steps 1 to 3 of [full-vocabulary.md](full-vocabulary.md), and its groups in the editor. A value a set does not fill keeps OpenProject's own value. Nothing is derived.
2. A dark value per colour.
3. Opacity per colour.
4. More parts in the preview.
5. Versions and restore.
6. A trial in your own session.
7. Own tokens, then custom CSS, once the owner has decided on custom CSS.
