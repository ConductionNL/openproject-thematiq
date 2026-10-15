// The picker: the bundled design systems, the search, and Apply changing the whole installation.
const { test, expect } = require("@playwright/test");
const { PICKER, rgb, primaryOf, barColour, applySet, exported, createCustom, snapshot, restore } = require("../support/thematiq");
const { config } = require("../support/env");

test.describe("picker", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("lists the bundled design systems", async ({ page }) => {
    await page.goto(PICKER);
    const count = page.locator('[data-test-selector="thematiq-count"]');
    await expect(count).toHaveText(/(\d+) of \1 design systems/);
    const total = Number((await count.innerText()).trim().split(" ")[0]);
    expect(total).toBeGreaterThanOrEqual(60);
    // The total counts the custom design systems too, which are listed first.
    await expect(page.getByRole("group").locator("input.thematiq-picker__radio")).toHaveCount(total);
    await expect(page.locator(".thematiq-picker__name").filter({ hasText: /^Cunningham \(blue base\)$/ })).toHaveCount(1);
  });

  test("search narrows the list and says when nothing matches", async ({ page }) => {
    await page.goto(PICKER);
    const search = page.locator("#thematiq-search-form");
    await search.getByLabel("Search design systems").fill("zuiddrecht");
    await Promise.all([page.waitForURL(/q=zuiddrecht/), search.getByRole("button", { name: "Search", exact: true }).click()]);
    await expect(page.locator('[data-test-selector="thematiq-count"]')).toHaveText(/1 of \d+ design systems/);
    await expect(page.locator(".thematiq-picker__name")).toHaveText(["Gemeente Zuiddrecht"]);

    await search.getByLabel("Search design systems").fill("no design system has this name");
    await Promise.all([page.waitForURL(/q=no/), search.getByRole("button", { name: "Search", exact: true }).click()]);
    const none = page.locator('[data-test-selector="thematiq-no-results"]');
    await expect(none).toBeVisible();
    await expect(none).toContainText("No design system has that name. Try another word or show all.");
    await page.getByRole("link", { name: "Show all" }).click();
    await expect(page).toHaveURL(/\/admin\/thematiq$/);
  });

  // First full test, finding 10: custom design systems were never searched, and the count left them out.
  test("search finds a custom design system and counts it", async ({ page }) => {
    const tag = Date.now().toString(36);
    const name = `E2E search ${tag}`;
    const id = await createCustom(page, { name });
    await page.goto(PICKER);
    const total = Number((await page.locator('[data-test-selector="thematiq-count"]').innerText()).trim().split(" ")[2]);
    const search = page.locator("#thematiq-search-form");
    await search.getByLabel("Search design systems").fill(tag.toUpperCase());
    await Promise.all([page.waitForURL(/q=/), search.getByRole("button", { name: "Search", exact: true }).click()]);
    await expect(page.locator('[data-test-selector="thematiq-count"]')).toHaveText(`1 of ${total} design systems`);
    await expect(page.locator(".thematiq-picker__name")).toHaveText([name]);
    await expect(page.locator(`#thematiq-set-${id}`)).toBeVisible();
  });

  test("apply changes the design system and the top bar for everyone", async ({ page, browser }) => {
    const target = saved.active === "zuiddrecht" ? "rotterdam" : "zuiddrecht";
    const set = await exported(page, target);
    await applySet(page, target);
    await expect(page.locator('[data-test-selector="thematiq-active"]')).toContainText(set.name);
    await page.goto("/projects");
    await expect.poll(() => primaryOf(page)).toBe(set.tokens.primary.toLowerCase());
    await expect(page.locator(".op-app-header")).toHaveCSS("background-color", rgb(barColour(set)));

    // Someone who is not signed in sees it too, on the sign-in page.
    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const signIn = await visitor.newPage();
    await signIn.goto("/login");
    await expect.poll(() => primaryOf(signIn)).toBe(set.tokens.primary.toLowerCase());
    await visitor.close();
  });

  // First full test, finding 14: Apply came after the list, about 200 tab stops in. The radio buttons are one
  // tab stop; the three links of each card are not. Apply now comes right after the search, before the list.
  test("Apply is a few tab stops from the search and stays in view", async ({ page }) => {
    await page.goto(PICKER);
    await page.getByLabel("Search design systems").focus();
    const apply = page.getByRole("button", { name: "Apply", exact: true });
    let stops = 0;
    while (stops < 5 && !(await apply.evaluate((el) => el === document.activeElement))) {
      await page.keyboard.press("Tab");
      stops += 1;
    }
    await expect(apply).toBeFocused();

    await page.locator(".thematiq-picker__option").last().scrollIntoViewIfNeeded();
    await expect(apply).toBeInViewport();
  });
});
