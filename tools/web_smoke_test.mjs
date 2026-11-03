// Loads the exported web build in headless Chromium and fails if the page
// logs errors or never starts the engine. Usage: node tools/web_smoke_test.mjs <url>
import { chromium } from "playwright";

const url = process.argv[2] ?? "http://localhost:8060/index.html";
const browser = await chromium.launch({
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage();
const problems = [];
page.on("console", (msg) => {
  console.log(`[console.${msg.type()}] ${msg.text()}`);
  if (msg.type() === "error") problems.push(msg.text());
});
page.on("pageerror", (err) => {
  console.log(`[pageerror] ${err.message}`);
  problems.push(err.message);
});
page.on("requestfailed", (req) => {
  console.log(`[requestfailed] ${req.url()} ${req.failure()?.errorText}`);
  problems.push(`request failed: ${req.url()}`);
});

await page.goto(url);
await page.waitForTimeout(20000);
const status = await page.evaluate(() => {
  const s = document.getElementById("status");
  return s ? { visible: getComputedStyle(s).visibility, text: s.innerText } : null;
});
console.log("status overlay:", JSON.stringify(status));
await page.screenshot({ path: "web-smoke.png" });
await browser.close();

if (status && status.visible !== "hidden" && status.text.trim()) {
  problems.push(`status overlay still showing: ${status.text.trim()}`);
}
if (problems.length) {
  console.log(`::error::Web build has ${problems.length} problem(s)`);
  process.exit(1);
}
console.log("Web build started cleanly.");
