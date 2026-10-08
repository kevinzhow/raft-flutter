#!/usr/bin/env node
// Resolve Web JSX Tailwind classes (not covered by raft-ui recipes) to CSS.
//
//   node tool/recipes/css-of.mjs "size-2.5 bg-brutal-lime border border-line-strong"
//
// Compiles the classes with Tailwind v4 + raft-ui styles.css + the Web @theme
// overrides (same compiler as resolve.mjs), prints each utility's rules and,
// for every literal colour (oklch/hex/rgb), its sRGB ARGB hex. `var(--x)`
// references are left symbolic: they are foundation tokens (RaftTokens).
// Note: Web-only custom variants (theme-brutal:) and @layer component classes
// (input-brutal, card-brutal) live in packages/web/src/index.css, not here.
import { createCompiler, splitOutput } from './lib/tailwind.mjs';
import { evaluate, parseValue } from './lib/css-value.mjs';

const classes = process.argv.slice(2).join(' ').split(/\s+/).filter(Boolean);
if (!classes.length) {
  console.error('usage: css-of.mjs "<tailwind classes>"');
  process.exit(2);
}
const compiler = await createCompiler(process.env.RAFT_UI_SOURCE ?? '/tmp/rui');
const { utilities, themeVars } = splitOutput(compiler.build(classes));
const hex = (argb) => `0x${argb.toString(16).toUpperCase().padStart(8, '0')}`;
const colours = (value) => {
  const out = [];
  const re = /(oklch\([^)]*\)|#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\))/g;
  for (const m of value.matchAll(re)) {
    try {
      const v = evaluate(parseValue(m[1]), { vars: new Map(), registered: new Map() });
      if (v?.t === 'color') out.push(`${m[1]} = ${hex(v.argb)}`);
    } catch {}
  }
  return out;
};
for (const c of classes) {
  const u = utilities.get(c);
  if (!u) {
    console.log(`${c}: (no Tailwind utility; Web component class or unknown)`);
    continue;
  }
  console.log(c);
  for (const l of u.layers) {
    const where = [l.target !== 'self' ? l.target : '', ...l.atoms].filter(Boolean).join(' ');
    for (const d of l.decls) {
      if (d.prop.startsWith('--tw-') && d.value === 'initial') continue;
      let value = d.value;
      const vars = [...value.matchAll(/var\((--[\w-]+)/g)].map((m) => m[1]);
      const theme = vars.map((v) => themeVars.has(v) ? `${v}: ${themeVars.get(v)}` : null).filter(Boolean);
      const cols = colours([value, ...theme].join(' '));
      console.log(`  ${where ? `[${where}] ` : ''}${d.prop}: ${value}${d.important ? ' !important' : ''}` +
        (theme.length ? `   {${theme.join('; ')}}` : '') + (cols.length ? `   => ${cols.join(', ')}` : ''));
    }
  }
}
