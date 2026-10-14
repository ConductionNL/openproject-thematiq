// Running it in production: the health report for an administrator.
const { test, expect } = require("@playwright/test");

test.describe("operations", () => {
  test("the health report answers JSON for an administrator", async ({ page }) => {
    const response = await page.request.get("/admin/thematiq/health");
    expect(response.status()).toBe(200);
    const report = await response.json();
    expect(report.status).toBe("ok");
    expect(report.problems).toEqual([]);
    expect(report.tables).toEqual({ uploads: true, scopes: true, changes: true });
    expect(report.core_changed).toEqual([]);
    expect(report.catalogue.sets).toBeGreaterThanOrEqual(60);
  });
});
