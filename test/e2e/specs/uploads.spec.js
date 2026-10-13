// Uploads of a custom design system: each kind shows where it should, hostile files are cleaned or refused,
// and the public file route serves without a session and refuses near-miss addresses.
const path = require("path");
const { test, expect } = require("@playwright/test");
const { REPO, createCustom, snapshot, restore, png } = require("../support/thematiq");
const { config } = require("../support/env");

const FIXTURES = path.join(REPO, "test", "fixtures", "uploads");
const FONT = path.join(REPO, "public", "thematiq", "fonts", "barlow-latin-400-normal.woff2");

async function upload(page, id, kind, file, extra) {
  await page.goto(`/admin/thematiq/custom?id=${id}`);
  const form = page.locator(`#thematiq-file-${kind}-form`);
  await form.locator('input[type="file"]').setInputFiles(file);
  if (extra) await extra(form);
  await Promise.all([page.waitForURL(new RegExp(`/admin/thematiq/custom\\?id=${id}$`)), form.locator('button[name="upload"]').click()]);
  return form;
}

// The address of the file the form shows now.
const shown = (form) => form.locator("img").getAttribute("src");

test.describe("uploads", () => {
  let saved;
  let id;
  test.beforeEach(async ({ page }) => {
    saved = await snapshot(page);
    id = await createCustom(page, { name: `E2E uploads ${Date.now()}`, from: "cunningham" });
  });
  test.afterEach(async ({ page }) => { await restore(page, saved); });

  test("each kind appears where it should", async ({ page }) => {
    const logo = await upload(page, id, "logo", { name: "logo.png", mimeType: "image/png", buffer: png(240, 60) });
    await expect(page.getByText("The logo is uploaded and in use.").first()).toBeVisible();
    const logoUrl = await shown(logo);
    expect(logoUrl).toMatch(/^\/thematiq\/files\/[0-9a-f]{64}$/);

    const inverse = await upload(page, id, "logo-inverse", { name: "inverse.png", mimeType: "image/png", buffer: png(240, 60, [255, 255, 255]) });
    const inverseUrl = await shown(inverse);
    const favicon = await upload(page, id, "favicon", { name: "favicon.png", mimeType: "image/png", buffer: png(32, 32) });
    const faviconUrl = await shown(favicon);
    const touch = await upload(page, id, "touch-icon", { name: "touch.png", mimeType: "image/png", buffer: png(180, 180) });
    const touchUrl = await shown(touch);
    await upload(page, id, "logo-mobile", { name: "mobile.png", mimeType: "image/png", buffer: png(64, 64) });
    await expect(page.getByText("The mobile logo is uploaded and in use.").first()).toBeVisible();
    await upload(page, id, "font", FONT, async (form) => { await form.getByLabel("Family name", { exact: true }).fill("E2E Barlow"); });
    await expect(page.getByText("The font is uploaded and in use.").first()).toBeVisible();

    await page.goto("/projects");
    // The variant for the coloured top bar comes first when both are there.
    await expect(page.locator(".op-logo--link").first()).toHaveCSS("background-image", new RegExp(inverseUrl));
    // The plugin writes its icon links before and after OpenProject's own, on purpose (docs/layouts.md). The last one counts.
    await expect(page.locator('link[rel="icon"]').last()).toHaveAttribute("href", faviconUrl);
    await expect(page.locator('link[rel="apple-touch-icon"]').last()).toHaveAttribute("href", touchUrl);
    const faces = await page.evaluate(() => [...document.styleSheets].flatMap((sheet) => {
      try { return [...sheet.cssRules].filter((rule) => rule instanceof CSSFontFaceRule).map((rule) => rule.cssText); } catch { return []; }
    }));
    expect(faces.some((rule) => rule.includes("E2E Barlow") && /\/thematiq\/files\/[0-9a-f]{64}/.test(rule))).toBe(true);
    expect(logoUrl).not.toBe(inverseUrl);
  });

  test("a hostile SVG is cleaned and a refused file changes nothing", async ({ page }) => {
    const form = await upload(page, id, "logo", path.join(FIXTURES, "hostile-script.svg"));
    await expect(page.getByText("Parts of the SVG file that the plugin does not allow were left out.").first()).toBeVisible();
    const url = await shown(form);
    const served = await page.request.get(url);
    const body = await served.text();
    expect(body).toContain("<svg");
    expect(body).not.toMatch(/<script|onload|javascript:/i);
    expect(served.headers()["content-security-policy"]).toContain("sandbox");

    await upload(page, id, "logo", path.join(FIXTURES, "hostile-entity-bomb.svg"));
    await expect(page.getByText("The SVG file declares entities or a document type of its own.").first()).toBeVisible();
    await upload(page, id, "logo", { name: "logo.png", mimeType: "image/png", buffer: Buffer.from("<html><script>alert(1)</script></html>") });
    await expect(page.getByText("The plugin does not know this kind of file. Nothing was uploaded.").first()).toBeVisible();
    await upload(page, id, "touch-icon", { name: "small.png", mimeType: "image/png", buffer: png(64, 64) });
    await expect(page.getByText("The picture is too small.").first()).toBeVisible();
    expect(await shown(page.locator("#thematiq-file-logo-form"))).toBe(url);
  });

  test("the public file route serves without a session and refuses near misses", async ({ page, browser }) => {
    const form = await upload(page, id, "favicon", { name: "favicon.png", mimeType: "image/png", buffer: png(32, 32) });
    const url = await shown(form);
    const token = url.split("/").pop();

    const visitor = await browser.newContext({ baseURL: config.baseURL, storageState: { cookies: [], origins: [] } });
    const response = await visitor.request.get(url);
    expect(response.status()).toBe(200);
    const headers = response.headers();
    expect(headers["content-type"]).toBe("image/png");
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["cross-origin-resource-policy"]).toBe("same-origin");
    expect(headers["cache-control"]).toContain("immutable");
    expect(headers["set-cookie"]).toBeUndefined();
    const again = await visitor.request.get(url, { headers: { "If-None-Match": headers.etag } });
    expect(again.status()).toBe(304);

    for (const miss of [token.slice(1), token.toUpperCase(), `${token}.png`, `${token}0`, "..%2f..%2fetc%2fpasswd", "0".repeat(64)]) {
      const near = await visitor.request.get(`/thematiq/files/${miss}`);
      expect(near.status(), miss).toBe(404);
    }
    await visitor.close();
  });
});
