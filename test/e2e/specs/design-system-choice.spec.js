// Whole design systems above the colour sets (cat-design-system-choice): each set names its design system, and the
// picker narrows to one of them.
const { test, expect } = require("@playwright/test");

test.describe("design system choice", () => {
  test("the picker narrows to La Suite and names it on each set", async ({ page }) => {
    await page.goto("/admin/thematiq");
    await expect(page.locator('#thematiq-set-utrecht ~ .thematiq-picker__text [data-test-selector="thematiq-design-system"]'))
      .toHaveAttribute("data-design-system", "nldesign");

    await page.locator("#thematiq-design-system-filter").selectOption("lasuite");
    await Promise.all([page.waitForLoadState("load"), page.locator("#thematiq-search-form").getByRole("button", { name: "Search" }).click()]);
    expect(new URL(page.url()).searchParams.get("ds")).toBe("lasuite");
    const ids = await page.locator('.thematiq-picker input[name="set_id"]').evaluateAll((inputs) => inputs.map((input) => input.value));
    expect(ids).toEqual(expect.arrayContaining(["lasuite", "frankendesk"]));
    expect(ids).not.toContain("utrecht");
    const badges = await page.locator('[data-test-selector="thematiq-design-system"]').evaluateAll((spans) => spans.map((span) => span.dataset.designSystem));
    expect(new Set(badges)).toEqual(new Set(["lasuite"]));
    await expect(page.locator("#thematiq-design-system-filter")).toHaveValue("lasuite");
  });

  test("an unknown design system shows every set", async ({ page }) => {
    await page.goto("/admin/thematiq?ds=..%2Fetc");
    await expect(page.locator("#thematiq-set-utrecht")).toHaveCount(1);
    await expect(page.locator("#thematiq-design-system-filter")).toHaveValue("");
  });
});
