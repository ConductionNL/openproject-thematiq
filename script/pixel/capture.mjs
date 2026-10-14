// Takes the screenshot the pixel check compares: the work package table of a project at 1440 x 1000.
//
// usage: node script/pixel/capture.mjs <out.png>
//
// Environment:
//   THEMATIQ_PIXEL_URL       the address of OpenProject, for example http://localhost:8080
//   THEMATIQ_PIXEL_USER      a user who can see the project, default "admin"
//   THEMATIQ_PIXEL_PASSWORD  that user's password
//   THEMATIQ_PIXEL_PROJECT   the project's identifier, default "demo-project"
//
// It needs the "playwright" package and a browser Playwright can start. See docs/pixel-check.md.
// Exit code 2 when the page could not be captured.
import { chromium } from "playwright";

const out = process.argv[2];
const base = (process.env.THEMATIQ_PIXEL_URL || "").replace(/\/+$/, "");
const user = process.env.THEMATIQ_PIXEL_USER || "admin";
const password = process.env.THEMATIQ_PIXEL_PASSWORD;
const project = process.env.THEMATIQ_PIXEL_PROJECT || "demo-project";

if (!out || !base || !password) {
  console.error("CANNOT RUN: give an output file, THEMATIQ_PIXEL_URL and THEMATIQ_PIXEL_PASSWORD");
  process.exit(2);
}

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1 });
  await page.goto(`${base}/login`);
  await page.fill("#username", user);
  await page.fill("#password", password);
  await Promise.all([page.waitForNavigation(), page.press("#password", "Enter")]);
  await page.goto(`${base}/projects/${project}/work_packages`);
  await page.waitForSelector("table.work-package-table tbody tr", { timeout: 60000 });
  await page.evaluate(() => document.fonts.ready);
  // The caret and running animations would make two runs differ.
  await page.addStyleTag({ content: "*, *::before, *::after { animation: none !important; transition: none !important; caret-color: transparent !important; }" });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: out });
  console.log(`wrote ${out}`);
} catch (error) {
  console.error(`CANNOT RUN: ${error.message.split("\n")[0]}`);
  process.exitCode = 2;
} finally {
  await browser.close();
}
