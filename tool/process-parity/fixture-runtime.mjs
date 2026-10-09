// The real pinned Source index.html -> main.tsx -> App, with isolated API gates.
// No product/store monkeypatch. /__process endpoints control only this fixture.
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync, appendFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

export function lookup(routes, method, path, params) {
  let found, specificity = -1;
  for (const [key, answer] of Object.entries(routes)) {
    if (!key.startsWith(`${method} ${path}?`)) continue;
    const expected = [...new URLSearchParams(key.split('?').slice(1).join('?'))];
    if (expected.every(([k, v]) => params.get(k) === v) && expected.length > specificity) {
      found = answer; specificity = expected.length;
    }
  }
  return found === undefined ? routes[`${method} ${path}`] : found;
}

export async function startRuntime({ source, fixturePath, out, port }) {
  mkdirSync(out, { recursive: false });
  const fixtureBytes = readFileSync(fixturePath);
  const fixture = JSON.parse(fixtureBytes);
  const fixtureSha = createHash('sha256').update(fixtureBytes).digest('hex');
  const sourceHead = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim();
  if (sourceHead !== '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6') throw new Error(`Source revision changed: ${sourceHead}`);
  const tracked = execFileSync('git', ['ls-files', '-z', '--', 'packages/web/src', 'packages/shared/src', 'packages/web/vite.config.ts'], { cwd: source }).toString().split('\0').filter(Boolean).sort();
  const productHash = createHash('sha256');
  for (const file of tracked) productHash.update(file + '\0').update(readFileSync(resolve(source, file)));
  const sourceInputSha = productHash.digest('hex');
  const runtimeSha = createHash('sha256').update(readFileSync(fileURLToPath(import.meta.url))).digest('hex');
  writeFileSync(resolve(out, 'fixture.json'), fixtureBytes);
  const web = `${source}/packages/web`;
  const require = createRequire(`${web}/package.json`);
  const { createServer } = await import(pathToFileURL(require.resolve('vite')));
  const held = new Map();
  const armed = new Set();
  let seq = 0;
  const requests = [];
  const record = (event) => {
    const row = { seq: ++seq, at: performance.now(), wallTime: Date.now(), ...event };
    appendFileSync(resolve(out, 'requests.jsonl'), JSON.stringify(row) + '\n');
    requests.push(row);
    return row;
  };
  const json = (res, value, status = 200) => {
    res.statusCode = status;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify(value));
  };
  const plugin = { name: 'source-process-fixture', configureServer(server) {
    server.middlewares.use(async (req, res, next) => {
      const url = new URL(req.url ?? '/', 'http://fixture.invalid');
      if (url.pathname === '/__process/fixture') {
        record({ kind: 'fixture-bytes', fixtureSha });
        res.setHeader('Content-Type', 'application/json');
        return res.end(fixtureBytes);
      }
      if (url.pathname === '/__process/state') return json(res, { fixtureSha, sourceHead, sourceInputSha, runtimeSha, requests, armed: [...armed], held: [...held].map(([key, list]) => ({ key, count: list.length })) });
      if (url.pathname === '/__process/arm') {
        const key = url.searchParams.get('key');
        if (!key) return json(res, { error: 'key required' }, 400);
        armed.add(key); record({ kind: 'armed', key });
        return json(res, { armed: key });
      }
      if (url.pathname === '/__process/release') {
        const key = url.searchParams.get('key');
        armed.delete(key);
        const list = held.get(key) ?? [];
        held.delete(key);
        record({ kind: 'released', key, count: list.length });
        for (const release of list) release();
        return json(res, { released: key, count: list.length });
      }
      if (!url.pathname.startsWith('/api/')) return next();
      const path = url.pathname.slice(4);
      const method = req.method ?? 'GET';
      const key = `${method} ${path}`;
      let body = '';
      for await (const chunk of req) body += chunk;
      let answer = lookup(fixture.routes, method, path, url.searchParams);
      let status = 200;
      if (answer === undefined) { status = 404; answer = { error: 'FIXTURE_MISSING', method, path }; }
      else if (answer && !Array.isArray(answer) && '__status' in answer) { status = answer.__status; answer = answer.body; }
      const request = record({ kind: 'request', key, query: url.search, body: body ? JSON.parse(body) : null, provider: req.headers['x-process-provider'] ?? null, status, held: armed.has(key) });
      const release = () => {
        if (res.writableEnded || res.destroyed) return;
        record({ kind: 'response', key, requestSeq: request.seq, status });
        json(res, answer, status);
      };
      if (armed.has(key)) {
        held.set(key, [...(held.get(key) ?? []), release]);
        res.on('close', () => {
          const live = (held.get(key) ?? []).filter(item => item !== release);
          if (live.length) held.set(key, live); else held.delete(key);
        });
      } else release();
    });
  }};
  const server = await createServer({ root: web, configFile: `${web}/vite.config.ts`,
    cacheDir: resolve(out, 'vite-cache'), plugins: [plugin],
    server: { host: '127.0.0.1', port, strictPort: true, proxy: {}, hmr: false }, logLevel: 'warn' });
  await server.listen();
  writeFileSync(resolve(out, 'runtime.json'), JSON.stringify({ sourceHead, sourceInputSha, runtimeSha, fixtureSha, port, fixturePath, source, server: 'real Source App; isolated API only' }, null, 2));
  return { server, base: `http://127.0.0.1:${port}` };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [fixturePath, out, port = '15413'] = process.argv.slice(2);
  if (!fixturePath || !out) throw new Error('fixture-runtime.mjs FIXTURE OUTPUT [PORT]');
  const source = process.env.RAFT_SOURCE ?? '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
  const runtime = await startRuntime({ source, fixturePath: resolve(fixturePath), out: resolve(out), port: Number(port) });
  console.log(JSON.stringify({ base: runtime.base }));
  const stop = async () => { await runtime.server.close(); process.exit(0); };
  process.on('SIGINT', stop); process.on('SIGTERM', stop);
}
