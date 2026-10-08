#!/usr/bin/env node
// Resolve every extracted recipe into exact CSS using Tailwind v4's compiler
// and raft-ui's styles.css, then normalise into a structured per-recipe model.
//
// Inputs:  build/recipes/recipes.raw.json (extract.mjs), raft-ui dist/*.css
// Outputs: build/recipes/recipes.json      structured model (consumed by gen_dart.mjs)
//          build/recipes/coverage.json     class coverage + unresolved report
//          build/recipes/tailwind.css      the compiled utilities (for inspection)
//          docs/component-recipes.md       human readable tables
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import postcss from 'postcss';
import { camel, evaluate, parseValue } from './lib/css-value.mjs';
import { expand } from './lib/expand.mjs';
import { buildRecipes, classesInOptions, enumerate, variantAxes } from './lib/recipes-eval.mjs';
import { createCompiler, inputCss, splitOutput, twVersion, WEB_THEME_PATH } from './lib/tailwind.mjs';
import { cascade, summarize } from './lib/cascade.mjs';
import { writeDocs } from './lib/docs.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
};
const sourceRoot = arg('source', process.env.RAFT_UI_SOURCE ?? '/tmp/rui');
const outDir = resolve(repo, arg('out', 'build/recipes'));
const docsPath = resolve(repo, arg('docs', 'docs/component-recipes.md'));
const knownUnresolved = JSON.parse(readFileSync(join(here, 'unresolved.json'), 'utf8')).classes;

const raw = JSON.parse(readFileSync(join(outDir, 'recipes.raw.json'), 'utf8'));

// ------------------------------------------------------------ 1. tv results
const { built } = await buildRecipes(raw, sourceRoot);
const recipeCombos = new Map();
const allClasses = new Set();
const optionClasses = new Map(); // class -> Set(recipe)
for (const r of raw.recipes) {
  const { axes } = variantAxes(raw, r.name);
  const combos = enumerate(built.get(r.name), axes);
  // Drop the implicit `base` slot when a slotted recipe never fills it.
  const slotSet = new Set(combos.flatMap((c) => Object.keys(c.slots)));
  const definesBase = (name) => {
    const x = raw.recipes.find((y) => y.name === name);
    return x.options.base !== undefined || (x.options.extend?.$recipe && definesBase(x.options.extend.$recipe));
  };
  if (slotSet.size > 1 && slotSet.has('base') && !definesBase(r.name) && combos.every((c) => c.slots.base.length === 0)) {
    for (const c of combos) delete c.slots.base;
  }
  recipeCombos.set(r.name, { axes, combos });
  for (const c of combos) for (const list of Object.values(c.slots)) list.forEach((x) => allClasses.add(x));
  for (const x of classesInOptions(r.options)) {
    allClasses.add(x);
    if (!optionClasses.has(x)) optionClasses.set(x, new Set());
    optionClasses.get(x).add(r.name);
  }
}

// ------------------------------------------------------- 2. Tailwind compile
// `--raft-ui-only` compiles against raft-ui styles.css alone (without the
// Web client's @theme overrides in tool/recipes/web-theme.css).
const webTheme = !process.argv.includes('--raft-ui-only');
const compiler = await createCompiler(sourceRoot, { webTheme });
const sortedClasses = [...allClasses].sort();
const css = compiler.build(sortedClasses);
const { utilities: twUtilities, themeVars, registered: registeredRaw } = splitOutput(css);

// Foundation tokens: every custom property declared by foundation.css, plus
// the font-family tokens of fonts.css (--heading-font, --sans-font, --mono-font).
const TOKEN_SOURCES = ['dist/foundation.css', 'dist/fonts.css'];
const foundation = new Set();
for (const f of TOKEN_SOURCES) {
  postcss.parse(readFileSync(join(sourceRoot, f), 'utf8')).walkDecls((d) => {
    if (d.prop.startsWith('--')) foundation.add(d.prop);
  });
}
const isToken = (name) => foundation.has(name);

// Theme variables (Tailwind @theme, emitted in @layer theme) are compile-time
// constants; foundation tokens stay symbolic.
const themeParsed = new Map();
const themeCtx = {
  lookupVar: (name) => {
    if (isToken(name) || !themeVars.has(name)) return undefined;
    if (!themeParsed.has(name)) themeParsed.set(name, parseValue(themeVars.get(name)));
    return themeParsed.get(name);
  },
  isToken,
  partial: true,
};
const fold = (text) => evaluate(parseValue(text), themeCtx);

const registered = new Map();
for (const [name, init] of [...registeredRaw].sort(([a], [b]) => a.localeCompare(b))) registered.set(name, init == null ? null : fold(init));

// ------------------------------------------------------------- 3. utilities
const MARKER = /^(group|peer)(\/[\w-]+)?$/;
const utilities = [];
const utilIndex = new Map();
for (const name of sortedClasses) {
  const u = twUtilities.get(name);
  const entry = { name, order: u ? u.order : -1, status: '', layers: [] };
  if (u) {
    const seen = new Set();
    for (const layer of u.layers) {
      const decls = [];
      for (const d of layer.decls) {
        const value = fold(d.value);
        if (d.prop.startsWith('--')) decls.push({ prop: d.prop, value, important: d.important });
        else for (const [prop, v] of expand(d.prop, value)) decls.push({ prop, value: v, important: d.important });
      }
      const atoms = [...layer.atoms].sort();
      const key = JSON.stringify([layer.target, atoms, decls]);
      if (seen.has(key)) continue; // e.g. dark: selector + prefers-color-scheme fallback
      seen.add(key);
      entry.layers.push({ target: layer.target, atoms, spec: layer.specificity, decls });
    }
    const targets = new Set(entry.layers.map((l) => l.target));
    entry.status = [...targets].some((t) => t === 'self' || t.startsWith('::')) ? 'resolved' : 'descendant';
  } else {
    entry.status = MARKER.test(name) ? 'marker' : 'no-css';
  }
  utilIndex.set(name, utilities.length);
  utilities.push(entry);
}

// ------------------------------------------------- 4. recipes + class lists
const classLists = [];
const classListIndex = new Map();
const internList = (list) => {
  const idx = list.map((c) => utilIndex.get(c));
  const key = idx.join(',');
  if (!classListIndex.has(key)) {
    classListIndex.set(key, classLists.length);
    classLists.push(idx);
  }
  return classListIndex.get(key);
};

const dartName = (name) => {
  const base = name
    .replace(/\$extend$/, 'Base')
    .replace(/\$/g, '')
    .replace(/(Variants|Recipe|Styles)$/, '');
  return `Raft${base[0].toUpperCase()}${base.slice(1)}Recipe`;
};

const recipes = raw.recipes.map((r) => {
  const { axes, combos } = recipeCombos.get(r.name);
  const slots = [...new Set(combos.flatMap((c) => Object.keys(c.slots)))];
  return {
    name: r.name,
    dartClass: dartName(r.name),
    line: r.line,
    region: r.region,
    exportedComponents: r.exportedComponents,
    directUsers: r.directUsers,
    extends: r.options.extend?.$recipe ?? null,
    slots,
    axes,
    definition: r.options,
    combos: combos.map((c) => ({ props: c.props, slots: Object.fromEntries(slots.map((s) => [s, internList(c.slots[s] ?? [])])) })),
  };
});
const dartNames = new Set();
for (const r of recipes) {
  if (dartNames.has(r.dartClass)) throw new Error(`duplicate Dart class name ${r.dartClass}`);
  dartNames.add(r.dartClass);
}

// ------------------------------------------- 5. resolved (base + per state)
const engineUtilities = utilities.map((u) => ({ order: u.order, layers: u.layers }));
const engineOpts = { registered, isToken };

function statesFor(atoms) {
  const flags = new Set();
  const st = { flags };
  for (const a of atoms) {
    if (a.startsWith('not:')) continue;
    const m = /^(width|height|container-width)(>=|<=|<|>)([\d.]+)$/.exec(a);
    if (m) {
      const n = parseFloat(m[3]);
      const v = m[2] === '>=' ? n : m[2] === '>' ? n + 1 : m[2] === '<=' ? n : n - 1;
      st[m[1] === 'width' ? 'width' : m[1] === 'height' ? 'height' : 'containerWidth'] = v;
      continue;
    }
    flags.add(a);
  }
  return st;
}

const resolved = classLists.map((list) => {
  const stateSets = new Map();
  for (const ci of list) {
    for (const l of utilities[ci].layers) {
      const positive = l.atoms.filter((a) => !a.startsWith('not:'));
      if (positive.length) stateSets.set(positive.join('+'), positive);
    }
  }
  const base = cascade(engineUtilities, list, { flags: new Set() }, engineOpts);
  const out = {};
  const summaries = new Map([...base].map(([t, ev]) => [t, summarize(ev)]));
  for (const [t, s] of summaries) out[t] = { base: s, states: {} };
  for (const [key, atoms] of [...stateSets].sort(([a], [b]) => a.localeCompare(b))) {
    const res = cascade(engineUtilities, list, statesFor(atoms), engineOpts);
    for (const [t, ev] of res) {
      const s = summarize(ev);
      const b = summaries.get(t) ?? {};
      const delta = {};
      for (const k of new Set([...Object.keys(b), ...Object.keys(s)])) {
        if (JSON.stringify(b[k]) !== JSON.stringify(s[k])) delta[k] = s[k] ?? null;
      }
      if (Object.keys(delta).length) {
        if (!out[t]) out[t] = { base: {}, states: {} };
        out[t].states[key] = delta;
      }
    }
  }
  return out;
});

// --------------------------------------------------------------- 6. output
const coverage = (() => {
  const total = [...optionClasses.keys()].sort();
  const by = {};
  for (const c of total) {
    const st = utilities[utilIndex.get(c)].status;
    (by[st] ??= []).push(c);
  }
  return {
    classesInRecipes: total.length,
    classesAfterMerge: allClasses.size,
    counts: Object.fromEntries(Object.entries(by).map(([k, v]) => [k, v.length]).sort()),
    noCss: (by['no-css'] ?? []).map((c) => ({ class: c, recipes: [...optionClasses.get(c)].sort(), reason: knownUnresolved[c] ?? null })),
    markers: by.marker ?? [],
    descendant: by.descendant ?? [],
  };
})();

const sha = (s) => createHash('sha256').update(s).digest('hex');
const model = {
  generatedBy: 'tool/recipes/resolve.mjs',
  source: {
    ...raw.source,
    tailwindcss: twVersion(),
    inputCss: inputCss({ webTheme }),
    webThemeSha256: webTheme ? sha(readFileSync(WEB_THEME_PATH)) : null,
    stylesSha256: sha(readFileSync(join(sourceRoot, 'dist/styles.css'))),
    foundationSha256: sha(readFileSync(join(sourceRoot, 'dist/foundation.css'))),
    fontsSha256: sha(readFileSync(join(sourceRoot, 'dist/fonts.css'))),
  },
  conventions: {
    units: 'Lengths in logical px (1rem = 16px); unitless numbers stay unitless; times in ms.',
    tokens: 'var(--x) of a foundation.css custom property is kept symbolic as {t:"var", token: lowerCamel(x)}.',
    atoms: 'Layer conditions are atoms; see tool/recipes/lib/selector.mjs. "not:" prefix negates.',
    cascade: 'Decls apply ordered by (!important, specificity, Tailwind utility order, layer order).',
    sides: 'Logical properties are mapped to physical sides for LTR.',
  },
  foundationTokens: [...foundation].sort().map((n) => ({ css: n, token: camel(n) })),
  registered: Object.fromEntries(registered),
  utilities,
  classLists,
  recipes,
  resolved,
};

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'tailwind.css'), css);
writeFileSync(join(outDir, 'recipes.json'), JSON.stringify(model) + '\n');
writeFileSync(join(outDir, 'coverage.json'), JSON.stringify(coverage, null, 2) + '\n');
writeDocs(docsPath, model, coverage);

console.log(
  `resolve: ${recipes.length} recipes, ${recipes.reduce((n, r) => n + r.combos.length, 0)} combos, ` +
    `${utilities.length} classes, ${classLists.length} unique class lists; coverage ${JSON.stringify(coverage.counts)}`,
);
