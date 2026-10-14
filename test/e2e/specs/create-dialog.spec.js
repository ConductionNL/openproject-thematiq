// Every create action of a project opens core's create dialog, as the OpCreateWorkPackage board draws it
// (Shell::CreateDialog). The work packages a test creates are deleted again through the API.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const dialog = (page) => page.locator("#create-work-package-dialog[open]");
const created = [];

async function expectBoardDialog(page) {
  await expect(dialog(page)).toBeVisible();
  await expect(dialog(page).getByRole("heading", { name: "Create work package" })).toBeVisible();
  await expect(dialog(page).locator(".thematiq-create__project")).toHaveText(/\S/);
  await expect(dialog(page).getByRole("button", { name: "Create work package" })).toBeVisible();
  // Focus moves into the dialog: core puts it in the subject.
  await expect(page.locator("#work_package_subject")).toBeFocused();
  expect(await dialog(page).evaluate((node) => Math.round(node.getBoundingClientRect().width))).toBeLessThanOrEqual(640);
}

test.afterAll(async ({ request }) => {
  for (const id of created) {
    await request.delete(`/api/v3/work_packages/${id}`, { headers: { "X-Requested-With": "XMLHttpRequest" } });
  }
});

test.describe("Create work package as a dialog", () => {
  test("the project menu's action opens the dialog; Escape closes it and focus goes back", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    const start = page.url();
    const action = page.locator("a.thematiq-nav-create");
    await action.focus();
    await page.keyboard.press("Enter");
    await expectBoardDialog(page);
    expect(page.url()).toBe(start);

    await page.keyboard.press("Escape");
    await expect(dialog(page)).toHaveCount(0);
    await expect(action).toBeFocused();
    expect(page.url()).toBe(start);
  });

  test("the page's Create button opens the dialog; the close button returns to the page", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    const create = page.locator("wp-create-button button.add-work-package");
    await create.click();
    await expectBoardDialog(page);
    await dialog(page).getByRole("button", { name: "Close" }).click();
    await expect(dialog(page)).toHaveCount(0);
    await expect(create).toBeFocused();
  });

  test("a type in the quick add menu opens the dialog with that type", async ({ page }) => {
    await page.goto(`/projects/${config.project}`);
    await page.locator("[data-test-selector=quick-add-menu-button]").click();
    const item = page.locator('#op-app-header--quick-add-menu-list a[href*="/work_packages/new?type="]').first();
    const type = (await item.innerText()).trim();
    await item.click();
    await expect(dialog(page)).toBeVisible();
    await expect(dialog(page).locator("[data-test-selector=work_package_create_dialog_type]")).toContainText(new RegExp(type, "i"));
    await page.keyboard.press("Escape");
    await expect(page.locator("[data-test-selector=quick-add-menu-button]")).toBeFocused();
  });

  test("core validates in the dialog, and saving refreshes the view with the new work package", async ({ page }) => {
    await page.goto(`/projects/${config.project}/gantt`);
    await expect(page.locator(".wp-timeline-cell").first()).toBeVisible();
    const start = new URL(page.url()).pathname;
    await page.locator("wp-create-button button.add-work-package").click();
    await expect(dialog(page)).toBeVisible();

    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toContainText("Subject can't be blank");

    const subject = `E2E dialog ${Date.now().toString(36)}`;
    await page.locator("#work_package_subject").fill(subject);
    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toHaveCount(0);
    await expect(page.getByText("Successful creation.")).toBeVisible();
    expect(new URL(page.url()).pathname).toBe(start);
    await expect(page.locator("td.subject", { hasText: subject })).toBeVisible();

    const found = await page.request.get(`/api/v3/work_packages?filters=${encodeURIComponent(JSON.stringify([{ subject: { operator: "~", values: [subject] } }]))}`,
      { headers: { "X-Requested-With": "XMLHttpRequest" } });
    for (const element of (await found.json())._embedded.elements) created.push(element.id);
    expect(created.length).toBeGreaterThan(0);
  });

  test("a click with a modifier key still opens core's page", async ({ page, context }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    const [tab] = await Promise.all([
      context.waitForEvent("page"),
      page.locator("a.thematiq-nav-create").click({ modifiers: ["ControlOrMeta"] }),
    ]);
    await tab.waitForLoadState();
    expect(new URL(tab.url()).pathname).toBe(`/projects/${config.project}/work_packages/new`);
    await expect(dialog(page)).toHaveCount(0);
    await tab.close();
  });
});

test.describe("Create work package as a dialog at 390 px", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test("the dialog fits the screen with a gutter", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    await page.locator("wp-create-button button.add-work-package").click();
    await expect(dialog(page)).toBeVisible();
    const box = await dialog(page).boundingBox();
    expect(box.x).toBeGreaterThanOrEqual(15);
    expect(box.x + box.width).toBeLessThanOrEqual(375);
    await page.keyboard.press("Escape");
  });
});
