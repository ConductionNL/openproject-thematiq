// A custom design system: create, export, delete and import again. Download for Figma and upload again.
const fs = require("fs");
const { test, expect } = require("@playwright/test");
const { PICKER, exported, createCustom, deleteCustom, customIds, snapshot, restore } = require("../support/thematiq");

test.describe("export, import and Figma", () => {
  let saved;
  test.beforeEach(async ({ page }) => { saved = await snapshot(page); });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("a custom design system survives export, delete and import", async ({ page }) => {
    const name = `E2E round trip ${Date.now()}`;
    const id = await createCustom(page, { name, from: "zuiddrecht", tokens: { primary: "#ffee00", "font-family": "Georgia, serif" } });
    const before = await exported(page, id);
    expect(before.tokens.primary).toBe("#ffee00");

    await page.goto(PICKER);
    const [download] = await Promise.all([page.waitForEvent("download"), page.getByRole("link", { name: `Export ${name} as a file`, exact: true }).click()]);
    const file = await download.path();
    expect(JSON.parse(fs.readFileSync(file, "utf8")).tokens).toEqual(before.tokens);

    await deleteCustom(page, id);
    expect(await customIds(page)).not.toContain(id);

    await page.goto(PICKER);
    await page.setInputFiles("#thematiq-import-file", file);
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
    await expect(page.getByText(`"${name}" is added as a custom design system.`).filter({ visible: true }).first()).toBeVisible();
    const added = (await customIds(page)).filter((custom) => !saved.customs.includes(custom));
    expect(added).toHaveLength(1);
    expect((await exported(page, added[0])).tokens).toEqual(before.tokens);
  });

  test("a file that is not a design system is refused and changes nothing", async ({ page }) => {
    await page.goto(PICKER);
    await page.setInputFiles("#thematiq-import-file", { name: "broken.json", mimeType: "application/json", buffer: Buffer.from("{ not json") });
    await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.locator("#thematiq-import-form").getByRole("button", { name: "Import" }).click()]);
    await expect(page.getByText("The file is not a design system file. It could not be read as JSON.").filter({ visible: true }).first()).toBeVisible();
    expect(await customIds(page)).toEqual(saved.customs);
  });

  for (const [format, label] of [["dtcg", "W3C design tokens"], ["tokens-studio", "Tokens Studio"], ["tokens-studio-legacy", "Tokens Studio, legacy spelling"]]) {
    test(`a Figma download as ${label} uploads again with the same values`, async ({ page }) => {
      const source = await exported(page, "zuiddrecht");
      await page.goto("/admin/thematiq/figma?id=zuiddrecht");
      const [download] = await Promise.all([page.waitForEvent("download"), page.getByRole("link", { name: `Download ${source.name} as ${label}`, exact: true }).click()]);
      expect(download.url()).toContain(`file_format=${format}`);

      await page.setInputFiles("#thematiq-figma-files", await download.path());
      await page.locator("#thematiq-figma-form").getByRole("button", { name: "Upload from Figma" }).click();
      await expect(page.getByText(`"${source.name}" is added as a custom design system. It is not applied yet.`).filter({ visible: true }).first()).toBeVisible();

      const added = (await customIds(page)).filter((custom) => !saved.customs.includes(custom));
      expect(added).toHaveLength(1);
      expect((await exported(page, added[0])).tokens).toEqual(source.tokens);
    });
  }
});
