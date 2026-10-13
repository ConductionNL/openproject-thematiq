// The field for the tiles of the top bar: an administrator picks and orders them, or turns the row off.
const { test, expect } = require("@playwright/test");
const { PICKER } = require("../support/thematiq");

const TILES = ".thematiq-app-row--item";

async function save(page, mode, keys = []) {
  await page.goto(PICKER);
  const form = page.locator("#thematiq-top-bar-form");
  await form.locator(`input[name="top_bar_mode"][value="${mode}"]`).check();
  for (let place = 1; place <= 12; place++) await form.locator(`#thematiq-tile-${place}`).selectOption(keys[place - 1] || "");
  await Promise.all([page.waitForURL(/\/admin\/thematiq/), form.getByRole("button", { name: "Save tiles" }).click()]);
}

test.describe("tiles in the top bar", () => {
  let saved;
  test.beforeEach(async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-top-bar-form");
    saved = {
      mode: await form.locator('input[name="top_bar_mode"]:checked').getAttribute("value"),
      keys: await form.locator("select").evaluateAll((selects) => selects.map((select) => select.value)),
    };
  });
  test.afterEach(async ({ page }) => { await save(page, saved.mode, saved.keys); });

  test("an own row shows in its order, and no row shows no tiles", async ({ page }) => {
    await save(page, "custom", ["gantt", "", "boards", "projects"]);
    await expect(page.getByText("Saved. The top bar shows the new row on the next page.").filter({ visible: true }).first()).toBeVisible();
    await expect(page.locator("#thematiq-tile-1")).toHaveValue("gantt");
    await expect(page.locator("#thematiq-tile-2")).toHaveValue("boards");

    await page.goto("/projects");
    const names = await page.locator(`${TILES} .thematiq-app-row--name`).allTextContents();
    expect(names).toEqual(["Gantt charts", "Boards", "Projects"]);
    await expect(page.locator(TILES).filter({ hasText: "Projects" })).toHaveAttribute("aria-current", "page");

    await save(page, "none");
    await page.goto("/projects");
    await expect(page.locator(TILES)).toHaveCount(0);
  });

  test("an own row without a tile is refused and changes nothing", async ({ page }) => {
    await save(page, "custom", []);
    await expect(page.getByText("Pick at least one tile and at most 12 for your own row. Nothing was saved.").filter({ visible: true }).first()).toBeVisible();
    await expect(page.locator(`#thematiq-top-bar-form input[name="top_bar_mode"][value="${saved.mode}"]`)).toBeChecked();
  });
});
