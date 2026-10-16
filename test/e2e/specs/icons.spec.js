// The icon library: listed for a signed-in person, each icon a static file anyone loads.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.describe("icon library", () => {
  test("the list names the sets and their licences, and an icon loads without a session", async ({ page, browser }) => {
    const list = await (await page.request.get("/thematiq/api/v1/icons")).json();
    expect(Object.keys(list.sets).sort()).toEqual(["den-haag", "dsfr", "open-gemeenten", "rvo"]);
    expect(list.sets.rvo.licence).toBe("CC0-1.0");
    const name = list.sets.rvo.names[0];
    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const icon = await visitor.request.get(list.url_template.replace("{set}", "rvo").replace("{name}", name));
    expect(icon.status()).toBe(200);
    expect(icon.headers()["content-type"]).toContain("image/svg+xml");
    await visitor.close();
  });
});
