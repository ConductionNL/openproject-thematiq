// thematiq's full vocabulary on the page: a design system with vocabulary values reaches OpenProject's own elements,
// and a design system without them leaves OpenProject's own values in place.
const { test, expect } = require("@playwright/test");
const { PICKER, customIds, applySet, snapshot, restore } = require("../support/thematiq");

// Adds a design system from a file in the set shape, through the import form, and returns its id.
async function importSet(page, set) {
  const before = await customIds(page);
  await page.goto(PICKER);
  await page.setInputFiles("#thematiq-import-file", { name: `${set.id}.json`, mimeType: "application/json", buffer: Buffer.from(JSON.stringify(set)) });
  await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
  const added = (await customIds(page)).filter((id) => !before.includes(id));
  expect(added, "one design system imported").toHaveLength(1);
  return added[0];
}

const variable = (page, name) => page.evaluate((n) => getComputedStyle(document.body).getPropertyValue(n).trim(), name);

const BASE = { id: "e2e-vocabulary", name: `E2E vocabulary ${Date.now()}`, tokens: { primary: "#3669a5" } };

test.describe("vocabulary", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("status colours reach Primer's scales and OpenProject's own messages", async ({ page }) => {
    const before = { danger: await (async () => { await page.goto(PICKER); return variable(page, "--fgColor-danger"); })() };
    const id = await importSet(page, { ...BASE, vocabulary: { "color-error": "#cc0000", "component-status-badge-error-color": "#a30000",
                                                              "component-status-badge-error-background-color": "#fcedec", "color-success": "#1e6b2a" } });
    await applySet(page, id);

    await page.goto(PICKER);
    expect(await variable(page, "--fgColor-danger")).toBe("#a30000");
    expect(await variable(page, "--bgColor-danger-emphasis")).toBe("#cc0000");
    expect(await variable(page, "--bgColor-danger-muted")).toBe("#fcedec");
    expect(await variable(page, "--bgColor-success-emphasis")).toBe("#1e6b2a");
    expect(await variable(page, "--fgColor-attention"), "a key the set leaves out keeps OpenProject's own value").not.toBe("");
    expect(before.danger).not.toBe("#a30000");

    // OpenProject's own error message: an import of a broken file.
    await page.setInputFiles("#thematiq-import-file", { name: "broken.json", mimeType: "application/json", buffer: Buffer.from("{") });
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
    const message = page.locator(".op-toast.-error, .Banner--error, .flash.error").filter({ visible: true }).first();
    await expect(message).toBeVisible();
    // The icon of the banner is drawn in Primer's danger text colour, which the badge's text colour sets.
    await expect(message.locator(".Banner-visual svg")).toHaveCSS("color", "rgb(163, 0, 0)");
  });

  test("text on fills, lines, the focus ring and corners", async ({ page }) => {
    const id = await importSet(page, { ...BASE, name: `E2E vocabulary shape ${Date.now()}`,
                                       vocabulary: { "color-focus-rgb": "204, 0, 0", "color-focus": "rgba(204, 0, 0, 0.5)", "border-radius-small": "1px",
                                                     "border-radius-pill": "20px", "component-separator-border-color": "#00aa55" } });
    await applySet(page, id);

    await page.goto(PICKER);
    expect(await variable(page, "--focus-outlineColor"), "the opaque channels, not the see-through colour").toBe("rgb(204, 0, 0)");
    expect(await variable(page, "--borderRadius-small")).toBe("1px");
    expect(await variable(page, "--borderRadius-full")).toBe("20px");
    expect(await variable(page, "--borderColor-muted")).toBe("#00aa55");
    expect(await variable(page, "--fgColor-onEmphasis"), "a key the set leaves out keeps OpenProject's own value").toBe("#ffffff");

    // A Primer button focused by keyboard draws its ring in that colour.
    const apply = page.getByRole("button", { name: "Apply", exact: true });
    await apply.focus();
    await page.keyboard.press("Shift+Tab");
    await page.keyboard.press("Tab");
    await expect(apply).toBeFocused();
    await expect(apply).toHaveCSS("outline-color", "rgb(204, 0, 0)");
  });

  test("the default and the danger button take the set's states, the main button stays the action colour", async ({ page }) => {
    const id = await importSet(page, { ...BASE, name: `E2E vocabulary buttons ${Date.now()}`, tokens: { primary: "#3669a5", action: "#1f883d" },
                                       vocabulary: { "component-button-color": "#5b2e91", "component-button-border-color": "#00aa55",
                                                     "color-error": "#cc0000", "color-button-primary-background": "#154273" } });
    await applySet(page, id);

    await page.goto(`/admin/thematiq/custom?id=${id}`);
    const preview = page.getByRole("button", { name: "Preview", exact: true });
    await expect(preview).toHaveCSS("color", "rgb(91, 46, 145)");
    await expect(preview).toHaveCSS("border-top-color", "rgb(0, 170, 85)");
    await expect(page.getByRole("button", { name: "Delete this custom design system" })).toHaveCSS("color", "rgb(204, 0, 0)");
    await expect(page.getByRole("button", { name: "Save and apply" })).toHaveCSS("background-color", "rgb(31, 136, 61)");
  });
});
