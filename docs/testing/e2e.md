# End-to-end tests

The end-to-end suite drives a real browser against a running OpenProject with the plugin. It lives in `test/e2e/` with its own `package.json`, so the plugin gem gains no Node dependency.

## What it checks

| Spec | What |
|---|---|
| `signin.spec.js` | The sign-in page and a missing page carry the active design system; the admin page sends a visitor to sign in |
| `picker.spec.js` | The bundled design systems are listed, the search narrows, Apply changes the colour of the top bar for everyone |
| `editor.spec.js` | The live preview follows typing in each group, the colour picker and Reset work, a bad colour blocks saving |
| `transfer.spec.js` | A custom design system survives export, delete and import; a broken file is refused; each Figma format uploads again with the same values |
| `uploads.spec.js` | Each kind of upload shows where it should, hostile files are cleaned or refused, the public file route serves without a session and refuses near misses |
| `shell.spec.js` | The two-layer project menu, the row of tiles, Home and `/my/page`, the sizes of the canon |
| `member.spec.js` | An ordinary member gets the shell but no admin page and none of its actions |
| `narrow.spec.js` | At 390 px wide the work package toolbar stays on the screen |
| `quality.spec.js` | No console errors or content security policy violations on the main pages; an accessibility pass with axe on the picker, the editor, the work package page and the sign-in page |

Two tests are marked as expected to fail, because they check a known fault: the table header is 45 px instead of 44, and the top bar is wider than the window at 1440 on a module page. When one of them is fixed, Playwright reports the test as failed with "expected to fail, but passed". Remove the `test.fail()` line then.

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
