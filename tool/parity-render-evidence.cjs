// Evidence for the React provider's Chromium text-rendering flags.
// Renders neutral ink (#141111) on white in the production raft-ui fonts
// (tool/parity-fonts cache) with the pinned Playwright Chromium at 3x, once
// with the desktop Linux default and once with the Android-emulating flags,
// and reports per run: LCD-AA pixels, text run widths and loaded font faces.
// Invoked by `tool/parity render-evidence` (cwd = raft-source/packages/web).
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require(path.join(process.cwd(), "node_modules/@playwright/test"));
const sharp = require(path.join(process.env.PARITY_VT_ROOT, "node_modules/sharp"));

const cache = process.env.PARITY_FONT_CACHE;
const manifest = JSON.parse(fs.readFileSync(path.join(cache, "manifest.json"), "utf8"));
const css = fs.readFileSync(path.join(cache, manifest.css.file), "utf8");
const modes = JSON.parse(process.env.PARITY_EVIDENCE_MODES);
const samples = [
  ["Hanken Grotesk", 400, 14], ["Hanken Grotesk", 700, 16], ["Geist", 400, 14],
  ["Inter", 600, 18], ["Geist Mono", 400, 13],
];
const html = `<!doctype html><link rel="stylesheet" href="https://fonts.googleapis.com/raft-ui.css">
<body style="margin:0;background:#fff;color:#141111;padding:12px">
${samples.map(([f, w, s], i) => `<div style="white-space:nowrap"><span id="s${i}" style="font:${w} ${s}px '${f}'">Shared Installed Update Built In task #273 ${f}</span></div>`).join("")}
</body>`;

(async () => {
  const out = {};
  for (const [name, args] of Object.entries(modes)) {
    const browser = await chromium.launch({ args });
    const page = await browser.newPage({ viewport: { width: 390, height: 220 }, deviceScaleFactor: 3 });
    await page.route("**/*", (route) => {
      const url = route.request().url();
      if (url === "https://fonts.googleapis.com/raft-ui.css") return route.fulfill({ contentType: "text/css", body: css });
      const entry = manifest.files[url];
      if (entry) return route.fulfill({ contentType: "font/woff2", path: path.join(cache, entry.file) });
      if (url.startsWith("http://evidence/")) return route.fulfill({ contentType: "text/html", body: html });
      return route.fulfill({ status: 404, body: "" });
    });
    await page.goto("http://evidence/");
    await page.evaluate(() => document.fonts.ready);
    const fonts = await page.evaluate(() =>
      [...new Set([...document.fonts].filter((f) => f.status === "loaded").map((f) => f.family))]);
    const widths = await page.evaluate((n) => Array.from({ length: n }, (_, i) =>
      document.getElementById(`s${i}`).getBoundingClientRect().width), samples.length);
    const png = await page.screenshot();
    const { data, info } = await sharp(png).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    // Grayscale AA of ink on paper gives p = paper + t*(ink - paper) with one t
    // for all channels; LCD AA gives per-channel coverage. Count pixels whose
    // per-channel coverage spread exceeds 0.08 (~19 levels).
    const ink = [20, 17, 17];
    let lcd = 0, chromatic = 0;
    for (let i = 0; i < data.length; i += 3) {
      const t = [0, 1, 2].map((c) => (255 - data[i + c]) / (255 - ink[c]));
      if (Math.max(...t) - Math.min(...t) > 0.08) lcd += 1;
      if (Math.max(data[i], data[i + 1], data[i + 2]) - Math.min(data[i], data[i + 1], data[i + 2]) > 3) chromatic += 1;
    }
    out[name] = { args, lcdPixels: lcd, chromaticPixels: chromatic, pixels: info.width * info.height, textRunWidths: widths, loadedFamilies: fonts };
    if (process.env.PARITY_EVIDENCE_DIR) fs.writeFileSync(path.join(process.env.PARITY_EVIDENCE_DIR, `${name}.png`), png);
    await browser.close();
  }
  console.log(JSON.stringify(out, null, 2));
})();
