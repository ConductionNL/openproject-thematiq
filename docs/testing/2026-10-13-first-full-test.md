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

1. **Major. Top bar on a project page at 1440 wide.** Open `/projects/demo-project/work_packages` at 1440 x 1000 as the admin "OpenProject Admin". Expected: the top bar fits the window. Actual: the three parts of the top bar add up to 1462 px, the account name is cut off at the right edge and the whole page scrolls 22 px sideways. It happens on every page where the current module tile shows its label (work packages, Gantt, cost reports, my time tracking). Home and the admin pages fit. Screenshot `t1440-wptable.png`.
2. **Minor. Table header height.** Work package table at 1440 wide. Canon 44 px, measured 45 px.
3. **Minor. The default design system fails the plugin's own contrast check.** Open **Thematiq design** on a fresh install. Cunningham, marked "Default" and "Active", carries the line "Low contrast, under 4.5 to 1: muted text on the page background". Expected: the default passes. Screenshot `a-picker-1440.png`.
4. **Minor. OpenProject's introduction tour points at a control that is gone.** First sign-in, select **Next** through the tour. The step "Use the return arrow in the top left corner to return to the project's main menu" points at the logo; the two-layer menu has no return arrow. Two steps also throw `TypeError: Cannot read properties of undefined (reading 'left')` in the console (on Home and on the work package page), and the tour's close button sits on top of the account name. The tour does reach its end. Screenshots `a-tour-b2.png`, `a-home-after-lang.png`.
5. **Cosmetic. Two arrows next to "Sign in".** Sign-in page, not signed in, top bar right. "Sign in" has two downward arrows side by side. Screenshot `v-login-1440.png`.
6. **Minor. README counts are out of date.** The README says 64 design systems (twice) and "a logo ships for 15 of the 64"; the picker lists 67. It says "It styles the light theme only", while the dark theme is claimed as done. It says the shell leans on "eight files of OpenProject"; `script/check-core.rb` checks 17.

## Works

- The README's Docker path: build and first start took 3 minutes 30 seconds with the base image on disk. Sign-in with `admin` / `admin` and the forced password change work.
- **Thematiq design** is in the administration menu and on the administration overview. The picker lists 67 design systems.
- 35 pages opened at 1440 wide as admin with every module on: none answered 500, none logged a content security policy violation. Top bar 68 px and sidebar 264 px on all of them.
- `/my/page` redirects to Home.

## Not done yet

Everything else in the test plan. This list shrinks as the test goes on.
