// The whole setup as one file: download it, change the design, read the file back after a dry run. And the history as CSV.
const { test, expect } = require("@playwright/test");
const { PICKER, activeSetId, applySet, snapshot, restore, flash } = require("../support/thematiq");

test.describe("configuration file", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("the setup goes out as a file and comes back after a dry run", async ({ page }) => {
    await applySet(page, "zuiddrecht");
    const response = await page.request.get("/admin/thematiq/bundle");
    expect(response.status()).toBe(200);
    expect(response.headers()["content-disposition"]).toContain("attachment");
    const bundle = await response.json();
    expect(bundle.format).toBe("openproject-thematiq-bundle");
    expect(bundle.settings.active_id).toBe("zuiddrecht");

    await applySet(page, "amsterdam");
    await page.goto(PICKER);
    const form = page.locator("#thematiq-bundle-form");
    await form.locator('input[type="file"]').setInputFiles({ name: "setup.json", mimeType: "application/json", buffer: Buffer.from(JSON.stringify(bundle)) });
    await form.getByRole("button", { name: "Read the file" }).click();
    await expect(page.locator('[data-test-selector="thematiq-bundle-changes"]')).toContainText("The design system in use goes from Gemeente Amsterdam to Gemeente Zuiddrecht.");
    expect(await activeSetId(page)).toBe("amsterdam");

    await page.goBack();
    await form.locator('input[type="file"]').setInputFiles({ name: "setup.json", mimeType: "application/json", buffer: Buffer.from(JSON.stringify(bundle)) });
    await form.getByRole("button", { name: "Read the file" }).click();
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Import this setup" }).click()]);
    await expect(flash(page).filter({ hasText: "The setup from the file is in use." }).first()).toBeVisible();
    expect(await activeSetId(page)).toBe("zuiddrecht");
  });

  test("a hostile file is refused and changes nothing", async ({ page }) => {
    const before = await activeSetId(page);
    const bundle = await (await page.request.get("/admin/thematiq/bundle")).json();
    bundle.settings.customs = { custom: { name: "x", based_on: "cunningham", overrides: { primary: "red; } body { display: none" } } };
    await page.goto(PICKER);
    const form = page.locator("#thematiq-bundle-form");
    await form.locator('input[type="file"]').setInputFiles({ name: "setup.json", mimeType: "application/json", buffer: Buffer.from(JSON.stringify(bundle)) });
    await form.getByRole("button", { name: "Read the file" }).click();
    await expect(flash(page).filter({ hasText: "has a value the plugin refuses" }).first()).toBeVisible();
    expect(await activeSetId(page)).toBe(before);
  });

  test("the history downloads as CSV", async ({ page }) => {
    await applySet(page, "zuiddrecht");
    const response = await page.request.get("/admin/thematiq/history.csv");
    expect(response.status()).toBe(200);
    expect(response.headers()["content-type"]).toContain("text/csv");
    const lines = (await response.text()).trim().split("\n");
    expect(lines[0]).toBe("time,user,action,detail,restorable");
    expect(lines[1]).toContain(",apply,Gemeente Zuiddrecht,true");
  });
});
