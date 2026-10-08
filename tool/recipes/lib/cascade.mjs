// Cascade + var() resolution for a list of utilities under a set of
// condition atoms. Mirrors packages/raft_ui/lib/src/recipes/recipe_runtime.dart.
import { evaluate, serialize } from './css-value.mjs';

// states: {flags: Set<string>, width?: number, height?: number, containerWidth?: number}
export function atomMatches(atom, states) {
  if (atom.startsWith('not:')) return !atomMatches(atom.slice(4), states);
  const m = /^(width|height|container-width)(>=|<=|<|>)([\d.]+)$/.exec(atom);
  if (m) {
    const v = m[1] === 'width' ? states.width : m[1] === 'height' ? states.height : states.containerWidth;
    if (v == null) return false;
    const n = parseFloat(m[3]);
    return m[2] === '>=' ? v >= n : m[2] === '<=' ? v <= n : m[2] === '<' ? v < n : v > n;
  }
  return states.flags.has(atom);
}

export function layerKey(utilOrder, layerIdx, spec) {
  return [spec[0], spec[1], spec[2], utilOrder, layerIdx];
}

function cmpKey(a, b) {
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] - b[i];
  return 0;
}

// utilities: array of {order, layers:[{target, atoms, spec, decls:[{prop, value, important}]}]}
// registered: Map(name -> initial AST | null) for @property custom properties (non-inheriting)
export function cascade(utilities, classIdxs, states, { registered, isToken }) {
  const byTarget = new Map();
  for (const ci of classIdxs) {
    const u = utilities[ci];
    if (!u) continue;
    u.layers.forEach((layer, li) => {
      if (!layer.atoms.every((a) => atomMatches(a, states))) return;
      if (!byTarget.has(layer.target)) byTarget.set(layer.target, []);
      byTarget.get(layer.target).push({ key: layerKey(u.order, li, layer.spec), layer });
    });
  }
  const declared = new Map();
  for (const [target, entries] of byTarget) {
    entries.sort((a, b) => cmpKey(a.key, b.key));
    const props = new Map();
    for (const important of [false, true]) {
      for (const { layer } of entries) for (const d of layer.decls) if (!!d.important === important) props.set(d.prop, d.value);
    }
    declared.set(target, props);
  }
  if (!declared.has('self')) declared.set('self', new Map());
  const self = declared.get('self');
  const out = new Map();
  for (const [target, props] of declared) {
    const lookupVar = (name) => {
      if (props.has(name)) return props.get(name);
      // Unregistered custom properties inherit from the element into
      // pseudo-elements and descendants.
      if (target !== 'self' && !registered.has(name) && self.has(name)) return self.get(name);
      return undefined;
    };
    const ctx = { lookupVar, isToken, registered };
    const evaluated = new Map();
    for (const [prop, value] of props) evaluated.set(prop, evaluate(value, ctx));
    out.set(target, evaluated);
  }
  return out;
}

// ---------------------------------------------------------------- summary

const round = (x) => Math.round(x * 10000) / 10000;

export function valueJson(v) {
  if (v == null) return null;
  switch (v.t) {
    case 'num': return v.u === 'px' || v.u === '' ? round(v.v) : `${round(v.v)}${v.u}`;
    case 'kw': return v.v;
    case 'str': return JSON.stringify(v.v);
    case 'color': return { color: `#${v.argb.toString(16).padStart(8, '0').toUpperCase()}`, src: v.src };
    case 'var':
      if (v.token) return v.fb ? { token: v.token, fallback: valueJson(v.fb) } : { token: v.token };
      return { var: v.name, fallback: valueJson(v.fb) };
    case 'unset': return null;
    default: return serialize(v);
  }
}

const itemsOf = (v) => (v?.t === 'seq' ? v.items : v ? [v] : []);
const isZeroTransparent = (layer) => {
  const it = itemsOf(layer);
  return it.every((x) => (x.t === 'num' && x.v === 0) || (x.t === 'color' && (x.argb >>> 24) === 0));
};

export function shadowLayers(v) {
  if (!v || v.t === 'unset' || (v.t === 'kw' && v.v === 'none')) return [];
  const layers = v.t === 'list' ? v.items : [v];
  const out = [];
  for (const layer of layers) {
    if (isZeroTransparent(layer)) continue;
    if (layer.t === 'var' && layer.token) { out.push({ token: layer.token }); continue; }
    if (layer.t === 'kw' && layer.v === 'none') continue;
    const it = itemsOf(layer).filter((x) => !(x.t === 'seq' && x.items.length === 0));
    const inset = it.some((x) => x.t === 'kw' && x.v === 'inset');
    const lens = it.filter((x) => x.t === 'num' || x.t === 'calc');
    const color = it.find((x) => !(x.t === 'num' || x.t === 'calc' || (x.t === 'kw' && x.v === 'inset')));
    const [x = 0, y = 0, blur = 0, spread = 0] = lens.map((n) => (n.t === 'num' ? round(n.v) : serialize(n)));
    out.push({ ...(inset ? { inset: true } : {}), x, y, blur, spread, color: valueJson(color ?? { t: 'kw', v: 'currentcolor' }) });
  }
  return out;
}

function sides(get, names) {
  const vals = names.map(get);
  if (vals.every((x) => x === undefined)) return undefined;
  const j = vals.map((x) => JSON.stringify(x ?? null));
  if (j.every((x) => x === j[0])) return vals[0];
  return Object.fromEntries(names.map((n, i) => [n, vals[i]]).filter(([, x]) => x !== undefined));
}

// Semantic summary of evaluated longhands (one target).
export function summarize(evaluated) {
  const used = new Set();
  const g = (p) => {
    if (!evaluated.has(p)) return undefined;
    used.add(p);
    return valueJson(evaluated.get(p));
  };
  const s = {};
  const put = (k, v) => { if (v !== undefined && !(v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === 0)) s[k] = v; };
  for (const p of ['display', 'position', 'width', 'height', 'min-width', 'min-height', 'max-width', 'max-height']) put(p, g(p));
  put('padding', sides((x) => g(`padding-${x}`), ['top', 'right', 'bottom', 'left']));
  put('margin', sides((x) => g(`margin-${x}`), ['top', 'right', 'bottom', 'left']));
  put('inset', sides((x) => g(x), ['top', 'right', 'bottom', 'left']));
  put('gap', sides((x) => g(`${x}-gap`), ['row', 'column']));
  put('font-family', g('font-family'));
  put('font-size', g('font-size'));
  put('font-weight', g('font-weight'));
  put('line-height', g('line-height'));
  put('letter-spacing', g('letter-spacing'));
  put('color', g('color'));
  put('background-color', g('background-color'));
  put('background-image', g('background-image'));
  put('border-width', sides((x) => g(`border-${x}-width`), ['top', 'right', 'bottom', 'left']));
  put('border-style', sides((x) => g(`border-${x}-style`), ['top', 'right', 'bottom', 'left']));
  put('border-color', sides((x) => g(`border-${x}-color`), ['top', 'right', 'bottom', 'left']));
  put('border-radius', sides((x) => g(`border-${x}-radius`), ['top-left', 'top-right', 'bottom-right', 'bottom-left']));
  put('opacity', g('opacity'));
  if (evaluated.has('box-shadow')) {
    used.add('box-shadow');
    put('box-shadow', shadowLayers(evaluated.get('box-shadow')));
  }
  const ring = evaluated.get('--tw-ring-shadow');
  if (ring && !isZeroTransparent(ring) && ring.t !== 'unset') {
    const [layer] = shadowLayers(ring);
    if (layer) put('ring', { width: layer.spread, color: layer.color, offsetWidth: g('--tw-ring-offset-width'), offsetColor: g('--tw-ring-offset-color') });
  }
  for (const p of ['outline-width', 'outline-style', 'outline-color', 'outline-offset']) put(p, g(p));
  for (const p of ['scale', 'translate', 'rotate', 'transform', 'transform-origin']) put(p, g(p));
  for (const p of ['transition-property', 'transition-duration', 'transition-timing-function', 'transition-delay']) put(p, g(p));
  for (const p of ['cursor', 'overflow-x', 'overflow-y', 'z-index']) put(p, g(p));
  for (const [p, v] of evaluated) {
    if (used.has(p) || p.startsWith('--')) continue;
    put(p, valueJson(v));
  }
  return s;
}

export function displayValue(v) {
  if (v == null) return '—';
  if (typeof v === 'number') return v >= 1e30 ? 'infinity' : String(v);
  if (typeof v === 'string') return v;
  if (Array.isArray(v)) return v.length ? v.map(displayValue).join(', ') : 'none';
  if ('x' in v && 'blur' in v) return `${v.inset ? 'inset ' : ''}${v.x} ${v.y} ${v.blur} ${v.spread} ${displayValue(v.color)}`;
  if ('token' in v) return v.fallback !== undefined && v.fallback !== null ? `token(${v.token}, ${displayValue(v.fallback)})` : `token(${v.token})`;
  if (typeof v.color === 'string') return v.src && !/^#/.test(v.src) ? `${v.src} [${v.color}]` : v.color;
  if ('var' in v) return `var(${v.var}${v.fallback != null ? `, ${displayValue(v.fallback)}` : ''})`;
  return Object.entries(v).map(([k, x]) => `${k}:${displayValue(x)}`).join(' ');
}
