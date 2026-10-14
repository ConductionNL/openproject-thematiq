// The history: every change leaves a row with who made it, and an earlier version can be restored after a dry run.
const { test, expect } = require("@playwright/test");
const { activeSetId, applySet, snapshot, restore, flash } = require("../support/thematiq");

test.describe("history", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("a change is listed with who made it, and restoring a version shows what it changes first", async ({ page }) => {
    await applySet(page, "zuiddrecht");
    await applySet(page, "amsterdam");

    await page.goto("/admin/thematiq");
    await page.locator('[data-test-selector="thematiq-history-link"]').click();
    await expect(page).toHaveURL(/\/admin\/thematiq\/history$/);
    const rows = page.locator('[data-test-selector="thematiq-history"] tbody tr');
    await expect(rows.first()).toContainText("Applied a design system");
    await expect(rows.first()).toContainText("Gemeente Amsterdam");
    await expect(rows.first()).toContainText("OpenProject Admin");
    await expect(rows.nth(1)).toContainText("Gemeente Zuiddrecht");

    // The version after the switch to Zuiddrecht: the dry run says the design system goes back, and writes nothing.
    await rows.nth(1).getByRole("link", { name: /Restore the version of/ }).click();
    const changes = page.locator('[data-test-selector="thematiq-bundle-changes"]');
    await expect(changes).toContainText("The design system in use goes from Gemeente Amsterdam to Gemeente Zuiddrecht.");
    expect(await activeSetId(page)).toBe("amsterdam");

    await page.goBack();
    await page.goBack();
    await rows.nth(1).getByRole("link", { name: /Restore the version of/ }).click();
    await Promise.all([page.waitForURL(/\/admin\/thematiq\/history$/), page.getByRole("button", { name: "Restore this version" }).click()]);
    await expect(flash(page).filter({ hasText: "is restored" }).first()).toBeVisible();
    await expect(rows.first()).toContainText("Restored a version");
    expect(await activeSetId(page)).toBe("zuiddrecht");
  });

  test("an unknown version answers 404", async ({ page }) => {
    const response = await page.request.get("/admin/thematiq/history/999999999");
    expect(response.status()).toBe(404);
  });
});
