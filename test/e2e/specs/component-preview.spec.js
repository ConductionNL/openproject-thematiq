// Your own component in a design system: pasted HTML and CSS in a frame that runs no script.
const { test, expect } = require("@playwright/test");
const { rgb, exported } = require("../support/thematiq");

test.describe("component preview", () => {
  test("pasted CSS reads the design system's variables in a sandboxed frame", async ({ page }) => {
    const chosen = await exported(page, "zuiddrecht");
    await page.goto("/admin/thematiq/playground?set_id=zuiddrecht");
    const form = page.locator("#thematiq-component-preview-form");
    await form.getByLabel("HTML").fill('<div class="card">My card</div><script>document.title = "ran"</script>');
    await form.getByLabel("CSS").fill(".card { background: var(--thematiq-primary); padding: 8px; }");
    await form.getByRole("button", { name: "Show my component" }).click();
    const frame = page.locator('[data-test-selector="thematiq-component-frame"]');
    await expect(frame).toHaveAttribute("sandbox", "");
    const card = page.frameLocator('[data-test-selector="thematiq-component-frame"]').locator(".card");
    await expect(card).toHaveCSS("background-color", rgb(chosen.tokens.primary));
    expect(await page.frameLocator('[data-test-selector="thematiq-component-frame"]').locator("html").evaluate(() => document.title)).not.toBe("ran");
  });

  test("CSS that reaches outward is refused and named", async ({ page }) => {
    await page.goto("/admin/thematiq/playground");
    const form = page.locator("#thematiq-component-preview-form");
    await form.getByLabel("HTML").fill("<p>x</p>");
    await form.getByLabel("CSS").fill("p { background: url(https://tracker.example/p.png); }");
    await form.getByRole("button", { name: "Show my component" }).click();
    await expect(page.locator('[data-test-selector="thematiq-preview-css-errors"]')).toBeVisible();
  });
});
