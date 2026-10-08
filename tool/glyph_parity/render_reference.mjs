// Reference raster for tool/glyph-parity: lucide-react's own SSR markup, painted by Chromium.
//
//   node render_reference.mjs <raft-source> <samples.json> <out-dir>
//
// Every sample is rendered with react-dom/server from the pinned lucide-react
// build named in the sample (0.575.0 = Web product imports, 1.48.0 = raft-ui),
// laid out on a white grid (one row per sample, one column per size, black
// currentColor) and screenshotted at deviceScaleFactor 1 by the Playwright
// Chromium the raft-source checkout pins. Writes chromium.png + manifest.json.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [raftSource, samplesPath, outDir] = process.argv.slice(2);
if (!outDir) {
  console.error('usage: render_reference.mjs <raft-source> <samples.json> <out-dir>');
  process.exit(2);
}
const pnpm = path.join(raftSource, 'node_modules/.pnpm');
const one = (pattern) => {
  const hits = fs.readdirSync(pnpm).filter((d) => pattern.test(d)).sort();
  if (!hits.length) throw new Error(`no ${pattern} in ${pnpm}`);
  return path.join(pnpm, hits[0], 'node_modules');
};
const packages = {
  '0.575.0': path.join(one(/^lucide-react@0\.575\.0_/), 'lucide-react'),
  '1.48.0': path.join(one(/^lucide-react@1\.48\.0_/), 'lucide-react'),
};
const webRequire = createRequire(path.join(raftSource, 'packages/web/package.json'));
const React = webRequire('react');
const { renderToStaticMarkup } = webRequire('react-dom/server');
const { chromium } = createRequire(path.join(one(/^playwright-core@1\.59\./), 'playwright-core/package.json'))(
  'playwright-core',
);

const lucide = {};
for (const [version, dir] of Object.entries(packages)) {
  const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
  if (pkg.version !== version) throw new Error(`${dir} is ${pkg.version}, want ${version}`);
  // Same React instance as react-dom/server (pnpm dedupes react@19.2.4 by realpath).
  lucide[version] = await import(pathToFileURL(path.join(dir, pkg.module)).href);
}

const spec = JSON.parse(fs.readFileSync(samplesPath, 'utf8'));
const { sizes, pitch, inset, samples } = spec;
const width = pitch * sizes.length;
const height = pitch * samples.length;
const cells = [];
const manifest = { samples: [] };
for (const [row, sample] of samples.entries()) {
  const Icon = lucide[sample.lucide][sample.export];
  if (!Icon) throw new Error(`lucide-react ${sample.lucide} has no export ${sample.export}`);
  const markup = sizes.map((size) =>
    renderToStaticMarkup(React.createElement(Icon, { size, ...(sample.props ?? {}) })),
  );
  sizes.forEach((size, col) => {
    cells.push(
      `<div style="position:absolute;left:${col * pitch + inset}px;top:${row * pitch + inset}px;` +
        `width:${size}px;height:${size}px;line-height:0">${markup[col]}</div>`,
    );
  });
  const entry = { id: sample.id, markup: markup[sizes.indexOf(24)] ?? markup[0] };
  if (sample.probe) {
    // Raw iconNode for element types the generated enum does not contain.
    const ext = sample.lucide === '0.575.0' ? '.js' : '.mjs';
    const mod = await import(pathToFileURL(path.join(packages[sample.lucide], 'dist/esm/icons', sample.probe + ext)).href);
    const nodes = mod.__iconNode ?? mod.__iconData.node;
    entry.nodes = nodes.map(([tag, attrs]) => {
      const { key, ...rest } = attrs;
      return [tag, Object.fromEntries(Object.entries(rest).map(([k, v]) => [k, String(v)]))];
    });
  }
  manifest.samples.push(entry);
}
const html =
  `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#fff;color:#000}` +
  `svg{display:block}</style></head><body><div style="position:relative;width:${width}px;height:${height}px">` +
  cells.join('') +
  `</div></body></html>`;

const browser = await chromium.launch();
try {
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  await page.setContent(html);
  fs.mkdirSync(outDir, { recursive: true });
  await page.screenshot({ path: path.join(outDir, 'chromium.png'), clip: { x: 0, y: 0, width, height } });
  manifest.chromium = browser.version();
  manifest.raster = { width, height, deviceScaleFactor: 1, background: '#ffffff', color: '#000000' };
} finally {
  await browser.close();
}
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
console.log(`reference: ${samples.length} samples x ${sizes.length} sizes, Chromium ${manifest.chromium}`);
