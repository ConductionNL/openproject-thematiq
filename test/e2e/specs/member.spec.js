// An ordinary project member: the shell, but no admin page and none of its actions.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.use({ storageState: ".auth/member.json" });

test.describe("member", () => {
  test("gets no admin page and none of its actions", async ({ page }) => {
    for (const path of ["/admin/thematiq", "/admin/thematiq/custom?from=cunningham", "/admin/thematiq/export?id=cunningham",
                        "/admin/thematiq/figma", "/admin/thematiq/figma/download?id=cunningham&file_format=dtcg"]) {
      const response = await page.request.get(path, { maxRedirects: 0 });
      expect(response.status(), path).toBe(403);
    }
    await page.goto("/my/account");
    const token = await page.locator('meta[name="csrf-token"]').getAttribute("content");
    for (const [path, form] of [["/admin/thematiq", { set_id: "zuiddrecht" }], ["/admin/thematiq/custom", { name: "x", save: "1" }],
                                ["/admin/thematiq/shell", { nextcloud_url: "https://example.org" }],
                                ["/admin/thematiq/top-bar", { top_bar_mode: "none" }]]) {
      const response = await page.request.post(path, { form: { ...form, authenticity_token: token }, maxRedirects: 0 });
      expect(response.status(), `POST ${path}`).toBe(403);
    }
  });

  test("sees the shell and only menu items they may open", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    await expect(page.locator(".op-app-header")).toHaveCSS("height", "68px");
    await expect(page.locator(".thematiq-app-row--item").first()).toBeVisible();
    await expect(page.getByRole("link", { name: "Thematiq design" })).toHaveCount(0);
    // The list under the nine-dot button has no "Manage apps" for a member.
    await page.getByRole("button", { name: "All apps and modules" }).click();
    const list = page.getByRole("dialog", { name: "All apps and modules" });
    await expect(list.locator("[data-thematiq-switcher-entry]").first()).toBeVisible();
    await expect(list.getByRole("link", { name: "Manage apps" })).toHaveCount(0);
    await page.keyboard.press("Escape");
    const links = await page.locator("#main-menu a[href]").evaluateAll((anchors) => [...new Set(anchors.map((a) => a.href))]);
    expect(links.length).toBeGreaterThan(5);
    for (const link of links) {
      const response = await page.request.get(link);
      expect(response.status(), link).toBeLessThan(400);
    }
  });

  test("Home shows the grid", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("region", { name: "Your widgets" })).toBeVisible();
  });
});
