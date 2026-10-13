// Removes the member the global setup created, so the installation is left as it was found.
const fs = require("fs");
const path = require("path");
const { request } = require("@playwright/test");
const { config } = require("./env");

module.exports = async () => {
  const AUTH = path.join(__dirname, "..", ".auth");
  const meta = path.join(AUTH, "member.json.meta");
  if (!fs.existsSync(meta) || !fs.existsSync(path.join(AUTH, "admin.json"))) return;
  const { id } = JSON.parse(fs.readFileSync(meta, "utf8"));
  const context = await request.newContext({ baseURL: config.baseURL, storageState: path.join(AUTH, "admin.json") });
  try {
    await context.fetch(`/api/v3/users/${id}`, { method: "DELETE", headers: { "X-Requested-With": "XMLHttpRequest" } });
  } finally {
    await context.dispose();
    fs.rmSync(meta, { force: true });
  }
};
