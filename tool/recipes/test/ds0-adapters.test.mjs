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

test('system-dark utility fallback cannot become global theme variables', async () => {
  // Published MessageItem shadow utility, compiled by the real pinned Tailwind.
  const shadow = 'dark:shadow-[0_0_0_3px_var(--mi-row-fill,transparent),0_0_0_3px_var(--layer-canvas)]';
  const candidates = new Set(['shadow-none', shadow]);
  const compiler = await createCompiler(source);
  const parsed = splitOutput(compiler.build([...candidates]), candidates);
  assert.ok(parsed.utilities.get(shadow).layers.some(l => l.atoms.includes('dark')));
  assert.equal(parsed.utilities.get('shadow-none').layers[0].decls.find(d => d.prop === '--tw-shadow').value, '0 0 #0000');
  for (const context of parsed.conditionalThemeVars) {
    assert.ok(!context.vars.has('--tw-shadow'), `utility shadow leaked into ${context.atoms}`);
    assert.ok(!context.vars.has('--tw-shadow-color'), `utility color leaked into ${context.atoms}`);
  }
});

test('root theme scopes keep explicit/system dark and independent responsive variables', () => {
  const parsed = splitOutput(`
    @layer theme {
      :root, :host { --column-margin: 16px; }
      @media (width >= 48rem) { :root, :host { --column-margin: 20px; } }
      @media (width >= 48rem) and (pointer: fine) { :where(:root), :host { --control-height: 34px; } }
    }
    :root.dark { --color-code-surface: #0a0c10; }
    @media (prefers-color-scheme: dark) {
      :root:not(.light):not(.dark) { --system-dark-root: 1; }
      :root .message-item { --descendant-only: 3px; }
    }
  `);
  const context = (...atoms) => parsed.conditionalThemeVars.find(c => c.atoms.join('|') === atoms.sort().join('|'));
  assert.equal(context('dark').vars.get('--color-code-surface'), '#0a0c10');
  assert.equal(context('dark').vars.get('--system-dark-root'), '1');
  assert.ok(!context('dark').vars.has('--descendant-only'));
  assert.equal(context('width>=768').vars.get('--column-margin'), '20px');
  assert.equal(context('width>=768', 'pointer-fine').vars.get('--control-height'), '34px');
  assert.equal(context('width>=768', 'pointer-fine').vars.get('--column-margin'), '20px');
});

test('unknown conditional root media rejects instead of broadening its variables', () => {
  assert.throws(() => splitOutput('@media (width >= 48rem) and (resolution > 1dppx) { :root { --control-height: 34px; } }'), /unsupported.*theme.*media/i);
});
