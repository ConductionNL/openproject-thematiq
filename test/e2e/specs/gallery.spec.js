// The gallery and the shared light or dark choice: both off by default, both turned on and off here.
// The gallery's fetch itself needs the internet; it is not part of this suite.
const { test, expect } = require("@playwright/test");
const { PICKER, flash } = require("../support/thematiq");

test.describe("gallery and appearance", () => {
  test("the gallery is off by default and refuses an address that is not https", async ({ page }) => {
    await page.goto(PICKER);
    await page.locator('[data-test-selector="thematiq-gallery-link"]').click();
    await expect(page.getByLabel("Read the gallery from the address below")).not.toBeChecked();
    await expect(page.getByRole("button", { name: "Check now" })).toHaveCount(0);
    await page.getByLabel("Address of the catalogue").fill("http://example.org/catalogue.json");
    await page.getByLabel("Read the gallery from the address below").check();
    await page.getByRole("button", { name: "Save", exact: true }).click();
    await expect(flash(page).filter({ hasText: "must be an https address" }).first()).toBeVisible();
    await expect(page.getByLabel("Read the gallery from the address below")).not.toBeChecked();
  });

  test("another product's link sets the person's light or dark choice once it is allowed", async ({ page }) => {
    expect((await page.request.get("/thematiq/appearance?mode=dark&return_to=/", { maxRedirects: 0 })).status()).toBe(404);
    await page.goto(PICKER);
    const form = page.locator("#thematiq-appearance-form");
    await form.getByLabel("Let another product set a person's light or dark choice by link").check();
    await form.getByRole("button", { name: "Save" }).click();
    try {
      await page.goto("/thematiq/appearance?mode=dark&return_to=/projects");
      await expect(page).toHaveURL(/\/projects$/);
      await expect(page.locator("body")).toHaveAttribute("data-color-mode", "dark");
    } finally {
      await page.goto("/thematiq/appearance?mode=light&return_to=/");
      await page.goto(PICKER);
      await page.locator("#thematiq-appearance-form").getByLabel("Let another product set a person's light or dark choice by link").uncheck();
      await page.locator("#thematiq-appearance-form").getByRole("button", { name: "Save" }).click();
    }
  });
});
