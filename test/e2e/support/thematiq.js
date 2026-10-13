// Shared steps of the specs. Every spec that changes the installation puts it back with these.
const path = require("path");
const zlib = require("zlib");
const { expect } = require("@playwright/test");

const PICKER = "/admin/thematiq";
const REPO = path.join(__dirname, "..", "..", "..");

// "#3669a5" -> "rgb(54, 105, 165)", the way getComputedStyle writes a colour.
function rgb(hex) {
  const value = hex.replace("#", "");
  const full = value.length === 3 ? value.split("").map((c) => c + c).join("") : value.slice(0, 6);
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16));
  return `rgb(${r}, ${g}, ${b})`;
}

// The id of the design system that is active now: the checked radio button of the picker.
async function activeSetId(page) {
  await page.goto(PICKER);
  return page.locator("input.thematiq-picker__radio:checked").getAttribute("value");
}

async function applySet(page, id) {
  await page.goto(PICKER);
  await page.locator(`#thematiq-set-${id}`).check();
  await Promise.all([page.waitForURL(/\/admin\/thematiq/), page.getByRole("button", { name: "Apply", exact: true }).click()]);
  await expect(page.locator('[data-test-selector="thematiq-active"]')).toBeVisible();
}

// The exported JSON of a design system, catalogue or custom.
async function exported(page, id) {
  const response = await page.request.get(`/admin/thematiq/export?id=${encodeURIComponent(id)}`);
  expect(response.status(), `export of ${id}`).toBe(200);
  return response.json();
}

async function customIds(page) {
  await page.goto(PICKER);
  return page.locator('[data-test-selector="thematiq-custom-option"] input.thematiq-picker__radio').evaluateAll((inputs) => inputs.map((input) => input.value));
}

// Makes a custom design system through the editor and returns its id. It becomes the active one.
async function createCustom(page, { name, from = "cunningham", tokens = {} }) {
  const before = await customIds(page);
  await page.goto(`/admin/thematiq/custom?from=${from}`);
  await page.locator("#thematiq-name").fill(name);
  for (const [key, value] of Object.entries(tokens)) await page.locator(`#thematiq-token-${key}`).fill(value);
  await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Save and apply" }).click()]);
  const after = await customIds(page);
  const added = after.filter((id) => !before.includes(id));
  expect(added, `one new custom design system named ${name}`).toHaveLength(1);
  return added[0];
}

async function deleteCustom(page, id) {
  await page.goto(`/admin/thematiq/custom?id=${encodeURIComponent(id)}`);
  const remove = page.getByRole("button", { name: "Delete this custom design system" });
  // Only a stored design system has the button. An unknown id opens a new, empty one.
  if (!(await remove.count())) return;
  // The delete is asked once more on a page of its own.
  await remove.click();
  await Promise.all([page.waitForURL(/\/admin\/thematiq$/), page.getByRole("button", { name: "Delete for good" }).click()]);
}

// Keeps the active design system and the list of custom ones, and puts both back after the test.
async function snapshot(page) {
  return { active: await activeSetId(page), customs: await customIds(page) };
}

async function restore(page, saved) {
  for (const id of await customIds(page)) if (!saved.customs.includes(id)) await deleteCustom(page, id);
  if (saved.active && (await activeSetId(page)) !== saved.active) await applySet(page, saved.active);
}

function flash(page) {
  return page.locator(".op-toast, .flash, [role=alert]");
}

// A whole PNG of the given size, one colour. Built here so the repository holds no binary test files.
function png(width, height, [r, g, b] = [200, 0, 80]) {
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buffer) => {
    let c = 0xffffffff;
    for (const byte of buffer) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
    return Buffer.concat([length, body, sum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4);
  header[8] = 8; header[9] = 2; header[10] = 0; header[11] = 0; header[12] = 0;
  const row = Buffer.concat([Buffer.from([0]), Buffer.alloc(width * 3).fill(Buffer.from([r, g, b]))]);
  const raw = Buffer.concat(Array.from({ length: height }, () => row));
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", header),
                        chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

// Console errors, page errors, content security policy violations and server errors of one page.
// OpenProject itself logs a few things the plugin has no part in; KNOWN_CORE names each one.
const KNOWN_CORE = [
  /gravatar\.com/,                                    // OpenProject asks Gravatar for avatars; 404 without one, refused offline
  /\/api\/v3\/users\/\d+\/avatar/,                    // a user without an uploaded avatar
  /Failed to load resource: the server responded with a status of 404 \(\)/, // the Gravatar answer above, without its address
  /Failed to load resource: net::ERR_/,               // Gravatar unreachable in a closed network
  /toolbarview-item-unavailable/,                     // CKEditor warns about toolbar items OpenProject leaves out
  /was preloaded using link preload but not used/,    // OpenProject preloads a stylesheet it loads later
];

function watchProblems(page) {
  const problems = [];
  const known = (text) => KNOWN_CORE.some((pattern) => pattern.test(text));
  page.on("console", (message) => {
    if (message.type() !== "error") return;
    const text = `${message.text()} ${message.location()?.url || ""}`;
    if (!known(text)) problems.push(`console: ${message.text().slice(0, 300)}`);
  });
  page.on("pageerror", (error) => problems.push(`page error: ${String(error).slice(0, 300)}`));
  page.on("response", (response) => {
    if (response.status() >= 500) problems.push(`HTTP ${response.status()} ${response.url()}`);
  });
  return problems;
}

// Content security policy violations are reported as an event in the page. This collects them.
async function watchCsp(context) {
  await context.addInitScript(() => {
    window.__thematiqCsp = [];
    document.addEventListener("securitypolicyviolation", (event) => {
      window.__thematiqCsp.push(`${event.violatedDirective} ${event.blockedURI}`);
    });
  });
}

module.exports = { REPO, PICKER, rgb, activeSetId, applySet, exported, customIds, createCustom, deleteCustom, snapshot, restore, flash, png, watchProblems, watchCsp };
