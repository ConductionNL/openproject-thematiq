// "Start from your colours": a name and two colours open in the editor, unsaved; saving makes a custom design system.
const { test, expect } = require("@playwright/test");
const { PICKER, customIds, exported, snapshot, restore } = require("../support/thematiq");

test.describe("short form", () => {
  test("two colours open in the editor, unsaved, and save as a custom design system", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto(PICKER);
      const form = page.locator("#thematiq-short-form-form");
      await form.getByLabel("Name").fill(`E2E short form ${Date.now()}`);
      await form.getByLabel("Main colour").fill("#c8102e");
      await form.getByLabel("Background colour").fill("#fafafa");
      await Promise.all([page.waitForURL(/\/admin\/thematiq\/from-colours$/), form.getByRole("button", { name: "Open in the editor" }).click()]);

      await expect(page.locator("#thematiq-token-primary")).toHaveValue("#c8102e");
      await expect(page.locator("#thematiq-token-action")).toHaveValue("#c8102e");
      await expect(page.locator("#thematiq-token-ground")).toHaveValue("#fafafa");
      await expect(page.locator('[data-thematiq-check="on-primary"]').first()).toContainText("to 1");
      await expect(page.getByText("Nothing is saved yet").first()).toBeVisible();

      await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      expect(file.tokens.primary).toBe("#c8102e");
      expect(file.tokens.ground).toBe("#fafafa");
    } finally {
      await restore(page, saved);
    }
  });

  test("a colour that is not a hex value is refused", async ({ page }) => {
    const token = await page.goto(PICKER).then(() => page.locator('#thematiq-short-form-form input[name="authenticity_token"]').inputValue());
    const response = await page.request.post("/admin/thematiq/from-colours", { form: { name: "x", primary: "red; }", background: "#ffffff", authenticity_token: token }, maxRedirects: 0 });
    expect(response.status()).toBe(302);
  });
});
