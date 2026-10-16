// gov-federated-share: one instance serves its setup with a share key, another pulls it after a preview. Both off by default.
// A pull needs an https address. Set THEMATIQ_E2E_SHARE_URL to an https address that reaches this instance's
// /thematiq/api/v1/setup (a TLS proxy the instance trusts) to run the pull itself; without it that test is skipped.
const { test, expect } = require("@playwright/test");
const { flash } = require("../support/thematiq");

const SHARE = "/admin/thematiq/share";
const ENDPOINT = "/thematiq/api/v1/setup";
const SHARE_URL = process.env.THEMATIQ_E2E_SHARE_URL;

async function setServing(page, on) {
  await page.goto(SHARE);
  const box = page.getByLabel("Let one other instance read this setup with the key");
  if (on) await box.check(); else await box.uncheck();
  await page.locator("#thematiq-share-serve-form").getByRole("button", { name: "Save", exact: true }).click();
  await expect(flash(page).filter({ hasText: "The share settings are saved." }).first()).toBeVisible();
}

async function setPulling(page, { on, url, key = "" }) {
  await page.goto(SHARE);
  const form = page.locator("#thematiq-share-pull-form");
  const box = form.getByLabel("Read the setup from the address below");
  if (on) await box.check(); else await box.uncheck();
  await form.getByLabel("Address of the other instance's setup").fill(url);
  await form.getByLabel("Share key of the other instance").fill(key);
  await form.getByRole("button", { name: "Save", exact: true }).click();
}

test.describe("federated share", () => {
  test.afterEach(async ({ page }) => {
    await setServing(page, false);
    await setPulling(page, { on: false, url: "" });
  });

  test("serving is off by default, then answers only to its key", async ({ page, playwright }) => {
    const anonymous = await playwright.request.newContext({ baseURL: test.info().project.use.baseURL, storageState: { cookies: [], origins: [] } });
    expect((await anonymous.get(ENDPOINT)).status()).toBe(404);

    await page.goto("/admin/thematiq");
    await page.locator('[data-test-selector="thematiq-share-link"]').click();
    await expect(page).toHaveURL(/\/admin\/thematiq\/share$/);
    await expect(page.getByLabel("Let one other instance read this setup with the key")).not.toBeChecked();
    await expect(page.locator("#thematiq-share-key")).toHaveCount(0);

    await setServing(page, true);
    await expect(page.locator("#thematiq-share-address")).toHaveValue(/\/thematiq\/api\/v1\/setup$/);
    const key = await page.locator("#thematiq-share-key").inputValue();
    expect(key).toMatch(/^[A-Za-z0-9_-]{32,128}$/);

    expect((await anonymous.get(ENDPOINT)).status()).toBe(403);
    expect((await anonymous.get(ENDPOINT, { headers: { "X-Thematiq-Share-Key": `${key.slice(0, -1)}x` } })).status()).toBe(403);
    const served = await anonymous.get(ENDPOINT, { headers: { "X-Thematiq-Share-Key": key } });
    expect(served.status()).toBe(200);
    expect(served.headers()["cache-control"]).toContain("no-store");
    const file = await served.json();
    expect(file.format).toBe("openproject-thematiq-bundle");
    expect(JSON.stringify(file)).not.toContain(key);
    expect((await anonymous.post(ENDPOINT, { headers: { "X-Thematiq-Share-Key": key } })).status()).not.toBe(200);

    await page.getByRole("button", { name: "Make a new key" }).click();
    await expect(flash(page).filter({ hasText: "There is a new share key." }).first()).toBeVisible();
    expect((await anonymous.get(ENDPOINT, { headers: { "X-Thematiq-Share-Key": key } })).status()).toBe(403);

    await setServing(page, false);
    const fresh = await page.locator("#thematiq-share-key").count();
    expect(fresh).toBe(0);
    expect((await anonymous.get(ENDPOINT, { headers: { "X-Thematiq-Share-Key": key } })).status()).toBe(404);
    await anonymous.dispose();
  });

  test("pulling is off by default and takes only an https address", async ({ page }) => {
    await page.goto(SHARE);
    await expect(page.getByLabel("Read the setup from the address below")).not.toBeChecked();
    await expect(page.getByRole("button", { name: "Pull now" })).toHaveCount(0);

    await setPulling(page, { on: true, url: "http://other.example.org/thematiq/api/v1/setup", key: "k".repeat(43) });
    await expect(flash(page).filter({ hasText: "Use an https address" }).first()).toBeVisible();
    await expect(page.getByLabel("Read the setup from the address below")).not.toBeChecked();
  });

  test("a pull that cannot reach the other instance changes nothing", async ({ page }) => {
    await setPulling(page, { on: true, url: "https://127.0.0.1:9/thematiq/api/v1/setup", key: "k".repeat(43) });
    await expect(flash(page).filter({ hasText: "The share settings are saved." }).first()).toBeVisible();
    const before = await (await page.request.get("/admin/thematiq/bundle")).json();
    await page.getByRole("button", { name: "Pull now" }).click();
    await expect(flash(page).filter({ hasText: "The setup could not be pulled" }).first()).toBeVisible();
    await expect(page.locator('[data-test-selector="thematiq-share-status"]')).toContainText("failed");
    const after = await (await page.request.get("/admin/thematiq/bundle")).json();
    expect(after.settings).toEqual(before.settings);
  });

  test("a pull shows what it changes before anything is applied", async ({ page }) => {
    test.skip(!SHARE_URL, "THEMATIQ_E2E_SHARE_URL is not set");
    await setServing(page, true);
    const key = await page.locator("#thematiq-share-key").inputValue();
    await setPulling(page, { on: true, url: SHARE_URL, key });
    await page.getByRole("button", { name: "Pull now" }).click();
    await expect(page.locator('[data-test-selector="thematiq-bundle-import"]')).toBeVisible();
    await expect(page.locator('[data-test-selector="thematiq-share-pulled-from"]')).toContainText(SHARE_URL);
    // The other instance here is this one, so its setup is this setup: the preview says nothing changes.
    await expect(page.locator('[data-test-selector="thematiq-bundle-nothing"]')).toBeVisible();
    await page.goto(SHARE);
    await expect(page.locator('[data-test-selector="thematiq-share-status"]')).toContainText("Last pulled");
  });
});
