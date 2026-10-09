// Serve a generated fixture-only repair with the pinned Web/Vite product.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const web = resolve(process.env.SLOCK_REACT_REPO_DIR, 'packages/web');
const target = resolve(web, 'visual-testing/VisualTestingCases.tsx');
const generated = resolve(process.env.PARITY_BASELINE_HOST_OUT, 'VisualTestingCases.generated.tsx');
const code = readFileSync(generated, 'utf8');
const require = createRequire(resolve(web, 'package.json'));
const { createServer } = await import(pathToFileURL(require.resolve('vite')));
const port = Number(process.env.PLAYWRIGHT_WEB_PORT);
const host = await createServer({
  root: web, configFile: resolve(web, 'vite.config.ts'),
  plugins: [{
    name: 'raft-owner-authorized-baseline-fixture-repair', enforce: 'pre',
    load(id) { if (id.split('?')[0] === target) return { code, map: null }; },
  }],
  server: { host: '127.0.0.1', port, strictPort: true, hmr: false },
  logLevel: 'warn',
});
await host.listen();
console.log(`Repaired public visual fixture host: http://127.0.0.1:${port}`);
