// Loads the exported web build in headless Chromium and fails if the page
// logs errors or never starts the engine. Usage: node tools/web_smoke_test.mjs <url>
import { chromium } from "playwright";

const url = process.argv[2] ?? "http://localhost:8060/index.html";
const browser = await chromium.launch({
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
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
// Print screenshots so they can be inspected straight from the CI log.
async function dumpScreenshot(label) {
  const shot = await page.screenshot({ type: "jpeg", quality: 60 });
  // Chunked lines: very long log lines get cut off.
  const data = shot.toString("base64");
  console.log(`SCREENSHOT_BASE64_BEGIN ${label}`);
  for (let i = 0; i < data.length; i += 4000) console.log(data.slice(i, i + 4000));
  console.log("SCREENSHOT_BASE64_END");
}
await dumpScreenshot("game");
// Walk forward for a bit, then peek at the inventory and the map.
await page.mouse.click(640, 360);
await page.keyboard.down("KeyW");
await page.waitForTimeout(2500);
await page.keyboard.up("KeyW");
await dumpScreenshot("walked");
await page.keyboard.press("KeyI");
await page.waitForTimeout(800);
await dumpScreenshot("inventory");
await page.keyboard.press("KeyI");
await page.keyboard.press("KeyM");
await page.waitForTimeout(800);
await dumpScreenshot("map");
await page.keyboard.press("KeyM");
await browser.close();

if (status && status.visible !== "hidden" && status.text.trim()) {
  problems.push(`status overlay still showing: ${status.text.trim()}`);
}
if (problems.length) {
  console.log(`::error::Web build has ${problems.length} problem(s)`);
  // exitCode instead of exit() so buffered stdout (the screenshots) still flushes.
  process.exitCode = 1;
} else {
  console.log("Web build started cleanly.");
}
