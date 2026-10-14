// The environment marker on every page, and deprecated tokens: shown in the editor, read by other apps, no value changed.
const { test, expect } = require("@playwright/test");
const { PICKER, flash } = require("../support/thematiq");
const { config } = require("../support/env");

test.describe("governance", () => {
  test("the environment marker shows on every page, the sign-in page too, and goes away", async ({ page, browser }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-marker-form");
    await form.getByLabel("Label").fill("Test");
    await form.getByRole("button", { name: "Save marker" }).click();
    await expect(flash(page).filter({ hasText: "The environment marker is saved." }).first()).toBeVisible();
    try {
      await page.goto("/projects");
      await expect(page.locator('[data-test-selector="thematiq-environment-marker"]')).toHaveText("Test");
      const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
      const signIn = await visitor.newPage();
      await signIn.goto("/login");
      await expect(signIn.locator('[data-test-selector="thematiq-environment-marker"]')).toHaveText("Test");
      await visitor.close();
    } finally {
      await page.goto(PICKER);
      await page.locator("#thematiq-marker-form").getByLabel("Label").fill("");
      await page.locator("#thematiq-marker-form").getByRole("button", { name: "Save marker" }).click();
    }
    await page.goto("/projects");
    await expect(page.locator('[data-test-selector="thematiq-environment-marker"]')).toHaveCount(0);
  });

  test("a deprecated token shows in the editor and in the read endpoint, and is removed again", async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-deprecation-form");
    await form.getByLabel("Token").selectOption("accent");
    await form.getByLabel("Severity").selectOption("critical");
    await form.getByLabel("Use instead").selectOption("color-error");
    await form.getByRole("button", { name: "Save deprecation" }).click();
    await expect(flash(page).filter({ hasText: "The deprecation is saved." }).first()).toBeVisible();
    try {
      await page.goto("/admin/thematiq/custom?from=cunningham");
      await expect(page.locator('[data-thematiq-deprecated="accent"]')).toContainText("Deprecated (critical)");
      await expect(page.locator('[data-thematiq-deprecated="accent"]')).toContainText("Use color-error instead.");
      const answer = await (await page.request.get("/thematiq/api/v1/deprecations")).json();
      const entry = answer.deprecations.find((item) => item.key === "accent");
      expect(entry).toMatchObject({ severity: "critical", replacement: "color-error", replacement_css_name: "--nldesign-color-error" });
    } finally {
      await page.goto(PICKER);
      const remove = page.getByRole("button", { name: "Remove the deprecation of accent" });
      if (await remove.count()) await remove.click();
    }
    await expect(page.locator('[data-thematiq-deprecation="accent"]')).toHaveCount(0);
  });
});
