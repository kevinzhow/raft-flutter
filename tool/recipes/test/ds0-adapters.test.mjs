import assert from 'node:assert/strict';
import {test} from 'node:test';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
const base = process.env.RAFT_TEST_ADAPTER_DIR ?? resolve('tool/recipes/lib');
const {loadBundle} = await import(pathToFileURL(`${base}/bundle.mjs`));
const {createCompiler, splitOutput} = await import(pathToFileURL(`${base}/tailwind.mjs`));
const {analyzeSelector} = await import(pathToFileURL(`${base}/selector.mjs`));
const source = process.env.RAFT_UI_SOURCE;

test('published modular stable AND WIP entry points retain all 152 recipes', () => {
  const bundle = loadBundle(source);
  assert.equal((bundle.code.match(/\btv\$1\(/g) ?? []).length, 152);
  assert.ok(bundle.files.some(f => f.includes('choice-list.recipe.mjs')));
  assert.ok(bundle.files.some(f => f.includes('button.mjs')));
});

test('Tailwind 4.3 keeps flat variants, media wrappers, dark islands and responsive defaults', async () => {
  const candidates = new Set(['text-body', 'hover:text-foreground', 'dark:bg-layer-card', 'md:pointer-fine:h-control', '*:size-4']);
  const compiler = await createCompiler(source);
  const parsed = splitOutput(compiler.build([...candidates]), candidates);
  for (const c of candidates) assert.ok(parsed.utilities.get(c)?.layers.length, c);
  assert.equal(parsed.themeVars.get('--text-body'), '16px');
  const desktop = parsed.conditionalThemeVars.find(c => c.atoms.includes('pointer-fine') && c.atoms.includes('width>=768'));
  assert.equal(desktop.vars.get('--text-body'), '14px');
  assert.equal(desktop.vars.get('--control-height'), '34px');
  const wideTouch = parsed.conditionalThemeVars.find(c => c.atoms.length === 1 && c.atoms[0] === 'width>=768');
  assert.equal(wideTouch.vars.get('--column-margin'), '20px');
  assert.ok(!wideTouch.vars.has('--control-height'));
  assert.ok(parsed.utilities.get('hover:text-foreground').layers.some(l => l.atoms.includes('hover')));
  assert.ok(parsed.utilities.get('dark:bg-layer-card').layers.every(l => l.atoms.includes('dark')));
  assert.ok(parsed.utilities.get('*:size-4').layers.every(l => l.target !== 'self'));
  assert.deepEqual(analyzeSelector('.x:hover', '.x').atoms, ['hover']);
});
