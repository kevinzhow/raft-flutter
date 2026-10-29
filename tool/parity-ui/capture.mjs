#!/usr/bin/env node
// React reference provider for the raft-ui specimens (tool/parity-ui/run).
//
// Builds the host (tool/parity-ui/host: @botiverse/raft-ui 0.7.1 + React 19 +
// Tailwind v4, versions fixed by pnpm-lock.yaml), serves the build on
// 127.0.0.1, and captures every manifest case with the pinned Playwright
// Chromium (playwright-core 1.59.1 -> chromium_headless_shell 147.0.7727.15)
// into the official provider output contract:
//   <out>/visual-testing-results/react/<case-id>.png + .metadata.json
//
// Determinism: fonts come only from the sha256-pinned cache in
// tool/parity-ui/fonts (Google is never contacted; any other external request
// fails the run), animations disabled, reduced motion, grayscale AA with
// unhinted advances (docs/parity.md "Text rendering"), fixed viewport/density,
// fresh browser context per case, UTC / en-US.
//
//   node capture.mjs --manifest <cases.json> --out <dir> [--only id,id] [--density N] [--dom-dump <dir>]
//
// --dom-dump writes <dir>/<case-id>.json instead of PNGs: every element under the capture
// selector with its rect (CSS px, relative to the target), classes, text and computed styles
// (plus ::before / ::after when they generate content). Diagnostic for the Flutter port.
import { createRequire } from "node:module";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, statSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const hostDir = join(here, "host");
const fontsDir = join(here, "fonts");
const require = createRequire(join(hostDir, "package.json"));

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => {
  if (a.startsWith("--")) acc.push([a.slice(2), all[i + 1]]);
  return acc;
}, []));
if (!args.manifest || !args.out) throw new Error("usage: capture.mjs --manifest <cases.json> --out <dir> [--only ids]");
const out = resolve(args.out);
const resultDir = join(out, "visual-testing-results", "react");
const manifest = JSON.parse(readFileSync(args.manifest, "utf8"));
const only = args.only ? new Set(args.only.split(",")) : null;
const cases = manifest.cases.filter((c) => !only || only.has(c.id));
if (cases.length === 0) throw new Error("no cases selected");

const EXPECTED_CHROMIUM = "147.0.7727.15";
// Android Chrome text: grayscale AA, subpixel glyph positions (docs/parity.md).
const CHROMIUM_ARGS = ["--disable-lcd-text", "--font-render-hinting=none"];
const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");

// --- pinned fonts -----------------------------------------------------------
const fontManifest = JSON.parse(readFileSync(join(fontsDir, "manifest.json"), "utf8"));
function pinned(entry) {
  const buf = readFileSync(join(fontsDir, entry.file));
  if (sha256(buf) !== entry.sha256) throw new Error(`font cache digest mismatch: ${entry.file}`);
  return buf;
}
const fontCss = pinned(fontManifest.css);
const fontFiles = new Map(Object.entries(fontManifest.files).map(([url, e]) => [url, pinned(e)]));

// --- build + serve ----------------------------------------------------------
const { build } = await import(pathToFileURL(require.resolve("vite")));
const dist = join(out, "host-dist");
rmSync(dist, { recursive: true, force: true });
await build({ root: hostDir, configFile: join(hostDir, "vite.config.mjs"), build: { outDir: dist, emptyOutDir: true } });

const MIME = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml", ".woff2": "font/woff2" };
const server = createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  let file = join(dist, path === "/" ? "index.html" : path);
  if (!file.startsWith(dist) || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, { "content-type": MIME[extname(file)] ?? "application/octet-stream", "cache-control": "no-store" });
  res.end(readFileSync(file));
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const origin = `http://127.0.0.1:${server.address().port}`;

// --- capture ----------------------------------------------------------------
const { chromium } = require("playwright-core");
const browser = await chromium.launch({ headless: true, args: CHROMIUM_ARGS });
const chromiumVersion = browser.version();
if (chromiumVersion !== EXPECTED_CHROMIUM) {
  throw new Error(`pinned Chromium is ${EXPECTED_CHROMIUM}, playwright-core launched ${chromiumVersion}`);
}

mkdirSync(resultDir, { recursive: true });
const failures = [];
const captured = [];

async function platformFonts(page, selector) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("DOM.enable");
  await cdp.send("CSS.enable");
  const { root } = await cdp.send("DOM.getDocument", { depth: -1 });
  const { nodeIds } = await cdp.send("DOM.querySelectorAll", { nodeId: root.nodeId, selector: `${selector}, ${selector} *` });
  const usage = {};
  for (const nodeId of nodeIds) {
    try {
      const { fonts } = await cdp.send("CSS.getPlatformFontsForNode", { nodeId });
      for (const f of fonts) {
        const key = `${f.familyName}${f.isCustomFont ? "" : " (system)"}`;
        usage[key] = (usage[key] ?? 0) + f.glyphCount;
      }
    } catch { /* nodes without layout have no platform fonts */ }
  }
  await cdp.detach();
  return Object.fromEntries(Object.entries(usage).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])));
}

// Runs in the page: depth-first dump of the target subtree.
function domDump(root) {
  const base = root.getBoundingClientRect();
  const KEYS = ["display", "position", "flexDirection", "alignItems", "justifyContent", "gap", "rowGap", "columnGap",
    "width", "height", "minWidth", "minHeight", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
    "marginTop", "marginRight", "marginBottom", "marginLeft",
    "color", "backgroundColor", "backgroundImage", "opacity",
    "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth",
    "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor", "borderTopStyle",
    "borderTopLeftRadius", "borderTopRightRadius", "borderBottomRightRadius", "borderBottomLeftRadius",
    "boxShadow", "outline", "outlineOffset", "overflow",
    "fontFamily", "fontSize", "fontWeight", "lineHeight", "letterSpacing", "textTransform", "textAlign", "whiteSpace",
    "textDecorationLine", "transform", "filter", "zIndex", "cursor"];
  const pick = (cs) => {
    const o = {};
    for (const k of KEYS) o[k] = cs[k];
    return o;
  };
  const rectOf = (el) => {
    const r = el.getBoundingClientRect();
    return { x: +(r.x - base.x).toFixed(3), y: +(r.y - base.y).toFixed(3), w: +r.width.toFixed(3), h: +r.height.toFixed(3) };
  };
  const walk = (el) => {
    const cs = getComputedStyle(el);
    const node = { tag: el.tagName.toLowerCase(), cls: el.getAttribute("class") ?? "", rect: rectOf(el), style: pick(cs) };
    for (const a of el.attributes) if (a.name.startsWith("data-") || a.name === "role" || a.name === "aria-checked" || a.name === "aria-selected" || a.name === "aria-current") (node.attrs ??= {})[a.name] = a.value;
    for (const pseudo of ["::before", "::after"]) {
      const ps = getComputedStyle(el, pseudo);
      if (ps.content !== "none" && ps.content !== "normal") (node.pseudo ??= {})[pseudo] = { content: ps.content, ...pick(ps) };
    }
    const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).filter(Boolean).join(" ");
    if (own) node.text = own;
    if (el.tagName.toLowerCase() === "svg") node.svg = el.outerHTML.slice(0, 600);
    node.children = [...el.children].map(walk);
    return node;
  };
  return walk(root);
}

for (const c of cases) {
  const props = c.variants[0].props;
  const { width, height, density } = c.viewport;
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: args.density ? Number(args.density) : density,
    locale: "en-US",
    timezoneId: "UTC",
    colorScheme: props.mode,
    reducedMotion: "reduce",
  });
  const page = await context.newPage();
  const problems = [];
  const servedFonts = new Set();
  page.on("pageerror", (e) => problems.push(`pageerror: ${e}`));
  page.on("console", (m) => { if (m.type() === "error" || m.type() === "warning") problems.push(`console.${m.type()}: ${m.text()}`); });
  await page.route("**/*", (route) => {
    const url = route.request().url();
    if (url.startsWith(origin)) return route.continue();
    if (url === fontManifest.cssUrl) { servedFonts.add(url); return route.fulfill({ status: 200, contentType: "text/css; charset=utf-8", body: fontCss }); }
    const file = fontFiles.get(url);
    if (file) { servedFonts.add(url); return route.fulfill({ status: 200, contentType: "font/woff2", body: file }); }
    if (url.startsWith("data:")) return route.continue();
    problems.push(`unexpected external request: ${url}`);
    return route.abort();
  });
  try {
    await page.goto(`${origin}/?specimen=${encodeURIComponent(props.specimen)}&mode=${props.mode}`, { waitUntil: "load" });
    const selector = c.capture.selector;
    const target = page.locator(selector);
    await target.waitFor({ state: "visible" });
    // ThemeProvider has put the mode class on <html>; fonts and images settled.
    await page.waitForFunction((mode) => document.documentElement.classList.contains(mode), props.mode);
    await page.evaluate(async () => {
      for (const face of ['400 16px "Space Grotesk"', '600 16px "Space Grotesk"', '700 16px "Space Grotesk"', '400 16px "Space Mono"', '700 16px "Space Mono"']) {
        await document.fonts.load(face, "Raft 0123456789");
      }
      await document.fonts.ready;
      await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
    });
    const fontFaces = await page.evaluate(() => [...document.fonts].map((f) => ({ family: f.family.replaceAll('"', ""), weight: f.weight, style: f.style, status: f.status })));
    const loaded = (family) => fontFaces.some((f) => f.family === family && f.status === "loaded");
    for (const family of ["Space Grotesk", "Space Mono"]) if (!loaded(family)) problems.push(`font face not loaded: ${family}`);
    // Two frames so layout, image decode and font swap have settled.
    await page.evaluate(() => new Promise((ok) => requestAnimationFrame(() => requestAnimationFrame(ok))));
    const rect = await target.boundingBox();
    if (args["dom-dump"]) {
      mkdirSync(args["dom-dump"], { recursive: true });
      const dump = await target.evaluate(domDump);
      writeFileSync(join(args["dom-dump"], `${c.id}.json`), JSON.stringify(dump, null, 1) + "\n");
      console.log(`dumped ${c.id}`);
      continue;
    }
    const used = await platformFonts(page, selector);
    const system = Object.keys(used).filter((k) => k.endsWith("(system)"));
    if (system.length) problems.push(`glyphs drawn with system fonts: ${system.join(", ")}`);
    if (problems.length) throw new Error(problems.join("\n"));
    const png = join(resultDir, `${c.id}.png`);
    await target.screenshot({ path: png, animations: "disabled", caret: "hide", scale: "device" });
    const r = (n) => Math.round(n);
    writeFileSync(join(resultDir, `${c.id}.metadata.json`), JSON.stringify({
      provider: "react",
      providerType: "react-playwright",
      source: "raft-ui-specimens",
      caseId: c.id,
      image: `visual-testing-results/react/${c.id}.png`,
      viewport: c.viewport,
      selector,
      crop: { mode: c.capture.crop, contract: c.capture.contract, rect: { x: r(rect.x), y: r(rect.y), width: r(rect.width), height: r(rect.height) }, targetRect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, outset: null },
      specimen: props.specimen,
      mode: props.mode,
      render: {
        raftUi: manifest.raftUi,
        chromium: chromiumVersion,
        chromiumArgs: CHROMIUM_ARGS,
        deviceScaleFactor: args.density ? Number(args.density) : density,
        fontSource: "sha256-pinned Google Fonts response for raft-ui fonts.css (tool/parity-ui/fonts)",
        fontFaces,
        platformFonts: used,
      },
      capturedAt: new Date().toISOString(),
    }, null, 2) + "\n");
    captured.push({ id: c.id, sha256: sha256(readFileSync(png)), rect: { width: rect.width, height: rect.height } });
    console.log(`captured ${c.id} ${rect.width}x${rect.height}`);
  } catch (error) {
    failures.push(`${c.id}: ${error.message}`);
    console.error(`FAILED ${c.id}: ${error.message}`);
  } finally {
    await context.close();
  }
}

await browser.close();
server.close();
if (failures.length) {
  console.error(`${failures.length} case(s) failed`);
  process.exit(1);
}
writeFileSync(join(out, "capture-receipt.json"), JSON.stringify({
  raftUi: manifest.raftUi, chromium: chromiumVersion, chromiumArgs: CHROMIUM_ARGS, cases: captured,
}, null, 2) + "\n");
console.log(`${captured.length} captures in ${resultDir}`);
