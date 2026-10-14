// Your own tokens: --thematiq-org-<name> on every page, light and dark, and listed for other apps.
const { test, expect } = require("@playwright/test");
const { PICKER, flash } = require("../support/thematiq");

test.describe("own tokens", () => {
  test("an own token reaches every page and the read endpoint, and is removed again", async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-own-token-form");
    await form.getByLabel("Name").fill("e2e-ribbon");
    await form.getByLabel("Label").fill("E2E ribbon");
    await form.getByLabel("Kind").selectOption("color");
    await form.getByLabel("Value", { exact: true }).fill("#c8102e");
    await form.getByLabel("Dark value").fill("#ff8099");
    await form.getByRole("button", { name: "Save token" }).click();
    await expect(flash(page).filter({ hasText: "--thematiq-org-e2e-ribbon is saved" }).first()).toBeVisible();
    try {
      await page.goto("/projects");
      const value = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--thematiq-org-e2e-ribbon").trim());
      expect(value).toBe("#c8102e");
      const list = await (await page.request.get("/thematiq/api/v1/own-tokens")).json();
      expect(list.own_tokens.find((token) => token.name === "e2e-ribbon")).toMatchObject({ value: "#c8102e", dark: "#ff8099" });
    } finally {
      await page.goto(PICKER);
      const remove = page.getByRole("button", { name: "Remove --thematiq-org-e2e-ribbon" });
      if (await remove.count()) await remove.click();
    }
    await expect(page.locator('[data-thematiq-own-token="e2e-ribbon"]')).toHaveCount(0);
  });
});
