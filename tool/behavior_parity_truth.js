#!/usr/bin/env node
'use strict';
// Ground truth for tool/behavior-parity validation (see docs/behavior-parity/VALIDATION.md).
//
// Independent of the Python scanner: anchors are resolved on the TypeScript AST and a
// "semantic hash" is taken from the AST structure (node kinds and token texts, no
// trivia, so comments, whitespace, quote style and trailing commas do not count).
//
//   echo '[{"id":"X","path":"store/a.ts","symbol":"foo"}]' | node tool/behavior_parity_truth.js <web checkout root> [--elsewhere]
//
// TypeScript is found via require('typescript'), $TYPESCRIPT_PATH, or a few local fallbacks.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function loadTs() {
  const candidates = [process.env.TYPESCRIPT_PATH, 'typescript', '/home/kevinzhow/github/graph-code/node_modules/typescript'].filter(Boolean);
  for (const c of candidates) {
    try { return require(c); } catch (e) { /* try next */ }
  }
  console.error('error: typescript module not found; set TYPESCRIPT_PATH');
  process.exit(2);
}
const ts = loadTs();
const K = ts.SyntaxKind;

const root = process.argv[2];
const wantElsewhere = process.argv.includes('--elsewhere');
if (!root) { console.error('usage: behavior_parity_truth.js <web root> [--elsewhere] < anchors.json'); process.exit(2); }
const srcRoot = path.join(root, 'packages/web/src');

const fileCache = new Map();
function parse(rel) {
  if (fileCache.has(rel)) return fileCache.get(rel);
  const p = path.join(srcRoot, rel);
  let sf = null;
  if (fs.existsSync(p)) {
    const text = fs.readFileSync(p, 'utf8');
    sf = ts.createSourceFile(rel, text, ts.ScriptTarget.Latest, true, rel.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
  }
  fileCache.set(rel, sf);
  return sf;
}

// ---- semantic serialisation ------------------------------------------------
function ser(node, sf, out) {
  out.push(String(node.kind));
  switch (node.kind) {
    case K.Identifier: case K.PrivateIdentifier:
      out.push(node.text); break;
    case K.StringLiteral: case K.NoSubstitutionTemplateLiteral: case K.RegularExpressionLiteral:
      out.push(JSON.stringify(node.text !== undefined && node.kind !== K.RegularExpressionLiteral ? node.text : node.getText(sf))); break;
    case K.NumericLiteral: case K.BigIntLiteral:
      out.push(node.text); break;
    case K.TemplateHead: case K.TemplateMiddle: case K.TemplateTail:
      out.push(JSON.stringify(node.text)); break;
    case K.JsxText: {
      const t = node.text.replace(/\s+/g, ' ').trim();
      if (!t) { out.pop(); return; }
      out.push(JSON.stringify(t)); break;
    }
    case K.PrefixUnaryExpression: case K.PostfixUnaryExpression:
      out.push(String(node.operator)); break;
    case K.VariableDeclarationList:
      out.push(String(node.flags & ts.NodeFlags.BlockScoped)); break;
    default:
  }
  out.push('(');
  ts.forEachChild(node, (c) => ser(c, sf, out));
  out.push(')');
}
function hash(parts) { return crypto.createHash('sha256').update(parts.join('\u0001')).digest('hex').slice(0, 16); }
function semantic(nodes, sf) {
  const out = [];
  for (const n of nodes) { ser(n, sf, out); out.push('|'); }
  return hash(out);
}

// ---- resolution --------------------------------------------------------------
const isFn = (n) => ts.isFunctionDeclaration(n) || ts.isFunctionExpression(n) || ts.isArrowFunction(n) || ts.isMethodDeclaration(n) || ts.isGetAccessor(n) || ts.isSetAccessor(n) || ts.isConstructorDeclaration(n);
function fnDepth(n) { let d = 0; for (let p = n.parent; p; p = p.parent) if (isFn(p)) d++; return d; }
function nameText(n) {
  const nm = n.name;
  if (!nm) return null;
  if (ts.isIdentifier(nm) || ts.isStringLiteral(nm) || ts.isNoSubstitutionTemplateLiteral(nm)) return nm.text;
  return null;
}
function isFunctionValue(init) {
  if (!init) return false;
  let e = init;
  while (ts.isParenthesizedExpression(e) || ts.isAsExpression(e) || ts.isSatisfiesExpression(e)) e = e.expression;
  if (ts.isArrowFunction(e) || ts.isFunctionExpression(e)) return true;
  if (ts.isCallExpression(e) && /^(use(Callback|Memo|Effect|LayoutEffect)|create)$/.test(e.expression.getText())) return true;
  return false;
}

// declarations of a name: returns [{node, kind, fnLike, depth}]
function declarations(sf, name) {
  const found = [];
  const visit = (n) => {
    let hit = null;
    if (ts.isFunctionDeclaration(n) && n.name && n.name.text === name && n.body) hit = { node: n, fnLike: true };
    else if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name) && n.name.text === name && n.initializer) hit = { node: n, fnLike: isFunctionValue(n.initializer) };
    else if ((ts.isPropertyAssignment(n) || ts.isMethodDeclaration(n) || ts.isPropertyDeclaration(n)) && nameText(n) === name) {
      if (ts.isMethodDeclaration(n)) { if (n.body) hit = { node: n, fnLike: true }; }
      else if (n.initializer) hit = { node: n, fnLike: isFunctionValue(n.initializer), prop: true };
    } else if ((ts.isClassDeclaration(n) || ts.isInterfaceDeclaration(n) || ts.isTypeAliasDeclaration(n) || ts.isEnumDeclaration(n)) && n.name && n.name.text === name) hit = { node: n, fnLike: false, typeLike: true };
    if (hit) { hit.depth = fnDepth(n); found.push(hit); }
    ts.forEachChild(n, visit);
  };
  visit(sf);
  return found;
}
function rank(d) { return d.fnLike ? 0 : d.typeLike ? 1 : d.prop ? 2 : 1; }
function primary(decls) {
  if (!decls.length) return [];
  const best = Math.min(...decls.map((d) => rank(d) * 1000 + d.depth));
  return decls.filter((d) => rank(d) * 1000 + d.depth === best);
}

function eventNodes(sf, event) {
  const nodes = [];
  const add = (n) => { if (n && !nodes.includes(n)) nodes.push(n); };
  const addIdent = (id) => primary(declarations(sf, id)).forEach((d) => add(d.node));
  const visit = (n) => {
    if (ts.isObjectLiteralExpression(n)) {
      const props = n.properties.filter((p) => ts.isPropertyAssignment(p) || ts.isShorthandPropertyAssignment(p));
      const ev = props.find((p) => ts.isPropertyAssignment(p) && nameText(p) === 'event' && (ts.isStringLiteral(p.initializer) || ts.isNoSubstitutionTemplateLiteral(p.initializer)) && p.initializer.text === event);
      const handler = props.find((p) => nameText(p) === 'handler');
      if (ev && handler) {
        add(n);
        if (ts.isShorthandPropertyAssignment(handler)) addIdent('handler');
        else if (ts.isIdentifier(handler.initializer)) addIdent(handler.initializer.text);
      }
    } else if (ts.isCallExpression(n) && ts.isPropertyAccessExpression(n.expression) && /^(on|once|addListener|addEventListener)$/.test(n.expression.name.text)
      && n.arguments.length >= 2 && (ts.isStringLiteral(n.arguments[0]) || ts.isNoSubstitutionTemplateLiteral(n.arguments[0])) && n.arguments[0].text === event) {
      const h = n.arguments[1];
      if (ts.isIdentifier(h)) addIdent(h.text); else add(h);
    } else if (ts.isCaseClause(n) && ts.isStringLiteral(n.expression) && n.expression.text === event) add(n);
    ts.forEachChild(n, visit);
  };
  visit(sf);
  return nodes;
}

function effectNodes(sf, ident) {
  const nodes = [];
  const visit = (n) => {
    if (ts.isCallExpression(n) && ts.isIdentifier(n.expression) && /^use(Layout)?Effect$/.test(n.expression.text)) {
      let has = false;
      const scan = (m) => { if (ts.isIdentifier(m) && m.text === ident) has = true; if (!has) ts.forEachChild(m, scan); };
      scan(n);
      if (has) nodes.push(n);
    }
    ts.forEachChild(n, visit);
  };
  visit(sf);
  return nodes;
}

function callStatements(sf, name) {
  return sf.statements.filter((s) => ts.isExpressionStatement(s) && ts.isCallExpression(s.expression) && ts.isIdentifier(s.expression.expression) && s.expression.expression.text === name);
}

function resolveIn(sf, symbol) {
  if (symbol.startsWith('event:')) return { nodes: eventNodes(sf, symbol.slice(6)), all: null };
  if (symbol.startsWith('effect:')) return { nodes: effectNodes(sf, symbol.slice(7)), all: null };
  const decls = declarations(sf, symbol);
  let nodes = primary(decls).map((d) => d.node);
  if (!nodes.length) nodes = callStatements(sf, symbol);
  return { nodes, all: decls.map((d) => d.node) };
}

function lines(sf, nodes) {
  return nodes.map((n) => [sf.getLineAndCharacterOfPosition(n.getStart(sf)).line + 1, sf.getLineAndCharacterOfPosition(n.getEnd()).line + 1]);
}

let allFiles = null;
function listFiles() {
  if (allFiles) return allFiles;
  allFiles = [];
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (!['node_modules', '__tests__', '__mocks__'].includes(e.name)) walk(p); }
      else if (/\.tsx?$/.test(e.name) && !e.name.endsWith('.d.ts') && !/\.(test|spec)\./.test(e.name)) allFiles.push(path.relative(srcRoot, p));
    }
  };
  walk(srcRoot);
  return allFiles.sort();
}

function elsewhere(symbol, exclude) {
  const needle = symbol.includes(':') && (symbol.startsWith('event:') || symbol.startsWith('effect:')) ? symbol.slice(symbol.indexOf(':') + 1) : symbol;
  const out = [];
  for (const rel of listFiles()) {
    if (rel === exclude) continue;
    const text = fs.readFileSync(path.join(srcRoot, rel), 'utf8');
    if (!text.includes(needle)) continue;
    const sf = parse(rel);
    const r = resolveIn(sf, symbol);
    if (!r.nodes.length) continue;
    if (!symbol.startsWith('event:') && !symbol.startsWith('effect:')) {
      // only real declarations count as a move target (not call statements, not bare object properties)
      const decls = declarations(sf, symbol);
      if (!decls.length || decls.every((d) => d.prop && !d.fnLike)) continue;
    }
    out.push({ path: rel, hash: semantic(r.nodes, sf), lines: lines(sf, r.nodes) });
  }
  return out;
}

const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const result = {};
for (const a of input) {
  const sf = parse(a.path);
  const rec = { found: false };
  if (sf) {
    rec.parseErrors = sf.parseDiagnostics.length;
    const r = resolveIn(sf, a.symbol);
    if (r.nodes.length) {
      rec.found = true;
      rec.hash = semantic(r.nodes, sf);
      rec.count = r.nodes.length;
      rec.lines = lines(sf, r.nodes);
      rec.kinds = r.nodes.map((n) => ts.SyntaxKind[n.kind]);
      if (r.all) { rec.allCount = r.all.length; rec.allHash = semantic(r.all, sf); }
      // single top-level declaration: whole statement lines (used by the mutation test to move/rename it)
      if (r.nodes.length === 1 && r.all) {
        let st = r.nodes[0];
        if (ts.isVariableDeclaration(st) && ts.isVariableDeclarationList(st.parent) && st.parent.declarations.length === 1) st = st.parent.parent;
        if (st.parent === sf && (ts.isFunctionDeclaration(st) || ts.isVariableStatement(st))) rec.move = lines(sf, [st])[0];
        if (ts.isFunctionDeclaration(r.nodes[0]) || ts.isVariableDeclaration(r.nodes[0])) rec.renamable = true;
      }
    }
  } else rec.noFile = true;
  if (!rec.found && wantElsewhere) rec.elsewhere = elsewhere(a.symbol, a.path);
  result[a.id] = rec;
}
process.stdout.write(JSON.stringify(result));
