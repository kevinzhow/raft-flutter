// Minimal CSS value model used by the recipe pipeline.
//
// Values are parsed into a small JSON-serialisable AST that both the JS
// resolver and the generated Dart runtime understand:
//
//   {t:'num', v, u}            number with unit ('' | 'px' | 'em' | '%' | 'ms' | 'deg' | ...)
//                              (rem is normalised to px at 16px/rem, s to ms, turn to deg)
//   {t:'kw', v}                identifier keyword (auto, none, solid, currentcolor, ...)
//   {t:'str', v}               quoted string
//   {t:'color', argb, src}     literal sRGB colour (0xAARRGGBB) + source text
//   {t:'var', name, fb, token} var(--name, fb); token = lowerCamel foundation token name
//   {t:'fn', name, args}       generic function; args are comma-separated values
//   {t:'calc', e}              math expression tree (calc/min/max/clamp wrappers are fn)
//   {t:'op', op, a, b}         math operation inside calc
//   {t:'seq', items}           space separated sequence
//   {t:'list', items}          comma separated list
//   {t:'slash'}                '/' separator inside a sequence
//   {t:'unset'}                guaranteed-invalid value (unresolved var without fallback)

export const REM_PX = 16;
export const CSS_INFINITY = 3.4028234663852886e38;

export const camel = (name) =>
  name.replace(/^--/, '').replace(/-+([a-z0-9])/gi, (_, c) => c.toUpperCase());

// ---------------------------------------------------------------- tokenizer

function tokenize(text) {
  const tokens = [];
  let i = 0;
  const n = text.length;
  const numRe = /^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i;
  const identRe = /^(--[\w-]*|-?[a-zA-Z_ -￿][\w-]*)/;
  while (i < n) {
    const c = text[i];
    if (/\s/.test(c)) {
      while (i < n && /\s/.test(text[i])) i++;
      tokens.push({ type: 'ws' });
      continue;
    }
    if (c === ',') { tokens.push({ type: 'comma' }); i++; continue; }
    if (c === '/') { tokens.push({ type: 'slash' }); i++; continue; }
    if (c === ')') { tokens.push({ type: 'close' }); i++; continue; }
    if (c === '(') { tokens.push({ type: 'open' }); i++; continue; }
    if (c === '"' || c === "'") {
      let j = i + 1;
      let v = '';
      while (j < n && text[j] !== c) {
        if (text[j] === '\\') { v += text[j + 1]; j += 2; continue; }
        v += text[j++];
      }
      tokens.push({ type: 'str', v });
      i = j + 1;
      continue;
    }
    if (c === '#') {
      const m = /^#[0-9a-f]+/i.exec(text.slice(i));
      if (m) { tokens.push({ type: 'hash', v: m[0] }); i += m[0].length; continue; }
    }
    const rest = text.slice(i);
    const prev = tokens[tokens.length - 1];
    // A sign directly after an operand is a math operator, not a number sign.
    const signIsOp = (c === '+' || c === '-') && prev && (prev.type === 'num' || prev.type === 'close');
    const m = !signIsOp && numRe.exec(rest);
    if (m) {
      i += m[0].length;
      const um = /^(%|[a-z]+)/i.exec(text.slice(i));
      let u = '';
      if (um) { u = um[0].toLowerCase(); i += um[0].length; }
      tokens.push({ type: 'num', v: parseFloat(m[0]), u });
      continue;
    }
    const im = identRe.exec(rest);
    if (im) {
      i += im[0].length;
      if (text[i] === '(') {
        tokens.push({ type: 'func', v: im[0].toLowerCase() });
        i++;
      } else {
        tokens.push({ type: 'ident', v: im[0] });
      }
      continue;
    }
    tokens.push({ type: 'delim', v: c });
    i++;
  }
  return tokens;
}

// ------------------------------------------------------------------- parser

const MATH_FNS = new Set(['calc', 'min', 'max', 'clamp']);
const COLOR_FNS = new Set(['oklch', 'oklab', 'rgb', 'rgba', 'hsl', 'hsla', 'lab', 'lch', 'color', 'hwb']);
const NAMED_COLORS = {
  transparent: [0, 0, 0, 0],
  black: [0, 0, 0, 1],
  white: [255, 255, 255, 1],
};

function normaliseNum(v, u) {
  switch (u) {
    case 'rem': return { t: 'num', v: v * REM_PX, u: 'px' };
    case 's': return { t: 'num', v: v * 1000, u: 'ms' };
    case 'turn': return { t: 'num', v: v * 360, u: 'deg' };
    default: return { t: 'num', v, u };
  }
}

class Parser {
  constructor(tokens) { this.tokens = tokens; this.i = 0; }
  peek() { return this.tokens[this.i]; }
  next() { return this.tokens[this.i++]; }
  skipWs() { while (this.peek()?.type === 'ws') this.i++; }

  // Parses comma separated values until ')' or end.
  parseList(stopAtClose) {
    const items = [this.parseSeq(stopAtClose)];
    while (this.peek()?.type === 'comma') {
      this.next();
      items.push(this.parseSeq(stopAtClose));
    }
    return items;
  }

  parseSeq(stopAtClose) {
    const items = [];
    for (;;) {
      this.skipWs();
      const tok = this.peek();
      if (!tok || tok.type === 'comma') break;
      if (tok.type === 'close') {
        if (stopAtClose) break;
        this.next();
        continue;
      }
      items.push(this.parseComponent());
    }
    return items.length === 1 ? items[0] : { t: 'seq', items };
  }

  parseComponent() {
    const tok = this.next();
    switch (tok.type) {
      case 'num': return normaliseNum(tok.v, tok.u);
      case 'str': return { t: 'str', v: tok.v };
      case 'slash': return { t: 'slash' };
      case 'hash': return hexColor(tok.v) ?? { t: 'kw', v: tok.v };
      case 'ident': {
        const lower = tok.v.toLowerCase();
        if (lower in NAMED_COLORS) {
          const [r, g, b, a] = NAMED_COLORS[lower];
          return { t: 'color', argb: argbFromRgba(r, g, b, a), src: lower };
        }
        return { t: 'kw', v: tok.v.startsWith('--') ? tok.v : lower === 'currentcolor' ? 'currentcolor' : tok.v };
      }
      case 'func': return this.parseFunction(tok.v);
      case 'open': {
        const inner = this.parseSeq(true);
        if (this.peek()?.type === 'close') this.next();
        return { t: 'fn', name: '', args: [inner] };
      }
      default: return { t: 'kw', v: tok.v ?? tok.type };
    }
  }

  parseFunction(name) {
    if (name === 'var') {
      this.skipWs();
      const id = this.next();
      this.skipWs();
      let fb = null;
      if (this.peek()?.type === 'comma') {
        this.next();
        const items = this.parseList(true);
        fb = items.length === 1 ? items[0] : { t: 'list', items };
      }
      if (this.peek()?.type === 'close') this.next();
      return { t: 'var', name: id.v, fb };
    }
    if (MATH_FNS.has(name)) {
      const args = [];
      for (;;) {
        args.push(this.parseMath());
        this.skipWs();
        const t = this.peek();
        if (t?.type === 'comma') { this.next(); continue; }
        if (t?.type === 'close') this.next();
        break;
      }
      if (name === 'calc') return { t: 'calc', e: args[0] };
      return { t: 'fn', name, args: args.map((e) => ({ t: 'calc', e })) };
    }
    const args = this.parseList(true);
    if (this.peek()?.type === 'close') this.next();
    const fn = { t: 'fn', name, args: args.length === 1 && args[0].t === 'seq' && args[0].items.length === 0 ? [] : args };
    if (COLOR_FNS.has(name)) return literalColorFn(fn) ?? fn;
    return fn;
  }

  // Math expression: sum := product (('+'|'-') product)*
  parseMath() {
    let left = this.parseProduct();
    for (;;) {
      this.skipWs();
      const t = this.peek();
      if (t?.type === 'delim' && (t.v === '+' || t.v === '-')) {
        this.next();
        const right = this.parseProduct();
        left = { t: 'op', op: t.v, a: left, b: right };
        continue;
      }
      // "- 2px" tokenised as num(-2) after whitespace is not produced by Tailwind,
      // but "a -b" may appear; treat a signed number following an operand as subtraction.
      if (t?.type === 'num' && (t.v < 0) && this.tokens[this.i - 1]?.type === 'ws') {
        const tok = this.next();
        left = { t: 'op', op: '-', a: left, b: normaliseNum(-tok.v, tok.u) };
        continue;
      }
      return left;
    }
  }

  parseProduct() {
    let left = this.parseMathAtom();
    for (;;) {
      this.skipWs();
      const t = this.peek();
      if ((t?.type === 'delim' && t.v === '*') || t?.type === 'slash') {
        this.next();
        const right = this.parseMathAtom();
        left = { t: 'op', op: t.type === 'slash' ? '/' : '*', a: left, b: right };
        continue;
      }
      return left;
    }
  }

  parseMathAtom() {
    this.skipWs();
    const t = this.peek();
    if (t?.type === 'open') {
      this.next();
      const e = this.parseMath();
      this.skipWs();
      if (this.peek()?.type === 'close') this.next();
      return e;
    }
    if (t?.type === 'delim' && t.v === '-') {
      // unary minus before a function/var: -var(--x)
      this.next();
      return { t: 'op', op: '*', a: { t: 'num', v: -1, u: '' }, b: this.parseMathAtom() };
    }
    return this.parseComponent();
  }
}

export function parseValue(text) {
  const p = new Parser(tokenize(text.trim()));
  const items = p.parseList(false);
  return items.length === 1 ? items[0] : { t: 'list', items };
}

// -------------------------------------------------------------- colour math

export function argbFromRgba(r, g, b, a) {
  const c = (x) => Math.max(0, Math.min(255, Math.round(x)));
  return ((c(a * 255) << 24) | (c(r) << 16) | (c(g) << 8) | c(b)) >>> 0;
}

function hexColor(hex) {
  let h = hex.slice(1);
  if (h.length === 3 || h.length === 4) h = [...h].map((x) => x + x).join('');
  if (h.length !== 6 && h.length !== 8) return null;
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
  return { t: 'color', argb: argbFromRgba(r, g, b, a), src: hex.toLowerCase() };
}

const srgbToLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const linearToSrgb = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);

export function linearSrgbToOklab([r, g, b]) {
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

export function oklabToLinearSrgb([L, a, b]) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
}

// Colour in a working form: {lab:[L,a,b], alpha, hueMissing}
function colorFromArgb(argb) {
  const a = ((argb >>> 24) & 255) / 255;
  const rgb = [(argb >>> 16) & 255, (argb >>> 8) & 255, argb & 255].map((x) => srgbToLinear(x / 255));
  return { lab: linearSrgbToOklab(rgb), alpha: a };
}

function argbFromLab(lab, alpha) {
  const lin = oklabToLinearSrgb(lab);
  const [r, g, b] = lin.map((x) => Math.max(0, Math.min(1, linearToSrgb(x))) * 255);
  return argbFromRgba(r, g, b, alpha);
}

const numOf = (n, pct = 1) => (n.t === 'num' ? (n.u === '%' ? (n.v / 100) * pct : n.v) : null);

// Converts a colour function with only literal arguments into a colour node.
function literalColorFn(fn) {
  const items = fn.args.length === 1 && fn.args[0].t === 'seq' ? fn.args[0].items : fn.args;
  if (!items.every((x) => x.t === 'num' || x.t === 'slash' || (x.t === 'kw' && x.v === 'none'))) return null;
  const slash = items.findIndex((x) => x.t === 'slash');
  const comps = slash >= 0 ? items.slice(0, slash) : items;
  const alphaNode = slash >= 0 ? items[slash + 1] : fn.name.endsWith('a') && items.length === 4 ? items[3] : null;
  const alpha = alphaNode ? numOf(alphaNode) : 1;
  const src = serialize(fn);
  const v = (x, pct) => (x.t === 'kw' ? 0 : numOf(x, pct));
  if (fn.name === 'oklch') {
    const L = v(comps[0], 1);
    const C = v(comps[1], 0.4);
    const H = ((comps[2].t === 'kw' ? 0 : comps[2].v) * Math.PI) / 180;
    return { t: 'color', argb: argbFromLab([L, C * Math.cos(H), C * Math.sin(H)], alpha), src };
  }
  if (fn.name === 'oklab') {
    return { t: 'color', argb: argbFromLab([v(comps[0], 1), v(comps[1], 0.4), v(comps[2], 0.4)], alpha), src };
  }
  if (fn.name === 'rgb' || fn.name === 'rgba') {
    const [r, g, b] = comps.slice(0, 3).map((x) => v(x, 255));
    return { t: 'color', argb: argbFromRgba(r, g, b, alpha), src };
  }
  return null;
}

// CSS Color 5 color-mix() of two literal colours.
export function mixColors(space, c1, p1, c2, p2) {
  if (p1 == null && p2 == null) { p1 = 0.5; p2 = 0.5; }
  else if (p1 == null) p1 = 1 - p2;
  else if (p2 == null) p2 = 1 - p1;
  const sum = p1 + p2;
  if (sum <= 0) return null;
  const alphaMult = Math.min(sum, 1);
  p1 /= sum; p2 /= sum;
  const a = colorFromArgb(c1);
  const b = colorFromArgb(c2);
  const alpha = a.alpha * p1 + b.alpha * p2;
  if (alpha === 0) return argbFromLab([0, 0, 0], 0);
  let lab;
  if (space === 'oklch') {
    const toLch = (c) => {
      const [L, A, B] = c.lab;
      const C = Math.hypot(A, B);
      // Achromatic colours (incl. transparent) have a missing (powerless) hue.
      return { L, C, H: C < 1e-6 ? null : Math.atan2(B, A), alpha: c.alpha };
    };
    const x = toLch(a);
    const y = toLch(b);
    let h1 = x.H ?? y.H ?? 0;
    let h2 = y.H ?? x.H ?? 0;
    // shorter hue interpolation
    if (h2 - h1 > Math.PI) h1 += 2 * Math.PI;
    else if (h1 - h2 > Math.PI) h2 += 2 * Math.PI;
    const L = (x.L * x.alpha * p1 + y.L * y.alpha * p2) / alpha;
    const C = (x.C * x.alpha * p1 + y.C * y.alpha * p2) / alpha;
    const H = h1 * p1 + h2 * p2; // hue is not premultiplied
    lab = [L, C * Math.cos(H), C * Math.sin(H)];
  } else {
    // oklab (and srgb approximated in oklab is NOT done: only oklab/oklch supported)
    lab = [0, 1, 2].map((i) => (a.lab[i] * a.alpha * p1 + b.lab[i] * b.alpha * p2) / alpha);
  }
  return argbFromLab(lab, alpha * alphaMult);
}

// ------------------------------------------------------------- serializer

export function serialize(n) {
  if (n == null) return '';
  switch (n.t) {
    case 'num': return `${+n.v.toFixed(6)}${n.u}`;
    case 'kw': return n.v;
    case 'str': return JSON.stringify(n.v);
    case 'color': return n.src ?? `#${n.argb.toString(16).padStart(8, '0')}`;
    case 'var': return n.token
      ? `token(${n.token}${n.fb ? `, ${serialize(n.fb)}` : ''})`
      : `var(${n.name}${n.fb ? `, ${serialize(n.fb)}` : ''})`;
    case 'fn': return `${n.name}(${n.args.map(serialize).join(', ')})`;
    case 'calc': return `calc(${serializeMath(n.e)})`;
    case 'op': return serializeMath(n);
    case 'seq': return n.items.map(serialize).join(' ');
    case 'list': return n.items.map(serialize).join(', ');
    case 'slash': return '/';
    case 'unset': return 'unset';
    default: return JSON.stringify(n);
  }
}
function serializeMath(e) {
  if (e.t === 'op') return `(${serializeMath(e.a)} ${e.op} ${serializeMath(e.b)})`;
  return serialize(e);
}

// ------------------------------------------------------------- evaluation

// ctx: {
//   lookupVar(name) -> AST | undefined   (values set on the element / theme)
//   isToken(name) -> bool                (foundation tokens stay symbolic)
//   registered: Map(name -> initial AST | null)  (@property registrations)
//   partial: bool                        (true: leave unknown vars symbolic)
// }
export function evaluate(node, ctx, depth = 0) {
  if (depth > 64) return { t: 'unset' };
  switch (node.t) {
    case 'var': return evalVar(node, ctx, depth);
    case 'calc': {
      const e = evalMath(node.e, ctx, depth);
      return e.t === 'num' ? e : { t: 'calc', e };
    }
    case 'fn': {
      const args = node.args.map((a) => evaluate(a, ctx, depth + 1));
      if (args.some((a) => a.t === 'unset')) return { t: 'unset' };
      if (['min', 'max', 'clamp'].includes(node.name)) {
        const vals = args.map((a) => (a.t === 'num' ? a : null));
        if (vals.every(Boolean) && vals.every((x) => x.u === vals[0].u)) {
          const vs = vals.map((x) => x.v);
          const v = node.name === 'min' ? Math.min(...vs) : node.name === 'max' ? Math.max(...vs) : Math.min(Math.max(vs[0], vs[1]), vs[2]);
          return { t: 'num', v, u: vals[0].u };
        }
      }
      if (node.name === 'color-mix') return evalColorMix({ ...node, args }) ?? { ...node, args };
      if (COLOR_FNS.has(node.name)) return literalColorFn({ ...node, args }) ?? { ...node, args };
      return { ...node, args };
    }
    case 'seq': {
      const items = node.items.map((x) => evaluate(x, ctx, depth + 1));
      if (items.some((a) => a.t === 'unset')) return { t: 'unset' };
      // flatten nested seqs that came from var substitution
      const flat = items.flatMap((x) => (x.t === 'seq' ? x.items : [x]));
      if (flat.length === 1) return flat[0];
      if (flat.some((x) => x.t === 'list')) {
        // var() substituted a comma list into a sequence: re-split on commas.
        return resplit(flat);
      }
      return { t: 'seq', items: flat };
    }
    case 'list': {
      const items = node.items.map((x) => evaluate(x, ctx, depth + 1));
      if (items.some((a) => a.t === 'unset')) return { t: 'unset' };
      return { t: 'list', items: items.flatMap((x) => (x.t === 'list' ? x.items : [x])) };
    }
    default: return node;
  }
}

function resplit(items) {
  const out = [[]];
  for (const x of items) {
    if (x.t === 'list') {
      x.items.forEach((y, i) => {
        if (i > 0) out.push([]);
        out[out.length - 1].push(...(y.t === 'seq' ? y.items : [y]));
      });
    } else out[out.length - 1].push(x);
  }
  return { t: 'list', items: out.map((s) => (s.length === 1 ? s[0] : { t: 'seq', items: s })) };
}

function evalVar(node, ctx, depth) {
  const set = ctx.lookupVar?.(node.name);
  if (set !== undefined) return evaluate(set, ctx, depth + 1);
  const fb = node.fb ? evaluate(node.fb, ctx, depth + 1) : null;
  if (ctx.isToken?.(node.name)) return { t: 'var', name: node.name, token: camel(node.name), fb };
  if (ctx.partial) return { t: 'var', name: node.name, fb, ...(node.token ? { token: node.token } : {}) };
  if (ctx.registered?.has(node.name)) {
    const init = ctx.registered.get(node.name);
    if (init) return evaluate(init, ctx, depth + 1);
  }
  if (fb) return fb;
  return { t: 'unset' };
}

function evalMath(e, ctx, depth) {
  if (e.t === 'op') {
    const a = evalMath(e.a, ctx, depth + 1);
    const b = evalMath(e.b, ctx, depth + 1);
    const r = arith(e.op, a, b);
    return r ?? { t: 'op', op: e.op, a, b };
  }
  if (e.t === 'calc') return evalMath(e.e, ctx, depth + 1);
  // CSS `infinity` in calc() clamps to the largest float (what browsers use
  // for `rounded-full`: calc(infinity * 1px)).
  if (e.t === 'kw' && e.v === 'infinity') return { t: 'num', v: CSS_INFINITY, u: '' };
  const v = evaluate(e, ctx, depth + 1);
  if (v.t === 'calc') return v.e;
  if (v.t === 'seq' && v.items.length === 0) return { t: 'num', v: 0, u: '' };
  return v;
}

function arith(op, a, b) {
  if (a.t !== 'num' || b.t !== 'num') return null;
  switch (op) {
    case '+':
    case '-': {
      // 0 without unit or with any unit is compatible
      let u = a.u;
      if (a.u !== b.u) {
        if (a.v === 0 && a.u !== '%') u = b.u;
        else if (b.v === 0 && b.u !== '%') u = a.u;
        else return null;
      }
      return { t: 'num', v: op === '+' ? a.v + b.v : a.v - b.v, u };
    }
    case '*':
      if (a.u && b.u) return null;
      return { t: 'num', v: a.v * b.v, u: a.u || b.u };
    case '/':
      if (b.u && a.u !== b.u) return null;
      if (b.v === 0) return null;
      return { t: 'num', v: a.v / b.v, u: b.u ? '' : a.u };
    default:
      return null;
  }
}

function evalColorMix(fn) {
  // color-mix(in <space> [<hue-method> hue], <color> [<pct>], <color> [<pct>])
  if (fn.args.length !== 3) return null;
  const spaceSeq = fn.args[0].t === 'seq' ? fn.args[0].items : [fn.args[0]];
  const space = spaceSeq[1]?.v;
  const part = (n) => {
    const items = n.t === 'seq' ? n.items : [n];
    const color = items.find((x) => x.t !== 'num');
    const pct = items.find((x) => x.t === 'num' && x.u === '%');
    return { color, p: pct ? pct.v / 100 : null };
  };
  const a = part(fn.args[1]);
  const b = part(fn.args[2]);
  if (a.color?.t !== 'color' || b.color?.t !== 'color') return null;
  if (space !== 'oklab' && space !== 'oklch') return null;
  const argb = mixColors(space, a.color.argb, a.p, b.color.argb, b.p);
  if (argb == null) return null;
  return { t: 'color', argb, src: serialize(fn) };
}

// True if the AST contains a var() that is not a foundation token.
export function hasFreeVar(n) {
  if (!n || typeof n !== 'object') return false;
  if (n.t === 'var' && !n.token) return true;
  return Object.values(n).some((v) => (Array.isArray(v) ? v.some(hasFreeVar) : typeof v === 'object' && hasFreeVar(v)));
}
