// Expand CSS shorthands and logical properties into physical longhands
// (horizontal-tb, LTR) so cascade works per longhand.
const SIDES = ['top', 'right', 'bottom', 'left'];
const CORNERS = ['top-left', 'top-right', 'bottom-right', 'bottom-left'];
const BORDER_STYLES = new Set(['none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset']);
const LINE_WIDTH_KW = new Set(['thin', 'medium', 'thick']);

const itemsOf = (v) => (v.t === 'seq' ? v.items : [v]);

function box(v) {
  const it = itemsOf(v);
  if (it.length < 1 || it.length > 4) return null;
  const [t, r = t, b = t, l = r] = it;
  return [t, r, b, l];
}
function pair(v) {
  const it = itemsOf(v);
  if (it.length < 1 || it.length > 2) return null;
  return [it[0], it[1] ?? it[0]];
}

const logicalSide = { 'inline-start': 'left', 'inline-end': 'right', 'block-start': 'top', 'block-end': 'bottom' };
const logicalPair = { inline: ['left', 'right'], block: ['top', 'bottom'] };
const logicalCorner = { 'start-start': 'top-left', 'start-end': 'top-right', 'end-start': 'bottom-left', 'end-end': 'bottom-right' };

function borderParts(v) {
  // <width> || <style> || <color>; omitted parts reset to initial values.
  const out = { width: { t: 'kw', v: 'medium' }, style: { t: 'kw', v: 'none' }, color: { t: 'kw', v: 'currentcolor' } };
  for (const x of itemsOf(v)) {
    if (x.t === 'num' || x.t === 'calc' || (x.t === 'kw' && LINE_WIDTH_KW.has(x.v))) out.width = x;
    else if (x.t === 'kw' && BORDER_STYLES.has(x.v)) out.style = x;
    else if (x.t === 'var' && !x.token && /style/.test(x.name)) out.style = x;
    else out.color = x;
  }
  return out;
}

// Returns [[prop, value], ...]
export function expand(prop, v) {
  let m;
  // padding / margin / inset
  for (const base of ['padding', 'margin', 'scroll-padding', 'scroll-margin']) {
    if (prop === base) {
      const b = box(v);
      return b ? SIDES.map((s, i) => [`${base}-${s}`, b[i]]) : [[prop, v]];
    }
    if ((m = new RegExp(`^${base}-(inline|block)$`).exec(prop))) {
      const p = pair(v);
      return p ? logicalPair[m[1]].map((s, i) => [`${base}-${s}`, p[i]]) : [[prop, v]];
    }
    if ((m = new RegExp(`^${base}-(inline|block)-(start|end)$`).exec(prop))) {
      return [[`${base}-${logicalSide[`${m[1]}-${m[2]}`]}`, v]];
    }
  }
  if (prop === 'inset') {
    const b = box(v);
    return b ? SIDES.map((s, i) => [s, b[i]]) : [[prop, v]];
  }
  if ((m = /^inset-(inline|block)$/.exec(prop))) {
    const p = pair(v);
    return p ? logicalPair[m[1]].map((s, i) => [s, p[i]]) : [[prop, v]];
  }
  if ((m = /^inset-(inline|block)-(start|end)$/.exec(prop))) return [[logicalSide[`${m[1]}-${m[2]}`], v]];

  // border
  for (const part of ['width', 'style', 'color']) {
    if (prop === `border-${part}`) {
      const b = box(v);
      return b ? SIDES.map((s, i) => [`border-${s}-${part}`, b[i]]) : [[prop, v]];
    }
    if ((m = new RegExp(`^border-(inline|block)-${part}$`).exec(prop))) {
      const p = pair(v);
      return p ? logicalPair[m[1]].map((s, i) => [`border-${s}-${part}`, p[i]]) : [[prop, v]];
    }
    if ((m = new RegExp(`^border-(inline|block)-(start|end)-${part}$`).exec(prop))) {
      return [[`border-${logicalSide[`${m[1]}-${m[2]}`]}-${part}`, v]];
    }
  }
  if (prop === 'border' || /^border-(top|right|bottom|left)$/.test(prop) || /^border-(inline|block)(-(start|end))?$/.test(prop)) {
    const parts = borderParts(v);
    let sides;
    if (prop === 'border') sides = SIDES;
    else if ((m = /^border-(top|right|bottom|left)$/.exec(prop))) sides = [m[1]];
    else if ((m = /^border-(inline|block)$/.exec(prop))) sides = logicalPair[m[1]];
    else { m = /^border-(inline|block)-(start|end)$/.exec(prop); sides = [logicalSide[`${m[1]}-${m[2]}`]]; }
    return sides.flatMap((s) => ['width', 'style', 'color'].map((p) => [`border-${s}-${p}`, parts[p]]));
  }
  if (prop === 'border-radius') {
    if (itemsOf(v).some((x) => x.t === 'slash')) return [[prop, v]];
    const b = box(v);
    return b ? CORNERS.map((c, i) => [`border-${c}-radius`, b[i]]) : [[prop, v]];
  }
  if ((m = /^border-(start-start|start-end|end-start|end-end)-radius$/.exec(prop))) return [[`border-${logicalCorner[m[1]]}-radius`, v]];

  if (prop === 'outline') {
    const parts = borderParts(v);
    return [['outline-width', parts.width], ['outline-style', parts.style], ['outline-color', parts.color]];
  }
  if (prop === 'overflow') {
    const p = pair(v);
    return p ? [['overflow-x', p[0]], ['overflow-y', p[1]]] : [[prop, v]];
  }
  if (prop === 'gap') {
    const p = pair(v);
    return p ? [['row-gap', p[0]], ['column-gap', p[1]]] : [[prop, v]];
  }
  if (prop === 'background') {
    if (v.t === 'kw' && v.v === 'none') return [['background-color', { t: 'color', argb: 0, src: 'transparent' }], ['background-image', v]];
    if (v.t === 'color' || (v.t === 'var' && v.token) || (v.t === 'fn' && v.name === 'color-mix')) {
      return [['background-color', v], ['background-image', { t: 'kw', v: 'none' }]];
    }
    return [[prop, v]];
  }
  if (prop === 'inline-size') return [['width', v]];
  if (prop === 'block-size') return [['height', v]];
  if ((m = /^(min|max)-(inline|block)-size$/.exec(prop))) return [[`${m[1]}-${m[2] === 'inline' ? 'width' : 'height'}`, v]];
  return [[prop, v]];
}
