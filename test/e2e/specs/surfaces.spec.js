// More surfaces: the brand stripe, the legal links in a footer, and a background behind the sign-in page.
const { test, expect } = require("@playwright/test");
const { PICKER, applySet, customIds, snapshot, restore, png, flash } = require("../support/thematiq");
const { config } = require("../support/env");

async function importSet(page, set) {
  const before = await customIds(page);
  await page.goto(PICKER);
  await page.setInputFiles("#thematiq-import-file", { name: `${set.id}.json`, mimeType: "application/json", buffer: Buffer.from(JSON.stringify(set)) });
  await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
  return (await customIds(page)).filter((id) => !before.includes(id))[0];
}

test.describe("surfaces", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  // The dossiq bar of the design has no stripe under it. The variable is on the page for the surfaces that draw it.
  test("a brand stripe is on the page and not under the top bar", async ({ page }) => {
    const id = await importSet(page, { id: "e2e-stripe", name: `E2E stripe ${Date.now()}`, tokens: { primary: "#2f6b4a" },
                                       vocabulary: { "brand-stripe-color-1": "#2f6b4a", "brand-stripe-color-2": "#f5b82e", "brand-stripe-color-3": "#2f6b4a",
                                                     "brand-stripe-height": "6px" } });
    await applySet(page, id);
    await page.goto("/projects");
    const stripe = await page.locator("body").evaluate((el) => getComputedStyle(el).getPropertyValue("--thematiq-v-brand-stripe"));
    expect(stripe).toContain("linear-gradient");
    expect(stripe.toLowerCase()).toContain("#f5b82e");
    const image = await page.locator(".op-app-header").evaluate((el) => getComputedStyle(el).backgroundImage);
    expect(image).toBe("none");
  });

  test("the legal links show at the end of every page and on the sign-in page", async ({ page, browser }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-footer-form");
    await form.getByLabel("Privacy statement").fill("https://example.org/privacy");
    await form.getByRole("button", { name: "Save links" }).click();
    await expect(flash(page).filter({ hasText: "The links are saved." }).first()).toBeVisible();
    try {
      await page.goto("/projects");
      await expect(page.locator('[data-test-selector="thematiq-footer"]').getByRole("link", { name: "Privacy statement" })).toHaveAttribute("href", "https://example.org/privacy");
      const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
      const signIn = await visitor.newPage();
      await signIn.goto("/login");
      await expect(signIn.locator('[data-test-selector="thematiq-footer"]')).toBeVisible();
      await visitor.close();
    } finally {
      await page.goto(PICKER);
      await page.locator("#thematiq-footer-form").getByLabel("Privacy statement").fill("");
      await page.locator("#thematiq-footer-form").getByRole("button", { name: "Save links" }).click();
    }
  });

  test("an uploaded sign-in background shows behind the sign-in page", async ({ page, browser }) => {
    const id = await importSet(page, { id: "e2e-background", name: `E2E background ${Date.now()}`, tokens: { primary: "#3669a5" } });
    await page.goto(`/admin/thematiq/custom?id=${id}`);
    const form = page.locator("#thematiq-file-login-background-form");
    await form.locator('input[type="file"]').setInputFiles({ name: "background.png", mimeType: "image/png", buffer: png(320, 240) });
    await Promise.all([page.waitForURL(new RegExp(`/admin/thematiq/custom\\?id=${id}$`)), form.locator('button[name="upload"]').click()]);
    await applySet(page, id);
    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const signIn = await visitor.newPage();
    await signIn.goto("/login");
    const image = await signIn.evaluate(() => getComputedStyle(document.body).backgroundImage);
    expect(image).toContain("/thematiq/files/");
    await visitor.close();
  });
});
