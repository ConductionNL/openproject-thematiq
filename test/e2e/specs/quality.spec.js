// No console errors or content security policy violations on the main pages, and one accessibility pass.
// The accessibility pass fails only on the plugin's own markup. Findings in OpenProject's markup are attached
// to the report, not failed on.
const { test, expect } = require("@playwright/test");
const AxeBuilder = require("@axe-core/playwright").default;
const { config } = require("../support/env");
const { watchProblems, watchCsp } = require("../support/thematiq");

const P = `/projects/${config.project}`;
const MAIN_PAGES = ["/", "/projects", P, `${P}/work_packages`, `${P}/work_packages/details/2/overview`, `${P}/gantt`, `${P}/boards`,
                    `${P}/meetings`, `${P}/members`, "/admin", "/admin/thematiq", "/admin/thematiq/custom?from=cunningham", "/admin/thematiq/figma"];

test.describe("quality", () => {
  test("no console errors or policy violations on the main pages", async ({ page, context }) => {
    await watchCsp(context);
    const problems = watchProblems(page);
    for (const path of MAIN_PAGES) {
      const response = await page.goto(path);
      expect(response.status(), path).toBeLessThan(400);
      await page.waitForLoadState("networkidle").catch(() => {});
      const violations = await page.evaluate(() => window.__thematiqCsp || []);
      expect(violations, `content security policy on ${path}`).toEqual([]);
    }
    expect(problems).toEqual([]);
  });

  // The plugin's own markup on each page. Everything else on the page is OpenProject's.
  const PLUGIN = [".thematiq-picker", ".thematiq-picker__search", ".thematiq-picker__import", "#thematiq-shell-form",
                  ".thematiq-editor", ".thematiq-files", ".thematiq-figma__formats", "#thematiq-figma-form",
                  ".op-app-header", "#main-menu", ".thematiq-home"];

  // Known findings in the plugin's markup, open in docs/testing/2026-10-13-first-full-test.md. They are attached
  // to the report and do not fail the run. Anything else in the plugin's markup does. Remove a line once it is fixed.
  const KNOWN = [
    /^color-contrast \(serious\): \.global-search--input$/,               // finding 16: search field in the top bar, 4.38 to 1
    /^color-contrast \(serious\): \.thematiq-app-row--item.*\.thematiq-app-row--name$/, // finding 17: label of the current tile, 4.04 to 1
  ];

  for (const [name, path, visitor] of [["picker", "/admin/thematiq"], ["editor", "/admin/thematiq/custom?from=cunningham"],
                                        ["work package page", `${P}/work_packages`], ["sign-in page", "/login", true]]) {
    test(`accessibility of the ${name}`, async ({ browser }, testInfo) => {
      const context = await browser.newContext({ baseURL: config.baseURL, storageState: visitor ? { cookies: [], origins: [] } : ".auth/admin.json" });
      const page = await context.newPage();
      await page.goto(path);
      await page.waitForLoadState("networkidle").catch(() => {});
      // The small pictures of a design system are pictures: their text is incidental (WCAG 1.4.3) and hidden from assistive technology.
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
        .exclude('[data-test-selector="thematiq-shell-preview"]').exclude(".thematiq-thumb").analyze();
      const serious = results.violations.filter((violation) => ["serious", "critical"].includes(violation.impact));
      const ours = [];
      const core = [];
      for (const violation of serious) {
        for (const node of violation.nodes) {
          const target = node.target.join(" ");
          // A node is the plugin's when it sits inside markup the plugin renders or rewrites.
          const plugin = await page.evaluate(([selector, owners]) => {
            const element = document.querySelector(selector);
            return Boolean(element && (element.closest(owners) || /thematiq/.test(element.className?.toString() || "")));
          }, [node.target[node.target.length - 1], PLUGIN.join(", ")]).catch(() => false);
          (plugin ? ours : core).push(`${violation.id} (${violation.impact}): ${target}`);
        }
      }
      await context.close();
      const known = ours.filter((line) => KNOWN.some((pattern) => pattern.test(line)));
      const fresh = ours.filter((line) => !known.includes(line));
      await testInfo.attach(`axe ${name}`, { body: JSON.stringify({ plugin: fresh, known, core }, null, 2), contentType: "application/json" });
      for (const line of known) testInfo.annotations.push({ type: "known finding", description: line });
      expect(fresh, `serious or critical findings in the plugin's markup on the ${name}`).toEqual([]);
    });
  }
});
