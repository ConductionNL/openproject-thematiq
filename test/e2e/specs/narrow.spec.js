// The shell on a phone.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.describe("390 px wide", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  // First full test, finding 21: the toolbar of the work package page started left of the screen and cut off Create.
  test("the work package toolbar stays on the screen", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    const create = page.locator("button.add-work-package").first();
    await expect(create).toBeVisible();
    const items = await page.locator(".toolbar-container .toolbar-items").first().boundingBox();
    expect(items.x).toBeGreaterThanOrEqual(0);
    expect((await create.boundingBox()).x).toBeGreaterThanOrEqual(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBe(0);
  });
});
