# Logos and fonts

A design system can have a logo and a font. The plugin ships the files it may pass on, and serves them itself.

## Where the files live

| Path | What it holds |
|---|---|
| `public/thematiq/logos/` | 22 logo files, for 15 design systems: 21 logos and the Zuiddrecht emblem |
| `public/thematiq/fonts/` | 47 font files in 13 families, and their licence texts |
| `lib/open_project/thematiq/assets.rb` | Which file belongs to which design system |

The plugin adds one static file handler to OpenProject. It answers for the files in `public/` and for nothing else. The addresses start with `/thematiq/`. No request leaves your server.

## Which files ship

Only what the catalogue marks `"redistributable": true`. For the rest the plugin has no file, and never fetches one.

- **Logos:** 15 of the 64 design systems. The other 49 keep OpenProject's logo.
- **Fonts:** 13 families: Barlow, Clear Sans, Figtree, Fira Sans, IBM Plex Sans, Inter, Lato, Lexend, Open Sans, Red Hat Text, Roboto, Source Sans 3 and Source Sans Pro. They are under the SIL Open Font License 1.1, and Clear Sans under Apache 2.0. `OFL.txt`, `OFL-inter.txt` and `APACHE-2.0.txt` sit next to the files.

The files were copied from thematiq at the commit the catalogue names in `generated_from`.

## The logo

The top bar has thematiq's header colour as its background where the design system gives one, and the primary colour otherwise. On a coloured bar the plugin shows the variant for dark backgrounds when the design system has one, and the normal logo otherwise. Where the bar is light, the normal logo comes first: on a white header such as Zuiddrecht's, on a light primary colour (white text does not read on it), in the dark theme when the dark block's primary is light (Zuiddrecht's is light blue), and in OpenProject's light high contrast theme, where the bar is OpenProject's own pale grey. When a design system has no normal logo, the light high contrast theme shows OpenProject's own logo. A custom design system keeps the logo of the design system it is based on, until you upload one. An uploaded logo wins.

## The font

For the active design system, the plugin writes one `@font-face` rule per bundled file of each family in its font stack, with `font-display: swap`. Text shows at once in a fallback font and switches when the file has loaded.

For 42 of the 64 design systems the first font in the stack ships with the plugin. For the other 22 it does not: a system font such as Arial, or a house font the catalogue does not mark as free to pass on. Those pages fall through the stack. Cunningham names Marianne first, which is not bundled, and Inter second, which is, so Cunningham renders in Inter.

A custom design system can also load fonts you uploaded. An uploaded family replaces the bundled files of the same family.

The admin page says which case applies to the active design system.

## What is not built

- A mobile logo, a favicon and a touch icon for a design system of the catalogue. The catalogue has none. A custom design system gets them by upload, see [uploads.md](uploads.md).
- A logo on the sign in page that differs from the one in the top bar.

To add files after a catalogue change, copy the redistributable ones into the two folders and run `bin/test`. It fails on a file no redistributable entry names.
