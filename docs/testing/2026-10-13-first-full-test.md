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

### Status

Fixed in pull requests to `development`, opened on 13 October 2026 by the lane that fixed the findings. "Open" means the pull request is not merged yet. The checks of the combined fixes are under [The end-to-end suite](#the-end-to-end-suite).

| # | Status | Pull request |
|---|---|---|
| 1 | Fixed, merged | #38 |
| 2 | Fixed: the search gives way to 240 px, the account label gives way on a module page between 1360 and 1439 px, a long name ends in an ellipsis | #41 |
| 3 | Fixed: `docker compose exec ... bash -lc` gets the secret from a login script the compose start writes; every command names the compose service and the `docker run` container | #52 |
| 4 | Fixed, merged | #39 |
| 5 | Fixed: the plain logo on OpenProject's light high contrast bar | #47 |
| 6 | Fixed: the thead height, `--generic-table--header-height`, is 44 | #41 |
| 7 | Fixed in thematiq: Cunningham's muted text is `#62656a`, 5.85 to 1 on white. The catalogue is vendored again | thematiq #1277, then #40 |
| 8 | Fixed: the step at core's return arrow is dropped while the plugin's menu is in place; the close button sits below the bar. The two TypeErrors are core's own (steps without a target) and stay | #50 |
| 9 | Fixed: 67 design systems, the dark theme, 17 core files, a font for 52 sets, removal tested, migrations on every start | #52 |
| 10 | Fixed: the search covers custom design systems, the count counts them | #43 (after #42) |
| 11 | Fixed: delete and remove ask first, on a page with a form | #44 |
| 12 | Fixed: the plain logo on Zuiddrecht's light blue dark bar | #47 |
| 13 | Fixed: plain `data-test-selector` attributes | #42 |
| 14 | Fixed: Apply comes before the list. The radio buttons were already one tab stop; the three links per card were the 200 | #49 |
| 15 | Fixed: a processing instruction counts as left out | #45 |
| 16 | Fixed: the layer over the bar stops where white keeps 4.5 to 1. Measured with Zuiddrecht active, not Cunningham | #48 |
| 17 | Fixed, as 16 | #48 |
| 18 | Documented in `docs/tokens.md` and the README | #52 |
| 19 | Fixed: `ready?` asks the database, not the schema cache; `docs/uploads.md` says what the pages do without the table | #46 |
| 20 | Ours (the shell's chevron next to core's triangle). Fixed | #51 |
| 21 | Ours (with the plugin's style tags disabled the row fits). Fixed: the toolbar wraps below 680 px | #51 |

### Blocker

1. **Blocker, data loss. A new custom design system at the limit overwrites the first one.** With 50 custom design systems, select **Customise** on any design system, give it a name and select **Save and apply**. Expected: the plugin refuses, as import and Figma upload do ("There are 50 custom design systems ... Delete one first"). Actual: it answers "is now the active design system" and the custom design system with id `custom` is replaced by the new one, without a word; its uploaded files now hang on the new one. Cause: `new_draft` and `custom_id_from_params` in `admin_controller.rb` fall back to the id `custom` when no id is free. Screenshot `c-too-many.png`. Fixed in the pull request named at the end.

### Major

2. **Major. Top bar on a project page at 1440 wide.** Open `/projects/demo-project/work_packages` at 1440 x 1000 as the admin "OpenProject Admin". Expected: the top bar fits the window. Actual: the three parts of the top bar add up to 1462 px, the account name is cut off at the right edge and the whole page scrolls 22 px sideways. It happens on every page where the current module tile shows its label (work packages, Gantt, cost reports, my time tracking). Home and the admin pages fit; at 1024 and 390 wide it fits too, because the row of tiles folds away. Screenshot `t1440-wptable.png`.
3. **Major, documentation. The commands in the docs do not run on the compose instance as written.** The README's "Remove the plugin" and `docs/uploads.md` name the container `openproject-thematiq`; the compose one is `openproject-thematiq-try-openproject-1`, so the command answers "No such container". With the right name, `rake db:migrate:down` and `rake db:migrate` work. The request check in `docs/admin-page.md` (`bin/rails runner`) does not: the compose file sets `SECRET_KEY_BASE` only for the main process, and every `rails runner` in `docker exec` stops with "INSECURE SECRET_KEY_BASE DETECTED". Prefixing the command with `SECRET_KEY_BASE=$(cat /var/openproject/secret/secret_key_base)` works.
4. **Major. An import loses the dark values.** Export a custom design system and import the file again. The file holds a `dark` block; the imported design system has the dark values of Cunningham instead (compare the two exports). A Figma upload of the W3C download keeps them. `admin_controller.rb#import` builds the draft without `dark:`.
5. **Major. Logo invisible in OpenProject's light high contrast theme.** My account, Interface, Light, **Increase contrast**, with Zuiddrecht active. OpenProject's high contrast top bar is pale grey (`#eff2f5`); the plugin still draws the white logo variant on it, so the logo nearly disappears. Screenshot `d-light-hc-wp.png`.

### Minor

6. **Minor. Table header height.** Work package table at 1440 wide. Canon 44 px, measured 45 px.
7. **Major, accessibility. The default design system makes all secondary text fail WCAG AA.** On a fresh install Cunningham is active, and its muted colour `#74777c` is 4.48 to 1 on white. The picker says so itself ("Low contrast, under 4.5 to 1: muted text on the page background"). axe counts 131 serious findings in the plugin's markup on the picker, the editor and the work package page, all of them this one colour: the line under each design system, the hints and role names in the editor, the editor's empty fields, the "Custom" and "Default" labels, and the group headings of the project menu ("PLAN", "WORK TOGETHER"). The colour comes from the catalogue, so the fix is a choice of value or of default, not code. Screenshot `a-picker-1440.png`.
8. **Minor. OpenProject's introduction tour points at a control that is gone.** First sign-in, select **Next** through the tour. The step "Use the return arrow in the top left corner to return to the project's main menu" points at the logo; the two-layer menu has no return arrow. Two steps also throw `TypeError: Cannot read properties of undefined (reading 'left')` (on Home and on the work package page), and the tour's close button sits on top of the account name. The tour does reach its end. Screenshots `a-tour-b2.png`, `a-home-after-lang.png`.
9. **Minor. The README is out of date.** It says 64 design systems (twice) and "a logo ships for 15 of the 64"; the picker lists 67. It says "It styles the light theme only", while the dark theme is styled. It says the shell leans on "eight files of OpenProject"; `script/check-core.rb` checks 17. It says "Removing the plugin was not tested"; see the experiments below.
10. **Minor. Search hides your own design systems.** Type a part of the name of a custom design system (for example "E2E") in **Search design systems**. Expected: it is found. Actual: "0 of 67 design systems"; custom ones are never searched, and the count never counts them.
11. **Minor. Delete has no confirmation.** **Delete this custom design system** deletes at once, uploaded files included, with no question. Removing an upload has no confirmation either.
12. **Minor. White logo on the light top bar of the dark theme.** Dark theme with Zuiddrecht: the top bar becomes light blue (`#84aad7`), the white logo variant on it has a contrast of about 2.3 to 1. Screenshot `d-dark-wp.png`.
13. **Minor, testing. Primer `test_selector` hooks never reach the page.** The image runs in production, where Primer drops `test_selector`. The hooks `thematiq-no-results`, `thematiq-rejected-banner` and `thematiq-catalogue-error` are therefore absent; the plain `data-test-selector` attributes in the plugin's own HTML do render. The end-to-end suite uses roles and texts for those three.
14. **Minor. 214 tab stops before Apply.** In the picker every design system has three links (Customise, Export, Figma), so a keyboard user tabs through about 200 stops to reach **Apply**. Enter on a selected radio button does apply, so it is usable.
15. **Minor. A cleaned SVG is not always reported.** Upload `hostile-processing-instruction.svg` as a logo: the processing instruction is removed, but the page says "The logo is uploaded and in use." without the note that parts were left out.

16. **Minor, accessibility. The search field in the top bar is under 4.5 to 1.** axe on every page with Cunningham: white text on the tinted field (`#4e7bb0`) is 4.38 to 1. The tint is a fixed white overlay on the primary colour, so a lighter primary makes it worse. A design question: how strong the tint may be.
17. **Minor, accessibility. The label of the current tile is under 4.5 to 1.** axe on the work package page with Cunningham: the small label "Work packages" under the current tile, white on `#5681b3`, is 4.04 to 1 at 11 px.
18. **Minor. "Increase contrast" is the only high contrast switch.** The two other checkboxes in My account, Interface (`force_light_theme_contrast`, `force_dark_theme_contrast`) are hidden in OpenProject 17.9.1; the earlier lane's script aimed at those, which is why it could not switch. By hand, **Increase contrast** works for light and dark.

19. **Minor. Right after the rollback of the uploads migration, the editor of a custom design system answers 500.** Roll back with `rake db:migrate:down VERSION=20261012090000` on a running instance, then open **Edit** on a custom design system: 500, `relation "thematiq_uploads" does not exist`. `Thematiq::Upload.ready?` asks `table_exists?`, which the running process still answers from its schema cache. `docs/uploads.md` says "No page fails". Other pages load, with OpenProject's own banner about pending migrations; the file route answers 503 as designed. A restart would run the migration again (the image's entrypoint migrates on start), so this only lasts until the plugin is removed, which the docs say to do next.

### Cosmetic

20. **Cosmetic. Two arrows next to "Sign in".** Sign-in page, not signed in, top bar right. Screenshot `v-login-1440.png`.
21. **Cosmetic. 390 wide, the work package toolbar starts left of the screen.** The **Create** button is cut off on the left. Screenshot `w390-wp.png`. Not checked whether OpenProject without the plugin does the same.

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
| Table header | 44 | 45 (44 since #41) |

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

## The README, followed as a newcomer

The path in "Try it locally with Docker" works as written, with one change: port 8080 is taken on the test machine, and the README's own advice (`THEMATIQ_PORT=8090 ...`) works. The first start took 3 minutes 30 seconds; the README says about three. The first sign-in with `admin` / `admin`, the forced password change and **Administration**, **Thematiq design** are where the README says. What does not work as written is everything after that which runs a command in the container: see finding 3.

## Existing checks on the fresh instance

| Check | Result |
|---|---|
| `bin/test` | 322 runs, 145,615 assertions, 0 failures. One warning: `transfer.rb:66` meets a duplicate key "primary" in a JSON test input, which json 3.0 will refuse |
| `bin/check-syntax` | ok |
| `script/check-core.rb` | ok, 17 core files match OpenProject 17.9.1 |
| `python3 -m unittest discover -s test/pixel` | ok |
| Request check `test/integration/admin_page_check.rb` | passes on the fresh instance, once `SECRET_KEY_BASE` is given (finding 3). 223 checks with the new section for finding 1 |
| Pixel check against the committed references | passes on the fresh instance: top bar and sidebar 0.00% different, once the demo project has its fresh set of modules again. With every module switched on the sidebar would differ, as the docs say |

## The two experiments that change the instance

### Rolling the uploads migration back and forward

With one uploaded logo in use on the active custom design system:

1. `docker exec openproject-thematiq bash -lc 'cd /app && bundle exec rake db:migrate:down VERSION=20261012090000'`, as the README writes it: "No such container" (finding 3). With the compose container's name it works: the table and the line in `schema_migrations` are gone, the setting `plugin_openproject_thematiq` stays.
2. While it is rolled back and OpenProject still runs: every page shows OpenProject's banner about pending migrations, the top bar falls back to OpenProject's logo, the file route answers 503, and the editor of a custom design system answers 500 (finding 19).
3. `bundle exec rake db:migrate`: the table is back, empty. The uploaded logo is gone for good and its address answers 404, as `docs/uploads.md` warns. The editor works again.

### Removing the plugin and putting it back

1. `docker compose down` (volumes kept), then the same service on the plain `openproject/openproject:17` image with the same volumes.
2. OpenProject starts in about two minutes and works: sign-in, Home, `/my/page` (OpenProject's own My page again), the work package table, Administration. **Plugins** says no plugins are installed. `/admin/thematiq`, `/thematiq/files/...` and `/thematiq/logos/...` answer 404. The look is OpenProject's own. No error in the log.
3. Left behind, as the docs say: the table `thematiq_uploads` with its one row, the line `20261012090000` in `schema_migrations`, the setting `plugin_openproject_thematiq`.
4. Back on the plugin's image: everything returns as it was. The active custom design system, its colours, its uploaded logo at the same address, all four custom design systems.

The docs are right about what stays and that OpenProject works with it. Wrong: the container name (finding 3), and the README's "Removing the plugin was not tested", which is now tested on the Docker route. Not said anywhere: the image's entrypoint runs the migrations on every start, so rolling back and then restarting with the plugin still installed brings the table back.

## The end-to-end suite

`test/e2e/`, described in [e2e.md](e2e.md): 8 spec files, 30 tests. Two of them are marked as expected to fail, for findings 2 and 6. The accessibility pass runs on Cunningham and treats findings 7, 16 and 17 as known; anything else in the plugin's markup fails it.

Local: 30 of 30 passed in two consecutive runs on this commit, with one worker (the second after the machine restarted and the instance came back on its volumes). Flaky along the way and fixed: a flash text matched both the banner and OpenProject's live region; the member's login collided with the member of the run before, which OpenProject deletes in a background job. CI: the workflow run on `1d01fbe` passed both jobs, unit tests and syntax in 51 s, end-to-end in 8 minutes 30 seconds.

### With the fixes of findings 2 to 21

All fix branches merged together locally, in pull request order (#40 to #52, #43 on top of #42), on `development` at `97e88ed`, and the instance rebuilt from that (OpenProject 17.9.1, port 8237, the volumes of this test).

| Check | Result |
|---|---|
| End-to-end suite, run 1 | 38 of 38 passed, one worker, 10.1 minutes |
| End-to-end suite, run 2, right after | 38 of 38 passed, 9.5 minutes |
| `bin/test` | 337 runs, 0 failures |
| `bin/check-syntax` | ok |
| `script/check-core.rb` | ok, 17 core files match OpenProject 17.9.1 |
| Request check | 232 checks, 0 failures, run with the README's `docker compose ... exec openproject bash -lc` command |
| `rake db:migrate:down VERSION=20261012090000` as the README writes it, on the running instance | Table dropped. The editor of a custom design system answers 200 and says the table is missing (finding 19); a file address answers 404. `rake db:migrate` brings the table back |
| Logo on Zuiddrecht, in the browser | Light: the variant for dark backgrounds on `#3669a5`. Dark theme attributes: the plain logo on `#84aad7`. Light high contrast (OpenProject's class on the logo): the plain logo on `#eff2f5` |

On the way, three things were red and fixed in their own pull requests: the tour's close button rule lost to the top EnjoyHint writes on the element (#50), the request check still looked for the logo rule's old selector (#47), and `docs/uploads.md` said the file route answers 503 without the table where it answers 404 (#46). A first attempt at the two runs is not counted: the branch of the checkout changed while it ran.

## Not done

- A real screen reader. Only axe and the keyboard.
- The two high contrast themes at 1024 and 390 wide, and the dark theme on every page; they were checked on the work package page, the picker and the editor.
- Gantt, Calendar, Team planner, Backlogs, Meetings, Wiki and Time and costs were opened and looked at, not used: no drag and drop, no editing.
- Opening a downloaded Figma file in Figma or Tokens Studio.
- A Tokens Studio folder of several files on upload: only single files were uploaded.
- Twelve fonts, and the limit of 12.
- Whether finding 21 (the cut-off toolbar at 390 wide) also happens without the plugin. Answered later by disabling the plugin's style tags in the page: it does not, it is ours.
