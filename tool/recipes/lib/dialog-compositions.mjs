import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export function dialogProductSlots(text, ts) {
  const ast = ts.createSourceFile('DialogCard.tsx', text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  if (ast.parseDiagnostics.length) throw Error('Cannot parse DialogCard.tsx');
  const tags = new Map();
  const defaults = [];
  function walk(n) {
    if (ts.isJsxOpeningElement(n) || ts.isJsxSelfClosingElement(n)) {
      const name = n.tagName.getText(ast);
      if (!tags.has(name)) tags.set(name, []);
      tags.get(name).push(n);
    }
    if (ts.isBindingElement(n) && n.name.getText(ast) === 'maxWidthClass' && n.initializer) {
      if (!ts.isStringLiteral(n.initializer)) throw Error('DialogCard maxWidthClass default must be literal');
      defaults.push(n.initializer.text);
    }
    ts.forEachChild(n, walk);
  }
  walk(ast);
  function one(tag) {
    const matches = tags.get(tag) ?? [];
    if (matches.length !== 1) throw Error(`DialogCard: expected one ${tag}, got ${matches.length}`);
    return matches[0];
  }
  function attr(n, name) {
    return n.attributes.properties.find((p) => ts.isJsxAttribute(p) && p.name.getText(ast) === name)?.initializer;
  }
  function classes(tag) {
    const v = attr(one(tag), 'className');
    if (v && ts.isStringLiteral(v)) return v.text.split(/\s+/).filter(Boolean);
    if (v && ts.isJsxExpression(v) && ts.isTemplateExpression(v.expression)) {
      const template = v.expression;
      if (template.templateSpans.length !== 1 || template.templateSpans[0].expression.getText(ast) !== 'maxWidthClass') {
        throw Error(`DialogCard ${tag}: unsupported dynamic className`);
      }
      if (template.templateSpans[0].literal.text.trim()) throw Error('Unexpected className suffix');
      return template.head.text.trim().split(/\s+/).filter(Boolean);
    }
    throw Error(`DialogCard ${tag}: className must be an understood literal`);
  }
  if (defaults.length !== 1) throw Error('DialogCard: missing or ambiguous default width');
  const closeSize = attr(one('CloseButton'), 'size');
  const glyphSize = attr(one('X'), 'size');
  if (!closeSize || !ts.isStringLiteral(closeSize)) throw Error('DialogCard: nonliteral close size');
  if (closeSize.text !== 'icon-sm') throw Error('DialogCard: source close size changed; update the Button axis binding');
  if (!glyphSize || !ts.isJsxExpression(glyphSize) || !ts.isNumericLiteral(glyphSize.expression)) throw Error('DialogCard: nonliteral glyph size');
  return {root: classes('DialogSurface'), header: classes('div'), title: classes('h2'), close: classes('CloseButton'),
    defaultWidth: defaults[0].split(/\s+/), closeSize: closeSize.text, glyphSize: Number(glyphSize.expression.text)};
}

export function extractDialogCompositions(web, ts) {
  const path = 'src/components/ui/DialogCard.tsx';
  const text = readFileSync(join(web, path), 'utf8');
  const slots = dialogProductSlots(text, ts);
  return [{name: 'webDialogCard', line: 1,
    region: `Web ${path} sha256:${createHash('sha256').update(text).digest('hex')}`,
    exported: [], directUsers: [], exportedComponents: ['DialogCard'],
    options: {slots: {root: slots.root, header: slots.header, title: slots.title,
      close: slots.close, defaultWidth: slots.defaultWidth, glyph: `size-[${slots.glyphSize}px]`}},
    nonLiteral: [], resolvedIdentifiers: []}];
}
