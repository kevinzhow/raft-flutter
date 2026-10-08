// Compile recipe classes with Tailwind v4's own compiler, using raft-ui's
// styles.css as the input stylesheet, and split the output back into
// per-utility layers.
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import postcss from 'postcss';
import { compile } from 'tailwindcss';
import { analyzeSelector, atRuleAtoms, flatten, specificity, unescapeIdent } from './selector.mjs';

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
export function splitOutput(css) {
  const root = postcss.parse(css);
  const utilities = new Map();
  const themeVars = new Map();
  const registered = new Map();
  const keyframes = new Map();
  let order = 0;
  root.walkAtRules((at) => {
    if (at.name === 'property') {
      let init = null;
      at.walkDecls('initial-value', (d) => { init = d.value; });
      registered.set(at.params.trim(), init);
    } else if (at.name === 'keyframes') {
      keyframes.set(at.params.trim(), at.toString());
    } else if (at.name === 'layer' && at.params.trim() === 'theme') {
      at.walkDecls((d) => { if (d.prop.startsWith('--')) themeVars.set(d.prop, d.value); });
    }
  });
  root.each((node) => {
    if (node.type !== 'atrule' || node.name !== 'layer' || node.params.trim() !== 'utilities') return;
    node.each((rule) => {
      if (rule.type !== 'rule') return;
      const selfSelector = rule.selector.trim();
      const candidate = unescapeIdent(selfSelector.slice(1));
      const layers = [];
      walkRule(rule, [selfSelector], [], selfSelector, layers);
      utilities.set(candidate, { order: order++, selfSelector, layers });
    });
  });
  return { css, utilities, themeVars, registered, keyframes };
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
