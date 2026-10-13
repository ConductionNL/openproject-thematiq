// OpenProject's introduction tour on the plugin's shell (first full test, finding 8).
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const STORAGE = "openProject-onboardingTour";

test.describe("introduction tour", () => {
  test.afterEach(async ({ page }) => {
    await page.evaluate((key) => {
      try { window.onboardingTourInstance?.trigger("skip"); } catch (error) { /* no tour running */ }
      sessionStorage.removeItem(key);
    }, STORAGE).catch(() => {});
  });

  test("the Gantt part skips the return arrow the project menu does not have", async ({ page }) => {
    // The part of the tour that runs on the Gantt page once the work package part is done.
    await page.goto(`/projects/${config.project}/work_packages`);
    await page.evaluate((key) => sessionStorage.setItem(key, "wpFullViewTourFinished"), STORAGE);
    await page.goto(`/projects/${config.project}/gantt`);

    const description = page.locator(".enjoyhint_custom_desc, .enjoy_hint_label").first();
    await expect(description).toContainText("edit your project plan", { timeout: 30_000 });
    await page.locator(".enjoyhint_next_btn").first().click();

    // The next step is the one after the arrow: boards, or the general menu steps without boards.
    await expect(description).not.toContainText("edit your project plan");
    await expect(description).not.toContainText("return arrow");
    await expect(description).toHaveText(/\S/);

    // The close button sits below the top bar, not on the account button.
    const close = await page.locator(".enjoyhint_close_btn").boundingBox();
    const bar = await page.locator(".op-app-header").boundingBox();
    expect(close.y).toBeGreaterThanOrEqual(bar.y + bar.height);
  });
});
