// The settings of a run, from the environment. No secret lives in the repository.
const config = {
  baseURL: (process.env.THEMATIQ_E2E_URL || "http://localhost:8080").replace(/\/+$/, ""),
  user: process.env.THEMATIQ_E2E_USER || "admin",
  password: process.env.THEMATIQ_E2E_PASSWORD,
  initialPassword: process.env.THEMATIQ_E2E_INITIAL_PASSWORD ?? "admin",
  project: process.env.THEMATIQ_E2E_PROJECT || "demo-project",
};

const MEMBER_LOGIN = "thematiq-e2e-member";

// Signs in through the real form. Returns "signed_in", "change_password" or "refused".
async function signIn(page, login, password) {
  await page.goto(`${config.baseURL}/login`);
  await page.fill("#username", login);
  await page.fill("#password", password);
  await Promise.all([page.waitForLoadState("load"), page.press("#password", "Enter")]);
  await page.waitForLoadState("load");
  if (await page.locator("#new_password").count()) return "change_password";
  if (new URL(page.url()).pathname === "/login") return "refused";
  return "signed_in";
}

module.exports = { config, signIn, MEMBER_LOGIN };
