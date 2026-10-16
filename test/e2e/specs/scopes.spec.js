// A design system per project and per module: the whole page follows a project, Turbo swaps it when you leave,
// and a module's design system reaches the content area only.
const { test, expect } = require("@playwright/test");
const { PICKER } = require("../support/thematiq");
const { config } = require("../support/env");

const DESIGN = `/projects/${config.project}/settings/design`;
// The design system of the page's frame, top bar included: its primary colour. Many sets share a white bar.
const bar = (page) => page.locator(".op-app-header").evaluate((el) => getComputedStyle(el).getPropertyValue("--thematiq-primary").trim().toLowerCase());

async function chooseForProject(page, id) {
  await page.goto(DESIGN);
  await page.locator("#thematiq-project-design").selectOption(id);
  await Promise.all([page.waitForURL(/settings\/design/), page.getByRole("button", { name: "Save" }).click()]);
}

async function chooseForModule(page, name, id) {
  await page.goto(PICKER);
  await page.locator(`#thematiq-module-${name}`).selectOption(id);
  await Promise.all([page.waitForURL(/\/admin\/thematiq/), page.locator("#thematiq-scopes-form").getByRole("button", { name: "Save" }).click()]);
}

test.describe("scopes", () => {
  test.afterEach(async ({ page }) => {
    await chooseForProject(page, "");
    await chooseForModule(page, "meetings", "");
  });

  test("a project's design system styles its whole page and Turbo swaps it on the way out and back", async ({ page }) => {
    await page.goto("/projects");
    const instanceBar = await bar(page);

    await chooseForProject(page, "amsterdam");
    await expect(page.locator('[data-test-selector="thematiq-project-source"]')).toContainText("It is chosen for this project.");
    await page.goto(`/projects/${config.project}/work_packages`);
    await expect.poll(() => bar(page)).not.toBe(instanceBar);
    const projectBar = await bar(page);

    // Leave the project by a link, the way Turbo moves, and come back by a link.
    await page.getByRole("button", { name: "All apps and modules" }).click();
    const switcher = page.getByRole("dialog", { name: "All apps and modules" });
    // "Portfolios" has "Projects grouped as portfolios" as its second line, so the name must match whole.
    await switcher.locator("[data-thematiq-switcher-entry]").filter({ has: page.locator(".thematiq-apps--name", { hasText: /^Projects$/ }) }).click();
    await page.waitForURL(/\/projects\/?$/);
    await expect.poll(() => bar(page)).toBe(instanceBar);
    await expect(page.locator("style#openproject-thematiq")).toHaveCount(1);
    await page.goBack();
    await page.waitForURL(/work_packages/);
    await expect.poll(() => bar(page)).toBe(projectBar);
    await expect(page.locator("style#openproject-thematiq")).toHaveCount(1);
  });

  test("a module's design system reaches the content of its pages, not the top bar", async ({ page }) => {
    await page.goto("/projects");
    const instanceBar = await bar(page);
    await chooseForModule(page, "meetings", "zuiddrecht");

    await page.goto("/meetings");
    await expect(page.locator("style#openproject-thematiq-content")).toHaveCount(1);
    expect(await bar(page)).toBe(instanceBar);
    const content = await page.locator("#content-wrapper").evaluate((el) => getComputedStyle(el).getPropertyValue("--thematiq-primary").trim());
    expect(content).toBe("#3669a5");

    // A page of another module has no content layer.
    await page.goto(`/projects/${config.project}/work_packages`);
    await expect(page.locator("style#openproject-thematiq-content")).toHaveCount(0);
  });

  test("projects may not choose until an administrator turns it on", async ({ page }) => {
    await page.goto(PICKER);
    await expect(page.locator("#thematiq-projects-may-choose")).not.toBeChecked();
  });
});
