// Signs in once as the administrator and once as an ordinary member, and keeps both sessions in .auth/.
// On a fresh install it walks through OpenProject's forced password change and its first-login dialogs.
// The member is created here through the API v3 and removed again in global-teardown.js.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { chromium, request } = require("@playwright/test");
const { config, signIn, MEMBER_LOGIN } = require("./env");

const AUTH = path.join(__dirname, "..", ".auth");

async function adminSession(browser) {
  const page = await browser.newPage({ baseURL: config.baseURL, viewport: { width: 1440, height: 1000 } });
  let result = await signIn(page, config.user, config.password);
  if (result === "refused" && config.initialPassword && config.initialPassword !== config.password) {
    result = await signIn(page, config.user, config.initialPassword);
    if (result !== "change_password") {
      throw new Error(`Cannot sign in as ${config.user}: neither THEMATIQ_E2E_PASSWORD nor the initial password works.`);
    }
    await page.fill("#password", config.initialPassword);
    await page.fill("#new_password", config.password);
    await page.fill("#new_password_confirmation", config.password);
    await Promise.all([page.waitForNavigation(), page.press("#new_password_confirmation", "Enter")]);
    result = "signed_in";
  }
  if (result !== "signed_in") throw new Error(`Cannot sign in as ${config.user}: ${result}.`);
  await dismissFirstLogin(page);
  await page.context().storageState({ path: path.join(AUTH, "admin.json") });
  return page;
}

// The language dialog and the introduction tour of a first sign-in. Both are OpenProject's own.
async function dismissFirstLogin(page) {
  await page.goto("/");
  const save = page.locator(".spot-modal").getByRole("button", { name: "Save" });
  if (await save.isVisible({ timeout: 3000 }).catch(() => false)) {
    await save.click();
    await page.waitForLoadState("load");
  }
  const skip = page.locator(".enjoyhint_skip_btn");
  if (await skip.isVisible({ timeout: 3000 }).catch(() => false)) await skip.click();
}

// One API call with the admin's session. OpenProject accepts a session on API v3 with this header.
async function api(context, method, url, data) {
  const response = await context.fetch(url, {
    method,
    headers: { "X-Requested-With": "XMLHttpRequest", "Content-Type": "application/json" },
    data: data ? JSON.stringify(data) : undefined,
  });
  const body = await response.text();
  return { status: response.status(), json: body ? JSON.parse(body) : null };
}

async function createMember(baseURL) {
  const context = await request.newContext({ baseURL, storageState: path.join(AUTH, "admin.json") });
  try {
    const found = await api(context, "GET", `/api/v3/users?filters=${encodeURIComponent(JSON.stringify([{ login: { operator: "=", values: [MEMBER_LOGIN] } }]))}`);
    for (const user of found.json?._embedded?.elements || []) await api(context, "DELETE", `/api/v3/users/${user.id}`);

    const password = `E2e-${crypto.randomBytes(9).toString("hex")}-Aa1!`;
    const created = await api(context, "POST", "/api/v3/users", {
      login: MEMBER_LOGIN, firstName: "Thematiq", lastName: "E2E member", email: `${MEMBER_LOGIN}@example.org`,
      admin: false, status: "active", language: "en", password,
    });
    if (created.status !== 201) throw new Error(`Cannot create the member: HTTP ${created.status} ${JSON.stringify(created.json?.message)}`);

    const project = await api(context, "GET", `/api/v3/projects/${config.project}`);
    if (project.status !== 200) throw new Error(`The project "${config.project}" does not exist. Set THEMATIQ_E2E_PROJECT.`);
    const roles = await api(context, "GET", "/api/v3/roles");
    const role = (roles.json?._embedded?.elements || []).find((element) => element.name === "Member");
    if (!role) throw new Error('OpenProject has no role named "Member".');
    const membership = await api(context, "POST", "/api/v3/memberships", {
      _links: { project: { href: `/api/v3/projects/${project.json.id}` }, principal: { href: `/api/v3/users/${created.json.id}` },
                roles: [{ href: `/api/v3/roles/${role.id}` }] },
    });
    if (membership.status !== 201) throw new Error(`Cannot add the member to the project: HTTP ${membership.status}`);
    fs.writeFileSync(path.join(AUTH, "member.json.meta"), JSON.stringify({ id: created.json.id }));
    return password;
  } finally {
    await context.dispose();
  }
}

module.exports = async () => {
  if (!config.password) throw new Error("Set THEMATIQ_E2E_PASSWORD to the administrator's password.");
  fs.mkdirSync(AUTH, { recursive: true });
  const browser = await chromium.launch();
  try {
    const page = await adminSession(browser);
    await page.close();
    const memberPassword = await createMember(config.baseURL);

    const memberPage = await browser.newPage({ baseURL: config.baseURL, viewport: { width: 1440, height: 1000 } });
    const result = await signIn(memberPage, MEMBER_LOGIN, memberPassword);
    if (result !== "signed_in") throw new Error(`Cannot sign in as the member: ${result}.`);
    await dismissFirstLogin(memberPage);
    await memberPage.context().storageState({ path: path.join(AUTH, "member.json") });
  } finally {
    await browser.close();
  }
};
