// The style editor: the live preview follows typing, and a value the plugin cannot use blocks saving.
const { test, expect } = require("@playwright/test");
const { customIds, exported, snapshot, restore } = require("../support/thematiq");

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
    await page.getByLabel("Pick a colour for Accent", { exact: true }).evaluate((input) => {
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
    await expect(page.getByText("Some values cannot be used. Correct the marked fields and save again.").filter({ visible: true }).first()).toBeVisible();
    await expect(page.locator("#thematiq-token-link")).toHaveAttribute("aria-invalid", "true");
    expect(await customIds(page)).toEqual(before);
  });

  // The full vocabulary: closed groups under "More values", found by search, checked like a role, kept and exported.
  test("a value of the full vocabulary is found, checked, saved and exported", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto("/admin/thematiq/custom?from=cunningham");
      await expect(page.getByRole("heading", { name: "More values" })).toBeVisible();
      const status = page.locator("details[data-thematiq-more]").filter({ has: page.locator('[data-thematiq-group="status"]') });
      await expect(status).not.toHaveAttribute("open", "");
      await expect(page.locator("#thematiq-token-color-error")).toBeHidden();

      // A search opens the group that holds a match.
      await page.locator("[data-thematiq-search]").fill("--nldesign-color-error");
      await expect(status).toHaveAttribute("open", "");
      const field = page.locator("#thematiq-token-color-error");
      await field.fill("#D52B1E");
      await expect(page.locator('[data-thematiq-row="color-error"] [data-thematiq-badge]')).toBeVisible();
      await expect(page.locator("[data-thematiq-total]")).toHaveText("1 value differs from the design system it is based on.");

      // A value the kind refuses is marked at once, and the server refuses it too.
      const channels = page.locator("#thematiq-token-color-error-rgb");
      await channels.fill("300, 0, 0");
      await expect(channels).toHaveAttribute("aria-invalid", "true");
      await page.locator("#thematiq-name").fill("E2E vocabulary, must not be saved");
      const [refused] = await Promise.all([
        page.waitForResponse((r) => r.request().method() === "POST" && r.url().endsWith("/admin/thematiq/custom")),
        page.getByRole("button", { name: "Save and apply" }).click(),
      ]);
      expect(refused.status()).toBe(422);
      await expect(page.locator("#thematiq-token-color-error-rgb-error")).toBeVisible();

      // The page that refused the value keeps the group open and the other value typed.
      await expect(page.locator("#thematiq-token-color-error")).toHaveValue("#d52b1e");
      await page.locator("#thematiq-token-color-error-rgb").fill("213, 43, 30");
      await page.locator("#thematiq-name").fill(`E2E vocabulary ${Date.now()}`);
      await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      // The export holds the base design system's vocabulary too, with the two values typed here on top.
      expect(file.vocabulary).toMatchObject({ "color-error": "#d52b1e", "color-error-rgb": "213, 43, 30" });

      // The stored value comes back in the editor, in an open group.
      await page.goto(`/admin/thematiq/custom?id=${added[0]}`);
      await expect(page.locator("#thematiq-token-color-error")).toHaveValue("#d52b1e");
      await expect(page.locator("#thematiq-token-color-error")).toBeVisible();
    } finally {
      await restore(page, saved);
    }
  });
});
