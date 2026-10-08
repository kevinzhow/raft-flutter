#!/usr/bin/env node
// Extract every tailwind-variants recipe (`tv$1({...})` call) from the compiled
// raft-ui bundle and statically evaluate its literal options object.
//
// Output: build/recipes/recipes.raw.json
//
// Usage: node tool/recipes/extract.mjs [--source /tmp/rui] [--out build/recipes]
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as acorn from 'acorn';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

export const sourceRoot = arg('source', process.env.RAFT_UI_SOURCE ?? '/tmp/rui');
const outDir = resolve(repo, arg('out', 'build/recipes'));
const TV_CALLEE = 'tv$1';

const file = join(sourceRoot, 'dist/index.mjs');
const code = readFileSync(file, 'utf8');
const pkg = JSON.parse(readFileSync(join(sourceRoot, 'package.json'), 'utf8'));

const comments = [];
const ast = acorn.parse(code, {
  ecmaVersion: 'latest',
  sourceType: 'module',
  locations: true,
  onComment: comments,
});

// `//#region src/components/button/button.tsx` markers emitted by the bundler.
const regions = [];
for (const c of comments) {
  const m = /^#region (.+)$/.exec(c.value.trim());
  if (m) regions.push({ start: c.start, path: m[1] });
}
function regionAt(pos) {
  let found = null;
  for (const r of regions) if (r.start <= pos) found = r.path;
  return found;
}

// Generic child iteration over ESTree nodes.
function* children(node) {
  for (const key of Object.keys(node)) {
    if (key === 'loc' || key === 'start' || key === 'end') continue;
    const v = node[key];
    if (Array.isArray(v)) {
      for (const c of v) if (c && typeof c.type === 'string') yield c;
    } else if (v && typeof v.type === 'string') {
      yield v;
    }
  }
}

function walk(node, visit, parents = []) {
  visit(node, parents);
  parents.push(node);
  for (const c of children(node)) walk(c, visit, parents);
  parents.pop();
}

// Top-level declarations: name -> node (for identifier resolution and usage).
const topLevel = new Map();
for (const stmt of ast.body) {
  if (stmt.type === 'VariableDeclaration') {
    for (const d of stmt.declarations) if (d.id.type === 'Identifier') topLevel.set(d.id.name, { kind: stmt.kind, node: d, stmt });
  } else if (stmt.type === 'FunctionDeclaration' && stmt.id) {
    topLevel.set(stmt.id.name, { kind: 'function', node: stmt, stmt });
  }
}

// Exports: local -> [exported names].
const exportsByLocal = new Map();
for (const stmt of ast.body) {
  if (stmt.type !== 'ExportNamedDeclaration') continue;
  for (const s of stmt.specifiers ?? []) {
    const local = s.local.name ?? s.local.value;
    const exported = s.exported.name ?? s.exported.value;
    if (!exportsByLocal.has(local)) exportsByLocal.set(local, []);
    exportsByLocal.get(local).push(exported);
  }
  if (stmt.declaration) {
    const d = stmt.declaration;
    const names = d.type === 'VariableDeclaration' ? d.declarations.map((x) => x.id.name) : [d.id.name];
    for (const n of names) exportsByLocal.set(n, [...(exportsByLocal.get(n) ?? []), n]);
  }
}

const src = (n) => code.slice(n.start, n.end);

// Static evaluation of literal option objects. Anything that is not a plain
// literal is recorded as {$nonLiteral: source} and reported.
function evaluate(node, ctx, path) {
  switch (node.type) {
    case 'Literal':
      return node.value;
    case 'TemplateLiteral':
      if (node.expressions.length === 0) return node.quasis[0].value.cooked;
      break;
    case 'ArrayExpression': {
      const out = [];
      node.elements.forEach((e, i) => {
        if (!e) return out.push(null);
        if (e.type === 'SpreadElement') {
          const v = evaluate(e.argument, ctx, `${path}[${i}]`);
          if (Array.isArray(v)) return out.push(...v);
          ctx.nonLiteral.push({ path: `${path}[${i}]`, source: src(e) });
          return out.push({ $nonLiteral: src(e) });
        }
        out.push(evaluate(e, ctx, `${path}[${i}]`));
      });
      return out;
    }
    case 'ObjectExpression': {
      const out = {};
      for (const p of node.properties) {
        if (p.type !== 'Property' || p.computed) {
          ctx.nonLiteral.push({ path, source: src(p) });
          continue;
        }
        const key = p.key.type === 'Identifier' ? p.key.name : String(p.key.value);
        out[key] = evaluate(p.value, ctx, `${path}.${key}`);
      }
      return out;
    }
    case 'UnaryExpression':
      if (node.operator === '!' && node.argument.type === 'Literal') return !node.argument.value;
      if (node.operator === '-' && node.argument.type === 'Literal') return -node.argument.value;
      // `void 0` is the minifier's spelling of `undefined`.
      if (node.operator === 'void' && node.argument.type === 'Literal') return null;
      break;
    case 'Identifier': {
      if (node.name === 'undefined') return null;
      const decl = topLevel.get(node.name);
      if (decl && decl.kind === 'const' && decl.node.init) {
        ctx.resolvedIdentifiers.push({ path, name: node.name });
        return evaluate(decl.node.init, ctx, path);
      }
      break;
    }
    case 'CallExpression':
      if (node.callee.type === 'Identifier' && node.callee.name === TV_CALLEE) {
        const inner = callNames.get(node);
        return { $recipe: inner };
      }
      break;
  }
  ctx.nonLiteral.push({ path, source: src(node) });
  return { $nonLiteral: src(node) };
}

// Pass 1: find tv$1 calls and name them.
const calls = [];
const callNames = new Map();
walk(ast, (node, parents) => {
  if (node.type !== 'CallExpression' || node.callee.type !== 'Identifier' || node.callee.name !== TV_CALLEE) return;
  calls.push({ node, parents: [...parents] });
});
// Name outer calls first so nested `extend: tv$1(...)` can derive from them.
for (const { node, parents } of calls) {
  const parent = parents[parents.length - 1];
  if (parent?.type === 'VariableDeclarator' && parent.id.type === 'Identifier') callNames.set(node, parent.id.name);
}
for (const { node, parents } of calls) {
  if (callNames.has(node)) continue;
  // Find the nearest named outer tv$1 call and the property key chain.
  let name = null;
  const keys = [];
  for (let i = parents.length - 1; i >= 0; i--) {
    const p = parents[i];
    if (p.type === 'Property') keys.unshift(p.key.name ?? p.key.value);
    if (callNames.has(p)) {
      name = `${callNames.get(p)}$${keys.join('$')}`;
      break;
    }
    if (p.type === 'VariableDeclarator' && p.id.type === 'Identifier') {
      name = `${p.id.name}$${keys.join('$') || 'anonymous'}`;
      break;
    }
  }
  callNames.set(node, name ?? `anonymous$${node.start}`);
}

// Pass 2: usages of recipe bindings in top-level functions/consts.
function enclosingTopLevel(parents) {
  for (const p of parents) {
    if (p.type === 'FunctionDeclaration' && p.id && topLevel.get(p.id.name)?.node === p) return p.id.name;
    if (p.type === 'VariableDeclarator' && p.id.type === 'Identifier' && topLevel.get(p.id.name)?.node === p) return p.id.name;
  }
  return null;
}
const recipeNames = new Set([...callNames.values()]);
const usage = new Map(); // recipe -> Map(user -> Set(keys))
walk(ast, (node, parents) => {
  if (node.type !== 'Identifier' || !recipeNames.has(node.name)) return;
  const parent = parents[parents.length - 1];
  if (parent?.type === 'VariableDeclarator' && parent.id === node) return;
  if (parent?.type === 'Property' && parent.key === node && !parent.shorthand) return;
  if (parent?.type === 'MemberExpression' && parent.property === node && !parent.computed) return;
  const user = enclosingTopLevel(parents);
  if (!user || user === node.name) return;
  if (!usage.has(node.name)) usage.set(node.name, new Map());
  const m = usage.get(node.name);
  if (!m.has(user)) m.set(user, new Set());
  // Record which variant props a direct call passes: recipe({theme, size}).
  if (parent?.type === 'CallExpression' && parent.callee === node) {
    const a = parent.arguments[0];
    if (a?.type === 'ObjectExpression') {
      for (const p of a.properties) if (p.type === 'Property' && !p.computed) m.get(user).add(p.key.name ?? String(p.key.value));
    }
  }
});

// Transitive exported components that use each recipe (through local helpers).
const references = new Map(); // top-level name -> Set(top-level users)
walk(ast, (node, parents) => {
  if (node.type !== 'Identifier' || !topLevel.has(node.name)) return;
  const parent = parents[parents.length - 1];
  if (parent?.type === 'VariableDeclarator' && parent.id === node) return;
  if (parent?.type === 'FunctionDeclaration' && parent.id === node) return;
  if (parent?.type === 'Property' && parent.key === node && !parent.shorthand) return;
  if (parent?.type === 'MemberExpression' && parent.property === node && !parent.computed) return;
  const user = enclosingTopLevel(parents);
  if (!user || user === node.name) return;
  if (!references.has(node.name)) references.set(node.name, new Set());
  references.get(node.name).add(user);
});
function exportedUsers(name) {
  const seen = new Set([name]);
  const queue = [name];
  const out = new Set();
  while (queue.length) {
    const n = queue.shift();
    for (const e of exportsByLocal.get(n) ?? []) if (n !== name) out.add(e);
    for (const u of references.get(n) ?? []) {
      if (seen.has(u)) continue;
      seen.add(u);
      // Only follow through direct users of the recipe and helpers one level
      // removed; stop at exported components so Button users are not all
      // attributed to buttonVariants.
      if (exportsByLocal.has(u)) for (const e of exportsByLocal.get(u)) out.add(e);
      else queue.push(u);
    }
  }
  return [...out].sort();
}

const recipes = calls
  .map(({ node }) => {
    const name = callNames.get(node);
    const ctx = { nonLiteral: [], resolvedIdentifiers: [] };
    const options = node.arguments.length === 1 ? evaluate(node.arguments[0], ctx, 'options') : { $nonLiteral: src(node) };
    const direct = usage.get(name) ?? new Map();
    return {
      name,
      line: node.loc.start.line,
      region: regionAt(node.start),
      exported: exportsByLocal.get(name) ?? [],
      directUsers: [...direct.keys()].sort().map((u) => ({
        name: u,
        exportedAs: exportsByLocal.get(u) ?? [],
        variantProps: [...direct.get(u)].sort(),
      })),
      exportedComponents: exportedUsers(name),
      options,
      nonLiteral: ctx.nonLiteral,
      resolvedIdentifiers: ctx.resolvedIdentifiers,
    };
  })
  .sort((a, b) => a.line - b.line);

// Sanity: count raw `tv$1(` occurrences so the test can assert full coverage.
const rawCallCount = (code.match(/\btv\$1\(/g) ?? []).length;

// The bundle's own `tv$1` wrapper (tailwind-variants + raft-ui cn), kept as
// source so resolve.mjs evaluates recipes exactly like the Web runtime.
const wrapperDecl = topLevel.get(TV_CALLEE);
const tvWrapperSource = wrapperDecl ? src(wrapperDecl.node.init) : null;
const tvImport = ast.body
  .filter((s) => s.type === 'ImportDeclaration' && s.specifiers.some((x) => x.local.name === 'tv'))
  .map((s) => src(s))[0] ?? null;

const out = {
  source: {
    package: pkg.name,
    version: pkg.version,
    file: 'dist/index.mjs',
    sha256: createHash('sha256').update(code).digest('hex'),
  },
  tvImport,
  tvWrapperSource,
  rawCallCount,
  recipeCount: recipes.length,
  recipes,
};
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'recipes.raw.json'), JSON.stringify(out, null, 2) + '\n');
const nonLit = recipes.filter((r) => r.nonLiteral.length);
console.log(`extract: ${recipes.length} recipes (${rawCallCount} tv$1 calls), ${nonLit.length} with non-literal parts`);
for (const r of nonLit) for (const n of r.nonLiteral) console.log(`  non-literal ${r.name} ${n.path}: ${n.source.slice(0, 80)}`);
