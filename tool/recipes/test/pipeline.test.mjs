// End-to-end checks of the generated recipe data.
//  - every tv$1(...) call in raft-ui is extracted with literal options;
//  - every class is resolved by Tailwind or listed in unresolved.json;
//  - Button spot values;
//  - the pipeline is deterministic and the committed outputs are up to date.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import * as acorn from 'acorn';

const here = fileURLToPath(new URL('.', import.meta.url));
const tool = resolve(here, '..');
const repo = resolve(tool, '../..');
const source = process.env.RAFT_UI_SOURCE ?? '/tmp/rui';
const build = join(repo, 'build/recipes');
const raw = JSON.parse(readFileSync(join(build, 'recipes.raw.json'), 'utf8'));
const model = JSON.parse(readFileSync(join(build, 'recipes.json'), 'utf8'));

test('every tv$1 call is extracted with literal options', () => {
  const code = readFileSync(join(source, 'dist/index.mjs'), 'utf8');
  let calls = 0;
  const walk = (n) => {
    if (!n || typeof n.type !== 'string') return;
    if (n.type === 'CallExpression' && n.callee.type === 'Identifier' && n.callee.name === 'tv$1') calls++;
    for (const [k, v] of Object.entries(n)) {
      if (k === 'loc') continue;
      if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') walk(v);
    }
  };
  walk(acorn.parse(code, { ecmaVersion: 'latest', sourceType: 'module' }));
  assert.equal(raw.recipes.length, calls);
  assert.equal(raw.rawCallCount, calls);
  assert.equal(model.recipes.length, calls);
  assert.deepEqual(raw.recipes.filter((r) => r.nonLiteral.length).map((r) => r.name), []);
  assert.equal(new Set(raw.recipes.map((r) => r.name)).size, calls);
});

test('every class is resolved, descendant, a marker, or explicitly unresolved', () => {
  const known = JSON.parse(readFileSync(join(tool, 'unresolved.json'), 'utf8')).classes;
  const statuses = new Set(['resolved', 'descendant', 'marker', 'no-css']);
  for (const u of model.utilities) assert.ok(statuses.has(u.status), u.name);
  const noCss = model.utilities.filter((u) => u.status === 'no-css').map((u) => u.name).sort();
  assert.deepEqual(noCss, Object.keys(known).sort(), 'no-css classes must match tool/recipes/unresolved.json');
  for (const u of model.utilities.filter((x) => x.status === 'marker')) assert.match(u.name, /^(group|peer)(\/[\w-]+)?$/);
  for (const u of model.utilities.filter((x) => x.status === 'resolved' || x.status === 'descendant')) {
    assert.ok(u.layers.length > 0 && u.layers.every((l) => l.decls.length > 0), u.name);
  }
});

test('condition atoms follow the documented grammar', () => {
  const re = /^(not:)?([a-z-]+(\*|\^|\$|~|\|)?=[^ ]+|[a-z-]+|(width|height|container-width)(>=|<=|<|>)[\d.]+|has:.+|(group|peer)(\/[\w-]+)?:.+|ancestor:.+|in:.+)$/;
  const bad = new Set();
  for (const u of model.utilities) for (const l of u.layers) for (const a of l.atoms) if (!re.test(a)) bad.add(a);
  assert.deepEqual([...bad], []);
});

test('Button spot values', () => {
  const r = model.recipes.find((x) => x.name === 'buttonVariants');
  const combo = (props) => r.combos.find((c) => Object.entries(props).every(([k, v]) => c.props[k] === v));
  const self = (props) => model.resolved[combo(props).slots.root].self;
  for (const theme of ['brutal', 'elegant']) {
    const md = self({ theme, variant: 'default', size: 'md' });
    assert.equal(md.base.height, 32);
    assert.deepEqual(md.base.padding, { top: 0, right: 12, bottom: 0, left: 12 });
    assert.equal(md.base['font-size'], 14);
    const xs = self({ theme, variant: 'default', size: 'xs' });
    assert.equal(xs.base.height, 24);
    assert.equal(xs.base['font-size'], 11);
    assert.equal(md.states.disabled.opacity, '40%');
  }
  assert.equal(self({ theme: 'brutal', variant: 'default', size: 'md' }).base['border-width'], 2);
  assert.equal(self({ theme: 'elegant', variant: 'default', size: 'md' }).states.active.scale, 0.985);
  // Base variant classes (before theme compounds) are primary-400 / hover primary-500.
  assert.ok(r.definition.variants.variant.primary.root.join(' ').includes('bg-primary-400'));
  assert.ok(r.definition.variants.variant.primary.root.join(' ').includes('hover:bg-primary-500'));
  const bg = model.utilities.find((u) => u.name === 'bg-primary-400').layers[0].decls[0].value;
  assert.equal(bg.token, 'primary400');
  const hover = model.utilities.find((u) => u.name === 'hover:bg-primary-500').layers[0];
  assert.deepEqual([hover.atoms, hover.decls[0].value.token], [['hover'], 'primary500']);
});

function files(dir) {
  const out = [];
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) out.push(...files(p));
    else out.push(p);
  }
  return out.sort();
}

test('pipeline is deterministic and committed outputs are current', { timeout: 120000 }, () => {
  const runs = [mkdtempSync(join(tmpdir(), 'recipes-a-')), mkdtempSync(join(tmpdir(), 'recipes-b-'))];
  try {
    for (const dir of runs) {
      const node = process.execPath;
      execFileSync(node, [join(tool, 'extract.mjs'), '--source', source, '--out', join(dir, 'build')], { stdio: 'pipe' });
      execFileSync(node, [join(tool, 'resolve.mjs'), '--source', source, '--out', join(dir, 'build'), '--docs', join(dir, 'docs/component-recipes.md')], { stdio: 'pipe' });
      execFileSync(node, [join(tool, 'gen_dart.mjs'), '--build', join(dir, 'build'), '--package', join(dir, 'pkg')], { stdio: 'pipe' });
    }
    const [a, b] = runs.map((d) => files(d).map((f) => [relative(d, f), readFileSync(f)]));
    assert.deepEqual(a.map(([f]) => f), b.map(([f]) => f));
    for (let i = 0; i < a.length; i++) assert.ok(a[i][1].equals(b[i][1]), `non-deterministic output: ${a[i][0]}`);
    // Committed generated files match a fresh run.
    const committed = [
      ['docs/component-recipes.md', 'docs/component-recipes.md'],
      ...files(join(runs[0], 'pkg')).map((f) => {
        const rel = relative(join(runs[0], 'pkg'), f);
        return [join('pkg', rel), join('packages/raft_ui', rel)];
      }),
    ];
    for (const [fresh, repoPath] of committed) {
      assert.ok(readFileSync(join(runs[0], fresh)).equals(readFileSync(join(repo, repoPath))), `${repoPath} is stale; run tool/recipes/run`);
    }
  } finally {
    for (const d of runs) rmSync(d, { recursive: true, force: true });
  }
});
