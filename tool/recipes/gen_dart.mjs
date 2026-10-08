#!/usr/bin/env node
// Generate Dart recipe classes from build/recipes/recipes.json.
//
// Outputs (packages/raft_ui):
//   lib/src/recipes/recipe_utilities.g.dart   global utility table + engine
//   lib/src/recipes/<recipe>.g.dart           one immutable recipe class per tv() recipe
//   lib/src/recipes/recipes.g.dart            barrel + name -> resolver registry
//   test/recipes/recipe_parity_cases.g.json   JS-resolved expectations for the Dart parity test
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cascade } from './lib/cascade.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
};
const buildDir = resolve(repo, arg('build', 'build/recipes'));
const model = JSON.parse(readFileSync(join(buildDir, 'recipes.json'), 'utf8'));
const pkg = resolve(repo, arg('package', 'packages/raft_ui'));
const outDir = join(pkg, 'lib/src/recipes');
const testDir = join(pkg, 'test/recipes');

const HEADER = (what) =>
  [
    '// GENERATED — do not edit. Regenerate with `tool/recipes/run`.',
    `// Source: raft-ui ${model.source.version} dist/index.mjs (sha256 ${model.source.sha256.slice(0, 16)}),`,
    `// tailwindcss ${model.source.tailwindcss} with raft-ui styles.css${model.source.webThemeSha256 ? ' + Web @theme overrides' : ''}. ${what}`,
    '// ignore_for_file: type=lint',
    '',
  ].join('\n');

// ------------------------------------------------------------- helpers
const RESERVED = new Set(
  'abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get hide if implements import in interface is late library mixin new null of on operator part required rethrow return sealed set show static super switch sync this throw true try type typedef var void when while with yield values index name'.split(' '),
);
const ident = (s) => {
  let x = String(s).replace(/[^A-Za-z0-9]+(.)?/g, (_, c) => (c ? c.toUpperCase() : ''));
  x = x.charAt(0).toLowerCase() + x.slice(1);
  if (/^[0-9]/.test(x)) x = `v${x}`;
  if (!x) x = 'empty';
  if (RESERVED.has(x)) x = `${x}_`;
  return x;
};
const pascal = (s) => {
  const x = ident(s).replace(/_$/, '');
  return x.charAt(0).toUpperCase() + x.slice(1);
};
const str = (s) => `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n')}'`;
const num = (v) => {
  if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
  return String(v);
};
const snake = (s) => s.replace(/\$/g, '_').replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

// Value pool: identical ASTs share one top-level const.
const pool = new Map();
const poolDecls = [];
function dv(n) {
  switch (n.t) {
    case 'num': return n.u ? `CssNum(${num(n.v)}, ${str(n.u)})` : `CssNum(${num(n.v)})`;
    case 'kw': return `CssKeyword(${str(n.v)})`;
    case 'str': return `CssString(${str(n.v)})`;
    case 'color': return `CssColor(0x${n.argb.toString(16).padStart(8, '0').toUpperCase()}${n.src && !/^#/.test(n.src) && n.src.length < 60 ? `, ${str(n.src)}` : ''})`;
    case 'var': {
      const args = [str(n.name)];
      if (n.fb || n.token) args.push(n.fb ? ref(n.fb) : 'null');
      if (n.token) args.push(str(n.token));
      return `CssVar(${args.join(', ')})`;
    }
    case 'fn': return `CssFunction(${str(n.name)}, [${n.args.map(ref).join(', ')}])`;
    case 'calc': return `CssCalc(${ref(n.e)})`;
    case 'op': return `CssOp(${str(n.op)}, ${ref(n.a)}, ${ref(n.b)})`;
    case 'seq': return `CssSeq([${n.items.map(ref).join(', ')}])`;
    case 'list': return `CssList([${n.items.map(ref).join(', ')}])`;
    case 'slash': return 'CssSlash()';
    case 'unset': return 'CssUnset()';
    default: throw new Error(`unknown node ${JSON.stringify(n)}`);
  }
}
function ref(n) {
  const code = dv(n);
  if (code.length < 24) return code;
  if (!pool.has(code)) {
    const name = `_v${pool.size}`;
    pool.set(code, name);
    poolDecls.push(`const ${name} = ${code};`);
  }
  return pool.get(code);
}

const written = new Set();
function write(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
  written.add(path);
}

// ---------------------------------------------------------- utilities
const STATUS = { resolved: 'resolved', descendant: 'descendant', marker: 'marker', 'no-css': 'noCss' };
const specInt = (s) => s[0] * 1000000 + s[1] * 1000 + s[2];
{
  const rows = model.utilities.map((u) => {
    const layers = u.layers.map((l) => {
      const decls = l.decls.map((d) => `RaftDecl(${str(d.prop)}, ${ref(d.value)}${d.important ? ', true' : ''})`);
      return `RaftLayer(${str(l.target)}, [${l.atoms.map(str).join(', ')}], ${specInt(l.spec)}, [${decls.join(', ')}])`;
    });
    return `  RaftUtility(${str(u.name)}, ${u.order}, RaftUtilityStatus.${STATUS[u.status]}, [${layers.join(', ')}]),`;
  });
  const registered = Object.entries(model.registered).map(([k, v]) => `  ${str(k)}: ${v ? ref(v) : 'null'},`);
  const body = [
    HEADER('Tailwind utility table.'),
    "import 'recipe_runtime.dart';",
    '',
    '/// Every class used by a raft-ui recipe, compiled by Tailwind v4 into',
    '/// cascade layers (index = class id used by the recipe tables).',
    'const List<RaftUtility> raftRecipeUtilities = <RaftUtility>[',
    ...rows,
    '];',
    '',
    '/// `@property` registered custom properties (initial values).',
    'const Map<String, CssValue?> raftRecipeRegistered = <String, CssValue?>{',
    ...registered,
    '};',
    '',
    'const RaftRecipeEngine raftRecipeEngine = RaftRecipeEngine(raftRecipeUtilities, raftRecipeRegistered);',
    '',
    ...poolDecls,
    '',
  ].join('\n');
  write(join(outDir, 'recipe_utilities.g.dart'), body);
}

// ------------------------------------------------------------- recipes
const isTheme = (a) => a.key === 'theme' && a.values.join(',') === 'brutal,elegant' && !a.allowsUnset;
const isBool = (a) => a.values.length === 2 && a.values.includes('true') && a.values.includes('false');
const barrel = [];
const registry = [];
for (const r of model.recipes) {
  const C = r.dartClass;
  const file = `${snake(r.name)}.g.dart`;
  const L = [HEADER(`Recipe \`${r.name}\`.`), "import 'recipe_runtime.dart';", "import 'recipe_utilities.g.dart';", ''];
  const params = [];
  const values = [];
  for (const a of r.axes) {
    const p = ident(a.key);
    if (isTheme(a)) {
      params.push(`required RaftRecipeTheme ${p}`);
      values.push(`${p}.name`);
    } else if (isBool(a)) {
      params.push(`bool? ${p}`);
      values.push(`${p}?.toString()`);
    } else {
      const E = `${C}${pascal(a.key)}`;
      L.push(`/// \`${a.key}\` axis of \`${r.name}\`${a.default ? ` (default \`${a.default}\`)` : ''}.`);
      L.push(`enum ${E} {`);
      L.push(a.values.map((v) => `  ${ident(v)}(${str(v)})`).join(',\n') + ';');
      L.push('');
      L.push(`  const ${E}(this.css);`);
      L.push('');
      L.push('  /// Variant value as written in the raft-ui source.');
      L.push('  final String css;');
      L.push('}');
      L.push('');
      params.push(`${E}? ${p}`);
      values.push(`${p}?.css`);
    }
  }
  const slotIds = r.slots.map((s) => ident(s));
  L.push(`/// Resolved slots of [${C}].`);
  L.push(`class ${C}Style {`);
  L.push(`  const ${C}Style({${slotIds.map((s) => `required this.${s}`).join(', ')}});`);
  L.push('');
  for (const [i, s] of slotIds.entries()) L.push(`  /// Slot \`${r.slots[i]}\`.\n  final RaftSlotStyle ${s};`);
  L.push('');
  L.push(`  Map<String, RaftSlotStyle> get slots => {${r.slots.map((s, i) => `${str(s)}: ${slotIds[i]}`).join(', ')}};`);
  L.push('}');
  L.push('');
  const comps = r.exportedComponents.length ? `\n///\n/// Used by: ${r.exportedComponents.join(', ')}.` : '';
  L.push(`/// raft-ui recipe \`${r.name}\` (\`${r.region}\`, index.mjs:${r.line}).${comps}`);
  L.push('///');
  L.push('/// Class lists are the exact tailwind-variants + tailwind-merge output for');
  L.push('/// every variant combination; [resolve] applies the CSS cascade for [states].');
  L.push(`abstract final class ${C} {`);
  L.push(`  static const String recipeName = ${str(r.name)};`);
  L.push(`  static const List<String> slotNames = [${r.slots.map(str).join(', ')}];`);
  L.push(`  static const List<RaftRecipeAxis> axes = [`);
  for (const a of r.axes) {
    L.push(`    RaftRecipeAxis(${str(a.key)}, [${a.values.map(str).join(', ')}], ${a.default != null ? str(a.default) : 'null'}, ${a.allowsUnset}),`);
  }
  L.push('  ];');
  L.push('');
  const paramList = [...params, 'RaftRecipeStates states = RaftRecipeStates.none', 'RaftTokenResolver? tokens'];
  L.push(`  static ${C}Style resolve({${paramList.join(', ')}}) {`);
  L.push(`    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [${values.join(', ')}], states, tokens);`);
  L.push(`    return ${C}Style(${slotIds.map((s, i) => `${s}: s[${i}]`).join(', ')});`);
  L.push('  }');
  L.push('');
  L.push('  /// Resolve by raw tailwind-variants props (`{\'size\': \'md\'}`); for tooling and tests.');
  L.push('  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {');
  L.push(`    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);`);
  L.push('    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};');
  L.push('  }');
  L.push('');
  // local class-list pool
  const local = new Map();
  const lists = [];
  const combos = r.combos.map((c) =>
    r.slots.map((s) => {
      const g = c.slots[s];
      if (!local.has(g)) {
        local.set(g, lists.length);
        lists.push(model.classLists[g]);
      }
      return local.get(g);
    }),
  );
  L.push('  /// Distinct class lists (indices into [raftRecipeUtilities]).');
  L.push('  static const List<List<int>> _lists = [');
  for (const l of lists) L.push(`    [${l.join(', ')}],`);
  L.push('  ];');
  L.push('');
  L.push('  /// Per combination (mixed radix over [axes]): class list per slot.');
  L.push('  static const List<List<int>> _combos = [');
  for (let i = 0; i < combos.length; i += 16) L.push(`    ${combos.slice(i, i + 16).map((c) => `[${c.join(', ')}]`).join(', ')},`);
  L.push('  ];');
  L.push('}');
  L.push('');
  write(join(outDir, file), L.join('\n'));
  barrel.push(`export '${file}';`);
  registry.push(`  ${str(r.name)}: ${C}.resolveProps,`);
}

write(
  join(outDir, 'recipes.g.dart'),
  [
    HEADER('Barrel and registry.'),
    "import 'recipe_runtime.dart';",
    ...model.recipes.map((r) => `import '${snake(r.name)}.g.dart';`),
    '',
    "export 'recipe_utilities.g.dart';",
    ...barrel,
    '',
    'typedef RaftRecipeResolver = Map<String, RaftSlotStyle> Function(Map<String, String?> props, {RaftRecipeStates states, RaftTokenResolver? tokens});',
    '',
    '/// tailwind-variants recipe name -> resolver.',
    'const Map<String, RaftRecipeResolver> raftRecipes = {',
    ...registry,
    '};',
    '',
  ].join('\n'),
);

// Remove stale generated files.
for (const f of readdirSync(outDir)) {
  const p = join(outDir, f);
  if (f.endsWith('.g.dart') && !written.has(p)) rmSync(p);
}

// ------------------------------------------------------- parity fixture
// Default combination per theme, base + up to 3 state sets, all targets.
{
  const registered = new Map(Object.entries(model.registered));
  const tokenSet = new Set(model.foundationTokens.map((t) => t.css));
  const engineUtilities = model.utilities.map((u) => ({ order: u.order, layers: u.layers }));
  // Canonical text form, mirrored by raftCssCanonical() in recipe_runtime.dart.
  const fmt = (v) => {
    const x = +v.toFixed(6);
    return Number.isInteger(x) && Math.abs(x) < 1e15 ? String(x) : String(x);
  };
  const canon = (n) => {
    switch (n.t) {
      case 'num': return `${fmt(n.v)}${n.u}`;
      case 'kw': return n.v;
      case 'str': return `"${n.v}"`;
      case 'color': return `#${n.argb.toString(16).padStart(8, '0')}`;
      case 'var': return `${n.token ? 'token' : 'var'}(${n.token ?? n.name}${n.fb ? `|${canon(n.fb)}` : ''})`;
      case 'fn': return `${n.name}(${n.args.map(canon).join(', ')})`;
      case 'calc': return `calc(${canon(n.e)})`;
      case 'op': return `(${canon(n.a)} ${n.op} ${canon(n.b)})`;
      case 'seq': return n.items.map(canon).join(' ');
      case 'list': return n.items.map(canon).join(', ');
      case 'slash': return '/';
      case 'unset': return 'unset';
      default: throw new Error(n.t);
    }
  };
  const cases = [];
  for (const r of model.recipes) {
    const themeAxis = r.axes.find((a) => a.key === 'theme');
    for (const theme of themeAxis ? themeAxis.values : [null]) {
      const want = Object.fromEntries(r.axes.map((a) => [a.key, a.key === 'theme' ? theme : a.default ?? (a.allowsUnset ? null : a.values[0])]));
      const combo = r.combos.find((c) => r.axes.every((a) => (c.props[a.key] ?? null) === want[a.key]));
      for (const slot of r.slots) {
        const listIdx = combo.slots[slot];
        const list = model.classLists[listIdx];
        const stateKeys = Object.keys(model.resolved[listIdx].self?.states ?? {}).slice(0, 3);
        for (const key of ['', ...stateKeys]) {
          const atoms = key ? key.split('+') : [];
          const st = { flags: new Set() };
          for (const a of atoms) {
            const m = /^(width|height|container-width)(>=|<=|<|>)([\d.]+)$/.exec(a);
            if (!m) { st.flags.add(a); continue; }
            const n = parseFloat(m[3]);
            const v = m[2] === '>=' ? n : m[2] === '>' ? n + 1 : m[2] === '<=' ? n : n - 1;
            st[m[1] === 'width' ? 'width' : m[1] === 'height' ? 'height' : 'containerWidth'] = v;
          }
          const res = cascade(engineUtilities, list, st, { registered, isToken: (n) => tokenSet.has(n) });
          const expected = {};
          // Custom properties are inputs to the projected values; compare the
          // longhands only to keep the fixture small.
          for (const [t, ev] of res) {
            expected[t] = Object.fromEntries([...ev].filter(([p]) => !p.startsWith('--')).map(([p, v]) => [p, canon(v)]));
          }
          cases.push({
            recipe: r.name,
            props: want,
            slot,
            flags: [...st.flags],
            width: st.width ?? null,
            height: st.height ?? null,
            containerWidth: st.containerWidth ?? null,
            expected,
          });
        }
      }
    }
  }
  // Full set under build/ (used by `tool/recipes/run`); a committed sample
  // (first slot of every recipe) keeps the Dart parity test self-contained.
  const fixture = (list) => JSON.stringify({ generated: 'GENERATED by tool/recipes/gen_dart.mjs — do not edit', count: list.length, cases: list }) + '\n';
  writeFileSync(join(buildDir, 'parity_cases.json'), fixture(cases));
  const firstSlot = new Map(model.recipes.map((r) => [r.name, r.slots[0]]));
  mkdirSync(testDir, { recursive: true });
  write(join(testDir, 'recipe_parity_cases.g.json'), fixture(cases.filter((c) => c.slot === firstSlot.get(c.recipe))));
}

console.log(`gen_dart: ${model.recipes.length} recipe classes, ${model.utilities.length} utilities, ${pool.size} pooled values`);
