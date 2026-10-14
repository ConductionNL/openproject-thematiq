// The contrast report for an audit: every design system in use, light and dark, to read, print or download.
const { test, expect } = require("@playwright/test");
const { PICKER } = require("../support/thematiq");

test.describe("contrast report", () => {
  test("lists the design system in use with its pairs, and downloads as JSON", async ({ page }) => {
    await page.goto(PICKER);
    await page.locator('[data-test-selector="thematiq-compliance-link"]').click();
    await expect(page.getByRole("heading", { name: "Contrast report" })).toBeVisible();
    const system = page.locator(".thematiq-compliance__system").first();
    await expect(system).toContainText("Used by: instance");
    await expect(system.getByRole("cell", { name: "main text on the page background" }).first()).toBeVisible();

    const response = await page.request.get("/admin/thematiq/compliance.json");
    expect(response.status()).toBe(200);
    expect(response.headers()["content-disposition"]).toContain("attachment");
    const report = await response.json();
    expect(report.criterion).toContain("1.4.3");
    expect(report.design_systems[0].used_by).toContain("instance");
  });
});
