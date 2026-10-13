// The sign-in page and the pages a visitor can reach carry the active design system.
const { test, expect } = require("@playwright/test");
const { rgb, activeSetId, exported } = require("../support/thematiq");
const { config } = require("../support/env");

test.describe("visitor", () => {
  let tokens;
  test.beforeAll(async ({ browser }) => {
    const admin = await browser.newPage({ baseURL: config.baseURL, storageState: ".auth/admin.json" });
    tokens = (await exported(admin, await activeSetId(admin))).tokens;
    await admin.close();
  });

  test.use({ storageState: { cookies: [], origins: [] } });

  test("the sign-in page is themed", async ({ page }) => {
    await page.goto("/login");
    await expect(page.locator("style#openproject-thematiq")).toHaveCount(1);
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(tokens.primary));
    await expect(page.locator(".op-app-header")).toHaveCSS("height", "68px");
    const family = await page.locator("body").evaluate((body) => getComputedStyle(body).fontFamily);
    expect(family.split(",")[0].replace(/["']/g, "").trim()).toBe(tokens["font-family"].split(",")[0].replace(/["']/g, "").trim());
  });

  test("a missing page is themed and answers 404", async ({ page }) => {
    const response = await page.goto("/thematiq-e2e-no-such-page");
    expect(response.status()).toBe(404);
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(tokens.primary));
  });

  test("the admin page sends a visitor to the sign-in page", async ({ page }) => {
    for (const path of ["/admin/thematiq", "/admin/thematiq/custom", "/admin/thematiq/export?id=cunningham", "/admin/thematiq/figma"]) {
      const response = await page.request.get(path, { maxRedirects: 0 });
      expect(response.status(), path).toBe(302);
      expect(response.headers().location, path).toContain("/login");
    }
  });
});
