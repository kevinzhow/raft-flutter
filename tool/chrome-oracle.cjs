// Chrome colour oracle for tool/gen-tokens (`tool/gen-tokens --sample-chrome`).
//
// Paints one swatch per token in the pinned Playwright Chromium (the parity
// harness's React provider browser, launched with the same Android text flags)
// and reads the painted bytes back from a PNG screenshot — not canvas
// getImageData, which stores premultiplied 8-bit and loses translucent
// channels. Each swatch is painted over every backdrop (white, black, the
// theme canvas, ...).
//
// Input: JSON spec on stdin
//   { args: [...chromium args], backdrops: {name: cssValue},
//     themes: [{ id, html: {theme, class}, css, swatches: [{key, value}] }] }
// Output: JSON on stdout
//   { chromium, args, themes: { id: { key: { <backdrop>: [r,g,b], ... } } } }
// Invoked with cwd = raft-source/packages/web (for @playwright/test) and
// PARITY_VT_ROOT pointing at packages/visual-testing (for sharp).
const path = require("node:path");
const { chromium } = require(path.join(process.cwd(), "node_modules/@playwright/test"));
const sharp = require(path.join(process.env.PARITY_VT_ROOT, "node_modules/sharp"));

const CELL = 6; // px per swatch (DPR 1); the centre pixel is sampled
const COLS = 60;
let BACKDROPS = [];
let BACKDROP_CSS = {};

function page(theme) {
  const rows = theme.swatches.map((s, i) => BACKDROPS.map((b, j) => {
    const idx = i * BACKDROPS.length + j;
    const x = (idx % COLS) * CELL, y = Math.floor(idx / COLS) * CELL;
    const bg = BACKDROP_CSS[b];
    return `<div style="position:absolute;left:${x}px;top:${y}px;width:${CELL}px;height:${CELL}px;background:${bg}">` +
      `<div style="width:100%;height:100%;background-color:${s.value}"></div></div>`;
  }).join("")).join("\n");
  const attrs = `data-theme="${theme.html.theme}"${theme.html.class ? ` class="${theme.html.class}"` : ""}`;
  return `<!doctype html><html ${attrs}><head><style>${theme.css}
html,body{margin:0;padding:0;background:#fff}</style></head><body>${rows}</body></html>`;
}

(async () => {
  const spec = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
  BACKDROP_CSS = spec.backdrops;
  BACKDROPS = Object.keys(spec.backdrops);
  const browser = await chromium.launch({ args: spec.args });
  const out = { chromium: browser.version(), args: spec.args, themes: {} };
  for (const theme of spec.themes) {
    const n = theme.swatches.length * BACKDROPS.length;
    const height = Math.ceil(n / COLS) * CELL;
    const ctx = await browser.newContext({ viewport: { width: COLS * CELL, height }, deviceScaleFactor: 1 });
    const p = await ctx.newPage();
    await p.setContent(page(theme));
    const png = await p.screenshot({ fullPage: true });
    const { data, info } = await sharp(png).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    const res = {};
    theme.swatches.forEach((s, i) => {
      res[s.key] = {};
      BACKDROPS.forEach((b, j) => {
        const idx = i * BACKDROPS.length + j;
        const x = (idx % COLS) * CELL + CELL / 2, y = Math.floor(idx / COLS) * CELL + CELL / 2;
        const o = (y * info.width + x) * 3;
        res[s.key][b] = [data[o], data[o + 1], data[o + 2]];
      });
    });
    out.themes[theme.id] = res;
    await ctx.close();
  }
  await browser.close();
  process.stdout.write(JSON.stringify(out));
})().catch((e) => { console.error(e); process.exit(1); });
