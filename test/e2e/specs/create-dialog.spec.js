// Every create action of a project opens core's create dialog, as the OpCreateWorkPackage board draws it
// (Shell::CreateDialog). The work packages a test creates are deleted again through the API.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const dialog = (page) => page.locator("#create-work-package-dialog[open]");
const SUBJECT_PREFIX = "E2E dialog";
// The quick add button and its entries go by role and name: the top bar around them changes with the shell.
const quickAdd = (page) => page.getByRole("banner").getByRole("button", { name: "Add…", exact: true });

async function expectBoardDialog(page) {
  await expect(dialog(page)).toBeVisible();
  await expect(dialog(page).getByRole("heading", { name: "Create work package" })).toBeVisible();
  await expect(dialog(page).locator(".thematiq-create__project")).toHaveText(/\S/);
  await expect(dialog(page).getByRole("button", { name: "Create work package" })).toBeVisible();
  // Focus moves into the dialog: core puts it in the subject.
  await expect(page.locator("#work_package_subject")).toBeFocused();
  expect(await dialog(page).evaluate((node) => Math.round(node.getBoundingClientRect().width))).toBeLessThanOrEqual(640);
}

// Every work package a run made, also those of an interrupted run, goes by its subject.
test.afterAll(async ({ request }) => {
  const headers = { "X-Requested-With": "XMLHttpRequest" };
  const filters = encodeURIComponent(JSON.stringify([{ subject: { operator: "~", values: [SUBJECT_PREFIX] } }, { status: { operator: "*", values: [] } }]));
  const found = await request.get(`/api/v3/work_packages?pageSize=100&filters=${filters}`, { headers });
  for (const element of (await found.json())._embedded.elements) {
    if (element.subject.startsWith(SUBJECT_PREFIX)) await request.delete(`/api/v3/work_packages/${element.id}`, { headers });
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
    await quickAdd(page).click();
    const type = "Task";
    await page.getByRole("menuitem", { name: type, exact: true }).click();
    await expect(dialog(page)).toBeVisible();
    await expect(dialog(page).locator("[data-test-selector=work_package_create_dialog_type]")).toContainText(new RegExp(type, "i"));
    await page.keyboard.press("Escape");
    await expect(quickAdd(page)).toBeFocused();
  });

  test("core validates in the dialog, and saving refreshes the view with the new work package", async ({ page }) => {
    await page.goto(`/projects/${config.project}/gantt`);
    await expect(page.locator(".wp-timeline-cell").first()).toBeVisible();
    const start = new URL(page.url()).pathname;
    await page.locator("wp-create-button button.add-work-package").click();
    await expect(dialog(page)).toBeVisible();

    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toContainText("Subject can't be blank");

    const subject = `${SUBJECT_PREFIX} ${Date.now().toString(36)}`;
    await page.locator("#work_package_subject").fill(subject);
    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toHaveCount(0);
    await expect(page.getByText("Successful creation.").first()).toBeVisible();
    expect(new URL(page.url()).pathname).toBe(start);
    await expect(page.locator("td.subject", { hasText: subject })).toBeVisible();
  });

  test("a click with a modifier key still opens core's page", async ({ page, context }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    const [tab] = await Promise.all([
      context.waitForEvent("page"),
      page.locator("a.thematiq-nav-create").click({ modifiers: ["ControlOrMeta"] }),
    ]);
    await tab.waitForURL(new RegExp(`/projects/${config.project}/work_packages/new`));
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
