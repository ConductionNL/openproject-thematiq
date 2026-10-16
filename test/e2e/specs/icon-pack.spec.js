// The icon pack (ast-icon-pack): an administrator picks a pack, and on the frontend route OpenProject's own icons,
// Angular and server rendered alike, take the pack's drawing. On the default route the admin page says why not.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

async function choose(page, value) {
  await page.goto("/admin/thematiq#thematiq-icon-pack");
  await page.locator("#thematiq-icon-pack-choice").selectOption(value);
  await Promise.all([page.waitForLoadState("load"), page.locator("#thematiq-icon-pack-form").getByRole("button", { name: "Save icon pack" }).click()]);
  await expect(page.getByText("The icon pack is saved.")).toBeVisible();
}

// Every mapped icon on the page, Angular (svg[<name>-icon]) and server rendered (svg.octicon-<name>), with its paths.
async function drawnIcons(page) {
  return page.evaluate(() => {
    const element = document.getElementById("thematiq-icon-pack-data");
    const pack = element ? JSON.parse(element.textContent) : null;
    if (!pack) return { pack: null, angular: [], server: [] };
    const paths = (svg) => Array.from(svg.querySelectorAll("path")).map((path) => path.getAttribute("d"));
    const angular = [];
    const server = [];
    Object.entries(pack.icons).forEach(([name, icon]) => {
      document.querySelectorAll(`svg[${name}-icon]`).forEach((svg) => angular.push({ name, drawn: paths(svg), expected: icon.paths }));
      document.querySelectorAll(`svg.octicon-${name}`).forEach((svg) => server.push({ name, drawn: paths(svg), expected: icon.paths }));
    });
    return { pack: pack.pack, marked: document.documentElement.getAttribute("data-thematiq-icon-pack"), angular, server };
  });
}

test.describe("icon pack", () => {
  test.afterEach(async ({ page }) => {
    await choose(page, "");
  });

  test("the chosen pack redraws OpenProject's icons on the frontend route", async ({ page }) => {
    await choose(page, "dsfr");
    const indicator = page.locator('[data-test-selector="thematiq-icon-pack-indicator"]');
    await expect(indicator).toHaveAttribute("data-pack", "dsfr");
    await expect(indicator).toHaveAttribute("data-source", "override");
    await expect(indicator).toContainText("You chose the pack DSFR for every design system.");

    if (!config.frontendRoute) {
      await expect(indicator).toContainText("this instance runs the default route");
      await expect(page.locator("#thematiq-icon-pack-data")).toHaveCount(0);
      return;
    }
    await expect(indicator).not.toContainText("default route");

    await page.goto(`/projects/${config.project}/work_packages`);
    await expect(page.locator("table.work-package-table tbody tr").first()).toBeVisible();
    const work = await drawnIcons(page);
    expect(work.pack).toBe("dsfr");
    expect(work.marked).toBe("dsfr");
    expect(work.angular.length, "Angular icons the pack maps on the work package page").toBeGreaterThan(0);
    work.angular.forEach((icon) => expect(icon.drawn, icon.name).toEqual(icon.expected));

    await page.goto("/admin/thematiq");
    const admin = await drawnIcons(page);
    expect(admin.server.length, "server rendered icons the pack maps on the admin page").toBeGreaterThan(0);
    admin.server.forEach((icon) => expect(icon.drawn, icon.name).toEqual(icon.expected));
  });

  test("none keeps OpenProject's own icons", async ({ page }) => {
    await choose(page, "none");
    await expect(page.locator('[data-test-selector="thematiq-icon-pack-indicator"]')).toContainText("You chose no icon pack");
    await page.goto(`/projects/${config.project}/work_packages`);
    await expect(page.locator("table.work-package-table tbody tr").first()).toBeVisible();
    await expect(page.locator("#thematiq-icon-pack-data")).toHaveCount(0);
    expect(await page.locator("html").getAttribute("data-thematiq-icon-pack")).toBeNull();
  });
});
