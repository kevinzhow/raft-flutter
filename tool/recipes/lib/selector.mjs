// Selector utilities: flattening of Tailwind's nested output, specificity and
// translation of selectors into condition atoms.
//
// Condition atoms (strings) are the vocabulary shared with the Dart runtime:
//   'hover' 'active' 'focus-visible' 'disabled' ...      pseudo-classes on the element
//   'aria-disabled=true' 'data-loading=true' 'data-open'  attribute selectors on the element
//   'dark'                                                raft-ui `dark` custom variant
//   'not:disabled'                                        negated atom
//   'has:data-icon=inline-start' 'has:>data-slot=x'       :has() relative selector
//   'group:hover' 'group/name:data-open'                  ancestor group state
//   'peer:checked'                                        preceding sibling peer state
//   'width>=768' 'width<768' 'height<=600'               viewport media queries (px)
//   'motion-reduce' 'motion-safe' 'starting-style' ...    other environment conditions

const DELIMS = new Set(['.', '#', ':', '[', ' ', '\t', '\n', '>', '+', '~', ',', '(', ')', '*', '&']);

// Split on a top-level character, respecting (), [], strings and escapes.
export function splitTopLevel(str, ch = ',') {
  const out = [];
  let depth = 0;
  let cur = '';
  let quote = null;
  for (let i = 0; i < str.length; i++) {
    const c = str[i];
    if (c === '\\') { cur += c + (str[i + 1] ?? ''); i++; continue; }
    if (quote) { cur += c; if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'") { quote = c; cur += c; continue; }
    if (c === '(' || c === '[') depth++;
    if (c === ')' || c === ']') depth--;
    if (c === ch && depth === 0) { out.push(cur.trim()); cur = ''; continue; }
    cur += c;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

// Replace unescaped '&' with the parent selector.
function replaceNesting(sel, parent) {
  let out = '';
  let quote = null;
  let found = false;
  for (let i = 0; i < sel.length; i++) {
    const c = sel[i];
    if (c === '\\') { out += c + (sel[i + 1] ?? ''); i++; continue; }
    if (quote) { out += c; if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'") { quote = c; out += c; continue; }
    if (c === '&') { out += parent; found = true; continue; }
    out += c;
  }
  return { out, found };
}

// Flatten one nesting level: parents are already-flat selectors.
export function flatten(parents, fragment) {
  const result = [];
  for (const alt of splitTopLevel(fragment)) {
    for (const p of parents) {
      const { out, found } = replaceNesting(alt, p);
      result.push(found ? out : `${p} ${alt}`);
    }
  }
  return result;
}

// ------------------------------------------------------------------ parsing

function readBalanced(s, i) {
  // s[i] === '(' ; returns [content, nextIndex]
  let depth = 0;
  let quote = null;
  let j = i;
  for (; j < s.length; j++) {
    const c = s[j];
    if (c === '\\') { j++; continue; }
    if (quote) { if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'") { quote = c; continue; }
    if (c === '(') depth++;
    if (c === ')') { depth--; if (depth === 0) break; }
  }
  return [s.slice(i + 1, j), j + 1];
}

function readName(s, i) {
  let j = i;
  while (j < s.length) {
    if (s[j] === '\\') { j += 2; continue; }
    if (DELIMS.has(s[j]) || s[j] === ']' || s[j] === '[') break;
    j++;
  }
  return [s.slice(i, j), j];
}

// Parse a complex selector into [{comb, simples:[{kind, name, args, text}]}].
export function parseComplex(sel) {
  const compounds = [{ comb: null, simples: [] }];
  let i = 0;
  const s = sel.trim();
  let pendingComb = null;
  const cur = () => compounds[compounds.length - 1];
  const push = (simple) => {
    if (pendingComb !== null) {
      compounds.push({ comb: pendingComb, simples: [] });
      pendingComb = null;
    }
    cur().simples.push(simple);
  };
  while (i < s.length) {
    const c = s[i];
    if (/\s/.test(c) || c === '>' || c === '+' || c === '~') {
      let comb = ' ';
      while (i < s.length && /[\s>+~]/.test(s[i])) {
        if (s[i] !== ' ' && !/\s/.test(s[i])) comb = s[i];
        i++;
      }
      if (cur().simples.length || compounds.length > 1) pendingComb = comb;
      else if (comb !== ' ') pendingComb = comb; // relative selector like '> x'
      continue;
    }
    if (c === '.') {
      const [name, j] = readName(s, i + 1);
      push({ kind: 'class', name, text: s.slice(i, j) });
      i = j;
    } else if (c === '#') {
      const [name, j] = readName(s, i + 1);
      push({ kind: 'id', name, text: s.slice(i, j) });
      i = j;
    } else if (c === '[') {
      let j = i + 1;
      let quote = null;
      for (; j < s.length; j++) {
        if (s[j] === '\\') { j++; continue; }
        if (quote) { if (s[j] === quote) quote = null; continue; }
        if (s[j] === '"' || s[j] === "'") { quote = s[j]; continue; }
        if (s[j] === ']') break;
      }
      push({ kind: 'attr', name: s.slice(i + 1, j), text: s.slice(i, j + 1) });
      i = j + 1;
    } else if (c === ':') {
      const el = s[i + 1] === ':';
      const start = i;
      const [name, j0] = readName(s, i + (el ? 2 : 1));
      let j = j0;
      let args = null;
      if (s[j] === '(') {
        const [inner, k] = readBalanced(s, j);
        args = inner;
        j = k;
      }
      push({ kind: el ? 'pseudo-element' : 'pseudo-class', name: name.toLowerCase(), args, text: s.slice(start, j) });
      i = j;
    } else if (c === '*') {
      push({ kind: 'universal', text: '*' });
      i++;
    } else if (c === '&') {
      push({ kind: 'nesting', text: '&' });
      i++;
    } else {
      const [name, j] = readName(s, i);
      if (j === i) { i++; continue; }
      push({ kind: 'type', name, text: name });
      i = j;
    }
  }
  if (pendingComb !== null) compounds.push({ comb: pendingComb, simples: [] });
  return compounds;
}

export function serializeComplex(compounds) {
  return compounds
    .map((c, idx) => {
      const body = c.simples.map((x) => x.text).join('');
      if (idx === 0) return c.comb && c.comb !== ' ' ? `${c.comb} ${body}` : body;
      return c.comb === ' ' ? ` ${body}` : ` ${c.comb} ${body}`;
    })
    .join('');
}

// --------------------------------------------------------------- specificity

export function specificity(sel) {
  let best = [0, 0, 0];
  for (const alt of splitTopLevel(sel)) {
    const s = specOfComplex(parseComplex(alt));
    if (cmpSpec(s, best) > 0) best = s;
  }
  return best;
}

function specOfComplex(compounds) {
  const total = [0, 0, 0];
  for (const c of compounds) for (const x of c.simples) addSpec(total, specOfSimple(x));
  return total;
}

function addSpec(t, s) { t[0] += s[0]; t[1] += s[1]; t[2] += s[2]; }

export function cmpSpec(a, b) {
  return a[0] - b[0] || a[1] - b[1] || a[2] - b[2];
}

function specOfSimple(x) {
  switch (x.kind) {
    case 'id': return [1, 0, 0];
    case 'class':
    case 'attr': return [0, 1, 0];
    case 'type':
    case 'pseudo-element': return [0, 0, 1];
    case 'pseudo-class': {
      if (x.name === 'where') return [0, 0, 0];
      if (['is', 'not', 'has', 'matches'].includes(x.name)) return specificity(x.args ?? '');
      if (x.name.startsWith('nth-') && /\bof\b/.test(x.args ?? '')) {
        const s = specificity(x.args.split(/\bof\b/)[1]);
        return [s[0], s[1] + 1, s[2]];
      }
      return [0, 1, 0];
    }
    default: return [0, 0, 0];
  }
}

// ------------------------------------------------------------------- atoms

export const unescapeIdent = (s) =>
  s.replace(/\\([0-9a-f]{1,6}\s?|.)/gi, (_, e) => (/^[0-9a-f]{1,6}\s?$/i.test(e) && e.length > 1 ? String.fromCodePoint(parseInt(e, 16)) : e));

function attrAtom(raw) {
  const m = /^\s*([\w-]+)\s*(?:([~|^$*]?=)\s*(?:"([^"]*)"|'([^']*)'|([^\s\]]*))\s*(i|s)?)?\s*$/.exec(raw);
  if (!m) return `[${raw}]`;
  const [, name, op, d, s, u] = m;
  if (!op) return name;
  const value = d ?? s ?? u;
  return op === '=' ? `${name}=${value}` : `${name}${op}${value}`;
}

const isDarkWhere = (args) => /data-theme="elegant"/.test(args) && /\.(dark|light)\b/.test(args);

// Atoms for a list of simples (excluding the element's own class / '*').
function atomsOf(simples, ctx) {
  const atoms = [];
  for (const x of simples) {
    const a = atomOf(x, ctx);
    if (a !== null) atoms.push(a);
  }
  return atoms;
}

function relativeText(arg, ctx) {
  // normalise ':has(*[data-icon="inline-start"])' -> 'data-icon=inline-start'
  const compounds = parseComplex(arg);
  return compounds
    .map((c, idx) => {
      const simples = c.simples.filter((x) => x.kind !== 'universal' || c.simples.length === 1);
      const body = simples.map((x) => (x.kind === 'universal' ? '*' : x.kind === 'type' ? x.name : atomOf(x, ctx) ?? x.text)).join('+');
      const comb = c.comb && c.comb !== ' ' ? c.comb : idx > 0 ? ' ' : '';
      return `${comb}${body}`;
    })
    .join('');
}

function atomOf(x, ctx) {
  switch (x.kind) {
    case 'universal':
    case 'nesting':
      return null;
    case 'class':
      return `class:${unescapeIdent(x.name)}`;
    case 'id':
      return `id:${x.name}`;
    case 'type':
      return x.name;
    case 'attr':
      return attrAtom(x.name);
    case 'pseudo-element':
      return null; // handled as target
    case 'pseudo-class': {
      if (x.args == null) return x.name;
      if ((x.name === 'where' || x.name === 'is') && isDarkWhere(x.args)) return 'dark';
      if (x.name === 'where' || x.name === 'is') {
        const alts = splitTopLevel(x.args);
        if (alts.length === 1) {
          const compounds = parseComplex(alts[0]);
          // group / peer patterns: :where(.group\/name)<state> *   |   ~ *
          const first = compounds[0];
          const marker = first.simples.find((s) => s.kind === 'pseudo-class' && s.name === 'where' && /^\.(group|peer)\b/.test(s.args ?? ''));
          const last = compounds[compounds.length - 1];
          if (marker && compounds.length === 2 && last.simples.length === 1 && last.simples[0].kind === 'universal') {
            const name = unescapeIdent(marker.args.slice(1));
            const rest = atomsOf(first.simples.filter((s) => s !== marker), ctx);
            return `${name}:${rest.join('+')}`;
          }
          if (compounds.length === 2 && last.simples.length === 1 && last.simples[0].kind === 'universal' && last.comb === ' ') {
            // in-* variant: ancestor matching
            return `in:${atomsOf(first.simples, ctx).join('+')}`;
          }
          if (compounds.length === 1) {
            const a = atomsOf(first.simples, ctx);
            if (a.length) return a.join('+');
          }
        }
        ctx.unknown.push(x.text);
        return `${x.name}(${x.args})`;
      }
      if (x.name === 'not') {
        const inner = parseComplex(x.args);
        const simples = inner.length === 1 ? inner[0].simples.filter((y) => y.kind !== 'universal') : [];
        if (simples.length === 1) {
          const a = atomOf(simples[0], ctx);
          if (a) return `not:${a}`;
        }
        return `not:(${x.args})`;
      }
      if (x.name === 'has') return `has:${relativeText(x.args, ctx)}`;
      return `${x.name}(${x.args})`;
    }
    default:
      return x.text;
  }
}

// Media / supports / other at-rule preludes -> atoms (null = always true).
export function atRuleAtoms(name, params, ctx) {
  name = name.toLowerCase();
  const p = params.trim();
  if (name === 'supports') return []; // modern engine assumed (color-mix etc.)
  if (name === 'starting-style') return ['starting-style'];
  if (name === 'container') {
    const m = /^\(?\s*width\s*(>=|<=|<|>)\s*([\d.]+)(rem|px)\s*\)?$/.exec(p);
    if (m) return [`container-width${m[1]}${+(parseFloat(m[2]) * (m[3] === 'px' ? 1 : 16)).toFixed(3)}`];
    return [`container:${p}`];
  }
  if (name !== 'media') { ctx.unknown.push(`@${name} ${p}`); return [`@${name} ${p}`]; }
  const atoms = [];
  for (const part of p.split(/\s+and\s+/)) {
    const q = part.replace(/^\(|\)$/g, '').trim().replace(/\s*:\s*/, ': ');
    let m;
    if (q === 'hover: hover') continue; // pointer device with hover: assumed
    if (q === 'prefers-color-scheme: dark') { atoms.push('dark'); continue; }
    if (q === 'hover: none') { atoms.push('hover-none'); continue; } // touch-only device
    if (/^forced-colors:\s*active$/.test(q)) { atoms.push('forced-colors'); continue; }
    if (q === 'prefers-reduced-motion: reduce') { atoms.push('motion-reduce'); continue; }
    if (q === 'prefers-reduced-motion: no-preference') { atoms.push('motion-safe'); continue; }
    if ((m = /^(width|height)\s*(>=|<=|<|>)\s*([\d.]+)(rem|px|em)$/.exec(q))) {
      const v = parseFloat(m[3]) * (m[4] === 'px' ? 1 : 16);
      atoms.push(`${m[1]}${m[2]}${+v.toFixed(3)}`);
      continue;
    }
    if ((m = /^(min|max)-(width|height):\s*([\d.]+)(rem|px|em)$/.exec(q))) {
      const v = parseFloat(m[3]) * (m[4] === 'px' ? 1 : 16);
      atoms.push(`${m[2]}${m[1] === 'min' ? '>=' : '<='}${+v.toFixed(3)}`);
      continue;
    }
    ctx.unknown.push(`@media ${q}`);
    atoms.push(`media:${q}`);
  }
  return atoms;
}

// Analyse a flat selector relative to the utility's own class selector.
// Returns {target, atoms, unknown}.
//   target: 'self' | '::before' | '::after' | '::placeholder' | ... |
//           descendant selector text with '&' standing for the element.
export function analyzeSelector(sel, selfClassText) {
  const ctx = { unknown: [] };
  const compounds = parseComplex(sel);
  const selfIdx = compounds.findIndex((c) => c.simples.some((x) => x.kind === 'class' && x.text === selfClassText));
  if (selfIdx === compounds.length - 1) {
    const c = compounds[selfIdx];
    const pseudo = c.simples.filter((x) => x.kind === 'pseudo-element');
    const others = c.simples.filter((x) => !(x.kind === 'class' && x.text === selfClassText) && x.kind !== 'pseudo-element');
    const atoms = atomsOf(others, ctx);
    for (const anc of compounds.slice(0, selfIdx)) atoms.push(`ancestor:${atomsOf(anc.simples, ctx).join('+') || anc.simples.map((x) => x.text).join('')}`);
    const target = pseudo.length ? pseudo.map((x) => x.text).join('') : 'self';
    return { target, atoms, unknown: ctx.unknown };
  }
  if (selfIdx >= 0) {
    // `.self:hover svg` -> descendant `& svg`, atoms of the self compound.
    const c = compounds[selfIdx];
    const others = c.simples.filter((x) => !(x.kind === 'class' && x.text === selfClassText));
    const atoms = atomsOf(others, ctx);
    const rest = compounds.slice(selfIdx + 1);
    const target = `&${serializeComplex([{ comb: null, simples: [] }, ...rest])}`;
    return { target, atoms, unknown: ctx.unknown };
  }
  // Self class nested inside a functional pseudo: `:is(.self *)[data-icon]`,
  // `:where(.self > :not(:last-child))`.
  const atoms = [];
  const rewritten = compounds.map((c) => ({
    comb: c.comb,
    simples: c.simples.map((x) => {
      if (x.kind !== 'pseudo-class' || !x.args || !x.args.includes(selfClassText)) return x;
      const inner = parseComplex(x.args);
      const innerSelf = inner.findIndex((ic) => ic.simples.some((s) => s.kind === 'class' && s.text === selfClassText));
      if (innerSelf >= 0) {
        const ic = inner[innerSelf];
        const others = ic.simples.filter((s) => !(s.kind === 'class' && s.text === selfClassText));
        atoms.push(...atomsOf(others, ctx));
        inner[innerSelf] = { comb: ic.comb, simples: [{ kind: 'nesting', text: '&' }] };
      }
      const args = serializeComplex(inner);
      return { ...x, args, text: `:${x.name}(${args})` };
    }),
  }));
  return { target: serializeComplex(rewritten), atoms, unknown: ctx.unknown };
}
