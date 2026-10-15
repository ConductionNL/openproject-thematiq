// The list under the nine-dot button, as the OpHeader board draws it.
const { test, expect } = require("@playwright/test");
const { PICKER } = require("../support/thematiq");
const { config } = require("../support/env");

async function setNextcloud(page, value) {
  await page.goto(PICKER);
  await page.locator("#thematiq-nextcloud-url").fill(value);
  await Promise.all([page.waitForURL(/\/admin\/thematiq/), page.locator("#thematiq-shell-form").getByRole("button", { name: "Save" }).click()]);
}

test.describe("app switcher", () => {
  let nextcloud;
  test.beforeEach(async ({ page }) => {
    await page.goto(PICKER);
    nextcloud = await page.locator("#thematiq-nextcloud-url").inputValue();
  });
  test.afterEach(async ({ page }) => { await setNextcloud(page, nextcloud); });

  test("the list has a heading, two columns, a line per entry, the current entry and Manage apps", async ({ page }) => {
    await setNextcloud(page, "https://cloud.example.org");
    await page.goto(`/projects/${config.project}/work_packages`);
    const button = page.getByRole("button", { name: "All apps and modules" });
    await expect(button).toHaveAttribute("aria-expanded", "false");
    await button.click();
    await expect(button).toHaveAttribute("aria-expanded", "true");

    const list = page.getByRole("dialog", { name: "All apps and modules" });
    await expect(list).toBeVisible();
    await expect(list.getByRole("heading", { name: "All apps and modules" })).toBeVisible();
    await expect(list.getByRole("heading", { name: "Nextcloud" })).toBeVisible();
    await expect(list.getByRole("link", { name: /Files\s+Project folders and documents/ })).toHaveAttribute("href", "https://cloud.example.org/apps/files/");
    const current = list.locator('[aria-current="page"]');
    await expect(current).toHaveCount(1);
    await expect(current).toContainText("Work packages");
    await expect(current).toContainText("All projects");
    await expect(list.getByRole("link", { name: "Manage apps" })).toHaveAttribute("href", /\/admin\/thematiq#thematiq-top-bar$/);

    // Arrow keys move between the entries.
    const entries = list.locator("[data-thematiq-switcher-entry]");
    await entries.first().focus();
    await page.keyboard.press("ArrowDown");
    await expect(entries.nth(1)).toBeFocused();
    await page.keyboard.press("End");
    await expect(list.getByRole("link", { name: "Manage apps" })).toBeFocused();

    await page.keyboard.press("Escape");
    await expect(list).toBeHidden();
    await expect(button).toHaveAttribute("aria-expanded", "false");
  });

  test("without a Nextcloud address there is one group, its entries tiles in four columns", async ({ page }) => {
    await setNextcloud(page, "");
    await page.goto("/projects");
    await page.getByRole("button", { name: "All apps and modules" }).click();
    const list = page.getByRole("dialog", { name: "All apps and modules" });
    await expect(list.getByRole("heading", { name: "Nextcloud" })).toHaveCount(0);
    await expect(list.locator('[aria-current="page"]')).toContainText("Projects");
    await expect(list.getByRole("heading", { name: "OpenProject" })).toHaveCount(0);
    await expect(list.getByText(/of them (is|are) in the bar/)).toHaveCount(0);
    const columns = await list.locator(".thematiq-apps--list").first()
      .evaluate((el) => getComputedStyle(el).gridTemplateColumns.split(" ").length);
    expect(columns).toBe(4);
    // A popover under the nine-dot button, as werkplek/AppMenu draws it, not a sheet.
    const box = await list.boundingBox();
    expect(Math.round(box.x)).toBe(160);
    expect(Math.round(box.width)).toBe(640);
  });
});
