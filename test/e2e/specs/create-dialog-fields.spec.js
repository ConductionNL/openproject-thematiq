// The fields of the OpCreateWorkPackage board in core's create dialog (Shell::CreateDialogFields): Parent, Assignee,
// Priority, Start date and Finish date, saved by core; the Nextcloud line only with a Nextcloud address, disabled.
// The work packages a test creates are deleted again through the API.
const { test, expect } = require("@playwright/test");
const { PICKER } = require("../support/thematiq");
const { config } = require("../support/env");

const dialog = (page) => page.locator("#create-work-package-dialog[open]");
const SUBJECT_PREFIX = "E2E fields";
const headers = { "X-Requested-With": "XMLHttpRequest" };

async function openDialog(page) {
  await page.goto(`/projects/${config.project}/work_packages`);
  await page.locator("wp-create-button button.add-work-package").click();
  await expect(dialog(page)).toBeVisible();
}

async function setNextcloud(page, value) {
  await page.goto(PICKER);
  await page.locator("#thematiq-nextcloud-url").fill(value);
  await Promise.all([page.waitForURL(/\/admin\/thematiq/), page.locator("#thematiq-shell-form").getByRole("button", { name: "Save" }).click()]);
}

// Picks an entry of one of core's autocompleters (ng-select) by typing part of its name.
async function pick(page, field, text) {
  const input = dialog(page).locator(`[data-thematiq-field="${field}"] input[type="text"]`).first();
  await input.click();
  await input.fill(text);
  const option = page.locator(".ng-dropdown-panel .ng-option").filter({ hasText: text }).first();
  await expect(option).toBeVisible();
  await option.click();
}

const top = (locator) => locator.evaluate((node) => Math.round(node.getBoundingClientRect().top));

test.afterAll(async ({ request }) => {
  const filters = encodeURIComponent(JSON.stringify([{ subject: { operator: "~", values: [SUBJECT_PREFIX] } }, { status: { operator: "*", values: [] } }]));
  const found = await request.get(`/api/v3/work_packages?pageSize=100&filters=${filters}`, { headers });
  for (const element of (await found.json())._embedded.elements) {
    if (element.subject.startsWith(SUBJECT_PREFIX)) await request.delete(`/api/v3/work_packages/${element.id}`, { headers });
  }
});

test.describe("The board's fields in the create dialog", () => {
  test("every field of the board has a label, in the board's rows of two", async ({ page }) => {
    await openDialog(page);
    for (const name of ["Type", "Parent", "Subject", "Description", "Assignee", "Priority", "Start date", "Finish date"]) {
      await expect(dialog(page).getByText(name, { exact: true }).first(), name).toBeVisible();
    }
    const field = (name) => dialog(page).locator(`[data-thematiq-field="${name}"]`).first();
    const typeTop = await top(dialog(page).locator('label[for="work_package_type_id"]'));
    expect(Math.abs(typeTop - (await top(field("parent").locator("label"))))).toBeLessThanOrEqual(2);
    expect(Math.abs((await top(field("assignee").locator("label"))) - (await top(dialog(page).locator('label[for="work_package_priority_id"]'))))).toBeLessThanOrEqual(2);
    expect(Math.abs((await top(dialog(page).locator('label[for="work_package_start_date"]'))) - (await top(dialog(page).locator('label[for="work_package_due_date"]'))))).toBeLessThanOrEqual(2);
    await page.keyboard.press("Escape");
  });

  test("core saves the parent, the assignee, the priority and the dates", async ({ page, request }) => {
    await openDialog(page);
    const subject = `${SUBJECT_PREFIX} ${Date.now().toString(36)}`;
    await page.locator("#work_package_subject").fill(subject);
    await pick(page, "parent", "Organize open source conference");
    await pick(page, "assignee", "OpenProject Admin");
    const priority = dialog(page).locator("select#work_package_priority_id");
    const high = await priority.locator("option").filter({ hasText: /high/i }).first().textContent();
    await priority.selectOption({ label: high.trim() });
    await page.locator("#work_package_start_date").fill("2026-10-20");
    await page.locator("#work_package_due_date").fill("2026-10-23");
    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toHaveCount(0);
    await expect(page.getByText("Successful creation.").first()).toBeVisible();

    const filters = encodeURIComponent(JSON.stringify([{ subject: { operator: "=", values: [subject] } }]));
    const found = await (await request.get(`/api/v3/work_packages?filters=${filters}`, { headers })).json();
    expect(found._embedded.elements).toHaveLength(1);
    const saved = found._embedded.elements[0];
    expect(saved._links.parent.title).toBe("Organize open source conference");
    expect(saved._links.assignee.title).toBe("OpenProject Admin");
    expect(saved._links.priority.title).toBe(high.trim());
    expect(saved.startDate).toBe("2026-10-20");
    expect(saved.dueDate).toBe("2026-10-23");
  });

  test("a value core refuses shows in the dialog, with what was filled in kept", async ({ page }) => {
    await openDialog(page);
    await page.locator("#work_package_start_date").fill("2026-10-23");
    await page.locator("#work_package_due_date").fill("2026-10-20");
    await dialog(page).getByRole("button", { name: "Create work package" }).click();
    await expect(dialog(page)).toContainText("Subject can't be blank");
    await expect(page.locator("#work_package_start_date")).toHaveValue("2026-10-23");
    await page.keyboard.press("Escape");
  });

  test("the Nextcloud line shows only with a Nextcloud address, disabled with a note", async ({ page }) => {
    await page.goto(PICKER);
    const before = await page.locator("#thematiq-nextcloud-url").inputValue();
    try {
      await setNextcloud(page, "");
      await openDialog(page);
      await expect(dialog(page).locator('[data-thematiq-field="nextcloud"]')).toHaveCount(0);
      await page.keyboard.press("Escape");

      await setNextcloud(page, "https://cloud.example.org");
      await openDialog(page);
      const box = dialog(page).getByRole("checkbox", { name: "Link the project folder in Nextcloud" });
      await expect(box).toBeDisabled();
      await expect(box).toHaveAccessibleDescription(/administrator links a Nextcloud folder/);
      await page.keyboard.press("Escape");
    } finally {
      await setNextcloud(page, before);
    }
  });
});

test.describe("The board's fields at 390 px", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test("one column, inside the dialog", async ({ page }) => {
    await openDialog(page);
    const box = await dialog(page).boundingBox();
    const start = await page.locator("#work_package_start_date").boundingBox();
    const due = await page.locator("#work_package_due_date").boundingBox();
    expect(due.y).toBeGreaterThan(start.y);
    expect(start.x + start.width).toBeLessThanOrEqual(box.x + box.width);
    await page.keyboard.press("Escape");
  });
});
