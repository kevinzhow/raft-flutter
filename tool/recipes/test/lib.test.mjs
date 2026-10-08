// Unit tests for the CSS value / selector / shorthand helpers.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { evaluate, mixColors, parseValue, serialize } from '../lib/css-value.mjs';
import { analyzeSelector, atRuleAtoms, flatten, specificity } from '../lib/selector.mjs';
import { expand } from '../lib/expand.mjs';
import { atomMatches, cascade } from '../lib/cascade.mjs';

const ev = (text, vars = {}, opts = {}) =>
  evaluate(parseValue(text), {
    lookupVar: (n) => (n in vars ? parseValue(vars[n]) : undefined),
    isToken: (n) => (opts.tokens ?? []).includes(n),
    registered: new Map(Object.entries(opts.registered ?? {}).map(([k, v]) => [k, v == null ? null : parseValue(v)])),
  });

test('calc with theme spacing folds to px', () => {
  assert.deepEqual(ev('calc(var(--spacing) * 2.5)', { '--spacing': '0.25rem' }), { t: 'num', v: 10, u: 'px' });
  assert.deepEqual(ev('calc(1.25 / 0.875)'), { t: 'num', v: 1.25 / 0.875, u: '' });
  assert.equal(ev('calc(infinity * 1px)').v > 1e38, true);
});

test('var fallback, tokens and registered initial values', () => {
  assert.equal(serialize(ev('var(--tw-leading, var(--text-sm--line-height))', { '--text-sm--line-height': '1.5' })), '1.5');
  const t = ev('var(--primary-400)', {}, { tokens: ['--primary-400'] });
  assert.equal(t.token, 'primary400');
  assert.equal(serialize(ev('var(--tw-ring-offset-width)', {}, { registered: { '--tw-ring-offset-width': '0px' } })), '0px');
  assert.equal(ev('var(--missing)').t, 'unset');
});

test('literal colours and color-mix', () => {
  assert.equal(ev('oklch(1 0 0 / 0.05)').argb.toString(16), 'dffffff');
  assert.equal(ev('#0000').argb, 0);
  // mixing with transparent scales alpha and keeps the colour
  const m = mixColors('oklch', 0xff112233, 0.5, 0x00000000, null);
  assert.equal(m >>> 24, 128);
  assert.equal(m & 0xffffff, 0x112233);
  assert.equal(ev('color-mix(in oklab, #ff0000 50%, transparent)').argb >>> 24, 128);
});

test('selector atoms', () => {
  const self = '.x';
  assert.deepEqual(analyzeSelector('.x:hover', self), { target: 'self', atoms: ['hover'], unknown: [] });
  assert.deepEqual(analyzeSelector('.x[aria-disabled="true"]:hover', self).atoms, ['aria-disabled=true', 'hover']);
  assert.deepEqual(analyzeSelector('.x:has(*[data-icon="inline-start"])', self).atoms, ['has:data-icon=inline-start']);
  assert.deepEqual(analyzeSelector('.x:is(:where(.group\\/drawer-popup)[data-nested-drawer-open] *)', self).atoms, ['group/drawer-popup:data-nested-drawer-open']);
  assert.deepEqual(analyzeSelector('.x:not(*[data-disabled])', self).atoms, ['not:data-disabled']);
  assert.equal(analyzeSelector('.x::before', self).target, '::before');
  assert.equal(analyzeSelector('.x svg', self).target, '& svg');
  assert.equal(analyzeSelector(':is(.x *)[data-icon]', self).target, ':is(& *)[data-icon]');
  const dark = flatten(['.x'], '&:where( :is([data-theme="elegant"].dark, [data-theme="elegant"].dark *))');
  assert.deepEqual(analyzeSelector(dark[0], self).atoms, ['dark']);
  assert.deepEqual(atRuleAtoms('media', '(width < 48rem)', { unknown: [] }), ['width<768']);
  assert.deepEqual(atRuleAtoms('media', '(hover: hover)', { unknown: [] }), []);
  assert.deepEqual(specificity('.x:hover'), [0, 2, 0]);
  assert.deepEqual(specificity('.x:where(.dark *)'), [0, 1, 0]);
  assert.deepEqual(specificity('.x:is(:where(.group)[data-a] *)'), [0, 2, 0]);
});

test('shorthands expand to physical LTR longhands', () => {
  const px = (n) => ({ t: 'num', v: n, u: 'px' });
  assert.deepEqual(expand('padding-inline', px(12)).map(([p]) => p), ['padding-left', 'padding-right']);
  assert.deepEqual(expand('padding', parseValue('1px 2px')).map(([p, v]) => [p, v.v]), [['padding-top', 1], ['padding-right', 2], ['padding-bottom', 1], ['padding-left', 2]]);
  assert.deepEqual(expand('border-start-start-radius', px(4))[0][0], 'border-top-left-radius');
  assert.equal(expand('border-width', px(2)).length, 4);
});

test('cascade: specificity, order, !important and state atoms', () => {
  const num = (v) => ({ t: 'num', v, u: 'px' });
  const utilities = [
    { order: 1, layers: [{ target: 'self', atoms: [], spec: [0, 1, 0], decls: [{ prop: 'height', value: num(32) }] }] },
    { order: 0, layers: [{ target: 'self', atoms: ['hover'], spec: [0, 2, 0], decls: [{ prop: 'height', value: num(40) }] }] },
    { order: 2, layers: [{ target: 'self', atoms: [], spec: [0, 1, 0], decls: [{ prop: 'height', value: num(24) }] }] },
  ];
  const opts = { registered: new Map(), isToken: () => false };
  assert.equal(cascade(utilities, [0, 1, 2], { flags: new Set() }, opts).get('self').get('height').v, 24);
  assert.equal(cascade(utilities, [0, 1, 2], { flags: new Set(['hover']) }, opts).get('self').get('height').v, 40);
  assert.equal(atomMatches('not:disabled', { flags: new Set() }), true);
  assert.equal(atomMatches('width<768', { flags: new Set(), width: 500 }), true);
  assert.equal(atomMatches('width<768', { flags: new Set() }), false);
});
