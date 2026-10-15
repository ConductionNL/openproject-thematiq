# The pixel check

The plugin styles OpenProject by class names that OpenProject can change in any release. The pixel check tells you when a release moved something in the top bar or the sidebar.

The reference images are in `script/pixel/reference/`. They were made on 14 October 2026 on OpenProject 17.9.1 with Cunningham active, when the top bar became the dossiq bar. Two captures in a row differed in 0.00% of the pixels of both regions, so the limits below leave room for font smoothing only. Without the reference images the check answers "cannot run", exit code 2. It never answers "pass" without them.

## What it does

1. `script/pixel/capture.mjs` signs in and takes one screenshot: the work package table of a project at 1440 x 1000.
2. `script/pixel/compare.py` cuts two regions out of it and compares each with its reference image.

| Region | Box | May differ |
|---|---|---|
| Top bar | 0, 0 to 1440, 68 | 0.5% of its pixels |
| Sidebar | 0, 68 to 264, 1000 | 1.0% of its pixels |

A pixel counts as different when a colour channel is more than 24 of 255 away from the reference. That lets font smoothing pass and catches a moved edge or a changed colour.

| Exit code | Meaning |
|---|---|
| 0 | Both regions are within their limit |
| 1 | A regression: at least one region is over its limit |
| 2 | The check could not run: a file is missing or the screenshot has the wrong size |

## What you need

- A running OpenProject with the plugin, in the state the references were made in. See "The state" below.
- Node with the `playwright` package and a browser for it: `npm install playwright && npx playwright install chromium`.
- Python 3 with Pillow: `pip install pillow`.

## Run it

```bash
THEMATIQ_PIXEL_URL=http://localhost:8080 THEMATIQ_PIXEL_PASSWORD='<admin password>' \
  node script/pixel/capture.mjs /tmp/thematiq-shot.png

python3 script/pixel/compare.py /tmp/thematiq-shot.png --out /tmp/thematiq-diff
```

`--out` writes one image per region that shows the differing pixels in red.

## The state

Two runs only compare when the page shows the same thing. The references are made, and the check is run, with:

- A fresh instance with OpenProject's demo data, so the project "Demo project" and its menu exist.
- The design system Cunningham, the default.
- The user `admin` with the name OpenProject gives it, English, the light theme.
- No Nextcloud address set, no Enterprise token.
- The main menu at its normal width, not collapsed.

## Run it for a new OpenProject release

1. Build the plugin's image on the new OpenProject image and start it on an empty database.
2. Run `script/check-core.rb` first. When it names changed core files, the top bar and project menu overrides are off, and the pixel check will fail for that reason.
3. Run the two commands above.
4. Exit code 0: the shell looks the same on the new release.
5. Exit code 1: open the images in the `--out` folder. Decide whether OpenProject moved something the plugin must follow, or whether the new look is right and the references must be made again.

## Make the references again

Do this when the plugin's own look changed on purpose, never to make a failing check pass.

```bash
python3 script/pixel/compare.py /tmp/thematiq-shot.png --write-reference
git add script/pixel/reference
```

Look at both images before you commit them. Say in the commit message which change made the new references necessary.

## What it does not cover

- Anything outside the two regions: the table, the page header, the admin page.
- Other pages, other widths, the dark theme and the high contrast themes.
- Other design systems than Cunningham.

## Run its own tests

```bash
python3 -m unittest discover -s test/pixel
```
