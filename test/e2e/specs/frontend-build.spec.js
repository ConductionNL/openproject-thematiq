// Which route the instance runs: the default image keeps OpenProject's prebuilt frontend, the frontend route
// rebuilds it with the plugin's Angular module. Set THEMATIQ_E2E_FRONTEND=1 against a frontend route instance.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.describe("frontend route", () => {
  test("the plugin's module runs in the bundle only on the frontend route", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    await expect(page.locator("table.work-package-table tbody tr").first()).toBeVisible();
    const marker = await page.locator("html").getAttribute("data-thematiq-frontend");
    expect(marker).toBe(config.frontendRoute ? "linked" : null);
  });

  test("the admin page says which frontend runs", async ({ page }) => {
    await page.goto("/admin/thematiq");
    const status = page.locator('[data-test-selector="thematiq-frontend-build"]');
    await expect(status).toHaveAttribute("data-state", config.frontendRoute ? "current" : "absent");
    await expect(status).toContainText(config.frontendRoute ? "rebuilt with the plugin's own module" : "prebuilt frontend");
  });
});
