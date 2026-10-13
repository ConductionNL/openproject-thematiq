# First full test, 13 October 2026

The first test of the whole plugin as one product, on a fresh install. This page grows while the test runs.

## Setup

- Plugin: branch `development` at `451c453`, started the way the README tells a newcomer to, with `THEMATIQ_PORT=8237`.
- OpenProject 17.9.1 community, image `openproject/openproject:17`, empty volumes, demo data.
- Browser: Chrome through Playwright, 1440 x 1000 unless a line says otherwise.
- Screenshots are named per finding. They stay on the test machine under `.lane/shots/` and are not in the repository.

## Severity

- **Blocker**: data loss, a security fault, or a page that does not load.
- **Major**: a feature that does not do what it says.
- **Minor**: wrong but usable.
- **Cosmetic**: looks off, nothing else.

## Findings

Each line: severity, where, how to reproduce, expected and actual, screenshot.

### Blocker

1. **Blocker, data loss. A new custom design system at the limit overwrites the first one.** With 50 custom design systems, select **Customise** on any design system, give it a name and select **Save and apply**. Expected: the plugin refuses, as import and Figma upload do ("There are 50 custom design systems ... Delete one first"). Actual: it answers "is now the active design system" and the custom design system with id `custom` is replaced by the new one, without a word; its uploaded files now hang on the new one. Cause: `new_draft` and `custom_id_from_params` in `admin_controller.rb` fall back to the id `custom` when no id is free. Screenshot `c-too-many.png`. Fixed in the pull request named at the end.

### Major

2. **Major. Top bar on a project page at 1440 wide.** Open `/projects/demo-project/work_packages` at 1440 x 1000 as the admin "OpenProject Admin". Expected: the top bar fits the window. Actual: the three parts of the top bar add up to 1462 px, the account name is cut off at the right edge and the whole page scrolls 22 px sideways. It happens on every page where the current module tile shows its label (work packages, Gantt, cost reports, my time tracking). Home and the admin pages fit; at 1024 and 390 wide it fits too, because the row of tiles folds away. Screenshot `t1440-wptable.png`.
3. **Major, documentation. Every `docker exec ... rails` command in the docs fails on the compose instance.** The compose file sets `SECRET_KEY_BASE` only for the main process. `docker exec ... bin/rails runner` (the request check in `docs/admin-page.md`) and `rake db:migrate:down` (README "Remove the plugin", `docs/uploads.md`) stop with "INSECURE SECRET_KEY_BASE DETECTED". The README's container is also named `openproject-thematiq`, the compose one `openproject-thematiq-try-openproject-1`. Workaround that works: prefix the command with `SECRET_KEY_BASE=$(cat /var/openproject/secret/secret_key_base)`.
4. **Major. An import loses the dark values.** Export a custom design system and import the file again. The file holds a `dark` block; the imported design system has the dark values of Cunningham instead (compare the two exports). A Figma upload of the W3C download keeps them. `admin_controller.rb#import` builds the draft without `dark:`.
5. **Major. Logo invisible in OpenProject's light high contrast theme.** My account, Interface, Light, **Increase contrast**, with Zuiddrecht active. OpenProject's high contrast top bar is pale grey (`#eff2f5`); the plugin still draws the white logo variant on it, so the logo nearly disappears. Screenshot `d-light-hc-wp.png`.

### Minor

6. **Minor. Table header height.** Work package table at 1440 wide. Canon 44 px, measured 45 px.
7. **Minor. The default design system fails the plugin's own contrast check.** On a fresh install Cunningham, marked "Default" and "Active", carries the line "Low contrast, under 4.5 to 1: muted text on the page background". Screenshot `a-picker-1440.png`.
8. **Minor. OpenProject's introduction tour points at a control that is gone.** First sign-in, select **Next** through the tour. The step "Use the return arrow in the top left corner to return to the project's main menu" points at the logo; the two-layer menu has no return arrow. Two steps also throw `TypeError: Cannot read properties of undefined (reading 'left')` (on Home and on the work package page), and the tour's close button sits on top of the account name. The tour does reach its end. Screenshots `a-tour-b2.png`, `a-home-after-lang.png`.
9. **Minor. The README is out of date.** It says 64 design systems (twice) and "a logo ships for 15 of the 64"; the picker lists 67. It says "It styles the light theme only", while the dark theme is styled. It says the shell leans on "eight files of OpenProject"; `script/check-core.rb` checks 17. It says "Removing the plugin was not tested"; see the experiments below.
10. **Minor. Search hides your own design systems.** Type a part of the name of a custom design system (for example "E2E") in **Search design systems**. Expected: it is found. Actual: "0 of 67 design systems"; custom ones are never searched, and the count never counts them.
11. **Minor. Delete has no confirmation.** **Delete this custom design system** deletes at once, uploaded files included, with no question. Removing an upload has no confirmation either.
12. **Minor. White logo on the light top bar of the dark theme.** Dark theme with Zuiddrecht: the top bar becomes light blue (`#84aad7`), the white logo variant on it has a contrast of about 2.3 to 1. Screenshot `d-dark-wp.png`.
13. **Minor, testing. Primer `test_selector` hooks never reach the page.** The image runs in production, where Primer drops `test_selector`. The hooks `thematiq-no-results`, `thematiq-rejected-banner` and `thematiq-catalogue-error` are therefore absent; the plain `data-test-selector` attributes in the plugin's own HTML do render. The end-to-end suite uses roles and texts for those three.
14. **Minor. 214 tab stops before Apply.** In the picker every design system has three links (Customise, Export, Figma), so a keyboard user tabs through about 200 stops to reach **Apply**. Enter on a selected radio button does apply, so it is usable.
15. **Minor. A cleaned SVG is not always reported.** Upload `hostile-processing-instruction.svg` as a logo: the processing instruction is removed, but the page says "The logo is uploaded and in use." without the note that parts were left out.

### Cosmetic

16. **Cosmetic. Two arrows next to "Sign in".** Sign-in page, not signed in, top bar right. Screenshot `v-login-1440.png`.
17. **Cosmetic. 390 wide, the work package toolbar starts left of the screen.** The **Create** button is cut off on the left. Screenshot `w390-wp.png`. Not checked whether OpenProject without the plugin does the same.

## Sizes against the canon

Measured with computed styles on `/projects/demo-project/work_packages` at 1440 x 1000, Cunningham active.

| Part | Canon | Measured |
|---|---|---|
| Top bar | 68 | 68 |
| Logo block | 264, divider on the sidebar edge | 264, divider 1 px at x 263, 28 px high |
| Sidebar | 264 | 264 |
| Nav item | 42 | 42 |
| Level two item | 36 | 36 |
| Primary button | 40 | 40 (Create); the round "+" in the top bar is 44 |
| Table row | 48 | 48 |
| Table header | 44 | 45 |

The top bar is 68 and the rows 48 on all eleven design systems tried.

## Works

- The README's Docker path: build and first start took 3 minutes 30 seconds with the base image on disk. Sign-in with `admin` / `admin` and the forced password change work.
- **Thematiq design** is in the administration menu and on the administration overview. The picker lists 67 design systems. Search narrows on the server ("gemeente z" gives 5), a search with no match shows "No design system has that name", script in the search field is shown as text.
- Apply: eleven design systems tried (Cunningham, Zuiddrecht, OpenProject default and Navy Blue, Haarlemmermeer, Noordoostpolder, Vught, Rotterdam, Nextcloud, Hoog contrast, Summer Breeze). Each changes the top bar, sidebar, links and font at once; the bundled logo (Zuiddrecht) and fonts (Fira Sans, Roboto, Inter) load. The three with a known weakness are flagged in the picker with the right pair.
- 35 pages opened at 1440 wide as admin with every module on: none answered 500, none logged a content security policy violation.
- Two-layer menu: on every module the current one is open with `aria-expanded="true"` and its page has `aria-current="page"`; every submenu toggle works with the keyboard and keeps focus.
- Row of tiles: the current module has `aria-current="page"`. Home shows the grid; `/my/page` redirects to `/`.
- Editor: live preview follows typing in all four groups, contrast lines update, **Changed** badges and counts update, **Reset**, **Reset group**, the colour picker, search and "Show changed values only" work. Bad values (`notacolour`, `url(javascript:alert(1))`, `red; } body {display:none`) are marked, never reach the preview, and saving answers 422 with the fields marked.
- Export and import round trip keeps every value. All three Figma downloads upload again with the same 18 values. A JSON file of the wrong kind is refused.
- Uploads: logo, logo for the coloured bar, mobile logo, favicon, touch icon and a font upload and show where they should (top bar, `link rel=icon`, `apple-touch-icon`, `@font-face`). Every hostile SVG under `test/fixtures/uploads/` is cleaned or refused; the served files carry the documented headers and no script. A file that is not an image, a program, a file over the size, a picture of 60,000 px, a touch icon under 120 px and a font as logo are refused with a clear line.
- Up to 50 custom design systems; the 51st by import or Figma is refused. Deleting one removes its files (old addresses answer 404). Deleting the active one falls back to Cunningham.
- An ordinary member (role Member on the demo project) sees the shell, the tiles and Home, gets 403 on every admin page and every admin action (GET and POST with a valid token), and every menu link they see opens.
- A visitor: the sign-in page is themed, admin pages redirect to the sign-in page, the public file route answers without a cookie, and every near miss (63 characters, capitals, `.svg` on the end, an encoded path) answers 404. A missing page is themed.
- Keyboard: focus is visible on everything tried, arrows move through the design systems, Enter applies, the nine-dot list opens with Enter and closes with Escape, focus returns to its button, nothing traps focus.
- Dark theme, "Automatic" with the browser in dark and in light, and both high contrast themes (switched by hand with **Increase contrast**): pages load, text contrast stays above 4.5 to 1. In high contrast the plugin's colours give way to OpenProject's.
- 1024 and 390 wide: no sideways scroll on Home, the work package table, the picker, the editor and a board; at 390 the mobile mark shows and the sidebar folds away.
- Existing checks on the fresh instance: `bin/test` 322 runs, 0 failures; `bin/check-syntax` ok; `script/check-core.rb` ok, 17 files match 17.9.1; `python3 -m unittest discover -s test/pixel` ok.

## Not done yet

Everything else in the test plan. This list shrinks as the test goes on.
