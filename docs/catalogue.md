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

The file in the plugin is generated from thematiq. `generated_from` names the thematiq commit. It holds 64 design systems, each with all eighteen tokens. [tokens.md](tokens.md) lists the tokens.

`redistributable` is `true`, `false` or `null`. `null` means the generator found nothing that says the file may be passed on. The plugin treats `null` like `false`. Of the 64 sets, 14 have a logo the plugin may ship.

A logo's `file` is the path it has in thematiq. The plugin uses the file name only and looks it up in its own folder.

`fonts` is read by `OpenProject::Thematiq::Assets`. [logos-and-fonts.md](logos-and-fonts.md) explains how.

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
