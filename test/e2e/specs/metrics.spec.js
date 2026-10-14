// /thematiq/metrics for a Prometheus scraper: off (404) unless the operator sets THEMATIQ_METRICS_TOKEN.
// Set THEMATIQ_E2E_METRICS_TOKEN to the same token to check the on state.
const { test, expect } = require("@playwright/test");
const { config } = require("../support/env");

test.describe("metrics", () => {
  test("answer only a scraper with the token, and nothing without one", async ({ browser }) => {
    const scraper = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const token = process.env.THEMATIQ_E2E_METRICS_TOKEN;
    if (!token) {
      expect((await scraper.request.get("/thematiq/metrics")).status()).toBe(404);
    } else {
      expect((await scraper.request.get("/thematiq/metrics")).status()).toBe(401);
      expect((await scraper.request.get("/thematiq/metrics", { headers: { Authorization: "Bearer wrong-token-wrong-token-wrong" } })).status()).toBe(401);
      const response = await scraper.request.get("/thematiq/metrics", { headers: { Authorization: `Bearer ${token}` } });
      expect(response.status()).toBe(200);
      const text = await response.text();
      expect(text).toContain("thematiq_up 1");
      expect(response.headers()["set-cookie"]).toBeUndefined();
    }
    await scraper.close();
  });
});
