// Compile recipe classes with Tailwind v4's own compiler, using raft-ui's
// styles.css as the input stylesheet, and split the output back into
// per-utility layers.
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import postcss from 'postcss';
import { compile } from 'tailwindcss';
import { analyzeSelector, atRuleAtoms, flatten, parseComplex, splitTopLevel, specificity, unescapeIdent } from './selector.mjs';

const require = createRequire(import.meta.url);
const twRoot = dirname(require.resolve('tailwindcss/package.json'));

export const WEB_THEME_PATH = fileURLToPath(new URL('../web-theme.css', import.meta.url));

// Mirrors the Web client's entry (packages/web/src/index.css): Tailwind, then
// raft-ui styles.css, then the Web's own @theme overrides (optional).
export function inputCss({ webTheme }) {
  return `@import "tailwindcss";\n@import "./styles.css";\n${webTheme ? '@import "raft-web-theme.css";\n' : ''}`;
}

export async function createCompiler(sourceRoot, { webTheme = true } = {}) {
  const base = join(sourceRoot, 'dist');
  const loadStylesheet = async (id, from) => {
    let path;
    if (id === 'raft-web-theme.css') path = WEB_THEME_PATH;
    else if (id === 'tailwindcss') path = join(twRoot, 'index.css');
    else if (id.startsWith('tailwindcss/')) path = join(twRoot, id.slice('tailwindcss/'.length));
    else if (!id.startsWith('.')) path = require.resolve(id);
    else path = resolve(from, id);
    return { path, base: dirname(path), content: readFileSync(path, 'utf8') };
  };
  return compile(inputCss({ webTheme }), { base, loadStylesheet, loadModule: async () => { throw new Error('plugins not supported'); } });
}

export function twVersion() {
  return JSON.parse(readFileSync(join(twRoot, 'package.json'), 'utf8')).version;
}

// Returns {css, utilities: Map(candidate -> {order, selfSelector, layers}),
//          themeVars: Map(name -> value), registered: Map(name -> initial|null),
//          keyframes: Map(name -> css)}
export function splitOutput(css, candidates = null) {
  const root = postcss.parse(css);
  const utilities = new Map();
  const themeVars = new Map();
  const registered = new Map();
  const keyframes = new Map();
  const conditionalThemeVars = new Map();
  let order = 0;
  root.walkAtRules((at) => {
    if (at.name === 'property') {
      let init = null;
      at.walkDecls('initial-value', (d) => { init = d.value; });
      registered.set(at.params.trim(), init);
    } else if (at.name === 'keyframes') {
      keyframes.set(at.params.trim(), at.toString());
    } else if (at.name === 'layer' && at.params.trim() === 'theme') {
      at.walkDecls((d) => {
        let p = d.parent;
        while (p && p !== at) { if (p.type === 'atrule' && p.name === 'media') return; p = p.parent; }
        if (d.prop.startsWith('--')) themeVars.set(d.prop, d.value);
      });
    }
  });
  root.walkRules((rule) => {
    if (!/:root\b/.test(rule.selector)) return;
    const atoms = [];
    if (rule.selector.trim() === ':root.dark') atoms.push('dark');
    for (let p = rule.parent; p; p = p.parent) if (p.type === 'atrule' && p.name === 'media')
      atoms.push(...atRuleAtoms(p.name, p.params, {unknown: []}));
    if (!atoms.some(a => /^(width|height|pointer-|dark)/.test(a))) return;
    const key = [...new Set(atoms)].sort().join('|');
    if (!conditionalThemeVars.has(key)) conditionalThemeVars.set(key, {atoms: key.split('|'), vars: new Map()});
    for (const d of rule.nodes ?? []) if (d.type === 'decl' && d.prop.startsWith('--'))
      conditionalThemeVars.get(key).vars.set(d.prop, d.value);
  });
  root.each((node) => {
    if (node.type !== 'atrule' || node.name !== 'layer' || node.params.trim() !== 'utilities') return;
    function visit(rule, inheritedAtoms = []) {
      if (rule.type === 'atrule') {
        const ctx = { unknown: [] };
        const extra = atRuleAtoms(rule.name, rule.params, ctx);
        for (const child of rule.nodes ?? []) visit(child, [...inheritedAtoms, ...extra]);
        return;
      }
      if (rule.type !== 'rule') return;
      // Tailwind 4.3 emits variants as flat selectors (including the owning
      // class inside :is). The complete selector is never a class name.
      function owner(selector) {
        for (const c of parseComplex(selector)) for (const x of c.simples) {
          if (x.kind === 'class' && (!candidates || candidates.has(unescapeIdent(x.name)))) return x;
          if (x.kind === 'pseudo-class' && x.args) {
            const found = owner(x.args);
            if (found) return found;
          }
        }
        return null;
      }
      const own = owner(rule.selector);
      if (!own) return; // authored non-class rule or unrequested utility
      const selfSelector = own.text;
      const candidate = unescapeIdent(own.name);
      const layers = [];
      walkRule(rule, [rule.selector], inheritedAtoms, selfSelector, layers);
      const previous = utilities.get(candidate);
      if (previous) previous.layers.push(...layers);
      else utilities.set(candidate, { order: order++, selfSelector, layers });
    }
    node.each((rule) => visit(rule));
  });
  // Ordinary helper classes (e.g. Web's narrow-dialog-enter) are not in
  // Tailwind's utilities layer. Retain their declarations and media states.
  if (candidates) root.walkRules((rule) => {
    const atoms = [];
    for (let p = rule.parent; p; p = p.parent) {
      if (p.type === 'atrule' && ['keyframes', 'property'].includes(p.name)) return;
      if (p.type === 'atrule' && p.name === 'layer' && p.params === 'utilities') return;
      if (p.type === 'atrule' && p.name === 'media') atoms.push(...atRuleAtoms(p.name, p.params, {unknown: []}));
    }
    for (const selector of splitTopLevel(rule.selector)) {
      const own = parseComplex(selector).flatMap(c => c.simples).find(x => x.kind === 'class' && candidates.has(unescapeIdent(x.name)));
      if (!own) continue;
      const candidate = unescapeIdent(own.name);
      const layers = [];
      walkRule(rule, [selector], atoms, own.text, layers);
      const previous = utilities.get(candidate);
      if (previous) previous.layers.push(...layers);
      else utilities.set(candidate, {order: -1, selfSelector: own.text, layers});
    }
  });
  const contexts = [...conditionalThemeVars.values()];
  for (const context of contexts) {
    const inherited = new Map();
    for (const ancestor of contexts) if (ancestor !== context && ancestor.atoms.every(a => context.atoms.includes(a)))
      for (const [name, value] of ancestor.vars) inherited.set(name, value);
    context.inheritedVars = inherited;
    context.vars = new Map([...inherited, ...context.vars]);
  }
  contexts.sort((a, b) => a.atoms.length - b.atoms.length);
  return { css, utilities, themeVars, conditionalThemeVars: contexts, registered, keyframes };
}

function walkRule(node, selectors, atoms, selfSelector, out) {
  const decls = [];
  for (const child of node.nodes ?? []) {
    if (child.type === 'decl') decls.push({ prop: child.prop, value: child.value, important: !!child.important });
  }
  if (decls.length) {
    for (const sel of selectors) {
      const a = analyzeSelector(sel, selfSelector);
      out.push({
        selector: sel,
        target: a.target,
        atoms: [...new Set([...a.atoms, ...atoms])],
        unknown: a.unknown,
        specificity: specificity(sel),
        decls,
      });
    }
  }
  for (const child of node.nodes ?? []) {
    if (child.type === 'rule') walkRule(child, flatten(selectors, child.selector), atoms, selfSelector, out);
    else if (child.type === 'atrule') {
      const ctx = { unknown: [] };
      const extra = atRuleAtoms(child.name, child.params, ctx);
      walkRule(child, selectors, [...atoms, ...extra], selfSelector, out);
    }
  }
}
