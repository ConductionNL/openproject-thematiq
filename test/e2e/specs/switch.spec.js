// Switch safely: see what changes before applying, keep single values, apply without a reload, try a design system
// in your own session first.
const { test, expect } = require("@playwright/test");
const { PICKER, rgb, activeSetId, applySet, exported, customIds, snapshot, restore, flash } = require("../support/thematiq");
const { config } = require("../support/env");

async function openCompare(page, id) {
  await page.goto(PICKER);
  await page.locator(`#thematiq-set-${id}`).check();
  await Promise.all([page.waitForURL(/\/admin\/thematiq\/compare/), page.locator("#thematiq-picker-form").getByRole("button", { name: "Apply", exact: true }).click()]);
}

test.describe("switch safely", () => {
  let saved;
  test.beforeEach(async ({ page }) => {
    saved = await snapshot(page);
    if (saved.active !== "cunningham") await applySet(page, "cunningham");
  });
  test.afterEach(async ({ page }) => {
    // A trial lives in the session: end it, so later specs see what everyone sees.
    await page.goto(PICKER);
    const discard = page.locator('[data-test-selector="thematiq-trial-banner"]').getByRole("button", { name: "Discard" });
    if (await discard.count()) await discard.click();
    await restore(page, saved);
  });

  test("the dialog lists what changes, applies nothing, and Apply repaints the page without a reload", async ({ page }) => {
    const target = await exported(page, "zuiddrecht");
    await openCompare(page, "zuiddrecht");
    await expect(page.getByRole("heading", { name: `Apply ${target.name}` })).toBeVisible();
    const rows = page.locator('[data-test-selector="thematiq-compare-rows"] tbody tr');
    await expect(rows.first()).toBeVisible();
    await expect(page.locator('[data-thematiq-compare-row="primary"]')).toContainText(target.tokens.primary);
    expect(await activeSetId(page)).toBe("cunningham");

    await openCompare(page, "zuiddrecht");
    // A marker on the window survives only when the page does not load again.
    await page.evaluate(() => { window.__thematiqSamePage = true; });
    await page.locator("#thematiq-compare-form").getByRole("button", { name: "Apply", exact: true }).click();
    await expect(page.locator('[data-test-selector="thematiq-applied"]')).toContainText(`${target.name} is now the active design system`);
    expect(await page.evaluate(() => window.__thematiqSamePage)).toBe(true);
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(target.tokens.primary));
    expect(await activeSetId(page)).toBe("zuiddrecht");
  });

  test("a value left unticked is kept, in a new custom design system", async ({ page }) => {
    const before = await customIds(page);
    const current = await exported(page, "cunningham");
    const target = await exported(page, "zuiddrecht");
    await openCompare(page, "zuiddrecht");
    // The picture of after follows the box.
    const after = page.locator("[data-thematiq-after] [data-thematiq-preview]");
    await page.getByLabel("Primary", { exact: true }).uncheck();
    await expect.poll(() => after.evaluate((el) => el.style.getPropertyValue("--tqp-primary"))).toBe(current.tokens.primary);
    await page.locator("#thematiq-compare-form").getByRole("button", { name: "Apply", exact: true }).click();
    await expect(page.locator('[data-test-selector="thematiq-applied"]')).toContainText("with values kept");

    const added = (await customIds(page)).filter((id) => !before.includes(id));
    expect(added).toHaveLength(1);
    const kept = await exported(page, added[0]);
    expect(kept.tokens.primary).toBe(current.tokens.primary);
    expect(kept.tokens.link).toBe(target.tokens.link);
    expect(await activeSetId(page)).toBe(added[0]);
  });

  test("a trial is seen by the administrator only, then published or discarded", async ({ page, browser }) => {
    const target = await exported(page, "zuiddrecht");
    const current = await exported(page, "cunningham");
    await openCompare(page, "zuiddrecht");
    await Promise.all([page.waitForURL((url) => !url.pathname.startsWith("/admin")), page.getByRole("button", { name: "Try it yourself first" }).click()]);
    const banner = page.locator('[data-test-selector="thematiq-trial-banner"]');
    await expect(banner).toContainText(`Trial: ${target.name}.`);
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(target.tokens.primary));
    expect(await activeSetId(page)).toBe("cunningham");

    // Someone else, not signed in, sees the design system in use and no banner.
    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const other = await visitor.newPage();
    await other.goto("/login");
    await expect(other.locator(".op-app-header")).toHaveCSS("background-color", rgb(current.tokens.primary));
    await expect(other.locator('[data-test-selector="thematiq-trial-banner"]')).toHaveCount(0);
    await visitor.close();

    await banner.getByRole("button", { name: "Discard" }).click();
    await expect(page.locator('[data-test-selector="thematiq-trial-banner"]')).toHaveCount(0);
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(current.tokens.primary));

    await openCompare(page, "zuiddrecht");
    await Promise.all([page.waitForURL((url) => !url.pathname.startsWith("/admin")), page.getByRole("button", { name: "Try it yourself first" }).click()]);
    await page.locator('[data-test-selector="thematiq-trial-banner"]').getByRole("button", { name: "Publish to everyone" }).click();
    await expect(flash(page).filter({ hasText: "is published" }).first()).toBeVisible();
    expect(await activeSetId(page)).toBe("zuiddrecht");
  });
});
