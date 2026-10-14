// The read endpoints: the catalogue, one design system, its style sheets, a contrast check, and thematiq's shell-tokens.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.describe("read endpoints", () => {
  test("a signed-in person reads the catalogue, one design system and its style sheets", async ({ page }) => {
    const list = await (await page.request.get("/thematiq/api/v1/sets")).json();
    expect(list.version).toBe(1);
    expect(list.sets.length).toBeGreaterThanOrEqual(60);
    expect(list.sets.filter((set) => set.active)).toHaveLength(1);

    const one = await page.request.get("/thematiq/api/v1/sets/zuiddrecht");
    expect(one.status()).toBe(200);
    expect((await one.json()).tokens.primary).toMatch(/^#/);
    expect((await page.request.get("/thematiq/api/v1/sets/no-such-set")).status()).toBe(404);

    const manifest = await (await page.request.get("/thematiq/api/v1/sets/zuiddrecht/manifest")).json();
    const css = await page.request.get(new URL(manifest.stylesheets[0].url).pathname);
    expect(css.headers()["content-type"]).toContain("text/css");
    expect(await css.text()).toContain("--header-bg-color");

    const contrast = await (await page.request.get("/thematiq/api/v1/contrast?foreground=%23000000&background=%23ffffff")).json();
    expect(contrast.verdict).toBe("pass");
  });

  test("shell-tokens answers without a session; the rest needs one", async ({ browser }) => {
    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const tokens = await visitor.request.get("/thematiq/api/shell-tokens");
    expect(tokens.status()).toBe(200);
    const body = await tokens.json();
    expect(body.version).toBe(1);
    expect(Object.keys(body.tokens)).toHaveLength(18);
    expect(tokens.headers()["set-cookie"]).toBeUndefined();

    const list = await visitor.request.get("/thematiq/api/v1/sets", { headers: { Accept: "application/json" }, maxRedirects: 0 });
    expect([302, 401]).toContain(list.status());
    await visitor.close();
  });
});
