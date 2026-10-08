// Evaluate extracted recipes with the real tailwind-variants + raft-ui `cn`
// (tailwind-merge with raft-ui's extension) to obtain the exact final class
// list for every slot of every variant combination.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

async function loadCn(sourceRoot) {
  // Rewrite raft-ui's own cn.mjs to import our linked dependencies.
  let code = readFileSync(join(sourceRoot, 'dist/cn.mjs'), 'utf8');
  code = code.replace(/from\s+"([^"]+)"/g, (_, spec) => `from ${JSON.stringify(import.meta.resolve(spec))}`);
  const mod = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
  return mod.cn;
}

export async function buildRecipes(raw, sourceRoot) {
  const cn = await loadCn(sourceRoot);
  const spec = /from\s+"([^"]+)"/.exec(raw.tvImport)[1];
  const { tv } = await import(spec);
  // eslint-disable-next-line no-new-func
  const tvWrapper = new Function('tv', 'cn', `return (${raw.tvWrapperSource});`)(tv, cn);

  const byName = new Map(raw.recipes.map((r) => [r.name, r]));
  const built = new Map();
  const materialise = (v) => {
    if (Array.isArray(v)) return v.map(materialise);
    if (v && typeof v === 'object') {
      if ('$recipe' in v) return build(v.$recipe);
      if ('$nonLiteral' in v) throw new Error(`non-literal value ${v.$nonLiteral}`);
      return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, materialise(x)]));
    }
    return v;
  };
  function build(name) {
    if (built.has(name)) return built.get(name);
    const r = byName.get(name);
    const recipe = tvWrapper(materialise(r.options));
    built.set(name, recipe);
    return recipe;
  }
  for (const r of raw.recipes) build(r.name);
  return { built, cn };
}

// Variant axes of a recipe including those inherited through `extend`.
export function variantAxes(raw, name) {
  const byName = new Map(raw.recipes.map((r) => [r.name, r]));
  const axes = new Map();
  const defaults = {};
  const visit = (n) => {
    const r = byName.get(n);
    if (r.options.extend?.$recipe) visit(r.options.extend.$recipe);
    for (const [k, vals] of Object.entries(r.options.variants ?? {})) {
      const list = axes.get(k) ?? [];
      for (const v of Object.keys(vals)) if (!list.includes(v)) list.push(v);
      axes.set(k, list);
    }
    Object.assign(defaults, r.options.defaultVariants ?? {});
  };
  visit(name);
  return {
    axes: [...axes.entries()].map(([key, values]) => {
      const def = defaults[key];
      const hasDefault = def !== undefined && def !== null;
      // A default outside the declared keys (e.g. `single: false` with only a
      // `true` key) is still a reachable state.
      if (hasDefault && !values.includes(String(def))) values.push(String(def));
      // Boolean variants accept both values even when only `true` is declared.
      if (values.includes('true') && !values.includes('false')) values.push('false');
      return {
        key,
        values,
        default: hasDefault ? String(def) : null,
        // `unset` (prop omitted) is a distinct state only when there is no
        // default. Components always pass `theme` (useThemeFamily()), so the
        // theme axis is never unset.
        allowsUnset: !hasDefault && key !== 'theme',
      };
    }),
  };
}

// Slot names including inherited ones; '' for base-only recipes.
export function slotNames(raw, name) {
  const byName = new Map(raw.recipes.map((r) => [r.name, r]));
  const out = [];
  const visit = (n) => {
    const r = byName.get(n);
    if (r.options.extend?.$recipe) visit(r.options.extend.$recipe);
    for (const s of Object.keys(r.options.slots ?? {})) if (!out.includes(s)) out.push(s);
  };
  visit(name);
  return out;
}

const toProp = (v) => (v === 'true' ? true : v === 'false' ? false : v);

// Enumerate every combination (mixed radix over axis options; option index 0
// is `unset` for axes that allow it). Returns [{props, slots:{slot: classes[]}}].
export function enumerate(recipe, axes) {
  const options = axes.map((a) => (a.allowsUnset ? [null, ...a.values] : a.values));
  const total = options.reduce((n, o) => n * o.length, 1);
  const combos = [];
  for (let i = 0; i < total; i++) {
    let rem = i;
    const props = {};
    // last axis varies fastest
    const idx = new Array(axes.length);
    for (let k = axes.length - 1; k >= 0; k--) {
      idx[k] = rem % options[k].length;
      rem = Math.floor(rem / options[k].length);
    }
    axes.forEach((a, k) => {
      const v = options[k][idx[k]];
      if (v !== null) props[a.key] = toProp(v);
    });
    const result = recipe(props);
    const out = {};
    if (typeof result === 'string') out.base = split(result);
    else for (const s of Object.keys(result)) out[s] = split(result[s]?.() ?? '');
    combos.push({ props: Object.fromEntries(axes.map((a, k) => [a.key, options[k][idx[k]]])), slots: out });
  }
  return combos;
}

const split = (s) => (s ?? '').split(/\s+/).filter(Boolean);

// Every class token that appears anywhere in a recipe's options.
export function classesInOptions(options) {
  const out = new Set();
  const addStr = (v) => {
    if (typeof v === 'string') for (const c of split(v)) out.add(c);
    else if (Array.isArray(v)) v.forEach(addStr);
    else if (v && typeof v === 'object' && !('$recipe' in v)) Object.values(v).forEach(addStr);
  };
  addStr(options.base);
  addStr(options.slots);
  for (const axis of Object.values(options.variants ?? {})) addStr(axis);
  for (const cv of options.compoundVariants ?? []) { addStr(cv.class); addStr(cv.className); }
  for (const cs of options.compoundSlots ?? []) { addStr(cs.class); addStr(cs.className); }
  return out;
}
