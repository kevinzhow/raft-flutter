// Render host for the raft-flutter parity EXTENSION suite (tool/parity-ext).
//
// Serves the pinned official Vite render host (packages/web/visual-testing)
// with three generated, anchor-checked additions; the Source checkout itself
// is never edited:
//   1. VisualTestingRoot.tsx: the `parityTheme` URL param selects
//      brutal-light / elegant-light / elegant-dark (same override as
//      tool/theme-parity-web.mjs, the supplemental three-theme runner).
//   2. VisualTestingCases.tsx: tool/parity-ext/host/*.tsx is appended and the
//      default export asks the extension registry first; official ids fall
//      through unchanged.
//   3. virtual:parity-ext/<name>: tool/parity-ext/fixtures/<name>.json.
//
// Env: PARITY_RAFT_SOURCE, PARITY_EXT_HOST_OUT (receipt + generated files),
//      PLAYWRIGHT_WEB_PORT (Playwright webServer contract).
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const source = process.env.PARITY_RAFT_SOURCE;
const out = process.env.PARITY_EXT_HOST_OUT;
if (!source || !out) throw new Error('PARITY_RAFT_SOURCE and PARITY_EXT_HOST_OUT required');
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const ext = resolve(root, 'tool/parity-ext');
const web = resolve(source, 'packages/web');
const rootTarget = resolve(web, 'visual-testing/VisualTestingRoot.tsx');
const casesTarget = resolve(web, 'visual-testing/VisualTestingCases.tsx');

function once(code, before, after) {
  if (code.split(before).length !== 2) throw new Error(`Source host anchor changed: ${before}`);
  return code.replace(before, after);
}
const sha = (text) => createHash('sha256').update(text).digest('hex');

const rootOriginal = readFileSync(rootTarget, 'utf8');
let rootCode = once(rootOriginal,
  '  const preset: AppThemePreset = defaultTheme === "elegant" ? "elegant-light" : "brutal";',
  `  const override = new URLSearchParams(window.location.search).get('parityTheme');
  if (override && !['brutal-light', 'elegant-light', 'elegant-dark'].includes(override)) {
    throw new Error('Unknown extension parity theme');
  }
  const selectedTheme = override ? (override === 'brutal-light' ? 'brutal' : 'elegant') : defaultTheme;
  const dark = override === 'elegant-dark';
  const preset: AppThemePreset = dark ? 'elegant-dark' : selectedTheme === 'elegant' ? 'elegant-light' : 'brutal';`);
rootCode = once(rootCode, '    resolvedMode: "light" as const,', '    resolvedMode: dark ? "dark" as const : "light" as const,');
rootCode = once(rootCode,
  '<ThemeProvider defaultTheme={defaultTheme} defaultMode="light">',
  '<ThemeProvider defaultTheme={selectedTheme} defaultMode={dark ? "dark" : "light"}>');

const casesOriginal = readFileSync(casesTarget, 'utf8');
const hostFiles = readdirSync(resolve(ext, 'host')).filter((f) => f.endsWith('.tsx')).sort();
let casesCode = once(casesOriginal,
  'export default function VisualTestingCases() {\n  const caseId = requestedCaseId();',
  'export default function VisualTestingCases() {\n  const parityExtElement = parityExtElements();\n'
  + '  if (parityExtElement) return parityExtElement;\n  const caseId = requestedCaseId();');
// Every host file exposes one `function parityExt<Name>Element()` returning its
// element for its own case ids (or null); the registry asks each in turn.
const hostElements = [];
for (const file of hostFiles) {
  const code = readFileSync(resolve(ext, 'host', file), 'utf8');
  hostElements.push(...[...code.matchAll(/^function (parityExt\w*[eE]lement)\(\)/gm)].map((m) => m[1]));
  casesCode += `\n// ---- raft-flutter parity extension: tool/parity-ext/host/${file}\n${code}`;
}
casesCode += `\nfunction parityExtElements() {\n  for (const element of [${hostElements.map((n) => `${n}()`).join(', ')}]) {\n`
  + '    if (element) return element;\n  }\n  return null;\n}\n';
const fixtures = Object.fromEntries(readdirSync(resolve(ext, 'fixtures'))
  .filter((f) => f.endsWith('.json'))
    .map((f) => [`virtual:parity-ext/${f.slice(0, -5)}`, readFileSync(resolve(ext, 'fixtures', f), 'utf8')]));

mkdirSync(out, { recursive: true });
writeFileSync(resolve(out, 'VisualTestingRoot.generated.tsx'), rootCode);
writeFileSync(resolve(out, 'VisualTestingCases.generated.tsx'), casesCode);
writeFileSync(resolve(out, 'host-receipt.json'), JSON.stringify({
  originalRootSha256: sha(rootOriginal), generatedRootSha256: sha(rootCode),
  originalCasesSha256: sha(casesOriginal), generatedCasesSha256: sha(casesCode),
  extensionHostFiles: hostFiles, fixtures: Object.fromEntries(Object.entries(fixtures).map(([k, v]) => [k, sha(v)])),
  scope: 'theme override at the fixture root + appended extension cases; official ids unchanged',
  sourceEdited: false, generatedAt: new Date().toISOString(),
}, null, 2));

const require = createRequire(resolve(web, 'package.json'));
const { createServer } = await import(pathToFileURL(require.resolve('vite')));
const port = Number(process.env.PLAYWRIGHT_WEB_PORT ?? process.env.PARITY_EXT_HOST_PORT ?? 15266);
const host = await createServer({
  root: web, configFile: resolve(web, 'vite.config.ts'),
  plugins: [{
    name: 'raft-flutter-parity-extension-host', enforce: 'pre',
    // Resolved ids must not end in .json (Vite's JSON plugin would re-parse).
    resolveId(id) { if (fixtures[id]) return `\0parity-ext-fixture:${id}`; },
    load(id) {
      if (id.startsWith('\0parity-ext-fixture:')) {
        return { code: `export default ${fixtures[id.slice('\0parity-ext-fixture:'.length)]};`, map: null };
      }
      const file = id.split('?')[0];
      if (file === rootTarget) return { code: rootCode, map: null };
      if (file === casesTarget) return { code: casesCode, map: null };
    },
  }],
  server: { host: '127.0.0.1', port, strictPort: true, hmr: false },
  logLevel: 'warn',
});
await host.listen();
console.log(`Extension parity render host: http://127.0.0.1:${port}`);
