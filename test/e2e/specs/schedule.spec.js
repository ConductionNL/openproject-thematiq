// A planned switch: planned, listed, cancelled. That the switch is made when its time comes is checked in the
// request check, which can plan a second ahead; the form takes minutes.
const { test, expect } = require("@playwright/test");
const { PICKER, flash } = require("../support/thematiq");

test.describe("planned switch", () => {
  test("a switch is planned, listed and cancelled", async ({ page }) => {
    await page.goto(PICKER);
    const form = page.locator("#thematiq-schedule-form");
    await form.getByLabel("Design system").selectOption("zuiddrecht");
    const later = new Date(Date.now() + 3 * 24 * 3600 * 1000);
    const local = new Date(later.getTime() - later.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    await form.getByLabel("From").fill(local);
    await form.getByRole("button", { name: "Plan the switch" }).click();
    await expect(flash(page).filter({ hasText: "is planned from" }).first()).toBeVisible();
    await expect(page.locator('[data-test-selector="thematiq-schedule"]')).toContainText("Gemeente Zuiddrecht");

    await page.getByRole("button", { name: "Cancel the switch to Gemeente Zuiddrecht" }).first().click();
    await expect(flash(page).filter({ hasText: "The planned switch is cancelled." }).first()).toBeVisible();
  });
});
