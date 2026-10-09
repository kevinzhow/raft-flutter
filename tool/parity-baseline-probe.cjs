// Measures where Chromium (Android text flags, 3x) puts the text baseline and
// the glyph ink inside CSS line boxes, for comparing with Flutter's
// TextPainter. Usage (cwd = raft-source/packages/web, env as render-evidence):
//   PARITY_PROBE_SPECS='[["Hanken Grotesk",400,12,16],...]' node tool/parity-baseline-probe.cjs
// Prints [{spec, baseline, inkTop, inkBottom}] in CSS px relative to the
// line box top (each line box starts at a fractional y given by spec[4] || 0).
const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require(path.join(process.cwd(), "node_modules/@playwright/test"));
const sharp = require(path.join(process.env.PARITY_VT_ROOT, "node_modules/sharp"));
const cache = process.env.PARITY_FONT_CACHE;
const manifest = JSON.parse(fs.readFileSync(path.join(cache, "manifest.json"), "utf8"));
const css = fs.readFileSync(path.join(cache, manifest.css.file), "utf8");
const specs = JSON.parse(process.env.PARITY_PROBE_SPECS);
const rowH = 60;
const html = `<!doctype html><link rel="stylesheet" href="https://fonts.googleapis.com/raft-ui.css">
<body style="margin:0;background:#fff;color:#000">
${specs.map(([f, w, s, lh, off], i) => `<div style="position:absolute;left:10px;top:${i * rowH + 10 + (off || 0)}px;font:${w} ${s}px/${lh}px '${f}';white-space:nowrap"><span id="t${i}">HHHH</span><span id="p${i}" style="display:inline-block;width:0;height:0"></span></div>`).join("")}
</body>`;
(async () => {
  const browser = await chromium.launch({ args: ["--disable-lcd-text", "--font-render-hinting=none"] });
  const page = await browser.newPage({ viewport: { width: 300, height: specs.length * rowH + 20 }, deviceScaleFactor: 3 });
  await page.route("**/*", (route) => {
    const url = route.request().url();
    if (url === "https://fonts.googleapis.com/raft-ui.css") return route.fulfill({ contentType: "text/css", body: css });
    const entry = manifest.files[url];
    if (entry) return route.fulfill({ contentType: "font/woff2", path: path.join(cache, entry.file) });
    if (url.startsWith("http://probe/")) return route.fulfill({ contentType: "text/html", body: html });
    return route.fulfill({ status: 404, body: "" });
  });
  await page.goto("http://probe/");
  await page.evaluate(() => document.fonts.ready);
  const rects = await page.evaluate((n) => Array.from({ length: n }, (_, i) => {
    const d = document.getElementById(`t${i}`).parentElement.getBoundingClientRect();
    const p = document.getElementById(`p${i}`).getBoundingClientRect();
    return { top: d.top, height: d.height, baseline: p.bottom - d.top };
  }), specs.length);
  const png = await page.screenshot();
  const { data, info } = await sharp(png).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const out = specs.map((spec, i) => {
    const r = rects[i];
    let top = null, bottom = null, sum = 0, wsum = 0;
    for (let y = Math.floor(r.top * 3) - 6; y < Math.ceil((r.top + r.height) * 3) + 6; y++) {
      let ink = 0;
      for (let x = 30; x < 150; x++) ink += 255 - data[(y * info.width + x) * 3];
      if (ink > 0) { if (top === null) top = y; bottom = y; sum += ink * y; wsum += ink; }
    }
    return { spec, lineTop: r.top, lineHeight: r.height, baseline: r.baseline,
      inkTop: top / 3 - r.top, inkBottom: (bottom + 1) / 3 - r.top, inkCentroid: (sum / wsum + 0.5) / 3 - r.top };
  });
  console.log(JSON.stringify(out));
  await browser.close();
})();
