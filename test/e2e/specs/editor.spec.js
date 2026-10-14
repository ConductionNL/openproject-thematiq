// The style editor: the live preview follows typing, and a value the plugin cannot use blocks saving.
const { test, expect } = require("@playwright/test");
const { customIds, exported, snapshot, restore, activeSetId } = require("../support/thematiq");

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
  // The dark value of a colour: checked like the light one, kept and exported. Empty keeps the base's dark value.
  test("a dark value is checked, saved and exported", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto("/admin/thematiq/custom?from=cunningham");
      const dark = page.locator("#thematiq-dark-primary");
      await expect(dark).toBeVisible();
      await dark.fill("notacolour");
      await expect(dark).toHaveAttribute("aria-invalid", "true");
      await expect(page.locator("#thematiq-dark-primary-error")).toBeVisible();

      await page.locator("#thematiq-name").fill("E2E dark, must not be saved");
      const [refused] = await Promise.all([
        page.waitForResponse((r) => r.request().method() === "POST" && r.url().endsWith("/admin/thematiq/custom")),
        page.getByRole("button", { name: "Save and apply" }).click(),
      ]);
      expect(refused.status()).toBe(422);
      await expect(page.locator("#thematiq-dark-primary")).toHaveAttribute("aria-invalid", "true");
      await expect(page.locator("#thematiq-dark-primary")).toHaveValue("notacolour");

      await page.locator("#thematiq-dark-primary").fill("#112233");
      await expect(page.locator('[data-thematiq-row="primary"] [data-thematiq-dark-badge]')).toBeVisible();
      await expect(page.locator("[data-thematiq-total]")).toHaveText("1 value differs from the design system it is based on.");
      await page.locator("#thematiq-name").fill(`E2E dark ${Date.now()}`);
      await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      expect(file.dark.tokens.primary).toBe("#112233");
      expect(file.tokens.primary, "the light value stays the base's").not.toBe("#112233");

      await page.goto(`/admin/thematiq/custom?id=${added[0]}`);
      await expect(page.locator("#thematiq-dark-primary")).toHaveValue("#112233");
      // Reset clears the light and the dark value of the row together.
      await page.getByRole("button", { name: "Reset Primary", exact: true }).click();
      await expect(page.locator("#thematiq-dark-primary")).toHaveValue("");
    } finally {
      await restore(page, saved);
    }
  });

  // thematiq's opacity control: at full opacity #rrggbb, below it #rrggbbaa; the picker keeps the opacity.
  test("the opacity control writes an eight digit hex and the picker keeps it", async ({ page }) => {
    await page.goto("/admin/thematiq/custom?from=cunningham");
    const field = page.locator("#thematiq-token-primary-light");
    await field.fill("#154273");
    const opacity = page.getByLabel("Opacity of Primary, light", { exact: true });
    await expect(opacity).toHaveValue("100");
    await opacity.fill("50");
    await expect(field).toHaveValue("#15427380");
    await expect.poll(() => preview(page, "primary-light")).toBe("#15427380");

    await page.getByLabel("Pick a colour for Primary, light", { exact: true }).evaluate((input) => {
      input.value = "#01689b";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await expect(field).toHaveValue("#01689b80");

    // A typed eight digit hex moves the opacity control.
    await field.fill("#154273cc");
    await expect(opacity).toHaveValue("80");
    await opacity.fill("100");
    await expect(field).toHaveValue("#154273");

    // The dark field has the same two controls.
    await expect(page.getByLabel("Opacity of Primary, light in the dark theme", { exact: true })).toBeVisible();
  });

  // A module's design system styles the content only: the preview shows the top bar and the menu in the instance's colours.
  test("the preview shows what a module's design system reaches", async ({ page }) => {
    const activeId = await activeSetId(page);
    const instance = (await exported(page, activeId)).tokens.primary;
    await page.goto("/admin/thematiq/custom?from=cunningham");
    await page.locator("#thematiq-token-primary").fill("#ffee00");
    const bar = page.locator('[data-test-selector="thematiq-shell-preview"] .thematiq-shell__bar');
    const main = page.locator('[data-test-selector="thematiq-shell-preview"] .thematiq-shell__main');
    const value = (locator) => locator.evaluate((el) => getComputedStyle(el).getPropertyValue("--tqp-primary").trim());
    await expect.poll(() => value(bar)).toBe("#ffee00");

    await page.getByLabel("Show the preview as the design system of").selectOption("module");
    await expect(page.locator('[data-thematiq-scope-hint="module"]')).toBeVisible();
    await expect.poll(() => value(bar)).toBe(instance);
    await expect.poll(() => value(main)).toBe("#ffee00");

    await page.getByLabel("Show the preview as the design system of").selectOption("page");
    await expect.poll(() => value(bar)).toBe("#ffee00");
  });
  // thematiq's primary lock: the main button follows the primary colour. And the sign-in page has a picture of its own.
  test("the primary lock puts the main button on the primary colour, and the sign-in picture follows", async ({ page }) => {
    const saved = await snapshot(page);
    try {
      await page.goto("/admin/thematiq/custom?from=cunningham");
      const signin = page.locator('[data-test-selector="thematiq-signin-preview"]');
      const value = (name) => signin.evaluate((el, property) => el.style.getPropertyValue(property), name);
      await page.locator("#thematiq-token-primary").fill("#aa0055");
      await page.locator("#thematiq-token-action").fill("#00aa55");
      await expect.poll(() => value("--tqp-primary")).toBe("#aa0055");
      await expect.poll(() => value("--tqp-action")).toBe("#00aa55");

      await page.getByLabel("The main button follows the primary colour").check();
      await expect.poll(() => value("--tqp-action")).toBe("#aa0055");
      await expect.poll(() => preview(page, "action")).toBe("#aa0055");
      await expect(page.locator("#thematiq-token-action")).toHaveValue("#00aa55");

      await page.locator("#thematiq-name").fill(`E2E primary lock ${Date.now()}`);
      await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
      const added = (await customIds(page)).filter((id) => !saved.customs.includes(id));
      expect(added).toHaveLength(1);
      const file = await exported(page, added[0]);
      expect(file.tokens.action).toBe("#aa0055");

      await page.goto(`/admin/thematiq/custom?id=${added[0]}`);
      await expect(page.getByLabel("The main button follows the primary colour")).toBeChecked();
      await expect(page.locator("#thematiq-token-action")).toHaveValue("#00aa55");
    } finally {
      await restore(page, saved);
    }
  });
});
