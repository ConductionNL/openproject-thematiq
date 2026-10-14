// The font library: a font uploaded once reaches every design system whose font names its family.
const path = require("path");
const { test, expect } = require("@playwright/test");
const { REPO, PICKER, createCustom, snapshot, restore } = require("../support/thematiq");

const FONT = path.join(REPO, "public", "thematiq", "fonts", "barlow-latin-400-normal.woff2");

test.describe("font library", () => {
  test("a library font loads for a design system that names its family, and is removed again", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto(PICKER);
      const form = page.locator("#thematiq-library-form");
      await form.locator('input[type="file"]').setInputFiles(FONT);
      await form.getByLabel("Family name", { exact: true }).fill("E2E Library Sans");
      await form.getByRole("button", { name: "Add to the library" }).click();
      await expect(page.locator('[data-test-selector="thematiq-library-fonts"]')).toContainText("E2E Library Sans");

      await createCustom(page, { name: `E2E library ${Date.now()}`, tokens: { "font-family": "'E2E Library Sans', sans-serif" } });
      await page.goto("/projects");
      const faces = await page.locator("#openproject-thematiq-assets").textContent();
      expect(faces).toContain("font-family: 'E2E Library Sans'");
      await expect.poll(() => page.evaluate(() => document.fonts.check("16px 'E2E Library Sans'"))).toBe(true);
    } finally {
      await page.goto(PICKER);
      const remove = page.locator("#thematiq-library-form").getByRole("button", { name: /Remove the font E2E Library Sans/ });
      if (await remove.count()) {
        await remove.first().click();
        await page.getByRole("button", { name: "Remove the file" }).click();
      }
      await restore(page, saved);
    }
  });
});
