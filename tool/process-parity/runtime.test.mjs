// The fixture must fail missing routes and hold real responses; no empty success.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { lookup, startRuntime } from './fixture-runtime.mjs';

test('query-specific read windows beat general routes without inventing missing rows', () => {
  const routes = { 'GET /messages/a': { window: 'tail' }, 'GET /messages/a?after=5': { window: 'new' }, 'GET /messages/a?after=5&limit=20': { window: 'page' } };
  assert.deepEqual(lookup(routes, 'GET', '/messages/a', new URLSearchParams('limit=20&after=5&unknown=x')), { window: 'page' });
  assert.deepEqual(lookup(routes, 'GET', '/messages/a', new URLSearchParams('after=6')), { window: 'tail' });
  assert.equal(lookup(routes, 'POST', '/messages/a', new URLSearchParams()), undefined);
});

test('held success and explicit denial retain request chronology and do not leak aborted gates', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'raft-process-runtime-'));
  const fixturePath = join(dir, 'fixture.json');
  writeFileSync(fixturePath, JSON.stringify({ routes: { 'GET /test-target': { id: 'target' }, 'GET /test-denial': { __status: 403, body: { error: 'FORBIDDEN' } } } }));
  const source = process.env.RAFT_SOURCE ?? '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source';
  const runtime = await startRuntime({ source, fixturePath, out: join(dir, 'run'), port: Number(process.env.RAFT_PROCESS_TEST_PORT ?? 15414) });
  const getState = async () => (await fetch(`${runtime.base}/__process/state`)).json();
  const waitFor = async check => { for (let i = 0; i < 100; i++) { const state = await getState(); if (check(state)) return state; await new Promise(r => setTimeout(r, 10)); } throw new Error('Runtime gate timeout'); };
  try {
    const served = await (await fetch(`${runtime.base}/__process/fixture`)).text();
    assert.equal(served, readFileSync(fixturePath, 'utf8'));
    const missing = await fetch(`${runtime.base}/api/never-seeded`);
    assert.equal(missing.status, 404); assert.equal((await missing.json()).error, 'FIXTURE_MISSING');
    await fetch(`${runtime.base}/__process/arm?key=GET%20%2Ftest-target`);
    let responded = false;
    const pending = fetch(`${runtime.base}/api/test-target`).then(r => { responded = true; return r.json(); });
    const held = await waitFor(state => state.held.some(item => item.count === 1));
    assert.equal(responded, false);
    const request = held.requests.find(row => row.key === 'GET /test-target' && row.kind === 'request');
    assert.equal(request.held, true); assert.equal(held.requests.some(row => row.requestSeq === request.seq), false);
    await fetch(`${runtime.base}/__process/release?key=GET%20%2Ftest-target`);
    assert.deepEqual(await pending, { id: 'target' });
    const released = await getState();
    assert.ok(released.requests.find(row => row.kind === 'released').seq < released.requests.find(row => row.requestSeq === request.seq).seq);
    const denial = await fetch(`${runtime.base}/api/test-denial`);
    assert.equal(denial.status, 403); assert.deepEqual(await denial.json(), { error: 'FORBIDDEN' });
    await fetch(`${runtime.base}/__process/arm?key=GET%20%2Ftest-target`);
    const abort = new AbortController();
    const abandoned = fetch(`${runtime.base}/api/test-target`, { signal: abort.signal }).catch(error => error.name);
    await waitFor(state => state.held.some(item => item.count === 1));
    abort.abort(); assert.equal(await abandoned, 'AbortError');
    await waitFor(state => state.held.length === 0);
    const releaseEmpty = await (await fetch(`${runtime.base}/__process/release?key=GET%20%2Ftest-target`)).json();
    assert.equal(releaseEmpty.count, 0);
  } finally { await runtime.server.close(); rmSync(dir, { recursive: true, force: true }); }
});
