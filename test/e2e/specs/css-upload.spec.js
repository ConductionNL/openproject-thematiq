// A CSS file of design tokens, as thematiq writes a token set, becomes a custom design system.
const { test, expect } = require("@playwright/test");
const { PICKER, customIds, exported, snapshot, restore, flash } = require("../support/thematiq");

const CSS = `:root {
  --brand-red: #c8102e;
  --nldesign-color-primary: var(--brand-red);
  --nldesign-color-error: #d52b1e;
  --nldesign-border-radius: 6px;
  --something-else: 4px;
}
@media (prefers-color-scheme: dark) { :root { --nldesign-color-primary: #ff8099; } }`;

test.describe("CSS upload", () => {
  test("a token file becomes a custom design system, with what was left out named", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto(PICKER);
      const form = page.locator("#thematiq-css-upload");
      await form.locator('input[type="file"]').setInputFiles({ name: "voorbeeld.css", mimeType: "text/css", buffer: Buffer.from(CSS) });
      await form.getByLabel("Name").fill(`E2E CSS ${Date.now()}`);
      await form.getByRole("button", { name: "Read the CSS file" }).click();
      const report = page.locator('[data-test-selector="thematiq-css-report"]');
      await expect(report).toContainText("values were read");
      await expect(page.locator('[data-test-selector="thematiq-css-skipped"]')).toContainText("--something-else");

      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      expect(file.tokens.primary).toBe("#c8102e");
      expect(file.tokens.radius).toBe("6px");
      expect(file.vocabulary["color-error"]).toBe("#d52b1e");
      expect(file.dark.tokens.primary).toBe("#ff8099");
    } finally {
      await restore(page, saved);
    }
  });

  test("a file the plugin cannot read is refused", async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-css-upload");
    await form.locator('input[type="file"]').setInputFiles({ name: "bad.css", mimeType: "text/css", buffer: Buffer.from("body { color: red; }") });
    await form.getByRole("button", { name: "Read the CSS file" }).click();
    await expect(flash(page).filter({ hasText: "holds no token the plugin knows" }).first()).toBeVisible();
  });
});
