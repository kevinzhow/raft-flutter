// End-to-end checks of the generated recipe data.
//  - every tv$1(...) call in raft-ui is extracted with literal options;
//  - every class is resolved by Tailwind or listed in unresolved.json;
//  - Button spot values;
//  - the raft_ui router (gen_router.mjs) matches the committed files;
//  - the pipeline is deterministic and the committed outputs are up to date.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import * as acorn from 'acorn';
import { loadBundle } from '../lib/bundle.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const tool = resolve(here, '..');
const repo = resolve(tool, '../..');
const source = process.env.RAFT_UI_SOURCE ?? '/tmp/rui';
const build = join(repo, 'build/recipes');
const raw = JSON.parse(readFileSync(join(build, 'recipes.raw.json'), 'utf8'));
const model = JSON.parse(readFileSync(join(build, 'recipes.json'), 'utf8'));

test('every tv$1 call is extracted with literal options', () => {
  const { code, aliasToLocal } = loadBundle(source);
  const callees = new Set(['tv$1', ...[...aliasToLocal].filter(([, l]) => l === 'tv$1').map(([a]) => a)]);
  let calls = 0;
  const walk = (n) => {
    if (!n || typeof n.type !== 'string') return;
    if (n.type === 'CallExpression' && n.callee.type === 'Identifier' && callees.has(n.callee.name)) calls++;
    for (const [k, v] of Object.entries(n)) {
      if (k === 'loc') continue;
      if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') walk(v);
    }
  };
  walk(acorn.parse(code, { ecmaVersion: 'latest', sourceType: 'module' }));
  const products = raw.recipes.filter((r) => r.region?.startsWith('Web '));
  assert.equal(products.length, raw.productRecipeCount ?? 0);
  assert.equal(raw.recipes.length - products.length, calls);
  assert.equal(raw.rawCallCount, calls);
  assert.equal(model.recipes.length, calls + products.length);
  for (const product of products) {
    assert.match(product.region, /^Web src\/.+\.tsx sha256:[a-f0-9]{64}$/);
    assert.ok(model.recipes.some((r) => r.name === product.name), product.name);
  }
  assert.deepEqual(raw.recipes.filter((r) => r.nonLiteral.length).map((r) => r.name), []);
  assert.equal(new Set(raw.recipes.map((r) => r.name)).size, calls + products.length);
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
  const re = /^(not:)?([a-z-]+(\*|\^|\$|~|\|)?=[^ ]+|[a-z-]+|(width|height|container-width)(>=|<=|<|>)[\d.]+|is\([a-z,]+\)|has:.+|(group|peer)(\/[\w-]+)?:.+|ancestor:.+|in:.+)$/;
  const bad = new Set();
  for (const u of model.utilities) for (const l of u.layers) for (const a of l.atoms) if (!re.test(a)) bad.add(a);
  assert.deepEqual([...bad], []);
});

test('Button spot values (raft-ui 0.7.0, no theme axis)', () => {
  const r = model.recipes.find((x) => x.name === 'buttonVariants');
  assert.deepEqual(Object.keys(r.definition.variants), ['variant', 'size']);
  const combo = (props) => r.combos.find((c) => Object.entries(props).every(([k, v]) => c.props[k] === v));
  const self = (props) => model.resolved[combo(props).slots.root].self;
  const md = self({ variant: 'default', size: 'md' });
  assert.equal(md.base.height, 32);
  assert.deepEqual(md.base.padding, { top: 0, right: 12, bottom: 0, left: 12 });
  assert.equal(md.base['font-size'], 13);
  assert.equal(md.base['font-weight'], 700);
  assert.equal(md.base['border-width'], 1.5);
  assert.equal(md.base['border-radius'], 8);
  assert.deepEqual(md.base['background-color'], { token: 'layerCard' });
  // xs, sm and md share one geometry in 0.7.0; lg is the only taller button.
  for (const size of ['xs', 'sm']) assert.deepEqual(self({ variant: 'default', size }).base.height, 32);
  const lg = self({ variant: 'default', size: 'lg' });
  assert.equal(lg.base.height, 44);
  assert.equal(lg.base['font-size'], 15);
  // Disabled swaps to the muted fill; it no longer fades to 40%.
  assert.equal(md.states['aria-disabled=true']['opacity'], '100%');
  assert.deepEqual(md.states['aria-disabled=true']['background-color'], { token: 'fillMuted' });
  // Primary is a sticker: attention fill, sticker-ink border, press overlay.
  const primary = r.definition.variants.variant.primary.root.join(' ');
  assert.ok(primary.includes('bg-attention-400'));
  assert.ok(primary.includes('border-sticker-ink'));
  assert.ok(primary.includes('hover:press-overlay-sticker'));
  const bg = model.utilities.find((u) => u.name === 'bg-attention-400').layers[0].decls[0].value;
  assert.equal(bg.token, 'attention400');
  const hover = model.utilities.find((u) => u.name === 'hover:press-overlay-sticker').layers[0];
  assert.deepEqual(hover.atoms, ['hover']);
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
        return [join('pkg', rel), join('packages/raft_theme', rel)];
      }),
    ];
    for (const [fresh, repoPath] of committed) {
      assert.ok(readFileSync(join(runs[0], fresh)).equals(readFileSync(join(repo, repoPath))), `${repoPath} is stale; run tool/recipes/run`);
    }
  } finally {
    for (const d of runs) rmSync(d, { recursive: true, force: true });
  }
});

test('the raft_ui recipe router is current', () => {
  execFileSync(process.execPath, [join(tool, 'gen_router.mjs'), '--check'], { stdio: 'pipe' });
});

test('the frozen legacy recipe set is untouched by the pipeline', () => {
  // lib/recipes/legacy holds raft-ui 0.5.52 output; the pipeline only reads it.
  const legacy = join(repo, 'packages/raft_theme/lib/recipes/legacy');
  assert.equal(readdirSync(legacy).filter((f) => f.endsWith('.g.dart')).length, 123);
  assert.match(readFileSync(join(legacy, 'badge.g.dart'), 'utf8'), /raft-ui 0\.5\.52 dist\/index\.mjs/);
});
