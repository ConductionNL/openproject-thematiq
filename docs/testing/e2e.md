# End-to-end tests

The end-to-end suite drives a real browser against a running OpenProject with the plugin. It lives in `test/e2e/` with its own `package.json`, so the plugin gem gains no Node dependency.

## What it checks

| Spec | What |
|---|---|
| `signin.spec.js` | The sign-in page and a missing page carry the active design system; the admin page sends a visitor to sign in |
| `bundle.spec.js` | The whole setup downloads as a file and comes back after a dry run; a hostile file is refused; the history downloads as CSV |
| `operations.spec.js` | The health report answers JSON for an administrator |
| `nlds.spec.js` | An NL Design System theme converts into a custom design system, with a report and what the table left out |
| `own-tokens.spec.js` | An own token reaches every page and the read endpoint |
| `picker.spec.js` | The bundled design systems are listed, the search narrows, Apply changes the colour of the top bar for everyone |
| `compliance.spec.js` | The contrast report lists the design system in use and downloads as JSON |
| `component-preview.spec.js` | Pasted CSS reads the design system's variables in a sandboxed frame that runs no script; CSS that reaches outward is refused |
| `css-upload.spec.js` | A CSS file of design tokens becomes a custom design system, with what was left out named; a file without tokens is refused |
| `custom-css.spec.js` | Your own CSS reaches every page once it is on; a part with `url()` refuses the whole submission |
| `editor.spec.js` | The live preview follows typing in each group, the colour picker and Reset work, a bad colour blocks saving; a value of the full vocabulary is found by search, checked, saved and exported |
| `transfer.spec.js` | A custom design system survives export, delete and import; a broken file is refused; each Figma format uploads again with the same values |
| `uploads.spec.js` | Each kind of upload shows where it should, hostile files are cleaned or refused, the public file route serves without a session and refuses near misses |
| `shell.spec.js` | The two-layer project menu, the row of tiles, Home and `/my/page`, the sizes of the canon |
| `top-bar.spec.js` | The field for the tiles of the top bar: an own row shows in its order, no row shows no tiles, an empty own row is refused |
| `api.spec.js` | The read endpoints for a signed-in person, and thematiq's shell-tokens answer without a session |
| `app-switcher.spec.js` | The list under the nine-dot button: heading, two columns, a second line, the current entry, Manage apps, `aria-expanded`, arrow keys and Escape; one column without a Nextcloud address |
| `icons.spec.js` | The icon library lists its sets and licences; an icon loads without a session |
| `library.spec.js` | A font in the library loads for a design system that names its family |
| `member.spec.js` | An ordinary member gets the shell but no admin page and none of its actions |
| `metrics.spec.js` | `/thematiq/metrics` answers 404 without `THEMATIQ_METRICS_TOKEN`; with it, 401 without the token and the text format with it. Set `THEMATIQ_E2E_METRICS_TOKEN` to check the second |
| `narrow.spec.js` | At 390 px wide the work package toolbar stays on the screen |
| `quality.spec.js` | No console errors or content security policy violations on the main pages; an accessibility pass with axe on the picker, the editor, the work package page and the sign-in page |
| `wave1.spec.js` | Each shipped design system says how much of the vocabulary it fills; a font named Marianne waits for the entitlement |
| `vocabulary.spec.js` | A design system with values of thematiq's full vocabulary, imported as a file, reaches Primer's variables and OpenProject's own elements; a key it leaves out keeps OpenProject's value |
| `schedule.spec.js` | A switch is planned, listed and cancelled (the switch itself is in the request check) |
| `playground.spec.js` | The playground draws OpenProject's components in a chosen design system, the content area only |
| `scopes.spec.js` | A project's design system styles its whole page, and leaving the project and coming back swaps the style tags (Turbo); a module's design system reaches the content only; projects may not choose by default |
| `gallery.spec.js` | The gallery is off by default and refuses an address that is not https; another product's link sets a person's light or dark choice once it is allowed |
| `governance.spec.js` | The environment marker on every page, the sign-in page too; a deprecated token in the editor and the read endpoint |
| `history.spec.js` | Each change is listed with who made it; restoring a version shows what it changes first, then brings it back |
| `short-form.spec.js` | Two colours open in the editor, unsaved, and save as a custom design system; a colour that is not a hex value is refused |
| `surfaces.spec.js` | A brand stripe under the top bar; the legal links on every page and the sign-in page; an uploaded sign-in background |
| `switch.spec.js` | The apply dialog lists what changes and applies nothing; Apply repaints the page without a reload; an unticked value is kept in a new custom design system; a trial is seen by the administrator only, then discarded or published |
| `tour.spec.js` | OpenProject's introduction tour skips the step at core's return arrow, which the project menu does not have, and its close button sits below the top bar |

A test that checks a known fault is marked with `test.fail()`. None is marked now: the two that were (the table header at 45 px, the top bar wider than the window on a module page) pass since findings 2 and 6 were fixed. When a marked test passes, Playwright reports it as failed with "expected to fail, but passed". Remove the `test.fail()` line then.

The accessibility pass fails only on serious or critical findings in the plugin's own markup: the admin pages of the plugin, the top bar and the project menu. Findings in OpenProject's own markup are attached to the report and do not fail the run.

## What a run changes

Each test puts the installation back as it found it: the active design system, and the list of custom design systems. The global setup adds one user, `thematiq-e2e-member`, as a member of the demo project; the global teardown removes it. Run it against a test instance, never against one people use: an interrupted run can leave a custom design system named "E2E ..." behind.

## Run it

You need Node 20 or later and a running OpenProject with the plugin and its demo data, for example the one from [Try it locally with Docker](../../README.md#try-it-locally-with-docker).

```bash
cd test/e2e
npm ci
npx playwright install chromium
THEMATIQ_E2E_URL=http://localhost:8080 THEMATIQ_E2E_PASSWORD='<admin password>' npm test
```

| Variable | Meaning | Default |
|---|---|---|
| `THEMATIQ_E2E_URL` | The address of OpenProject | `http://localhost:8080` |
| `THEMATIQ_E2E_USER` | An administrator | `admin` |
| `THEMATIQ_E2E_PASSWORD` | That administrator's password. Required | |
| `THEMATIQ_E2E_INITIAL_PASSWORD` | The password of a fresh install. When it still works, the setup changes it to `THEMATIQ_E2E_PASSWORD` | `admin` |
| `THEMATIQ_E2E_PROJECT` | The identifier of a project with work packages | `demo-project` |

On a fresh install, give any new password in `THEMATIQ_E2E_PASSWORD`: the setup signs in with `admin`, answers OpenProject's forced password change with it and closes the first-login dialogs.

The suite runs one test at a time, because the tests change the design system of one installation. `npm run report` opens the report of the last run, with a trace of each failed test.

## In CI

`.github/workflows/test.yml` runs `bin/test` and `bin/check-syntax` on every pull request. The end-to-end job builds the image, starts the compose instance and runs this suite; see the workflow for when it runs.
