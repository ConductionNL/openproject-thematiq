// The account menu as Nextcloud draws it: a dropdown under the avatar, not a sheet from the right. It opens on click
// and under the pointer, Escape closes it and puts the focus back, and its entries are core's.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const BUTTON = "#thematiq-account-button";
const PANEL = "#thematiq-account-panel";

async function openProjects(page) {
  await page.goto("/projects");
  await expect(page.locator(BUTTON)).toBeVisible();
}

test.describe("account menu", () => {
  test("a click opens a dropdown under the avatar with core's entries", async ({ page }) => {
    await openProjects(page);
    const button = page.locator(BUTTON);
    await expect(button).toHaveAttribute("aria-expanded", "false");
    await expect(button).toHaveAttribute("aria-controls", "thematiq-account-panel");
    await button.click();
    await expect(button).toHaveAttribute("aria-expanded", "true");

    const panel = page.getByRole("navigation", { name: "Account" });
    await expect(panel).toBeVisible();
    for (const name of ["My activity", "Account settings", "Administration", "Sign out"]) {
      await expect(panel.getByRole("link", { name })).toBeVisible();
    }
    await expect(panel.getByRole("link", { name: "Sign out" })).toHaveAttribute("data-turbo", "false");

    // Under the button and aligned to its right edge, not a sheet over the page.
    const b = await button.boundingBox();
    const p = await panel.boundingBox();
    expect(p.y).toBeGreaterThanOrEqual(b.y + b.height);
    expect(Math.abs(p.x + p.width - (b.x + b.width))).toBeLessThanOrEqual(1);
    expect(p.width).toBeLessThan(400);
    await expect(page.locator("dialog.Overlay--placement-right[open]")).toHaveCount(0);

    // A second click closes it, and so does a click outside.
    await button.click();
    await expect(panel).toBeHidden();
    await button.click();
    await expect(panel).toBeVisible();
    await page.locator("#content-wrapper").click({ position: { x: 600, y: 600 } });
    await expect(panel).toBeHidden();
    await expect(button).toHaveAttribute("aria-expanded", "false");
  });

  test("the pointer opens it and leaving closes it", async ({ page }) => {
    await openProjects(page);
    await page.locator(BUTTON).hover();
    await expect(page.locator(PANEL)).toBeVisible();
    await page.locator(PANEL).getByRole("link", { name: "Account settings" }).hover();
    await expect(page.locator(PANEL)).toBeVisible();
    await page.mouse.move(400, 600);
    await expect(page.locator(PANEL)).toBeHidden();
  });

  test("works by keyboard: Enter, the arrow keys, Escape returns the focus", async ({ page }) => {
    await openProjects(page);
    const button = page.locator(BUTTON);
    await button.focus();
    await page.keyboard.press("Enter");
    await expect(button).toHaveAttribute("aria-expanded", "true");
    await page.keyboard.press("ArrowDown");
    const entries = page.locator(`${PANEL} [data-thematiq-account-entry]`);
    await expect(entries.first()).toBeFocused();
    await page.keyboard.press("End");
    await expect(page.locator(PANEL).getByRole("link", { name: "Sign out" })).toBeFocused();
    await page.keyboard.press("Home");
    await expect(entries.first()).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(page.locator(PANEL)).toBeHidden();
    await expect(button).toBeFocused();
    await expect(button).toHaveAttribute("aria-expanded", "false");
  });

  test("the button names the person", async ({ page }) => {
    await openProjects(page);
    await expect(page.locator(BUTTON)).toHaveAccessibleName(/^Menu of \S/);
  });

  test("at 390 px the menu fits the screen", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await openProjects(page);
    await page.locator(BUTTON).click();
    const panel = await page.locator(PANEL).boundingBox();
    expect(panel.x).toBeGreaterThanOrEqual(0);
    expect(panel.x + panel.width).toBeLessThanOrEqual(390);
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBe(0);
  });
});

test.describe("account menu of a member", () => {
  test.use({ storageState: ".auth/member.json" });

  test("has no Administration", async ({ page }) => {
    await page.goto(`/projects/${config.project}/work_packages`);
    await page.locator(BUTTON).click();
    const panel = page.locator(PANEL);
    await expect(panel.getByRole("link", { name: "Account settings" })).toBeVisible();
    await expect(panel.getByRole("link", { name: "Administration" })).toHaveCount(0);
    await expect(panel).toContainText("Member");
  });
});
