// The style editor: the live preview follows typing, and a value the plugin cannot use blocks saving.
const { test, expect } = require("@playwright/test");
const { customIds } = require("../support/thematiq");

const preview = (page, role) =>
  page.locator('[data-test-selector="thematiq-shell-preview"]').evaluate((el, name) => el.style.getPropertyValue(`--tqp-${name}`), role);

test.describe("editor", () => {
  test("the preview follows typing in each group", async ({ page }) => {
    await page.goto("/admin/thematiq/custom?from=cunningham");
    for (const [role, value] of [["primary", "#ffee00"], ["ground", "#fafafa"], ["action", "#c80000"], ["font-family", "Georgia, serif"], ["radius", "20px"]]) {
      await page.locator(`#thematiq-token-${role}`).fill(value);
      await expect.poll(() => preview(page, role), role).toBe(value);
      const row = page.locator(`[data-thematiq-row="${role}"]`);
      await expect(row.locator("[data-thematiq-badge]"), `${role} badge`).toBeVisible();
    }
    await expect(page.locator("[data-thematiq-total]")).toHaveText("5 values differ from the design system it is based on.");

    // The swatch's colour picker writes into the field, and the preview follows.
    await page.getByLabel("Pick a colour for Accent").evaluate((input) => {
      input.value = "#00aa55";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await expect(page.locator("#thematiq-token-accent")).toHaveValue("#00aa55");
    await expect.poll(() => preview(page, "accent")).toBe("#00aa55");

    // Reset puts one value back without leaving the page.
    await page.getByRole("button", { name: "Reset Primary", exact: true }).click();
    await expect(page.locator("#thematiq-token-primary")).toHaveValue("");
  });

  test("a bad colour is marked, never reaches the preview and blocks saving", async ({ page }) => {
    const before = await customIds(page);
    await page.goto("/admin/thematiq/custom?from=cunningham");
    const base = await preview(page, "link");
    const field = page.locator("#thematiq-token-link");
    await field.fill("notacolour");
    await expect(field).toHaveAttribute("aria-invalid", "true");
    await expect(page.locator("#thematiq-token-link-error")).toBeVisible();
    expect(await preview(page, "link")).toBe(base);

    await page.locator("#thematiq-token-muted").fill("red; } body { display: none");
    expect(await preview(page, "muted")).not.toContain("display");

    await page.locator("#thematiq-name").fill("E2E bad colour, must not be saved");
    const [response] = await Promise.all([
      page.waitForResponse((r) => r.request().method() === "POST" && r.url().endsWith("/admin/thematiq/custom")),
      page.getByRole("button", { name: "Save and apply" }).click(),
    ]);
    expect(response.status()).toBe(422);
    await expect(page.getByText("Some values cannot be used. Correct the marked fields and save again.")).toBeVisible();
    await expect(page.locator("#thematiq-token-link")).toHaveAttribute("aria-invalid", "true");
    expect(await customIds(page)).toEqual(before);
  });
});
