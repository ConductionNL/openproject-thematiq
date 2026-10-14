// The Gantt page as the OpGantt board draws it (Shell::Gantt). Uses the demo project's own work packages: a
// summary task with children, a milestone and "follows" relations are part of OpenProject's demo data.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

const ganttPath = `/projects/${config.project}/gantt`;

async function openGantt(page, query = "") {
  await page.goto(`${ganttPath}${query}`);
  await expect(page.locator("[data-test-selector=thematiq-gantt-bar]")).toBeVisible();
}

async function zoomTo(page, level) {
  await page.locator("[data-test-selector=thematiq-gantt-zoom]").selectOption(level);
  await expect(page.locator("body")).toHaveAttribute("data-tq-gantt-zoom", level);
}

function token(page, name) {
  return page.evaluate((n) => {
    const probe = document.createElement("span");
    probe.style.color = `var(${n})`;
    document.body.appendChild(probe);
    const value = getComputedStyle(probe).color;
    probe.remove();
    return value;
  }, name);
}

test.describe("Gantt page", () => {
  test("the chips, the actions and the view switch of the board", async ({ page }) => {
    await openGantt(page);
    const chips = page.locator(".thematiq-gantt__chips a");
    await expect(chips.first()).toHaveText(/^All open\s*\d+$/);
    await expect(chips.first()).toHaveAttribute("aria-current", "page");
    await expect(page.getByRole("button", { name: "Export PDF" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Today" })).toBeVisible();

    const views = page.getByRole("group", { name: "View" });
    await expect(views.getByRole("link", { name: "Gantt" })).toHaveAttribute("aria-current", "page");
    await expect(views.getByRole("link", { name: "Table" })).toHaveAttribute("href", new RegExp(`/projects/${config.project}/work_packages`));
    // Core's three zoom buttons make way for the list, which presses them.
    await expect(page.locator("#work-packages-timeline-zoom-in-button")).toBeHidden();

    const milestones = page.getByRole("link", { name: "Milestones only" });
    if (await milestones.count()) {
      await milestones.click();
      await expect(page).toHaveURL(/name=milestones/);
      await expect(page.getByRole("link", { name: "Milestones only" })).toHaveAttribute("aria-current", "page");
    }
  });

  test("weeks: one label per week, a letter per day, weekends shaded, today marked", async ({ page }) => {
    await openGantt(page);
    await zoomTo(page, "weeks");
    const header = page.locator(".wp-table-timeline--header-inner");
    await expect(header.locator('[data-tq-row="week"]').first()).toHaveText(/^\d{1,2} \S+$/);
    await expect(header.locator('[data-tq-row="day"]').first()).toHaveText(/^\S$/);
    expect(await page.locator("wp-timeline-header").evaluate((node) => node.getBoundingClientRect().height)).toBe(44);

    const weekend = page.locator(".wp-timeline--non-working-day").first();
    await expect(weekend).toBeAttached();
    expect(await weekend.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe(await token(page, "--thematiq-ground"));

    const today = page.locator("#wp-timeline-static-element-today-line");
    await expect(today).toHaveAttribute("data-label", "Today");
    await page.getByRole("button", { name: "Today" }).click();
    const side = await page.locator(".work-packages-tabletimeline--timeline-side").boundingBox();
    const line = await today.boundingBox();
    expect(line.x).toBeGreaterThanOrEqual(side.x);
    expect(line.x).toBeLessThanOrEqual(side.x + side.width);

    await zoomTo(page, "days");
    await expect(header.locator('[data-tq-row="day"]').first()).toHaveText(/^\S \d{1,2}$/);
  });

  test("bars, the parent, the milestone and the dependency lines in the board's shapes", async ({ page }) => {
    await openGantt(page);
    await expect(page.locator(".wp-timeline-cell").first()).toBeVisible();
    const action = await token(page, "--thematiq-action");
    const light = await token(page, "--thematiq-primary-light");

    const leaf = page.locator('.wp-timeline-cell:not([class*="__hierarchy-root-"]) .timeline-element.bar').first();
    expect(await leaf.evaluate((node) => node.getBoundingClientRect().height)).toBe(20);
    expect(await leaf.locator(".timeline-element--bg").evaluate((node) => getComputedStyle(node).backgroundColor)).toBe(action);

    const parent = page.locator('.wp-timeline-cell[class*="__hierarchy-root-"] .timeline-element.bar .timeline-element--bg').first();
    expect(await parent.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe(light);

    const diamond = page.locator(".timeline-element.milestone .diamond").first();
    expect(await diamond.evaluate((node) => node.offsetWidth)).toBe(14);

    // Core's lines are drawn for rows of 40 px and hidden; the plugin's follow the bars of 48 px rows.
    await expect(page.locator(".thematiq-gantt__relations path").first()).toBeAttached();
    expect(await page.locator(".relation-line").first().evaluate((node) => getComputedStyle(node).visibility)).toBe("hidden");

    const legend = page.locator("[data-test-selector=thematiq-gantt-legend] li");
    await expect(legend).toHaveText(["Work package", "Parent, spans its children", "Milestone", "Follows, starts after the one before"]);
  });

  test("Export PDF opens core's export dialog", async ({ page }) => {
    await openGantt(page);
    await page.getByRole("button", { name: "Export PDF" }).click();
    const dialog = page.locator("dialog[open]");
    await expect(dialog).toBeVisible();
    await expect(dialog).toContainText("PDF");
  });
});

test.describe("Gantt page at 390 px", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  // Core shows cards without a timeline on a phone, so Today, the zoom list and the legend step aside.
  test("the row of chips stays on the screen; the timeline's controls step aside with the timeline", async ({ page }) => {
    await openGantt(page);
    await expect(page.locator("body")).toHaveAttribute("data-tq-gantt-timeline", "off");
    const bar = await page.locator("[data-test-selector=thematiq-gantt-bar]").boundingBox();
    expect(bar.x).toBeGreaterThanOrEqual(0);
    expect(bar.x + bar.width).toBeLessThanOrEqual(390);
    await expect(page.getByRole("button", { name: "Today" })).toBeHidden();
    await expect(page.locator("[data-test-selector=thematiq-gantt-zoom]")).toBeHidden();
    await expect(page.getByRole("group", { name: "View" })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBe(0);
  });
});
