# The catalogue

The design systems ship inside the plugin, in one JSON file. This page explains the file and how to replace it.

## Where it lives

| Path | What it holds |
|---|---|
| `data/catalogue/shell-catalogue.json` | The design systems |
| `data/catalogue/logos/` | The logos the catalogue marks as redistributable |
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
      "logo": { "file": null, "inverse_file": null, "licence": null, "redistributable": false }
    }
  ],
  "fonts": []
}
```

A set has up to eighteen tokens. [tokens.md](tokens.md) lists them. The loader does not read `fonts` yet.

## What the loader does

- It checks every value with the same validator as any other input. A file in the plugin is not trusted more than an uploaded one.
- A token value that fails falls back to the last resort value for that token.
- An entry that is not a set, or that repeats an id, is skipped.
- A logo counts only when `redistributable` is `true`, the file name is one plain `svg` or `png` name and the file is in `data/catalogue/logos/`. A set without a usable logo keeps OpenProject's own logo.
- Loading never fails a page. When the file cannot be used, the plugin runs on the last resort set and the loader records why.

`cunningham` is the design system of a fresh install. It comes first in every list. The others follow by name.

## Replace the catalogue

1. Copy the new `shell-catalogue.json` over `data/catalogue/shell-catalogue.json`.
2. Copy only the logos of sets with `"redistributable": true` into `data/catalogue/logos/`.
3. Run `bin/test`. It fails when a value in the file is refused, when a named logo is missing and when a logo is in the folder that no set names.
