import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import test from 'node:test';
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
function run(env) {
  return spawnSync('bash', ['tool/recipes/run'], { cwd: repo,
    env: { ...process.env, ...env }, encoding: 'utf8' });
}
test('recipe regeneration refuses to select an unrelated implicit Web checkout', () => {
  const result = run({ RAFT_UI_SOURCE: '/missing-unpacked-raft-ui', RAFT_WEB_CSS: '' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Set RAFT_WEB_CSS to the pinned Web client/);
});
test('the inferred Web source must exist before the pipeline writes anything', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'recipe-web-source-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const result = run({ RAFT_UI_SOURCE: join(root, 'node_modules/@botiverse/raft-ui'), RAFT_WEB_CSS: '' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Pinned Web CSS does not exist:/);
});
