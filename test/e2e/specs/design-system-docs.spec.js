// cat-design-system-docs: the picker and the settings page link to a design system's own documentation, when it has one.
const { test, expect } = require("@playwright/test");
const { PICKER, flash, exported, createCustom, snapshot, restore } = require("../support/thematiq");

const option = (page, id) => page.locator(".thematiq-picker__option").filter({ has: page.locator(`#thematiq-set-${id}`) });

test.describe("design system documentation", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("a set of a design system with documentation links to it in a new tab", async ({ page }) => {
    await page.goto(PICKER);
    const link = option(page, "utrecht").locator('[data-test-selector="thematiq-docs-link"]');
    await expect(link).toHaveAttribute("href", "https://nldesignsystem.nl");
    await expect(link).toHaveAttribute("target", "_blank");
    await expect(link).toHaveAttribute("rel", "noopener noreferrer");
    await expect(link).toHaveAccessibleName(/opens in a new tab/);
    await expect(option(page, "hoog-contrast").locator('[data-test-selector="thematiq-docs-link"]')).toHaveCount(0);
  });

  test("a custom design system takes an address in the editor and keeps it in its export", async ({ page }) => {
    const id = await createCustom(page, { name: `E2E docs ${Date.now()}`, from: "hoog-contrast" });
    await page.goto(`/admin/thematiq/custom?id=${id}`);
    await page.locator("#thematiq-documentation-url").fill("javascript:alert(1)");
    await page.getByRole("button", { name: "Save and apply" }).click();
    await expect(flash(page).filter({ hasText: "Some values cannot be used" }).first()).toBeVisible();
    await expect(page.locator("#thematiq-documentation-url")).toHaveAttribute("aria-invalid", "true");

    await page.locator("#thematiq-documentation-url").fill("https://house-style.example.org/docs");
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
    const link = option(page, id).locator('[data-test-selector="thematiq-docs-link"]');
    await expect(link).toHaveAttribute("href", "https://house-style.example.org/docs");
    await expect(link).toHaveAttribute("rel", "noopener noreferrer");
    const active = page.locator('[data-test-selector="thematiq-active-docs"]');
    await expect(active).toHaveAttribute("href", "https://house-style.example.org/docs");
    await expect(active).toHaveAttribute("target", "_blank");
    expect((await exported(page, id)).documentation_url).toBe("https://house-style.example.org/docs");
  });

  test("an import with a script address is refused", async ({ page }) => {
    await page.goto(PICKER);
    const file = { id: "docs-e2e", name: "Docs e2e", tokens: { primary: "#aa0055" }, documentation_url: "javascript:alert(1)" };
    await page.setInputFiles("#thematiq-import-file", { name: "docs.json", mimeType: "application/json", buffer: Buffer.from(JSON.stringify(file)) });
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
    await expect(flash(page).filter({ hasText: "documentation address is not an http or https address" }).first()).toBeVisible();
  });
});
