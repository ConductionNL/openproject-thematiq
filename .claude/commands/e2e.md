---
description: Run the Playwright end-to-end suite against a running OpenProject with the plugin
argument-hint: "[spec file, e.g. specs/picker.spec.js]"
---
The suite in `test/e2e/` drives a real browser against a running instance. Read `docs/testing/e2e.md` first. Never run it against an instance people use.

1. Make sure an instance is up. If not, start the local one from the repository root and wait until `http://localhost:8080/login` answers (the first start takes a few minutes):

   ```bash
   docker compose -f docker/compose.yml up -d --build
   ```

2. Install and run the suite. `THEMATIQ_E2E_PASSWORD` is required; ask for it if it is not set.

   ```bash
   cd test/e2e
   npm ci
   npx playwright install chromium
   THEMATIQ_E2E_URL=http://localhost:8080 THEMATIQ_E2E_PASSWORD="$THEMATIQ_E2E_PASSWORD" npx playwright test $ARGUMENTS
   ```

3. Report passed, failed and flaky counts. The HTML report opens with `npm run report`.
