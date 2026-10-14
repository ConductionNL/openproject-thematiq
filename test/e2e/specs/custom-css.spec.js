// Your own CSS: off by default, checked part by part, served last on every page.
const { test, expect } = require("@playwright/test");
const { PICKER, flash } = require("../support/thematiq");

async function save(page, css, on) {
  await page.goto(PICKER);
  const form = page.locator("#thematiq-custom-css-form");
  await form.getByLabel("CSS", { exact: true }).fill(css);
  await form.getByLabel("Use this CSS on every page").setChecked(on);
  await form.getByRole("button", { name: "Save CSS" }).click();
}

test.describe("your own CSS", () => {
  test.afterEach(async ({ page }) => { await save(page, "", false); });

  test("a rule reaches every page once it is on", async ({ page }) => {
    await save(page, ".op-app-header { outline: 3px solid rgb(1, 2, 3); }", false);
    await expect(flash(page).filter({ hasText: "It is not in use" }).first()).toBeVisible();
    await page.goto("/projects");
    await expect(page.locator("#openproject-thematiq-custom")).toHaveCount(0);

    await save(page, ".op-app-header { outline: 3px solid rgb(1, 2, 3); }", true);
    await page.goto("/projects");
    await expect(page.locator(".op-app-header")).toHaveCSS("outline-color", "rgb(1, 2, 3)");
  });

  test("a hostile part refuses the whole submission and is named", async ({ page }) => {
    await save(page, "a { color: red; }\nbody { background: url(https://tracker.example/p.png); }", true);
    await expect(page.locator('[data-test-selector="thematiq-custom-css-errors"]')).toContainText("such as url()");
    await page.goto("/projects");
    await expect(page.locator("#openproject-thematiq-custom")).toHaveCount(0);
  });
});
