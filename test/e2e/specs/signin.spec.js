// The sign-in page and the pages a visitor can reach carry the active design system.
const { test, expect } = require("@playwright/test");
const { rgb, barColour, activeSetId, exported } = require("../support/thematiq");
const { config } = require("../support/env");

test.describe("visitor", () => {
  let tokens;
  let bar;
  test.beforeAll(async ({ browser }) => {
    const admin = await browser.newPage({ baseURL: config.baseURL, storageState: ".auth/admin.json" });
    const set = await exported(admin, await activeSetId(admin));
    tokens = set.tokens;
    bar = barColour(set);
    await admin.close();
  });

  test.use({ storageState: { cookies: [], origins: [] } });

  // The sign-in page as Nextcloud Zuiddrecht draws it (werkplek/NcLogin): no top bar, the logo above a card on the
  // ground colour, core's own form in the card.
  test("the sign-in page is themed and has no top bar", async ({ page }) => {
    await page.goto("/login");
    await expect(page.locator("style#openproject-thematiq")).toHaveCount(1);
    await expect(page.locator(".op-app-header")).toBeHidden();
    await expect(page.locator("#content-wrapper")).toHaveCSS("background-color", rgb(tokens.ground));
    const card = page.locator("#login-form");
    await expect(card).toBeVisible();
    expect(Math.round((await card.boundingBox()).width)).toBe(420);
    await expect(page.locator('[data-test-selector="thematiq-sign-in-brand"]')).toBeVisible();
    // Core's form is untouched: its fields and its button.
    await expect(card.getByLabel(/Username/)).toBeVisible();
    await expect(card.getByLabel(/Password/)).toBeVisible();
    await expect(card.getByRole("button", { name: "Sign in" })).toBeVisible();
    const family = await page.locator("body").evaluate((body) => getComputedStyle(body).fontFamily);
    expect(family.split(",")[0].replace(/["']/g, "").trim()).toBe(tokens["font-family"].split(",")[0].replace(/["']/g, "").trim());
  });

  // First full test, finding 20: core's triangle and the shell's chevron both showed next to "Sign in".
  // The sign-in page has no bar now; a missing page has, with the button for a visitor.
  test("the sign-in button has one arrow", async ({ page }) => {
    await page.goto("/thematiq-e2e-no-such-page");
    const button = page.locator(".op-app-header--end > button.op-app-menu--item");
    await expect(button).toContainText("Sign in");
    await expect(button.locator(".Button-trailingVisual")).toBeHidden();
    const chevron = await button.locator(".Button-label").evaluate((label) => getComputedStyle(label, "::after").content);
    expect(chevron).not.toBe("none");
  });

  test("a missing page is themed and answers 404", async ({ page }) => {
    const response = await page.goto("/thematiq-e2e-no-such-page");
    expect(response.status()).toBe(404);
    // An error page has OpenProject's plain layout: the early variable layer and core's header in the primary colour,
    // without the shell (docs/layouts.md).
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
