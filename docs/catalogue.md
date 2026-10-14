# The catalogue

The design systems ship inside the plugin, in one JSON file. This page explains the file and how to replace it.

## Where it lives

| Path | What it holds |
|---|---|
| `data/catalogue/shell-catalogue.json` | The design systems |
| `public/thematiq/logos/` | The logos the catalogue marks as redistributable |
| `public/thematiq/fonts/` | The fonts the catalogue marks as redistributable |
| `lib/open_project/thematiq/catalogue.rb` | The loader |

## The shape

```json
{
  "version": 1,
  "generated_from": "where the file came from",
  "sets": [
    {
      "id": "cunningham",
      "name": "Cunningham",
      "tokens": { "primary": "#1a67a3", "radius": "3px", "font-family": "Arial, sans-serif" },
      "logo": { "file": "img/logos/cunningham.svg", "inverse_file": null, "licence": "...", "redistributable": null, "basis": "..." }
    }
  ],
  "fonts": [
    { "family": "Fira Sans", "sets": ["amsterdam"], "shipped": true, "files": ["css/fonts/..."], "licence": "OFL-1.1",
      "licence_files": ["css/fonts/OFL.txt"], "redistributable": true, "basis": "..." }
  ]
}
```

The file in the plugin is generated from thematiq. `generated_from` says where it came from and ends in a digest of its sets. It holds 64 design systems, each with all eighteen tokens, and 63 of them with a `dark` block. 63 of them also carry a `vocabulary` block: the tokens of thematiq's full vocabulary that the set's own file declares, so the plugin draws a set's status colours, table, navigation and headings as thematiq does, and carries the rest ([design/full-vocabulary.md](design/full-vocabulary.md)). `basis` on a logo or a font says why its `redistributable` answer is what it is; the plugin reads past it. `licence_files` on a font names the notices that must travel with its files. [tokens.md](tokens.md) lists the tokens.

`redistributable` is `true`, `false` or `null`. `null` means the generator found nothing that says the file may be passed on. The plugin treats `null` like `false`. Of the 64 sets, 15 have a logo the plugin may ship.

A logo's `file` is the path it has in thematiq. The plugin uses the file name only and looks it up in its own folder.

`fonts` is read by `OpenProject::Thematiq::Assets`. [logos-and-fonts.md](logos-and-fonts.md) explains how.

## The plugin's own sets

`data/catalogue/openproject-themes.json` has the same shape and is written by hand. It holds OpenProject's own three colour themes as design systems: "OpenProject (default)", "OpenProject Gray" and "OpenProject Navy Blue". The five colours of each come from `lib/open_project/custom_styles/color_themes.rb` in OpenProject 17.9.1. The other values are OpenProject's defaults.

The loader reads the generated file first and adds these. A set in this file cannot replace a generated one.

These three are the only sets with the optional role `menu`, the background of the main menu. [tokens.md](tokens.md) explains it.

## What the loader does

- It checks every value with the same validator as any other input. A file in the plugin is not trusted more than an uploaded one.
- A token value that fails falls back to the last resort value for that token.
- An entry that is not a set, or that repeats an id, is skipped.
- A logo counts only when `redistributable` is `true`, the reference ends in one plain `svg` or `png` name and the file is in `public/thematiq/logos/`. A set without a usable logo keeps OpenProject's own logo.
- Loading never fails a page. When the file cannot be used, the plugin runs on the last resort set and the loader records why.

`cunningham` is the design system of a fresh install. It comes first in every list. The others follow by name.

## Replace the catalogue

1. Copy the new `shell-catalogue.json` over `data/catalogue/shell-catalogue.json`. Do not edit it by hand.
2. Copy only the logos of sets with `"redistributable": true` into `public/thematiq/logos/`, and only the fonts of families with `"redistributable": true` into `public/thematiq/fonts/`.
3. Change the number of sets in `test/catalogue_test.rb` when it changed.
4. Run `bin/test`. It fails when a value in the file is refused, when a named logo is missing, when a logo is in the folder that no redistributable set names and when a logo file holds a script or a link.
