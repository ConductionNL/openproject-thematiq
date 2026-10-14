// The shared shell: the two-layer project menu, the row of tiles, the merged Home, and the sizes of the canon.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const WORK_PACKAGES = `/projects/${config.project}/work_packages`;

async function openWorkPackages(page) {
  await page.goto(WORK_PACKAGES);
  await expect(page.locator("table.work-package-table tbody tr").first()).toBeVisible();
}

test.describe("shell", () => {
  test("the project menu opens the current module in place", async ({ page }) => {
    await openWorkPackages(page);
    const menu = page.locator("#main-menu");
    await expect(menu.getByRole("button", { name: "Collapse Work packages" })).toHaveAttribute("aria-expanded", "true");
    const current = menu.locator('[aria-current="page"]');
    await expect(current.filter({ hasText: "All open" })).toHaveCount(1);
    await expect(menu.getByRole("link", { name: "All open" })).toBeVisible();

    // Another module opens by keyboard and says so.
    const gantt = menu.getByRole("button", { name: "Expand Gantt charts" });
    await expect(gantt).toHaveAttribute("aria-expanded", "false");
    const sub = await gantt.getAttribute("aria-controls");
    await gantt.focus();
    await page.keyboard.press("Enter");
    const open = menu.getByRole("button", { name: "Collapse Gantt charts" });
    await expect(open).toHaveAttribute("aria-expanded", "true");
    await expect(open).toBeFocused();
    await expect(page.locator(`#${sub}`)).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`${WORK_PACKAGES}$`));
  });

  test("the row of tiles marks the current module", async ({ page }) => {
    await openWorkPackages(page);
    const tiles = page.locator(".thematiq-app-row--item");
    await expect(tiles.filter({ hasText: "Work packages" })).toHaveAttribute("aria-current", "page");
    expect(await page.locator('.thematiq-app-row--item[aria-current="page"]').count()).toBe(1);

    await page.goto("/projects");
    await expect(tiles.filter({ hasText: "Projects" })).toHaveAttribute("aria-current", "page");
    await expect(tiles.filter({ hasText: "Work packages" })).not.toHaveAttribute("aria-current", "page");
  });

  test("Home shows the grid and My page leads to Home", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("region", { name: "Your widgets" })).toBeVisible();
    await expect(page.locator(".PageHeader-title").filter({ hasText: /Hello / })).toBeVisible();
    const response = await page.request.get("/my/page", { maxRedirects: 0 });
    expect(response.status()).toBe(302);
    expect(new URL(response.headers().location).pathname).toBe("/");
  });

  test("the sizes hold the canon", async ({ page }) => {
    await openWorkPackages(page);
    const size = (selector) => page.locator(selector).first().evaluate((el) => {
      const box = el.getBoundingClientRect();
      return { width: Math.round(box.width * 10) / 10, height: Math.round(box.height * 10) / 10 };
    });
    expect((await size(".op-app-header")).height, "top bar").toBe(68);
    expect((await size(".op-logo")).width, "logo block").toBe(264);
    expect((await size("#main-menu")).width, "sidebar").toBe(264);
    expect((await size("#main-menu .main-item-wrapper")).height, "nav item").toBe(42);
    expect((await size("#main-menu .op-submenu--item-action")).height, "level two").toBe(36);
    // The Create button of the work package toolbar, OpenProject's own class for a primary button.
    const create = page.locator("button.button.-primary.add-work-package");
    await expect(create).toBeVisible();
    expect((await create.boundingBox()).height, "primary button").toBe(40);
    expect((await size("table.work-package-table tbody tr")).height, "table row").toBe(48);
  });

  test("the table header is 44 px", async ({ page }) => {
    // First full test, finding 6: it measured 45, the height OpenProject gives the thead.
    await openWorkPackages(page);
    const height = await page.locator("table.work-package-table thead tr").evaluate((el) => el.getBoundingClientRect().height);
    expect(height).toBe(44);
  });

  // First full test, finding 2: on a module page the top bar was 22 px wider than a 1440 px window.
  // 1360 is where the account label still shows on other pages.
  for (const width of [1440, 1360]) {
    test(`the top bar fits the window at ${width} wide`, async ({ page }) => {
      await page.setViewportSize({ width, height: 1000 });
      await openWorkPackages(page);
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(overflow).toBe(0);
      const bar = await page.locator(".op-app-header").evaluate((el) => el.scrollWidth - el.clientWidth);
      expect(bar, "nothing in the top bar is cut off").toBe(0);
    });
  }
});
