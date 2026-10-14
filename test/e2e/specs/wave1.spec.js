// Small rows: how complete a design system is, and the confirmation Marianne asks for.
const path = require("path");
const { test, expect } = require("@playwright/test");
const { REPO, PICKER, flash } = require("../support/thematiq");

const FONT = path.join(REPO, "public", "thematiq", "fonts", "barlow-latin-400-normal.woff2");

test.describe("small rows", () => {
  test("each shipped design system says how much of thematiq's vocabulary it fills", async ({ page }) => {
    await page.goto(PICKER);
    await expect(page.locator('[data-test-selector="thematiq-completeness"]').first()).toContainText("values of thematiq's full vocabulary");
  });

  test("a font named Marianne is refused until the entitlement is confirmed", async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-library-form");
    await form.locator('input[type="file"]').setInputFiles(FONT);
    await form.getByLabel("Family name", { exact: true }).fill("Marianne");
    await form.getByRole("button", { name: "Add to the library" }).click();
    await expect(flash(page).filter({ hasText: "Marianne is reserved for French State administrations" }).first()).toBeVisible();
    await expect(page.locator('[data-test-selector="thematiq-library-fonts"]')).toHaveCount(0);
  });
});
