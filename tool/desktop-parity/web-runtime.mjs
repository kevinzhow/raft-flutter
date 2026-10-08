// Serves the REAL Raft Web app (packages/web index.html -> main.tsx -> App)
// from the pinned raft-source checkout, with every /api request answered by
// the shared desktop fixture (tool/desktop-parity/desktop-fixture.json).
// The same fixture file feeds the Flutter fake RaftClient, so both sides
// render identical data.
//
// Usage: node web-runtime.mjs [port]   (default 15260)
// Env:   RAFT_SOURCE=<raft-source checkout>  (default: Cody's pinned checkout)
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { readFileSync, appendFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sourceRoot = process.env.RAFT_SOURCE ??
  '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
const web = `${sourceRoot}/packages/web`;
const port = Number(process.argv[2] ?? 15260);
const fixturePath = process.env.RAFT_DESKTOP_FIXTURE ?? resolve(here, 'desktop-fixture.json');
const logDir = process.env.RAFT_RUNTIME_LOG_DIR ?? resolve(here, '../../.local/desktop-parity');
const missLog = resolve(logDir, 'web-fixture-misses.jsonl');
const servedLog = resolve(logDir, 'web-fixture-served.jsonl');

const require = createRequire(`${web}/package.json`);
const { createServer } = await import(pathToFileURL(require.resolve('vite')));

// Same lookup rule as the Flutter fixture client (desktop_fixture_client.dart):
// a "METHOD path?k=v" key matches when every listed param equals the
// request's; the most specific match wins, else the bare "METHOD path" key.
export function lookup(routes, method, path, searchParams) {
  const prefix = `${method} ${path}?`;
  let best, bestCount = -1;
  for (const [key, value] of Object.entries(routes)) {
    if (!key.startsWith(prefix)) continue;
    const params = [...new URLSearchParams(key.slice(prefix.length)).entries()];
    if (params.every(([k, v]) => searchParams.get(k) === v) && params.length > bestCount) {
      best = value; bestCount = params.length;
    }
  }
  return best !== undefined ? best : routes[`${method} ${path}`];
}

const fixtureApi = {
  name: 'raft-desktop-parity-fixture-api',
  configureServer(server) {
    server.middlewares.use((req, res, next) => {
      if (!req.url?.startsWith('/api/')) return next();
      const url = new URL(req.url, 'http://fixture.local');
      const path = url.pathname.slice(4);
      const method = req.method ?? 'GET';
      const fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
      // A test can pin a deliberately slow endpoint (loading-state cases).
      const delayMs = Number(fixture.delays?.[`${method} ${path}`] ?? 0);
      let answer = lookup(fixture.routes, method, path, url.searchParams);
      let status = 200;
      if (answer && typeof answer === 'object' && !Array.isArray(answer) && '__status' in answer) {
        status = answer.__status;
        answer = answer.body;
      }
      if (answer === undefined) {
        appendFileSync(missLog, JSON.stringify({ at: new Date().toISOString(), method, path: path + url.search }) + '\n');
        status = method === 'GET' ? 404 : 200;
        answer = method === 'GET' ? { error: 'FIXTURE_MISSING', method, path } : {};
      } else {
        appendFileSync(servedLog, JSON.stringify({ method, path: path + url.search, status }) + '\n');
      }
      setTimeout(() => {
        res.statusCode = status;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(answer));
      }, delayMs);
    });
  },
};

const server = await createServer({
  root: web,
  configFile: `${web}/vite.config.ts`,
  plugins: [fixtureApi],
  server: { host: '127.0.0.1', port, strictPort: true, proxy: {}, hmr: false },
  logLevel: 'warn',
});
await server.listen();
writeFileSync(resolve(logDir, 'web-runtime.port'), String(port));
console.log(`desktop parity web runtime: http://127.0.0.1:${port}/  fixture=${fixturePath}`);
