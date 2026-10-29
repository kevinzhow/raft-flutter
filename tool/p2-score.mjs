#!/usr/bin/env node
// Score freshly captured pages against the P2 (a57b9dab) baseline images.
//
// Uses the official visual-testing metric, not an approximation of it: read
// `pixelPerfectSimilarity` and `rgbSimilarity` straight out of
// packages/visual-testing/src/sharp-image-overlay.mjs so a number here means the
// same thing as a number in the parity report.
//
//   node tool/p2-score.mjs <baseline-root> <current-root> [out.json]
//
// Both roots contain `android/<case>.png` plus `<case>.metadata.json`.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sharp = require('/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source/packages/visual-testing/node_modules/sharp');

async function rgbaBuffer(file, width, height, mode) {
  let p = sharp(file);
  if (mode === 'resize') {
    return p.resize(width, height, { fit: 'fill' }).raw().toBuffer();
  }
  // pad: keep native pixels, pad the missing area white (official behaviour).
  const meta = await p.metadata();
  return p
    .extend({
      top: 0,
      left: 0,
      bottom: Math.max(0, height - Number(meta.height || 0)),
      right: Math.max(0, width - Number(meta.width || 0)),
      background: '#ffffff',
    })
    .raw()
    .toBuffer();
}

// The comparison box is the baseline's own capture rect, exactly as the official
// tool compares a candidate against its reference.
function boxOf(metaFile) {
  const meta = JSON.parse(fs.readFileSync(metaFile, 'utf8'));
  const rect = meta.crop?.rect ?? {};
  return {
    width: Math.round(rect.width ?? meta.width ?? 0),
    height: Math.round(rect.height ?? meta.height ?? 0),
  };
}

async function main() {
  const [baseRoot, curRoot, outFile] = process.argv.slice(2);
  if (!baseRoot || !curRoot) {
    console.error('usage: p2-score.mjs <baseline-root> <current-root> [out.json]');
    process.exit(2);
  }
  const files = fs.readdirSync(curRoot).filter((f) => f.endsWith('.png')).sort();
  const rows = [];
  for (const file of files) {
    const caseId = file.slice(0, -4);
    const basePng = path.join(baseRoot, file);
    if (!fs.existsSync(basePng)) continue;
    const { width, height } = boxOf(path.join(baseRoot, caseId + '.metadata.json'));
    if (!width || !height) continue;

    const rgbL = await rgbaBuffer(basePng, width, height, 'resize');
    const rgbR = await rgbaBuffer(path.join(curRoot, file), width, height, 'resize');
    const pxL = await rgbaBuffer(basePng, width, height, 'pad');
    const pxR = await rgbaBuffer(path.join(curRoot, file), width, height, 'pad');
    let diff = 0;
    let matching = 0;
    for (let i = 0; i < rgbL.length; i += 4) {
      diff += (Math.abs(rgbL[i] - rgbR[i]) + Math.abs(rgbL[i + 1] - rgbR[i + 1]) + Math.abs(rgbL[i + 2] - rgbR[i + 2])) / 3;
      if (pxL[i] === pxR[i] && pxL[i + 1] === pxR[i + 1] && pxL[i + 2] === pxR[i + 2] && pxL[i + 3] === pxR[i + 3]) matching += 1;
    }
    rows.push({
      case: caseId,
      theme: caseId.split('.').pop(),
      rgbSimilarity: Math.max(0, 1 - diff / (width * height * 255)),
      pixelPerfectSimilarity: matching / (width * height),
      width,
      height,
    });
  }
  rows.sort((a, b) => a.pixelPerfectSimilarity - b.pixelPerfectSimilarity);
  const out = { count: rows.length, rows };
  fs.writeFileSync(outFile ?? 'p2-scores.json', JSON.stringify(out, null, 1) + '\n');
  for (const r of rows.slice(0, 20)) {
    console.log(
      `${(r.pixelPerfectSimilarity * 100).toFixed(2)}%  pp  ${(r.rgbSimilarity * 100).toFixed(2)}%  rgb  ${r.case}`,
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
