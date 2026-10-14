// An NL Design System theme converts, by thematiq's table, into a custom design system.
const { test, expect } = require("@playwright/test");
const { PICKER, customIds, exported, snapshot, restore } = require("../support/thematiq");

const THEME = `.voorbeeld-theme {
  --voorbeeld-color-primary: #c8102e;
  --utrecht-button-primary-action-background-color: var(--voorbeeld-color-primary);
  --utrecht-link-color: #9b0c23;
  --utrecht-page-max-inline-size: 1200px;
}`;

test.describe("NL Design System theme", () => {
  test("converts into a custom design system with a report", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto(PICKER);
      const form = page.locator("#thematiq-nlds-upload");
      await form.locator('input[type="file"]').setInputFiles({ name: "theme.css", mimeType: "text/css", buffer: Buffer.from(THEME) });
      await form.getByLabel("Name").fill(`E2E NLDS ${Date.now()}`);
      await form.getByRole("button", { name: "Convert the theme" }).click();
      const report = page.locator('[data-test-selector="thematiq-nlds-report"]');
      await expect(report).toContainText("brand prefix voorbeeld");
      await expect(page.locator('[data-thematiq-nlds-target="--nldesign-color-primary"]')).toContainText("from the theme");
      await expect(page.locator('[data-test-selector="thematiq-nlds-skipped"]')).toContainText("--utrecht-page-max-inline-size");

      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      expect(file.tokens.primary).toBe("#c8102e");
      expect(file.tokens.link).toBe("#9b0c23");
    } finally {
      await restore(page, saved);
    }
  });
});
