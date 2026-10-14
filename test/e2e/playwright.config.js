// End-to-end tests of the plugin against a running OpenProject. See docs/testing/e2e.md.
//
// Environment:
//   THEMATIQ_E2E_URL               the address of OpenProject, default http://localhost:8080
//   THEMATIQ_E2E_USER              an administrator, default "admin"
//   THEMATIQ_E2E_PASSWORD          that administrator's password (required)
//   THEMATIQ_E2E_INITIAL_PASSWORD  the password of a fresh install, default "admin". When it still works,
//                                  the global setup changes it to THEMATIQ_E2E_PASSWORD.
const { defineConfig, devices } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./specs",
  outputDir: ".results/artifacts",
  globalSetup: require.resolve("./support/global-setup.js"),
  globalTeardown: require.resolve("./support/global-teardown.js"),
  // The specs change the active design system of one installation. Two at once would see each other's colours.
  workers: 1,
  fullyParallel: false,
  retries: 0,
  // Generous: the machine that runs the suite is often loaded by other work, and the editor page is large.
  timeout: 180_000,
  expect: { timeout: 15_000 },
  reporter: [["list"], ["html", { outputFolder: ".results/report", open: "never" }]],
  use: {
    baseURL: (process.env.THEMATIQ_E2E_URL || "http://localhost:8080").replace(/\/+$/, ""),
    storageState: ".auth/admin.json",
    viewport: { width: 1440, height: 1000 },
    locale: "en-GB",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    actionTimeout: 20_000,
    navigationTimeout: 60_000,
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 1000 } } }],
});
