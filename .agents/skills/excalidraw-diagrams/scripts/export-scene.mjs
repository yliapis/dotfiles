#!/usr/bin/env node
/**
 * Export excalidraw-mcp shorthand elements to committable artifacts:
 *   <out>.svg         vector render (embed in README/docs)
 *   <out>.excalidraw  editable scene (open on excalidraw.com, or upload via export_to_excalidraw)
 *   <out>.png         raster render (visual QA — always inspect before committing)
 *
 * Replays the widget's own pipeline (label defaults -> convertToExcalidrawElements
 * -> Excalifont -> exportToSvg -> serializeAsJSON) in headless Chrome, loading
 * @excalidraw/excalidraw from esm.sh exactly like the built widget does.
 * Pseudo-elements (cameraUpdate, delete, restoreCheckpoint) are filtered out.
 *
 * Usage: node export-scene.mjs <elements.json> <out-basename>
 *   e.g. node export-scene.mjs /tmp/elements.json docs/my-diagram
 *
 * Requirements: a Chrome/Chromium binary (CHROME_PATH env overrides detection),
 * npm, and network access to esm.sh. puppeteer-core is installed on first use
 * into /tmp/excalidraw-export-driver.
 */

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";

// Versions matching third_party/excalidraw-mcp (package.json / vite.config.ts)
const EXCALIDRAW_VERSION = "0.18.0";
const REACT_VERSION = "19.0.0";

const [elementsPath, outBase] = process.argv.slice(2);
if (!elementsPath || !outBase) {
  console.error("usage: node export-scene.mjs <elements.json> <out-basename>");
  process.exit(2);
}

const elementsJson = fs.readFileSync(elementsPath, "utf-8");
JSON.parse(elementsJson); // fail fast on invalid input

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "/usr/local/bin/google-chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ].filter(Boolean);
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  console.error(
    "error: no Chrome/Chromium binary found. Install one or set CHROME_PATH.",
  );
  process.exit(1);
}

function ensurePuppeteer() {
  const driverDir = path.join(os.tmpdir(), "excalidraw-export-driver");
  const require = createRequire(path.join(driverDir, "index.js"));
  try {
    return require("puppeteer-core");
  } catch {
    console.error("Installing puppeteer-core (first use)...");
    fs.mkdirSync(driverDir, { recursive: true });
    fs.writeFileSync(
      path.join(driverDir, "package.json"),
      JSON.stringify({ name: "excalidraw-export-driver", private: true }),
    );
    execFileSync("npm", ["install", "puppeteer-core@24", "--no-fund", "--no-audit"], {
      cwd: driverDir,
      stdio: "inherit",
    });
    return require("puppeteer-core");
  }
}

const RENDER_HTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>body { margin: 0; padding: 0; } svg { display: block; }</style>
<script>window.EXCALIDRAW_ASSET_PATH = "https://esm.sh/@excalidraw/excalidraw@${EXCALIDRAW_VERSION}/dist/prod/";</script>
<script type="importmap">
{
  "imports": {
    "react": "https://esm.sh/react@${REACT_VERSION}",
    "react-dom": "https://esm.sh/react-dom@${REACT_VERSION}?deps=react@${REACT_VERSION}",
    "react/jsx-runtime": "https://esm.sh/react@${REACT_VERSION}/jsx-runtime",
    "@excalidraw/excalidraw": "https://esm.sh/@excalidraw/excalidraw@${EXCALIDRAW_VERSION}?deps=react@${REACT_VERSION},react-dom@${REACT_VERSION}"
  }
}
</script>
<script type="application/json" id="elements-data">__ELEMENTS__</script>
</head>
<body>
<script type="module">
import { exportToSvg, convertToExcalidrawElements, serializeAsJSON, FONT_FAMILY } from "@excalidraw/excalidraw";

const raw = JSON.parse(document.getElementById("elements-data").textContent);
const pseudo = new Set(["cameraUpdate", "delete", "restoreCheckpoint"]);
const real = raw.filter(el => !pseudo.has(el.type));
// Same label defaults the widget applies before conversion
const withDefaults = real.map(el =>
  el.label ? { ...el, label: { textAlign: "center", verticalAlign: "middle", ...el.label } } : el
);

try {
  const converted = convertToExcalidrawElements(withDefaults, { regenerateIds: false })
    .map(el => el.type === "text" ? { ...el, fontFamily: (FONT_FAMILY).Excalifont ?? 1 } : el);

  const svg = await exportToSvg({
    elements: converted,
    appState: { exportBackground: true, viewBackgroundColor: "#ffffff" },
    files: null,
    exportPadding: 32,
  });
  document.body.appendChild(svg);

  const sceneJson = serializeAsJSON(converted, {}, {}, "database");
  const holder = document.createElement("script");
  holder.type = "application/json";
  holder.id = "scene-json";
  holder.textContent = sceneJson.replace(/</g, "\\\\u003c");
  document.body.appendChild(holder);

  await document.fonts.ready;
  const w = Math.ceil(parseFloat(svg.getAttribute("width")));
  const h = Math.ceil(parseFloat(svg.getAttribute("height")));
  document.title = \`READY \${w} \${h}\`;
} catch (err) {
  document.title = "ERROR " + err.message;
}
</script>
</body>
</html>
`;

const puppeteer = ensurePuppeteer();
const chromePath = findChrome();

const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "excalidraw-render-"));
const htmlPath = path.join(workDir, "render.html");
// Escape "<" inside the injected JSON so it cannot terminate the script tag
fs.writeFileSync(
  htmlPath,
  RENDER_HTML.replace("__ELEMENTS__", elementsJson.replace(/</g, "\\u003c")),
);

const browser = await puppeteer.launch({
  executablePath: chromePath,
  headless: "new",
  args: ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1600, height: 1200, deviceScaleFactor: 2 });
  page.on("pageerror", (e) => console.error("[pageerror]", e.message));

  await page.goto(`file://${htmlPath}`, { waitUntil: "networkidle0", timeout: 120000 });
  await page.waitForFunction(
    () => document.title.startsWith("READY") || document.title.startsWith("ERROR"),
    { timeout: 120000 },
  );
  const title = await page.title();
  if (title.startsWith("ERROR")) throw new Error(title);

  fs.mkdirSync(path.dirname(path.resolve(outBase)), { recursive: true });

  const svg = await page.$eval("svg", (el) => el.outerHTML);
  fs.writeFileSync(`${outBase}.svg`, svg);

  const sceneJson = await page.$eval("#scene-json", (el) => el.textContent);
  fs.writeFileSync(
    `${outBase}.excalidraw`,
    JSON.stringify(JSON.parse(sceneJson), null, 4) + "\n",
  );

  const [, w, h] = title.split(" ").map(Number);
  await page.setViewport({
    width: Math.min(w, 3000),
    height: Math.min(h, 3000),
    deviceScaleFactor: 2,
  });
  const svgHandle = await page.$("svg");
  await svgHandle.screenshot({ path: `${outBase}.png` });

  console.log(`Rendered ${w}x${h}:`);
  for (const ext of ["svg", "excalidraw", "png"]) {
    console.log(`  ${outBase}.${ext} (${fs.statSync(`${outBase}.${ext}`).size} bytes)`);
  }
} finally {
  await browser.close();
  fs.rmSync(workDir, { recursive: true, force: true });
}
