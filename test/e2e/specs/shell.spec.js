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

  // The dossiq bar: the brand block, the app switcher, the search in the middle, the buttons, no tiles and no quick add.
  test("the top bar is the dossiq bar", async ({ page }) => {
    await openWorkPackages(page);
    const header = page.locator(".op-app-header");
    const brand = header.locator('[data-test-selector="thematiq-brand"]');
    await expect(brand).toBeVisible();
    await expect(brand.locator(".thematiq-brand--app")).toHaveText(/\S/);
    await expect(header.locator(".thematiq-app-row--item")).toHaveCount(0);
    const box = async (locator) => locator.first().boundingBox();
    // Quick add stays: a round button before the bell, where the create dialog opens from a type.
    const add = await box(header.locator("#op-app-header--quick-add-menu-button"));
    expect([Math.round(add.width), Math.round(add.height)]).toEqual([44, 44]);
    await expect(header.getByRole("button", { name: "All apps and modules" })).toBeVisible();

    const brandBox = await box(header.locator(".thematiq-brand"));
    expect(Math.round(brandBox.x)).toBe(14);
    expect(Math.round(brandBox.width)).toBe(237);
    const apps = await box(header.getByRole("button", { name: "All apps and modules" }));
    expect([Math.round(apps.x), Math.round(apps.width)]).toEqual([276, 40]);
    const search = await box(header.locator(".top-menu-search"));
    expect([Math.round(search.x), Math.round(search.width), Math.round(search.height)]).toEqual([437, 560, 44]);
    const bell = await box(header.locator(".op-ian-bell"));
    expect([Math.round(bell.width), Math.round(bell.height)]).toEqual([44, 44]);
  });

  test("Home shows the grid and My page leads to Home", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("region", { name: "Your widgets" })).toBeVisible();
    await expect(page.locator(".PageHeader-title").filter({ hasText: /Hello / })).toBeVisible();
    const response = await page.request.get("/my/page", { maxRedirects: 0 });
    expect(response.status()).toBe(302);
    expect(new URL(response.headers().location).pathname).toBe("/");
  });

  test("Home's widgets are cards on a quiet surface (OpHome)", async ({ page }) => {
    await page.goto("/");
    const card = page.locator(".thematiq-home--grid .grid--area-content.widget-box").first();
    await expect(card).toBeVisible();
    const looks = await card.evaluate((el) => {
      // What the plugin's variables resolve to on this page, through a probe that takes them.
      const probe = document.createElement("div");
      probe.style.cssText = "background: var(--thematiq-ground); border-radius: var(--thematiq-radius-lg); color: var(--thematiq-surface)";
      document.body.appendChild(probe);
      const want = getComputedStyle(probe);
      const result = {
        ground: want.backgroundColor, radius: want.borderTopLeftRadius, surface: want.color,
        page: getComputedStyle(el.closest("#content-wrapper") || el.closest("#content")).backgroundColor,
        card: getComputedStyle(el).backgroundColor, cardRadius: getComputedStyle(el).borderTopLeftRadius,
        line: getComputedStyle(el).borderTopWidth, shadow: getComputedStyle(el).boxShadow,
      };
      probe.remove();
      return result;
    });
    expect(looks.page, "the quiet surface").toBe(looks.ground);
    expect(looks.card, "the card").toBe(looks.surface);
    expect(looks.cardRadius).toBe(looks.radius);
    expect(looks.line).toBe("1px");
    expect(looks.shadow).toBe("none");
  });

  test("the sizes hold the canon", async ({ page }) => {
    await openWorkPackages(page);
    const size = (selector) => page.locator(selector).first().evaluate((el) => {
      const box = el.getBoundingClientRect();
      return { width: Math.round(box.width * 10) / 10, height: Math.round(box.height * 10) / 10 };
    });
    expect((await size(".op-app-header")).height, "top bar").toBe(68);
    expect((await size(".op-logo")).width, "brand block").toBe(237);
    expect((await size("#main-menu")).width, "sidebar").toBe(264);
    expect((await size("#main-menu .main-item-wrapper")).height, "nav item").toBe(42);
    expect((await size("#main-menu .op-submenu--item-action")).height, "level two").toBe(36);
    // The Create button of the work package toolbar, OpenProject's own class for a primary button.
    const create = page.locator("button.button.-primary.add-work-package");
    await expect(create).toBeVisible();
    expect((await create.boundingBox()).height, "primary button").toBe(48);
    expect((await size("table.work-package-table tbody tr")).height, "table row").toBe(44);
    // Body text follows Nextcloud: 15 px.
    expect(await page.evaluate(() => getComputedStyle(document.body).fontSize), "body text").toBe("15px");
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
