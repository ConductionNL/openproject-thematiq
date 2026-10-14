// The playground: OpenProject's components in a chosen design system, in the content area only.
const { test, expect } = require("@playwright/test");
const { PICKER, rgb, exported } = require("../support/thematiq");

test.describe("playground", () => {
  test("the components take the chosen design system, the top bar keeps the one in use", async ({ page }) => {
    const chosen = await exported(page, "zuiddrecht");
    await page.goto(PICKER);
    await page.locator('[data-test-selector="thematiq-playground-link"]').click();
    await page.getByLabel("Design system").selectOption("zuiddrecht");
    await page.getByRole("button", { name: "Show" }).click();
    await expect(page.locator('[data-test-selector="thematiq-playground"]')).toHaveAttribute("data-thematiq-playground-set", "zuiddrecht");
    await expect(page.locator('[data-thematiq-sample="button-primary"]')).toHaveCSS("background-color", rgb(chosen.tokens.action));
    await expect(page.locator("#openproject-thematiq-content")).toHaveCount(1);
  });
});
