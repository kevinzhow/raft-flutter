// Supplemental test host only: extend the pinned VisualTestingRoot's public
// ThemeProvider/AppThemeContext inputs without editing the Source checkout.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const source = process.env.PARITY_RAFT_SOURCE;
const out = process.env.PARITY_THEME_HOST_OUT;
if (!source || !out) throw new Error('PARITY_RAFT_SOURCE and PARITY_THEME_HOST_OUT required');
const web = resolve(source, 'packages/web');
const target = resolve(web, 'visual-testing/VisualTestingRoot.tsx');
const original = readFileSync(target, 'utf8');
function once(code, before, after) {
  if (code.split(before).length !== 2) throw new Error(`Source host anchor changed: ${before}`);
  return code.replace(before, after);
}
let code = once(original,
  '  const preset: AppThemePreset = defaultTheme === "elegant" ? "elegant-light" : "brutal";',
  `  const override = new URLSearchParams(window.location.search).get('parityTheme');
  if (override && !['brutal-light', 'elegant-light', 'elegant-dark'].includes(override)) {
    throw new Error('Unknown supplemental parity theme');
  }
  const selectedTheme = override ? (override === 'brutal-light' ? 'brutal' : 'elegant') : defaultTheme;
  const dark = override === 'elegant-dark';
  const preset: AppThemePreset = dark ? 'elegant-dark' : selectedTheme === 'elegant' ? 'elegant-light' : 'brutal';`);
code = once(code, '    resolvedMode: "light" as const,', '    resolvedMode: dark ? "dark" as const : "light" as const,');
code = once(code,
  '<ThemeProvider defaultTheme={defaultTheme} defaultMode="light">',
  '<ThemeProvider defaultTheme={selectedTheme} defaultMode={dark ? "dark" : "light"}>');
mkdirSync(out, { recursive: true });
// Apply the same owner-authorized fixture repair as the original 99 runner.
// Theme overrides still affect only the fixture root; no product code edits.
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
execFileSync('python3', [resolve(root, 'tool/parity_baseline_repairs.py'),
  '--root', root, '--source', source, '--out', out]);
const casesTarget = resolve(web, 'visual-testing/VisualTestingCases.tsx');
const casesCode = readFileSync(resolve(out, 'VisualTestingCases.generated.tsx'), 'utf8');
const sha = text => createHash('sha256').update(text).digest('hex');
writeFileSync(resolve(out, 'host-receipt.json'), JSON.stringify({
  originalHostSha256: sha(original), generatedHostSha256: sha(code),
  scope: 'fixture root ThemeProvider and fixed AppThemeContext inputs only',
  sourceEdited: false, generatedAt: new Date().toISOString(),
}, null, 2));
writeFileSync(resolve(out, 'VisualTestingRoot.generated.tsx'), code);
const require = createRequire(resolve(web, 'package.json'));
const { createServer } = await import(pathToFileURL(require.resolve('vite')));
const port = Number(process.env.PARITY_THEME_HOST_PORT ?? 15264);
const host = await createServer({
  root: web, configFile: resolve(web, 'vite.config.ts'),
  plugins: [{
    name: 'raft-supplemental-theme-fixture-host', enforce: 'pre',
    load(id) {
      if (id.split('?')[0] === target) return { code, map: null };
      if (id.split('?')[0] === casesTarget) return { code: casesCode, map: null };
    },
  }],
  server: { host: '127.0.0.1', port, strictPort: true, hmr: false },
  logLevel: 'warn',
});
await host.listen();
console.log(`Supplemental theme fixture host: http://127.0.0.1:${port}`);
