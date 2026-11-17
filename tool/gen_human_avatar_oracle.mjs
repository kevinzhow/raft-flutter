// Real-Web oracle for the Flutter human pixel avatar (packages/raft_ui
// human_pixel_avatar.dart): draws each recipe with the shared TS renderer
// (renderHumanAvatarSvg) in Playwright Chromium, the way Web's HumanPixelAvatar
// shows it (an <img> of the SVG, image-rendering: pixelated, DPR 1), and writes
// one PNG per recipe and size. test/human_pixel_avatar_oracle_test.dart
// compares the Flutter render byte for byte against them.
//
// usage (node 24, from the raft-source checkout so zod/playwright resolve):
//   cd <raft-source> && node --import @oxc-node/core/register \
//     <repo>/tool/gen_human_avatar_oracle.mjs <repo>/apps/raft_flutter/test/fixtures/human_avatar
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const src = path.join(process.cwd(), "packages/shared/src");
const { renderHumanAvatarSvg, readHumanAvatarRecipe } = await import(path.join(src, "humanAvatar.ts"));
const { HUMAN_AVATAR_ART } = await import(path.join(src, "humanAvatarArt.ts"));
const require = createRequire(path.join(process.cwd(), "packages/web/package.json"));
const { chromium } = require("@playwright/test");

const out = process.argv[2];
mkdirSync(out, { recursive: true });
const RECIPES = {
  default: "pixel-human:v1:yellow.2.short.ink.wink.cap.none",
  sky_glasses: "pixel-human:v1:sky.3.curly.brown.grin.headphones.glasses",
  pink_long: "pixel-human:v1:pink.5.long.blonde.blush.none.glasses",
  mint_bun: "pixel-human:v1:mint.1.bun.ginger.oh.beanie.none",
  lilac_buzz: "pixel-human:v1:lilac.4.buzz.grey.smirk.none.none",
  cream_side: "pixel-human:v1:cream.2.side.ink.calm.cap.glasses/auto",
  yellow_happy: "pixel-human:v1:yellow.3.short.grey.happy.none.none",
};
const SIZES = [112, 99, 56, 40, 24, 17];

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: 300, height: 300 } });
const manifest = {};
for (const [name, value] of Object.entries(RECIPES)) {
  const svg = renderHumanAvatarSvg(readHumanAvatarRecipe(value), HUMAN_AVATAR_ART);
  manifest[name] = value;
  for (const size of SIZES) {
    await page.setContent(
      `<body style="margin:0;background:#fff"><img id="a" style="display:block;width:${size}px;height:${size}px;image-rendering:pixelated" src="data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}"></body>`,
    );
    await page.evaluate(() => document.getElementById("a").decode());
    const png = await page.locator("#a").screenshot({ omitBackground: false });
    writeFileSync(path.join(out, `${name}_${size}.png`), png);
  }
}
writeFileSync(path.join(out, "recipes.json"), JSON.stringify({ sizes: SIZES, recipes: manifest }, null, 2) + "\n");
await browser.close();
